#!/bin/bash

set -euo pipefail

VNC_DISPLAY="${VNC_DISPLAY:-:0}"
VNC_GEOMETRY="${VNC_GEOMETRY:-1280x1024}"
VNC_DEPTH="${VNC_DEPTH:-24}"
TAIL_PID=""
export DISPLAY="${VNC_DISPLAY}"

cleanup() {
    set +e
    vncserver -kill "${VNC_DISPLAY}" >/dev/null 2>&1 || true
    /opt/i2p/i2prouter stop >/dev/null 2>&1 || true
    if [[ -n "${TAIL_PID}" ]]; then
        kill "${TAIL_PID}" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT INT TERM

/opt/i2p/i2prouter start

vncserver "${VNC_DISPLAY}" -geometry "${VNC_GEOMETRY}" -depth "${VNC_DEPTH}"

tail -f /dev/null &
TAIL_PID=$!

wait "${TAIL_PID}"
