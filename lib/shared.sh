#!/usr/bin/env bash

# Colors and Formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

CHECK="✓"
CROSS="✗"
ARROW="→"
STAR="★"
LOCK="🔐"
PACKAGE="📦"
ROCKET="🚀"
HOURGLASS="⏳"
SPARKLES="✨"

# State and Recording
STATE_FILE=".ship-it.state"
RECORD_FILE=".ship-it.record"

load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        source "$STATE_FILE"
    fi
}

save_state() {
    local var_name=$1
    local value=$2
    # Simple append/update for state file
    if grep -q "^$var_name=" "$STATE_FILE" 2>/dev/null; then
        sed -i '' "s/^$var_name=.*/$var_name='$value'/" "$STATE_FILE"
    else
        echo "$var_name='$value'" >> "$STATE_FILE"
    fi
}

record_action() {
    local action=$1
    local value=$2
    echo "$action='$value'" >> "$RECORD_FILE"
}

print_banner() {
    echo -e "${CYAN}    ╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}    ║${RESET}                                                           ${CYAN}║${RESET}"
    echo -e "${CYAN}    ║${RESET}   ${BOLD}${WHITE}  ███████╗██╗  ██╗██╗██████╗     ██╗████████╗${RESET}           ${CYAN}║${RESET}"
    echo -e "${CYAN}    ║${RESET}   ${BOLD}${WHITE}  ██╔════╝██║  ██║██║██╔══██╗    ██║╚══██╔══╝${RESET}           ${CYAN}║${RESET}"
    echo -e "${CYAN}    ║${RESET}   ${BOLD}${WHITE}  ███████╗███████║██║██████╔╝    ██║   ██║   ${RESET}           ${CYAN}║${RESET}"
    echo -e "${CYAN}    ║${RESET}   ${BOLD}${WHITE}  ╚════██║██╔══██║██║██╔═══╝     ██║   ██║   ${RESET}           ${CYAN}║${RESET}"
    echo -e "${CYAN}    ║${RESET}   ${BOLD}${WHITE}  ███████║██║  ██║██║██║         ██║   ██║   ${RESET}           ${CYAN}║${RESET}"
    echo -e "${CYAN}    ║${RESET}   ${BOLD}${WHITE}  ╚══════╝╚═╝  ╚═╝╚═╝╚═╝         ╚═╝   ╚═╝   ${RESET}           ${CYAN}║${RESET}"
    echo -e "${CYAN}    ║${RESET}                                                           ${CYAN}║${RESET}"
    echo -e "${CYAN}    ║${RESET}           ${ROCKET} ${BOLD}Apple Project Tool Suite${RESET}  ${ROCKET}              ${CYAN}║${RESET}"
    echo -e "${CYAN}    ║${RESET}                                                           ${CYAN}║${RESET}"
    echo -e "${CYAN}    ╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

print_header() {
    echo ""
    echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${MAGENTA}║${RESET}  ${CYAN}${BOLD}$1${RESET}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

print_step() {
    local step=$1
    local total=$2
    local message=$3
    echo -e "${BLUE}${BOLD}[${step}/${total}]${RESET} ${CYAN}${ARROW}${RESET} ${message}"
}

print_success() {
    echo -e "     ${GREEN}${CHECK} $1${RESET}"
}

print_error() {
    echo -e "     ${RED}${CROSS} $1${RESET}"
}

print_warning() {
    echo -e "     ${YELLOW}! $1${RESET}"
}

print_info() {
    echo -e "     ${DIM}$1${RESET}"
}

prompt_input() {
    local prompt=$1
    local var_name=$2
    local is_secret=${3:-false}
    
    local default_val
    eval "default_val=\$$var_name"

    # 1. Check playback file (highest priority for automation)
    if [[ -f "$PLAYBACK_FILE" ]]; then
        local playback_val=$(grep "^$var_name=" "$PLAYBACK_FILE" | cut -d'=' -f2- | tr -d "'")
        if [[ -n "$playback_val" ]]; then
            eval "$var_name='$playback_val'"
            if [[ "$is_secret" == "true" ]]; then
                print_info "Using playback value for $prompt: ********"
            else
                print_info "Using playback value for $prompt: $playback_val"
            fi
            record_action "$var_name" "$playback_val"
            return
        fi
    fi

    # 2. If SHIP_YES is true and we have a default, use it
    if [[ "${SHIP_YES:-}" == "true" && -n "$default_val" ]]; then
        record_action "$var_name" "$default_val"
        return
    fi

    # 3. Prompt user
    if [[ -n "$default_val" ]]; then
        echo -ne "${YELLOW}${ARROW}${RESET} ${WHITE}${prompt}${RESET} ${DIM}[$default_val]${RESET}: "
    else
        echo -ne "${YELLOW}${ARROW}${RESET} ${WHITE}${prompt}${RESET}: "
    fi

    local input
    if [ "$is_secret" = true ]; then
        read -s input
        echo ""
    else
        read input
    fi

    if [[ -z "$input" && -n "$default_val" ]]; then
        input="$default_val"
    fi

    eval "$var_name='$input'"
    record_action "$var_name" "$input"
}

prompt_confirm() {
    local prompt=$1
    local key=$2 # Unique key for this confirmation to support recording
    
    # 1. Check playback file
    if [[ -f "$PLAYBACK_FILE" ]]; then
        local playback_val=$(grep "^CONFIRM_$key=" "$PLAYBACK_FILE" | cut -d'=' -f2- | tr -d "'")
        if [[ -n "$playback_val" ]]; then
            print_info "Using playback confirmation for $prompt: $playback_val"
            record_action "CONFIRM_$key" "$playback_val"
            [[ "$playback_val" == "true" ]]
            return $?
        fi
    fi

    # 2. Check if we should skip confirmation
    if [[ "${SHIP_YES:-}" == "true" ]]; then
        record_action "CONFIRM_$key" "true"
        return 0
    fi

    # 3. Prompt user
    echo -ne "${YELLOW}?${RESET} ${WHITE}${prompt}${RESET} ${DIM}[y/N]${RESET}: "
    local reply
    read -n 1 reply
    echo ""
    if [[ "$reply" =~ ^[Yy]$ ]]; then
        record_action "CONFIRM_$key" "true"
        return 0
    else
        record_action "CONFIRM_$key" "false"
        return 1
    fi
}
