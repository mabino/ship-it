#!/usr/bin/env bash

# ship-it: Unified Apple platform project tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/shared.sh"

PLAYBACK_FILE=""
RECORD_MODE=false

usage() {
    print_banner
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  scaffold     Scaffold ship-it into your project"
    echo "  build        Build your project"
    echo "  test         Run project tests"
    echo "  run          Run your app"
    echo "  notarize     Sign, notarize, and staple your app"
    echo "  release      Create a GitHub release"
    echo ""
    echo "Global Options:"
    echo "  -y, --yes          Assume 'yes' for all prompts"
    echo "  --playback <file>  Play back actions from a record file"
    echo "  --record           Record actions to .ship-it.record"
    echo "  --help             Show this help message"
    echo ""
}

# Parse global options
COMMAND=""
ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            export SHIP_YES=true
            shift
            ;;
        --playback)
            PLAYBACK_FILE="$2"
            export PLAYBACK_FILE
            shift 2
            ;;
        --record)
            RECORD_MODE=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            if [[ -z "$COMMAND" ]]; then
                COMMAND=$1
            else
                ARGS+=("$1")
            fi
            shift
            ;;
    esac
done

if [[ -z "$COMMAND" ]]; then
    usage
    exit 1
fi

# Initialize recording if requested
if [[ "$RECORD_MODE" == "true" ]]; then
    echo "# ship-it record started at $(date)" > "$RECORD_FILE"
fi

# Load existing state for resumability
load_state

# Signal handler for graceful exit and state preservation
cleanup_on_exit() {
    print_warning "Interrupted! Saving state..."
    # Any additional cleanup logic can go here
    exit 1
}
trap cleanup_on_exit SIGHUP SIGINT

case "$COMMAND" in
    scaffold|build|test|run|notarize|release)
        COMMAND_FILE="${SCRIPT_DIR}/commands/${COMMAND}.sh"
        if [[ -f "$COMMAND_FILE" ]]; then
            source "$COMMAND_FILE" "${ARGS[@]}"
        else
            print_error "Command '${COMMAND}' not implemented yet."
            exit 1
        fi
        ;;
    *)
        print_error "Unknown command: ${COMMAND}"
        usage
        exit 1
        ;;
esac
