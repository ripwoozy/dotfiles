#!/usr/bin/env bash
#
# Combined‑battery status for systems with 1 or more batteries

icons=( "󰂃" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰁹" )
charging_icon="󰂄"

# initialise totals
total_now=0
total_full=0
charging=false

# iterate over every power‑supply directory whose TYPE is “Battery”
for bat in /sys/class/power_supply/*; do
    [[ -f "$bat/type" ]] && grep -q "^Battery" "$bat/type" || continue

    # pick the proper file pair: energy_* (newer) or charge_* (older)
    if [[ -f "$bat/energy_now" ]]; then
        now=$(<"$bat/energy_now")
        full=$(<"$bat/energy_full")
    else
        now=$(<"$bat/charge_now")
        full=$(<"$bat/charge_full")
    fi

    total_now=$(( total_now + now ))
    total_full=$(( total_full + full ))

    # if any battery is charging, mark it
    [[ -f "$bat/status" && $(<"$bat/status") == "Charging" ]] && charging=true
done

# avoid division‑by‑zero in case something went wrong
[[ $total_full -eq 0 ]] && { echo "??% ${icons[0]}"; exit 1; }

# combined, rounded percentage
percentage=$(( 100 * total_now / total_full ))

# icon bucket (0‑9)
icon_index=$(( percentage / 10 ))
icon=${icons[icon_index]}

# charging icon overrides if needed
$charging && icon=$charging_icon

printf '%s%% %s\n' "$percentage" "$icon"
