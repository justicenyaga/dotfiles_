#!/bin/bash
# Configuration
BATTERY_PATH="/sys/class/power_supply/BAT0"  # Adjust if your battery is BAT1
LOW_THRESHOLD=30
CRITICAL_THRESHOLD=15

DEFAULT_PROFILE="performance"   # performance | balanced | power-saver

# State file to track notifications (prevents spam)
STATE_FILE="/tmp/battery_monitor_state"

send_notification() {
    local title="$1"
    local message="$2"
    local urgency="$3"
    local icon="$4"
    notify-send -u "$urgency" -i "$icon" "$title" "$message"
}

set_power_profile() {
    local profile="$1"
    if command -v powerprofilesctl &>/dev/null; then
        powerprofilesctl set "$profile"
    fi
}

get_battery_percentage() {
    if [ -f "$BATTERY_PATH/capacity" ]; then
        cat "$BATTERY_PATH/capacity"
    else
        echo "100"  # Default to 100% if can't read battery
    fi
}

is_charging() {
    if [ -f "$BATTERY_PATH/status" ]; then
        local status=$(cat "$BATTERY_PATH/status")
        [ "$status" = "Charging" ] || [ "$status" = "Full" ]
    else
        return 1
    fi
}

main() {
    local battery_percent=$(get_battery_percentage)
    local current_state=""

    # Read previous state
    if [ -f "$STATE_FILE" ]; then
        current_state=$(cat "$STATE_FILE")
    fi

    # Skip if charging - restore default profile once
    if is_charging; then
        if [ "$current_state" != "" ]; then
            set_power_profile "$DEFAULT_PROFILE"
            echo "" > "$STATE_FILE"
        fi
        exit 0
    fi

    if [ "$battery_percent" -le "$CRITICAL_THRESHOLD" ]; then
        if [ "$current_state" != "critical" ]; then
            send_notification "Battery Critically Low!" \
                "Battery at ${battery_percent}%. Please plug in your charger immediately!" \
                "critical" \
                "battery-caution"
            set_power_profile "power-saver"
            echo "critical" > "$STATE_FILE"
        fi
    elif [ "$battery_percent" -le "$LOW_THRESHOLD" ]; then
        if [ "$current_state" != "low" ] && [ "$current_state" != "critical" ]; then
            send_notification "Battery Low" \
                "Battery at ${battery_percent}%. Consider plugging in your charger." \
                "normal" \
                "battery-low"
            set_power_profile "balanced"
            echo "low" > "$STATE_FILE"
        fi
    else
        if [ "$current_state" != "" ]; then
            set_power_profile "$DEFAULT_PROFILE"
            echo "" > "$STATE_FILE"
        fi
    fi
}

main "$@"
