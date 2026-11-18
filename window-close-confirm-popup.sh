#!/bin/bash
# ============================================================
# window-close-guard
# Intercepts window close attempts and asks for confirmation.
# ============================================================

# Load user config from file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config"

#function to edit the config file using gui
edit_config() {
    local path="${1:-$CONFIG_FILE}"
    local wl="" to="60" md=""

    if [ -r "$path" ]; then
        source "$path"
        wl="${WHITELIST:-}"
        to="${TIMEOUT:-60}"
        md="${MODE:-}"
    fi

    #change order of options based on current mode
    case "$md" in
        "-a") opt1="^Always show popup"; opt2="Never show popup"; opt3="Show popup if NOT IN whitelist"; opt4="Show popup if IS IN whitelist" ;;
        "-n") opt1="Always show popup"; opt2="^Never show popup"; opt3="Show popup if NOT IN whitelist"; opt4="Show popup if IS IN whitelist" ;;
        "-w") opt1="Always show popup"; opt2="Never show popup"; opt3="^Show popup if NOT IN whitelist"; opt4="Show popup if IS IN whitelist" ;;
        "-b") opt1="Always show popup"; opt2="Never show popup"; opt3="Show popup if NOT IN whitelist"; opt4="^Show popup if IS IN whitelist" ;;
        *)  opt1="^Always show popup"; opt2="Never show popup"; opt3="Show popup if NOT IN whitelist"; opt4="Show popup if IS IN whitelist" ;;
    esac

    #gui form to edit config
    local result
    result=$(yad --form \
        --title="window-close-confirm-popup — settings" \
        --window-icon="preferences-system" \
        --image="preferences-system" \
        --text='<span size="xx-large" weight="bold">window-close-confirm-popup\n</span>\n<span size="medium">Configure which windows ask for confirmation before closing\n</span>' \
        --text-align=center \
        --center \
        --width=420 \
        --separator="|" \
        --field="Whitelist (space-separated, lowercase)" "$wl" \
        --field="Timeout (seconds, 0 = wait forever)" "$to" \
        --field="Mode (Customise which apps get popup):CB" \
        "$opt1!$opt2!$opt3!$opt4" \
        --button="Cancel:1" \
        --button="Save:0" \
        ) || return 1

    IFS="|" read -r wl to md <<< "$result"

    case "$md" in
        "Always show popup") md="-a" ;;
        "Never show popup") md="-n" ;;
        "Show popup if NOT IN whitelist") md="-w" ;;
        "Show popup if IS IN whitelist") md="-b" ;;
    esac

    if ! [[ "$to" =~ ^[0-9]+$ ]]; then
        yad --error --text="Timeout must be a number."
        return 1
    fi

    sed -i \
        -e "s|^WHITELIST=.*|WHITELIST=\"$wl\"|" \
        -e "s|^TIMEOUT=.*|TIMEOUT=$to|" \
        -e "s|^MODE=.*|MODE=\"$md\"|" \
        "$path"

    notify-send -i dialog-information "window-close-confirm-popup" "Saved config file to: \n $path"
}
#------------------------------------------------

if [ ! -r "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" <<'EOF'
# ┌─────────────────────────────────────────────────────────┐
# │            close-guard — configuration file             │
# └─────────────────────────────────────────────────────────┘

# ============================================================
#  ▼ EDIT THIS FILE TO CHANGE SETTINGS ▼
# ============================================================

# Apps that close without confirmation (space-separated, lowercase).
WHITELIST=""

# Seconds before the dialog auto-closes. 0 = wait forever.
TIMEOUT=60

#  "-n" = never ask (no popup)
#  "-w" = ask only for apps NOT in WHITELIST
#  "-b" = ask only for apps IN WHITELIST
#  "-a" = always ask (ignore whitelist)
MODE="-a"
EOF
fi

source "$CONFIG_FILE"

if [ "$1" = "-config" ]; then
    edit_config "$CONFIG_FILE" || exit 1
    exit 0
fi

if [ "$1" = "-whitelist" ]; then
    if [ "$#" -lt 2 ]; then
        echo "Whitelist: $WHITELIST"
        exit 0
    fi
    sed -i "s|^WHITELIST=.*|WHITELIST=\"$2\"|" "$CONFIG_FILE"
    echo "Whitelist: $2" 
    exit 0
fi

if [ "$1" = "-timeout" ]; then
    if [ "$#" -lt 2 ]; then
        echo "Timeout: $TIMEOUT"
        exit 0
    fi
    if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: timeout must be a non-negative number" >&2
        exit 1
    fi
    sed -i "s|^TIMEOUT=.*|TIMEOUT=$2|" "$CONFIG_FILE"
    echo "Timeout: $2"
    exit 0
fi

if [ "$1" = "-mode" ]; then
    if [ "$#" -lt 2 ]; then
        echo "Mode: $MODE"
        exit 0
    fi
    if ! [[ "$2" =~ ^(-a|-n|-w|-b)$ ]]; then
        echo "Error: mode must be one of -a, -n, -w, -b" >&2
        exit 1
    fi
    sed -i "s|^MODE=.*|MODE=\"$2\"|" "$CONFIG_FILE"
    echo "Mode: $2"
    exit 0
fi

if [ "$#" -gt 0 ]; then
    echo "Error: Too many arguments." >&2
    exit 1
fi

#window whitelist logic

WINDOW_ID=$(xdotool getactivewindow 2>/dev/null)
if [ -z "$WINDOW_ID" ]; then
    echo "Error: could not determine active window." >&2
    exit 1
fi

WINDOW_CLASS=$(xprop -id "$WINDOW_ID" WM_CLASS 2>/dev/null \
    | awk -F '"' '{print $4}' \
    | tr '[:upper:]' '[:lower:]')

#confirmation popup function
popup() {
    zenity --question \
           --title="Confirm Close" \
           --text="Are you sure you want to close this window?" \
           --width=300 \
           --ok-label="Close" \
           --cancel-label="Keep Open" \
           --timeout="$TIMEOUT" 2>/dev/null
    local code=$?

    # 0 = Close clicked, 5 = timeout
    if [ "$code" -eq 0 ] || [ "$code" -eq 5 ]; then
        wmctrl -ic "$WINDOW_ID"
    fi
}

# -a : Always show popup
if [ "$MODE" = "-a" ]; then
    popup
    exit 0
fi

if [ "$MODE" = "-n" ]; then
    wmctrl -ic "$WINDOW_ID"   # Never show popup
    exit 0
fi

# Whitelist match?
if echo "$WHITELIST" | grep -qw "$WINDOW_CLASS"; then
    if [ "$MODE" = "-w" ]; then
        wmctrl -ic "$WINDOW_ID"   # whitelist mode -> close immediately
    else
        popup                     # blacklist / default -> confirm
    fi
else
    if [ "$MODE" = "-b" ]; then
        wmctrl -ic "$WINDOW_ID"   # blacklist mode -> close immediately
    else
        popup                     # whitelist / default -> confirm
    fi
fi