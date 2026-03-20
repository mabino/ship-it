#!/usr/bin/env bash

print_header "Scaffolding ship-it"

PROJECT_ROOT=$(pwd)
CONFIG_FILE="${PROJECT_ROOT}/.ship-it.conf"

print_step 1 3 "Detecting project type..."

PROJECT_TYPE="unknown"
if [[ -f "Package.swift" ]]; then
    PROJECT_TYPE="spm"
    _DETECTED_APP_NAME=$(grep "name:" Package.swift | head -1 | cut -d'"' -f2)
    print_success "Detected SPM project: $_DETECTED_APP_NAME"
    APP_NAME="$_DETECTED_APP_NAME"
    prompt_input "Project name" APP_NAME
elif ls *.xcodeproj >/dev/null 2>&1; then
    PROJECT_TYPE="xcode"
    XCODEPROJ=$(ls -d *.xcodeproj | head -1)
    _DETECTED_APP_NAME=$(basename "$XCODEPROJ" .xcodeproj)
    print_success "Detected Xcode project: $_DETECTED_APP_NAME"
    APP_NAME="$_DETECTED_APP_NAME"
    prompt_input "Project name" APP_NAME
else
    print_warning "Could not detect project type. Using defaults."
    prompt_input "Enter project name" APP_NAME
fi

print_step 2 3 "Creating configuration..."

if [[ -f "$CONFIG_FILE" ]]; then
    if ! prompt_confirm "Configuration file already exists. Overwrite?" "OVERWRITE_CONFIG"; then
        print_info "Skipping configuration creation."
    else
        rm "$CONFIG_FILE"
    fi
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    cat <<EOF > "$CONFIG_FILE"
# ship-it configuration for $APP_NAME
APP_NAME="$APP_NAME"
PROJECT_TYPE="$PROJECT_TYPE"
BUILD_DIR="build"
DIST_DIR="dist"
SCHEME="$APP_NAME"
CONFIGURATION="Release"
EOF
    print_success "Created .ship-it.conf"
fi

print_step 3 3 "Setting up project scripts..."

# Create a 'ship' shortcut script in project root
cat <<EOF > "ship"
#!/usr/bin/env bash
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
# Path to ship-it submodule or directory
SHIP_IT_PATH="\${SCRIPT_DIR}/ship-it/ship-it.sh"
if [[ ! -f "\$SHIP_IT_PATH" ]]; then
    # Fallback if called from within submodule or other location
    SHIP_IT_PATH="\${SCRIPT_DIR}/ship-it.sh"
fi

if [[ ! -f "\$SHIP_IT_PATH" ]]; then
    echo "Error: ship-it.sh not found at \$SHIP_IT_PATH"
    exit 1
fi

exec bash "\$SHIP_IT_PATH" "\$@"
EOF
chmod +x "ship"
print_success "Created './ship' shortcut script"

print_header "Scaffolding Complete!"
print_info "You can now use './ship build', './ship run', etc."
print_info "Edit .ship-it.conf to customize your build settings."
