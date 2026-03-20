# ship-it

Unified Apple Platform Project Tools.

This repository is designed to be used as a git submodule in your Swift/SwiftUI projects.

## Installation

Add as a submodule:
```bash
git submodule add https://github.com/your-org/ship-it.git ship-it
```

Scaffold the project:
```bash
./ship-it/ship-it.sh scaffold
```
This will create a `.ship-it.conf` and a `./ship` shortcut in your project root.

## Usage

Use the `./ship` shortcut:

```bash
./ship build        # Build the project
./ship test         # Run tests
./ship run          # Run the app
./ship notarize     # Sign and notarize for distribution
./ship release      # Create a GitHub release
./ship deploy       # Deploy/Submit app to App Store Connect
```

## Features

- **Interactive**: Colorful prompts and status updates.
- **Non-interactive**: Use `-y` or set `SHIP_YES=true` to skip prompts.
- **Resumable**: Progress is saved to `.ship-it.state`.
- **Record/Playback**: Record your actions with `--record` and play them back with `--playback <file>`.
- **Configurable**: Customize behavior in `.ship-it.conf`.

## Customization

Edit `.ship-it.conf` in your project root:

```bash
APP_NAME="MyGreatApp"
PROJECT_TYPE="spm" # or "xcode"
BUILD_DIR="build"
DIST_DIR="dist"
SCHEME="MyGreatApp"
CONFIGURATION="Release"
```
