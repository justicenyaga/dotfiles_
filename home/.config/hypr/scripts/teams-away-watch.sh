#!/bin/bash
STATEFILE="/tmp/teams-for-linux-idle-state-$USER"
LOG=/tmp/teams-watch-debug.log
TEAMS_CLASS="teams-for-linux"
AWAY_DELAY=90
IDLE_TIMEOUT=90

IDLE=0
UNFOCUSED_TOO_LONG=0

write_state() {
  if [ "$IDLE" = "1" ] || [ "$UNFOCUSED_TOO_LONG" = "1" ]; then
    echo inactive > "$STATEFILE"
  else
    echo active > "$STATEFILE"
  fi
}

(
  swayidle -w \
    timeout "$IDLE_TIMEOUT" "touch /tmp/.tflx-idle" \
    resume   "rm -f /tmp/.tflx-idle"
) &

SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
TIMER_PID=""

start_unfocus_timer() {
  echo "$(date +%T) starting unfocus timer" >> "$LOG"
  if [ -z "$TIMER_PID" ] || ! kill -0 "$TIMER_PID" 2>/dev/null; then
    (sleep "$AWAY_DELAY" && touch /tmp/.tflx-unfocused && echo "$(date +%T) touched unfocused flag" >> "$LOG") &
    TIMER_PID=$!
  fi
}

cancel_unfocus_timer() {
  echo "$(date +%T) cancel unfocus timer" >> "$LOG"
  [ -n "$TIMER_PID" ] && kill "$TIMER_PID" 2>/dev/null
  rm -f /tmp/.tflx-unfocused
}

INITIAL_CLASS=$(hyprctl activewindow -j | grep -o '"class": *"[^"]*"' | cut -d'"' -f4)
if [ "$INITIAL_CLASS" = "$TEAMS_CLASS" ]; then
  rm -f /tmp/.tflx-unfocused
else
  start_unfocus_timer
fi

(
  socat -U - UNIX-CONNECT:"$SOCK" | while read -r line; do
    echo "$(date +%T) event: $line" >> "$LOG"
    case "$line" in
      activewindow\>\>*)
        CLASS=$(echo "$line" | cut -d',' -f1 | sed 's/^activewindow>>//')
        if [ "$CLASS" = "$TEAMS_CLASS" ]; then
          cancel_unfocus_timer
        else
          start_unfocus_timer
        fi
        ;;
    esac
  done
) &

while true; do
  [ -f /tmp/.tflx-idle ] && IDLE=1 || IDLE=0
  [ -f /tmp/.tflx-unfocused ] && UNFOCUSED_TOO_LONG=1 || UNFOCUSED_TOO_LONG=0
  write_state
  sleep 2
done
