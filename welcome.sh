#!/bin/bash
# /etc/profile.d/welcome.sh
# Universal Linux Welcome Screen
# Author: Stefan Schulz-Lauterbach
# License: MIT

# Only run in interactive shells
[[ $- != *i* ]] && return

GREEN="\033[1;32m"; YELLOW="\033[1;33m"; RED="\033[1;31m"
BLUE="\033[1;34m"; CYAN="\033[1;36m"; RESET="\033[0m"

{
    clear

    # OS Info
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS="$PRETTY_NAME"
    else
        OS="$(uname -s)"
    fi

    HOSTNAME=$(hostname)
    UPTIME=$(uptime -p 2>/dev/null || awk '{printf "up %.0f hours", $1/3600}' /proc/uptime)
    LOAD=$(awk '{print $1","$2","$3}' /proc/loadavg)
    USERS=$(who | wc -l)
    IP=$(hostname -I 2>/dev/null | awk '{print $1}')

    # Memory
    MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{printf "%.0f", $2/1024}')
    MEM_FREE=$(grep MemAvailable /proc/meminfo | awk '{printf "%.0f", $2/1024}')

    # Disk
    DISK=$(df -h / | awk 'NR==2 {print $4 " free of " $2}')

    # Detect package manager
    if command -v apt >/dev/null 2>&1; then PM="apt"
    elif command -v dnf >/dev/null 2>&1; then PM="dnf"
    elif command -v yum >/dev/null 2>&1; then PM="yum"
    elif command -v zypper >/dev/null 2>&1; then PM="zypper"
    elif command -v pacman >/dev/null 2>&1; then PM="pacman"
    elif command -v apk >/dev/null 2>&1; then PM="apk"
    else PM="unknown"
    fi

    # Cached update check
    UPDATE_FILE="/tmp/linux-welcome-updates"
    UPDATE_MAX_AGE=21600
    if [ ! -f "$UPDATE_FILE" ] || [ $(($(date +%s) - $(stat -c %Y "$UPDATE_FILE"))) -gt $UPDATE_MAX_AGE ]; then
        case "$PM" in
            apt)    UPDATES=$(apt list --upgradeable 2>/dev/null | grep -c upgradable) ;;
            dnf)    UPDATES=$(dnf check-update 2>/dev/null | grep -cE '^[[:alnum:]]') ;;
            yum)    UPDATES=$(yum check-update 2>/dev/null | grep -cE '^[[:alnum:]]') ;;
            zypper) UPDATES=$(zypper lu 2>/dev/null | grep -c '|') ;;
            pacman) UPDATES=$(checkupdates 2>/dev/null | wc -l || echo 0) ;;
            apk)    UPDATES=$(apk version -l '<' 2>/dev/null | wc -l) ;;
            *)      UPDATES=0 ;;
        esac
        echo "$UPDATES" > "$UPDATE_FILE"
    fi
    UPDATES=$(cat "$UPDATE_FILE")

    # Services
    if command -v systemctl >/dev/null 2>&1; then
        FAILED=$(systemctl --failed --no-legend --no-pager 2>/dev/null | awk '{print $1}' | xargs)
    elif command -v service >/dev/null 2>&1; then
        FAILED=$(service --status-all 2>&1 | grep -c '\[ - \]')
    else
        FAILED=""
    fi
    if [ -z "$FAILED" ]; then
        SERVICE_STATUS="${GREEN}No failed services${RESET}"
    else
        SERVICE_STATUS="${RED}Some services failed${RESET}"
    fi

    # Reboot required?
    REBOOT_REASON=""
    if [ -f /var/run/reboot-required ] || [ -f /run/reboot-required ]; then
        # Debian / Ubuntu
        REBOOT_PKGS=$(sort -u /var/run/reboot-required.pkgs /run/reboot-required.pkgs 2>/dev/null | xargs)
        REBOOT_REASON="${REBOOT_PKGS:-pending updates}"
    elif [ -f /run/reboot-needed ] || [ -f /var/run/reboot-needed ]; then
        # openSUSE (libzypp)
        REBOOT_REASON="pending updates"
    elif [ "$PM" = "dnf" ] || [ "$PM" = "yum" ]; then
        # Fedora / RHEL: needs-restarting -r exits 1 when a reboot is required
        if command -v needs-restarting >/dev/null 2>&1; then
            timeout 5 needs-restarting -r >/dev/null 2>&1
            [ $? -eq 1 ] && REBOOT_REASON="core packages updated"
        elif [ "$PM" = "dnf" ]; then
            timeout 5 dnf -q needs-restarting -r >/dev/null 2>&1
            [ $? -eq 1 ] && REBOOT_REASON="core packages updated"
        fi
    fi
    # Generic fallback (Arch, Alpine, ...): modules of the running kernel are gone
    # (skipped in containers, where the host kernel never matches the image's modules)
    if [ -z "$REBOOT_REASON" ] && [ ! -f /.dockerenv ] && [ ! -f /run/.containerenv ] \
        && [ -n "$(ls -A /lib/modules 2>/dev/null)" ] && [ ! -d "/lib/modules/$(uname -r)" ]; then
        REBOOT_REASON="kernel updated"
    fi
    if [ -n "$REBOOT_REASON" ]; then
        REBOOT_STATUS="${RED}⚠ Reboot required${RESET} (${REBOOT_REASON})"
    else
        REBOOT_STATUS="${GREEN}Not required${RESET}"
    fi

    # Last login (previous session = 2nd entry of the user; the 1st is the current one)
    LOGIN_USER="${USER:-$(id -un)}"
    parse_last_iso() {
        # Expects "--time-format iso" output; host column may be missing for local ttys
        awk -v u="$LOGIN_USER" '
            $1 == u {
                for (i = 2; i <= NF; i++) if ($i ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T/) break
                if (i > NF) next
                if (++n == 2) {
                    out = substr($i, 1, 10) " " substr($i, 12, 5)
                    if (i == 4) out = out " from " $3
                    print out; exit
                }
            }'
    }
    LAST_LOGIN=""
    if command -v last >/dev/null 2>&1; then
        LAST_LOGIN=$(last --time-format iso -n 5 "$LOGIN_USER" 2>/dev/null | parse_last_iso)
        if [ -z "$LAST_LOGIN" ]; then
            # Old/busybox last without --time-format
            LAST_LOGIN=$(last -n 5 "$LOGIN_USER" 2>/dev/null | awk -v u="$LOGIN_USER" \
                '$1 == u && NF >= 7 && ++n == 2 {print $4" "$5" "$6" "$7" from "$3; exit}')
        fi
    fi
    if [ -z "$LAST_LOGIN" ] && command -v wtmpdb >/dev/null 2>&1; then
        # Debian 13+, newer Ubuntu, openSUSE: Y2038-safe wtmpdb instead of /var/log/wtmp
        LAST_LOGIN=$(wtmpdb last --time-format iso -n 5 "$LOGIN_USER" 2>/dev/null | parse_last_iso)
    fi
    unset -f parse_last_iso
    LAST_LOGIN="${LAST_LOGIN:-n/a}"

    # Banner
    if command -v figlet >/dev/null 2>&1; then
        FONT="${WELCOME_FONT:-slant}"
        echo -e "${CYAN}"
        figlet -f "$FONT" "$HOSTNAME"
        echo -e "${RESET}"
    elif command -v toilet >/dev/null 2>&1; then
        echo -e "${CYAN}"
        toilet -f standard "$HOSTNAME"
        echo -e "${RESET}"
    else
        echo -e "${CYAN}🧭  Welcome to ${YELLOW}$HOSTNAME${RESET}"
    fi

    echo -e "${BLUE}───────────────────────────────────────────────${RESET}"
    echo -e "🖥  System:       $OS"
    echo -e "⏱  Uptime:       $UPTIME"
    echo -e "⚙  Load:         $LOAD"
    echo -e "👥  Users:        $USERS"
    echo -e "💾  Memory:       ${MEM_FREE} MB free / ${MEM_TOTAL} MB total"
    echo -e "📀  Disk:         $DISK"
    echo -e "🌐  IP address:   $IP"
    echo -e "📦  Updates:      ${YELLOW}$UPDATES${RESET} available via $PM"
    echo -e "🧩  Services:     $SERVICE_STATUS"
    echo -e "🔄  Reboot:       $REBOOT_STATUS"
    echo -e "📜  Last login:  ${YELLOW}$LAST_LOGIN${RESET}"
    echo -e "${BLUE}───────────────────────────────────────────────${RESET}"
} 2>/dev/null
