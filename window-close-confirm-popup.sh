#!/bin/bash
# ============================================================
# window-close-guard
# Intercepts window close attempts and asks for confirmation.
# ============================================================

# -------------------- CONFIG --------------------
# Space-separated list of window classes to whitelist.
# Match is case-insensitive against WM_CLASS.
WHITELIST="gnome-terminal firefox"

# Seconds before the dialog auto-closes (and closes the window).
TIMEOUT=60
# ------------------------------------------------

MODE=$1

if [ "$#" -gt 1 ]; then
    echo "Error: Too many arguments." >&2
    echo "Usage: $0 [-a|-w|-b]" >&2
    exit 1
fi

WINDOW_ID=$(xdotool getactivewindow 2>/dev/null)
if [ -z "$WINDOW_ID" ]; then
    echo "Error: could not determine active window." >&2
    exit 1
fi

WINDOW_CLASS=$(xprop -id "$WINDOW_ID" WM_CLASS 2>/dev/null \
    | awk -F '"' '{print $4}' \
    | tr '[:upper:]' '[:lower:]')

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

# -a : Always close (ignore whitelist & popup)
if [ "$MODE" = "-a" ]; then
    wmctrl -ic "$WINDOW_ID"
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