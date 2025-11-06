#!/bin/sh

set -e

APP_USER="${APP_USER:-i2p}"
CONFIG_DIR="${CONFIG_DIR:-/config}"
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-${APP_USER}}"
XAUTHORITY="${XAUTHORITY:-${CONFIG_DIR}/.Xauthority}"

mkdir -p "${CONFIG_DIR}" "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}" 2>/dev/null || true

if [ "$(id -u)" -eq 0 ]; then
    chown -R "${APP_USER}:${APP_USER}" "${CONFIG_DIR}" "${XDG_RUNTIME_DIR}"
fi

if command -v xauth >/dev/null 2>&1; then
    COOKIE="$(mcookie 2>/dev/null || true)"
    if [ -z "${COOKIE}" ]; then
        COOKIE="$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    fi
    xauth -f "${XAUTHORITY}" remove :1 2>/dev/null || true
    xauth -f "${XAUTHORITY}" add :1 . "${COOKIE}"
    chmod 600 "${XAUTHORITY}" 2>/dev/null || true
    if [ "$(id -u)" -eq 0 ]; then
        chown "${APP_USER}:${APP_USER}" "${XAUTHORITY}" 2>/dev/null || true
    fi
fi

export XDG_RUNTIME_DIR
export XAUTHORITY

exec "$@"
