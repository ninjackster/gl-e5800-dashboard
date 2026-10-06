#!/bin/sh
# Runs the dashboard, retrying on crash. After repeated crashes, or on a
# clean stop (SIGTERM -> python exits 0), hands the screen back to the
# stock gl_screen UI so the physical display is never left blank/frozen.
#
# Backgrounds the python process and traps TERM/INT so procd's stop signal
# actually reaches the child instead of orphaning it (a plain foreground
# `python3 ...` here would swallow the signal at the shell and leave the
# python process running after `/etc/init.d/citydash stop`).

LOG_TAG="citydash"
child=""

term_handler() {
    [ -n "$child" ] && kill -TERM "$child" 2>/dev/null
    wait "$child" 2>/dev/null
    exit 0
}
trap term_handler TERM INT

# Stop GL's boot animation. gl_screen normally does this once it has
# initialised (platform.sh kill_boot); with gl_screen replaced nothing
# did, so screen_boot kept spinning for the whole uptime -- measured at
# ~12% of one core (232 ticks/20s), 11x the dashboard's own idle cost.
if [ -x /etc/gl_screen/platform.sh ] && pidof screen_boot >/dev/null; then
    /etc/gl_screen/platform.sh kill_boot >/dev/null 2>&1
    logger -t "$LOG_TAG" "stopped boot animation (screen_boot)"
fi

fails=0
# A run that lasted this long counts as healthy: the crash counter is
# about "this build cannot start", not "this build has ever crashed".
# Without the reset, three crashes MONTHS apart still added up and handed
# the screen back to the stock UI permanently.
HEALTHY_SECONDS=300

while true; do
    started=$(date +%s)
    python3 /root/dashboard/dashboard.py &
    child=$!
    wait "$child"
    rc=$?
    if [ "$rc" -eq 0 ]; then
        logger -t "$LOG_TAG" "clean stop requested"
        exit 0
    fi
    ran_for=$(( $(date +%s) - started ))
    if [ "$ran_for" -ge "$HEALTHY_SECONDS" ]; then
        [ "$fails" -gt 0 ] && logger -t "$LOG_TAG" "ran ${ran_for}s before failing, resetting crash count"
        fails=0
    fi
    fails=$((fails + 1))
    logger -t "$LOG_TAG" "dashboard exited rc=$rc (failure $fails)"
    if [ "$fails" -ge 3 ]; then
        logger -t "$LOG_TAG" "too many crashes, falling back to stock gl_screen"
        /etc/init.d/gl_screen start
        exit 1
    fi
    sleep 2
done
