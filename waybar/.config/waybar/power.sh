#!/bin/bash
# Power menu — fuzzel preferred (compact popup), wofi/rofi fallbacks

options_icons="\n  Lock\n󰒲  Suspend\n󰤁  Hibernate\n󰍃  Logout\n󰜉  Reboot\n󰐥  Shutdown"
options_text="Lock\nSuspend\nHibernate\nLogout\nReboot\nShutdown"

if command -v fuzzel &>/dev/null; then
    choice=$(echo -e "$options_icons" | fuzzel --dmenu \
        --prompt="Power  " \
        --lines=6 \
        --width=16 \
        --horizontal-pad=16 \
        --anchor=center \
        --no-mouse \
        --no-run-if-empty 2>/dev/null)
elif command -v wofi &>/dev/null; then
    choice=$(echo -e "$options_text" | wofi --dmenu -p "Power:" 2>/dev/null)
elif command -v rofi &>/dev/null; then
    choice=$(echo -e "$options_text" | rofi -dmenu -p "Power:" 2>/dev/null)
else
    niri msg action quit
    exit 0
fi

case "${choice##* }" in
    Lock)      loginctl lock-session ;;
    Suspend)   systemctl suspend ;;
    Hibernate) systemctl hibernate ;;
    Logout)    niri msg action quit ;;
    Reboot)    systemctl reboot ;;
    Shutdown)  systemctl poweroff ;;
esac
