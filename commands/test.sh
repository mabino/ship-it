#!/usr/bin/env bash

# Test Command

if [[ -f ".ship-it.conf" ]]; then
    source ".ship-it.conf"
fi

print_header "Testing ${APP_NAME:-Project}"

if [[ "$PROJECT_TYPE" == "spm" ]]; then
    xcrun swift test
elif [[ "$PROJECT_TYPE" == "xcode" ]]; then
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
        -destination 'platform=macOS' \
        test
else
    print_error "Unsupported project type for tests: $PROJECT_TYPE"
    exit 1
fi
