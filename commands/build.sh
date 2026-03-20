#!/usr/bin/env bash

# Build Command

# Source config if exists
if [[ -f ".ship-it.conf" ]]; then
    source ".ship-it.conf"
fi

# Override with arguments
CONFIG="${1:-$CONFIGURATION}"
CONFIG="${CONFIG:-Release}"

print_header "Building ${APP_NAME:-Project} ($CONFIG)"

# Ensure directories exist
mkdir -p "${BUILD_DIR:-build}"

if [[ "$PROJECT_TYPE" == "spm" ]]; then
    print_step 1 2 "Building with Swift Package Manager..."
    
    if [[ "$CONFIG" == "Release" ]]; then
        xcrun swift build -c release
        BIN_PATH=$(xcrun swift build -c release --show-bin-path)/${APP_NAME}
    else
        xcrun swift build
        BIN_PATH=$(xcrun swift build --show-bin-path)/${APP_NAME}
    fi
    
    if [[ -f "$BIN_PATH" ]]; then
        cp "$BIN_PATH" "${BUILD_DIR:-build}/"
        print_success "Build complete: ${BUILD_DIR:-build}/$(basename "$BIN_PATH")"
    else
        print_error "Build failed: Binary not found at $BIN_PATH"
        exit 1
    fi

elif [[ "$PROJECT_TYPE" == "xcode" ]]; then
    print_step 1 2 "Building with xcodebuild..."
    
    XCODEPROJ=$(ls -d *.xcodeproj | head -1)
    XCODEWS=$(ls -d *.xcworkspace 2>/dev/null | head -1)
    
    BUILD_CMD="xcodebuild"
    if [[ -n "$XCODEWS" ]]; then
        BUILD_CMD+=" -workspace $XCODEWS"
    else
        BUILD_CMD+=" -project $XCODEPROJ"
    fi
    
    $BUILD_CMD \
        -scheme "${SCHEME:-$APP_NAME}" \
        -configuration "$CONFIG" \
        -derivedDataPath "${BUILD_DIR:-build}/DerivedData" \
        -destination 'platform=macOS' \
        build
        
    APP_PATH="${BUILD_DIR:-build}/DerivedData/Build/Products/$CONFIG/${APP_NAME}.app"
    if [[ -d "$APP_PATH" ]]; then
        cp -R "$APP_PATH" "${BUILD_DIR:-build}/"
        print_success "Build complete: ${BUILD_DIR:-build}/${APP_NAME}.app"
    else
        print_error "Build failed: App not found at $APP_PATH"
        exit 1
    fi
else
    print_error "Unsupported project type: $PROJECT_TYPE"
    exit 1
fi
