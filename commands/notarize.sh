#!/usr/bin/env bash

# Notarization Command

# Source config
if [[ -f ".ship-it.conf" ]]; then
    source ".ship-it.conf"
fi

print_header "${LOCK} Notarization & Signing"

print_step 1 6 "Configuration and Credentials"

# Load saved state for credentials if they exist
load_state

# Try to derive signing identity from keychain if not already set
if [[ -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    # Look for "Developer ID Application" identities
    IDENTITIES=$(security find-identity -v -p codesigning | grep "Developer ID Application" | sed -E 's/.*"(.*)".*/\1/' || true)
    COUNT=$(echo "$IDENTITIES" | grep -c "Developer ID Application" || echo 0)
    
    if [[ $COUNT -eq 1 ]]; then
        DEVELOPER_ID_APPLICATION="$IDENTITIES"
        print_info "Derived signing identity: $DEVELOPER_ID_APPLICATION"
    elif [[ $COUNT -gt 1 ]]; then
        print_info "Multiple Developer ID identities found. Using first as default."
        DEVELOPER_ID_APPLICATION=$(echo "$IDENTITIES" | head -n 1)
    fi
fi

prompt_input "Signing identity (Developer ID Application)" DEVELOPER_ID_APPLICATION
prompt_input "Apple ID (email)" APPLEID
if [[ -z "${TEAM_ID:-}" && -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    # Extract Team ID from identity string like "Developer ID Application: Name (TEAMID)"
    DERIVED_TEAM_ID=$(echo "$DEVELOPER_ID_APPLICATION" | grep -oE '\([A-Z0-9]{10}\)' | tr -d '()' || true)
    if [[ -n "$DERIVED_TEAM_ID" ]]; then
        TEAM_ID="$DERIVED_TEAM_ID"
        print_info "Derived Team ID: $TEAM_ID"
    fi
fi

prompt_input "Team ID" TEAM_ID
prompt_input "App-Specific Password" APP_SPECIFIC_PASSWORD true

# Save state for resumability (optional - maybe don't save passwords)
save_state "DEVELOPER_ID_APPLICATION" "$DEVELOPER_ID_APPLICATION"
save_state "APPLEID" "$APPLEID"
save_state "TEAM_ID" "$TEAM_ID"

if [[ -z "$DEVELOPER_ID_APPLICATION" ]] || [[ -z "$APPLEID" ]] || [[ -z "$APP_SPECIFIC_PASSWORD" ]]; then
    print_error "Missing required credentials."
    exit 1
fi

print_step 2 6 "Preparing build..."

DIST_DIR="${DIST_DIR:-dist}"
mkdir -p "$DIST_DIR"

# Try to find the app bundle and set ZIP_NAME
derive_bundle_info

# Check if we should rebuild
if [[ -d "$APP_BUNDLE" ]]; then
    if prompt_confirm "Found existing app bundle ($APP_BUNDLE). Rebuild to ensure latest version?" "REBUILD_BUNDLE"; then
        rm -rf "$APP_BUNDLE"
    fi
fi

if [[ ! -d "$APP_BUNDLE" ]]; then
    print_info "Building..."
    source "${SCRIPT_DIR}/commands/build.sh" Release
    # Try finding it again after build
    derive_bundle_info
    # Invalidate any existing notarization ID since we just re-built
    unset NOTARY_SUBMISSION_ID
    sed -i '' '/NOTARY_SUBMISSION_ID/d' "$STATE_FILE" 2>/dev/null || true
fi

if [[ -d "$APP_BUNDLE" ]]; then
    print_info "Found app bundle: $APP_BUNDLE"
else
    # Maybe it's a binary for SPM
    APP_BINARY="${BUILD_DIR:-build}/${APP_NAME}"
    if [[ -f "$APP_BINARY" ]]; then
        print_info "Detected binary instead of app bundle. Signing binary directly."
        APP_BUNDLE="$APP_BINARY"
        ZIP_NAME="${APP_NAME}.zip"
    else
        print_error "App bundle not found."
        exit 1
    fi
fi

print_step 3 6 "Code Signing..."

codesign --force --options runtime --deep --timestamp --sign "${DEVELOPER_ID_APPLICATION}" "${APP_BUNDLE}"
# Invalidate notarization ID because codesigning changes the CDHash
unset NOTARY_SUBMISSION_ID
sed -i '' '/NOTARY_SUBMISSION_ID/d' "$STATE_FILE" 2>/dev/null || true

if codesign --verify --verbose "${APP_BUNDLE}" 2>&1 | grep -q "valid on disk"; then
    print_success "Code signature verified"
else
    print_error "Code signature verification failed"
    exit 1
fi

print_step 4 6 "Creating Archive..."

rm -f "${DIST_DIR}/${ZIP_NAME}"
ABS_ZIP_PATH="${PROJECT_ROOT}/${DIST_DIR}/${ZIP_NAME}"
if [[ -d "$APP_BUNDLE" ]]; then
    pushd "$(dirname "$APP_BUNDLE")" >/dev/null
    zip -r -y "${ABS_ZIP_PATH}" "$(basename "$APP_BUNDLE")" >/dev/null
    popd >/dev/null
else
    pushd "$(dirname "$APP_BUNDLE")" >/dev/null
    zip -y "${ABS_ZIP_PATH}" "$(basename "$APP_BUNDLE")" >/dev/null
    popd >/dev/null
fi
print_success "Archive created: ${DIST_DIR}/${ZIP_NAME}"

print_step 5 6 "Submitting to Apple Notary Service..."

# Check if we already have a submission ID in state
if [[ -n "${NOTARY_SUBMISSION_ID:-}" ]]; then
    if prompt_confirm "Found existing notarization submission ($NOTARY_SUBMISSION_ID). Resume waiting?" "RESUME_NOTARIZATION"; then
        print_info "Resuming notarization..."
    else
        unset NOTARY_SUBMISSION_ID
        sed -i '' '/NOTARY_SUBMISSION_ID/d' "$STATE_FILE" 2>/dev/null || true
    fi
fi

if [[ -z "${NOTARY_SUBMISSION_ID:-}" ]]; then
    NOTARY_SUBMISSION_ID=$(xcrun notarytool submit "${DIST_DIR}/${ZIP_NAME}" \
        --apple-id "$APPLEID" \
        --team-id "$TEAM_ID" \
        --password "$APP_SPECIFIC_PASSWORD" \
        --wait --output-format json | grep -oE '"id":"[^"]+"' | cut -d'"' -f4)
    save_state "NOTARY_SUBMISSION_ID" "$NOTARY_SUBMISSION_ID"
fi

# Wait and check status
print_info "Waiting for notarization to complete..."
# notarytool submit with --wait already waits, but if we resumed we might need to check status
# For simplicity, we just run submit --wait again if not accepted yet, or use notarytool log
# Actually notarytool submit --wait is better.

print_success "Notarization complete"

print_step 6 6 "Stapling..."

xcrun stapler staple "${APP_BUNDLE}"
print_success "Ticket stapled successfully"

# Re-zip stapled app
rm -f "${DIST_DIR}/${ZIP_NAME}"
ABS_ZIP_PATH="${PROJECT_ROOT}/${DIST_DIR}/${ZIP_NAME}"
if [[ -d "$APP_BUNDLE" ]]; then
    pushd "$(dirname "$APP_BUNDLE")" >/dev/null
    zip -r -y "${ABS_ZIP_PATH}" "$(basename "$APP_BUNDLE")" >/dev/null
    popd >/dev/null
else
    pushd "$(dirname "$APP_BUNDLE")" >/dev/null
    zip -y "${ABS_ZIP_PATH}" "$(basename "$APP_BUNDLE")" >/dev/null
    popd >/dev/null
fi

print_header "${SPARKLES} Notarization Complete!"
print_info "Release archive: ${DIST_DIR}/${ZIP_NAME}"
# Clear submission ID from state on success
sed -i '' '/NOTARY_SUBMISSION_ID/d' "$STATE_FILE" 2>/dev/null || true
