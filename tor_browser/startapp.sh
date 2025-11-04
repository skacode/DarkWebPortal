#!/bin/bash

set -euo pipefail

TOR_BROWSER_DIR="/opt/tor-browser/Browser"
TOR_WINDOW_NAME="Tor Browser"

if [ "$(id -u)" -eq 0 ]; then
    exec /opt/base/sbin/su-exec app:app "$0" "$@"
fi

cd "${TOR_BROWSER_DIR}"

export DISPLAY="${DISPLAY:-:0}"

./start-tor-browser --foreground --allow-remote &
browser_pid=$!

if command -v wmctrl >/dev/null 2>&1 || command -v xdotool >/dev/null 2>&1; then
    for _ in $(seq 1 30); do
        window_id="$(xdotool search --name "${TOR_WINDOW_NAME}" 2>/dev/null | head -n1 || true)"
        if [ -n "${window_id}" ]; then
            if command -v wmctrl >/dev/null 2>&1; then
                wmctrl_id="$(printf '0x%08x' "${window_id}")"
                wmctrl -ir "${wmctrl_id}" -b remove,maximized_vert,maximized_horz >/dev/null 2>&1 || true
                wmctrl -ir "${wmctrl_id}" -b add,maximized_vert,maximized_horz >/dev/null 2>&1 || true
                wmctrl -ir "${wmctrl_id}" -e 0,0,0,-1,-1 >/dev/null 2>&1 || true
            fi
            if command -v xdotool >/dev/null 2>&1; then
                xdotool windowactivate "${window_id}" >/dev/null 2>&1 || true
            fi
            break
        fi
        sleep 1
    done
fi

wait "${browser_pid}"
