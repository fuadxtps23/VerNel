#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# For disabling touchpad.
# Device is auto-detected from `hyprctl devices` (first mouse named *-touchpad);
# override with TOUCHPAD_DEVICE env or $Touchpad_Device in Laptops.conf.
# Uses the Lua config syntax (hyprctl eval hl.device) required by Hyprland 0.55+.

set -euo pipefail

laptops_conf="$HOME/.config/hypr/UserConfigs/Laptops.conf"

touchpad_device="${TOUCHPAD_DEVICE:-}"
if [[ -z "$touchpad_device" && -f "$laptops_conf" ]]; then
    touchpad_device="$(
        awk -F= '/^\$Touchpad_Device/ {
            gsub(/[[:space:]]*/, "", $1);
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2);
            print $2;
            exit
        }' "$laptops_conf"
    )"
fi
if [[ -z "$touchpad_device" ]]; then
    touchpad_device="$(hyprctl -j devices | python3 -c "
import json, sys
try:
    devs = json.load(sys.stdin).get('mice', [])
    print(next((m['name'] for m in devs if m['name'].endswith('-touchpad')), ''))
except Exception:
    print('')
")"
fi

if [[ -z "$touchpad_device" ]]; then
    echo "Touchpad device not found (check hyprctl devices)" >&2
    exit 1
fi

status_file="${XDG_RUNTIME_DIR:-/tmp}/touchpad.status"

enable_touchpad() {
    printf "true" >"$status_file"
    hyprctl eval "hl.device({ name = '$touchpad_device', enabled = true })"
}

disable_touchpad() {
    printf "false" >"$status_file"
    hyprctl eval "hl.device({ name = '$touchpad_device', enabled = false })"
}

current_state="true"
if [[ -f "$status_file" ]]; then
    current_state="$(<"$status_file")"
fi

case "${1:-}" in
    on)
        if [[ "$current_state" != "true" ]]; then
            enable_touchpad
        fi
        ;;
    off)
        if [[ "$current_state" != "false" ]]; then
            disable_touchpad
        fi
        ;;
    *)
        if [[ "$current_state" == "true" ]]; then
            disable_touchpad
        else
            enable_touchpad
        fi
        ;;
esac