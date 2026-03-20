#!/usr/bin/env bash

# Release Command

if [[ -f ".ship-it.conf" ]]; then
    source ".ship-it.conf"
fi

print_header "${ROCKET} GitHub Release"

# Check if gh CLI is installed
if ! command -v gh >/dev/null 2>&1; then
    print_error "GitHub CLI (gh) is not installed. Please install it with: brew install gh"
    exit 1
fi

# Ensure user is logged in
if ! gh auth status >/dev/null 2>&1; then
    print_warning "Not logged in to GitHub CLI. Please run: gh auth login"
    exit 1
fi

DIST_DIR="${DIST_DIR:-dist}"
ZIP_NAME="${APP_NAME}.zip"
RELEASE_ARCHIVE="${DIST_DIR}/${ZIP_NAME}"

if [[ ! -f "$RELEASE_ARCHIVE" ]]; then
    print_warning "Release archive not found. Notarizing first..."
    source "${SCRIPT_DIR}/commands/notarize.sh"
fi

# Get version from app if possible
print_step 1 3 "Gathering release information..."
VERSION="1.0.0" # Default
if [[ -d "${BUILD_DIR:-build}/${APP_NAME}.app" ]]; then
    PLIST="${BUILD_DIR:-build}/${APP_NAME}.app/Contents/Info.plist"
    VERSION=$(defaults read "${PROJECT_ROOT}/${PLIST}" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")
fi

prompt_input "Release tag (e.g., v$VERSION)" RELEASE_TAG
RELEASE_TAG="${RELEASE_TAG:-v$VERSION}"

prompt_input "Release title" RELEASE_TITLE
RELEASE_TITLE="${RELEASE_TITLE:-$APP_NAME $RELEASE_TAG}"

prompt_input "Release notes" RELEASE_NOTES
RELEASE_NOTES="${RELEASE_NOTES:-Initial release of $APP_NAME $RELEASE_TAG. Notarized and stapled.}"

print_step 2 3 "Creating release on GitHub..."

if prompt_confirm "Create release $RELEASE_TAG and upload archive?" "CONFIRM_RELEASE"; then
    gh release create "$RELEASE_TAG" "$RELEASE_ARCHIVE" \
        --title "$RELEASE_TITLE" \
        --notes "$RELEASE_NOTES"
    print_success "Release created and archive uploaded!"
else
    print_info "Release aborted."
fi

print_step 3 3 "Cleanup..."
if prompt_confirm "Clean up build and dist directories?" "CONFIRM_CLEANUP"; then
    rm -rf "${BUILD_DIR:-build}" "${DIST_DIR:-dist}"
    print_success "Cleanup complete."
fi

print_header "${SPARKLES} Release Process Complete!"
