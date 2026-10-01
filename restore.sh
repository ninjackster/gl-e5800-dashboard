#!/bin/sh
# Fork: put the dashboard back after a GL firmware update.
# Firmware updates wipe opkg packages (python3, pillow) and the dashboard
# code; "Keep settings" preserves /root/dashboard/config.json because it is
# listed in /etc/sysupgrade.conf, so theme, wallpaper and clocks come back.
# Usage: ./restore.sh [router-ip]   (default 192.168.2.1, the Mudi's LAN)
set -e
ROUTER="${1:-192.168.2.1}"
DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/install.sh" "$ROUTER"
ssh "root@$ROUTER" '
    for f in /root/dashboard/config.json /root/dashboard/game_scores.json; do
        [ -f "$f" ] && { grep -qx "$f" /etc/sysupgrade.conf || echo "$f" >> /etc/sysupgrade.conf; }
    done
    /root/dashboard/toggle.sh on
'
echo "Dashboard restored and switched on."
