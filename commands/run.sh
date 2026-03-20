#!/usr/bin/env bash

# Run Command

if [[ -f ".ship-it.conf" ]]; then
    source ".ship-it.conf"
fi

print_header "Running ${APP_NAME:-Project}"

APP_BUNDLE="${BUILD_DIR:-build}/${APP_NAME}.app"
APP_BINARY="${BUILD_DIR:-build}/${APP_NAME}"

if [[ -d "$APP_BUNDLE" ]]; then
    print_info "Opening $APP_BUNDLE..."
    open "$APP_BUNDLE"
elif [[ -f "$APP_BINARY" ]]; then
    print_info "Executing $APP_BINARY..."
    "$APP_BINARY" "$@"
else
    print_warning "App not found in build directory. Building first..."
    source "${SCRIPT_DIR}/commands/build.sh" Debug
    
    if [[ -d "$APP_BUNDLE" ]]; then
        open "$APP_BUNDLE"
    elif [[ -f "$APP_BINARY" ]]; then
        "$APP_BINARY" "$@"
    else
        print_error "Failed to run. Build did not produce expected output."
        exit 1
    fi
fi
