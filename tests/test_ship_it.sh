#!/usr/bin/env bash

set -e

# Mocking tools for testing
MOCK_DIR="$(pwd)/mock_bin"
mkdir -p "$MOCK_DIR"
cat <<EOF > "$MOCK_DIR/xcrun"
#!/bin/bash
if [[ "\$1" == "swift" && "\$2" == "build" ]]; then
    if [[ "\$*" == *"--show-bin-path"* ]]; then
        echo "\$(pwd)/.build/debug"
    else
        mkdir -p .build/debug
        touch .build/debug/\$APP_NAME
    fi
elif [[ "\$1" == "notarytool" ]]; then
    echo '{"id":"mock-id-123", "status": "Accepted"}'
else
    exit 0
fi
EOF
chmod +x "$MOCK_DIR/xcrun"

# Add mock dir to PATH but keep original path
export PATH="$MOCK_DIR:$PATH"

# Test Case 1: Scaffold an SPM project
TEST_DIR="test_spm_project"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

cat <<EOF > Package.swift
import PackageDescription
let package = Package(name: "TestApp", products: [.executable(name: "TestApp", targets: ["TestApp"])])
EOF
mkdir -p Sources/TestApp
touch Sources/TestApp/main.swift

echo "Testing Scaffold..."
# Use absolute path to ship-it.sh
SHIP_IT_PATH="$(pwd)/../ship-it/ship-it.sh"
ln -s ../ship-it ship-it
bash "$SHIP_IT_PATH" scaffold -y

if [[ -f ".ship-it.conf" ]]; then
    echo "✓ Scaffold created .ship-it.conf"
else
    echo "✗ Scaffold failed to create .ship-it.conf"
    exit 1
fi

if [[ -f "ship" ]]; then
    echo "✓ Scaffold created ./ship shortcut"
else
    echo "✗ Scaffold failed to create ./ship shortcut"
    exit 1
fi

# Test Case 2: Build SPM project (mocked)
echo "Testing Build..."
export APP_NAME="TestApp" # Needed by mock
./ship build Debug

if [[ -f "build/TestApp" ]]; then
    echo "✓ Build succeeded"
else
    echo "✗ Build failed: build/TestApp not found"
    ls -R build
    exit 1
fi

# Test Case 3: Recording and Playback
echo "Testing Recording..."
rm -f .ship-it.record
# We need to provide input for a command that prompts.
# Let's use scaffold again but without -y.
# We'll use a heredoc to provide multiple inputs.
echo -e "NewAppName\nn" | bash "$SHIP_IT_PATH" scaffold --record

if [[ -f ".ship-it.record" ]]; then
    echo "✓ Recording created .ship-it.record"
    cat .ship-it.record
else
    echo "✗ Recording failed"
    exit 1
fi

echo "Testing Playback..."
# Change name in record file to verify it's used
# Note: prompt_input records as APP_NAME='NewAppName'
sed -i '' "s/APP_NAME=.*/APP_NAME='PlaybackApp'/" .ship-it.record
sed -i '' "s/CONFIRM_OVERWRITE_CONFIG=.*/CONFIRM_OVERWRITE_CONFIG='true'/" .ship-it.record
bash "$SHIP_IT_PATH" scaffold --playback .ship-it.record -y

source .ship-it.conf
if [[ "$APP_NAME" == "PlaybackApp" ]]; then
    echo "✓ Playback succeeded"
else
    echo "✗ Playback failed. App name is $APP_NAME"
    exit 1
fi

echo "All tests passed!"
