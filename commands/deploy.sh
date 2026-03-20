#!/usr/bin/env bash

# Deploy Command (App Store Publication)

if [[ -f ".ship-it.conf" ]]; then
    source ".ship-it.conf"
fi

print_header "${ROCKET} App Store Publication"

if [[ "$PROJECT_TYPE" != "xcode" ]]; then
    print_error "Deploy is currently only supported for Xcode projects."
    exit 1
fi

print_step 1 4 "Configuration"

load_state

prompt_input "Apple Developer Team ID (10-character alphanumeric)" TEAM_ID
save_state "TEAM_ID" "$TEAM_ID"

if [[ -z "$TEAM_ID" ]]; then
    print_error "Team ID is required for App Store submission."
    exit 1
fi

BUILD_DIR="${BUILD_DIR:-build}"
ARCHIVE_PATH="$BUILD_DIR/${APP_NAME}.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"

mkdir -p "$BUILD_DIR"

print_step 2 4 "Creating ExportOptions.plist..."

cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>destination</key>
    <string>upload</string>
</dict>
</plist>
PLIST
print_success "ExportOptions.plist generated."

print_step 3 4 "Archiving Project..."

XCODEPROJ=$(ls -d *.xcodeproj | head -1)
XCODEWS=$(ls -d *.xcworkspace 2>/dev/null | head -1)

BUILD_CMD="xcodebuild"
if [[ -n "$XCODEWS" ]]; then
    BUILD_CMD+=" -workspace $XCODEWS"
else
    BUILD_CMD+=" -project $XCODEPROJ"
fi

if prompt_confirm "Build release archive now?" "CONFIRM_ARCHIVE"; then
    $BUILD_CMD archive \
        -scheme "${SCHEME:-$APP_NAME}" \
        -destination "generic/platform=iOS" \
        -archivePath "$ARCHIVE_PATH" \
        CODE_SIGN_STYLE=Automatic \
        -quiet
    
    if [[ -d "$ARCHIVE_PATH" ]]; then
        print_success "Archive created at $ARCHIVE_PATH"
    else
        print_error "Archive creation failed."
        exit 1
    fi
else
    if [[ ! -d "$ARCHIVE_PATH" ]]; then
        print_error "No archive found to deploy."
        exit 1
    fi
    print_info "Using existing archive at $ARCHIVE_PATH"
fi

print_step 4 4 "Exporting and Uploading to App Store Connect..."

if prompt_confirm "Upload to App Store Connect? (This requires active Xcode session credentials)" "CONFIRM_UPLOAD"; then
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS" \
        -exportPath "$EXPORT_PATH" \
        -quiet
        
    if [[ $? -eq 0 ]]; then
        print_success "Successfully uploaded to App Store Connect!"
    else
        print_error "Upload failed. Check Xcode account authentication."
        exit 1
    fi
else
    print_info "Upload skipped. You can manually upload using Xcode Organizer."
fi

print_header "${SPARKLES} Deploy Process Complete!"
