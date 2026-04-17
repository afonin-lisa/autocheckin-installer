#!/bin/bash
# Interactive input helpers

ask() {
    local prompt="$1"
    local default="${2:-}"
    if [ -n "$default" ]; then
        echo -en "${CYAN}▸ ${prompt} [${default}]: ${NC}"
    else
        echo -en "${CYAN}▸ ${prompt}: ${NC}"
    fi
    read -r REPLY
    echo "${REPLY:-$default}"
}

ask_secret() {
    local prompt="$1"
    echo -en "${CYAN}▸ ${prompt}: ${NC}"
    read -rs REPLY
    echo
    echo "$REPLY"
}

confirm() {
    local prompt="$1"
    echo -en "${CYAN}▸ ${prompt} [y/N]: ${NC}"
    read -r REPLY
    [[ "$REPLY" =~ ^[Yy]$ ]]
}

choose() {
    local prompt="$1"
    shift
    local options=("$@")
    echo -e "${CYAN}▸ ${prompt}:${NC}"
    for i in "${!options[@]}"; do
        echo -e "  ${BOLD}$((i+1)))${NC} ${options[$i]}"
    done
    echo -en "${CYAN}  Выбор [1]: ${NC}"
    read -r REPLY
    local idx=$((${REPLY:-1} - 1))
    echo "${options[$idx]}"
}
