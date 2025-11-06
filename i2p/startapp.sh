#!/bin/sh

set -euo pipefail

APP_USER="${APP_USER:-i2p}"
CONFIG_DIR="${CONFIG_DIR:-/config}"
I2P_HOME="${I2P_HOME:-/i2p}"
I2P_CONFIG_DIR="${I2P_CONFIG_DIR:-${CONFIG_DIR}/.i2p}"
I2P_LOG_DIR="${I2P_LOG_DIR:-${I2P_CONFIG_DIR}/logs}"
I2P_PID_DIR="${I2P_PID_DIR:-${I2P_CONFIG_DIR}}"
FIREFOX_DIR="${CONFIG_DIR}/firefox"
PROFILE_DIR="${FIREFOX_DIR}/i2p.default"
FIREFOX_BIN="$(command -v firefox-esr || command -v firefox)"
ROUTER_PID_FILE="${I2P_PID_DIR}/router.pid"
FIREFOX_WINDOW_NAME="Mozilla Firefox"

if [ -z "${JVM_XMX:-}" ]; then
    JVM_XMX="512m"
    echo "[startapp] JVM_XMX not set, defaulting to ${JVM_XMX}"
fi
export JVM_XMX

export HOME="${CONFIG_DIR}"
export CONFIG_DIR I2P_CONFIG_DIR I2P_LOG_DIR I2P_PID_DIR I2P_HOME
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-${CONFIG_DIR}/.Xauthority}"

run_as_app() {
    if [ "$(id -u)" -eq 0 ]; then
        if command -v gosu >/dev/null 2>&1; then
            gosu "${APP_USER}:${APP_USER}" "$@"
            return
        fi
        if command -v su-exec >/dev/null 2>&1; then
            su-exec "${APP_USER}:${APP_USER}" "$@"
            return
        fi
        if command -v runuser >/dev/null 2>&1; then
            runuser -u "${APP_USER}" -- "$@"
            return
        fi
        echo "Unable to drop privileges; required tool not found." >&2
        exit 1
    fi
    "$@"
}

mkdir -p "${I2P_CONFIG_DIR}" "${I2P_LOG_DIR}" "${FIREFOX_DIR}"
echo "[startapp] Preparing configuration in ${CONFIG_DIR}"

if [ ! -e "${CONFIG_DIR}/firefox/profiles.ini" ]; then
    cp -a /defaults/config/firefox/. "${CONFIG_DIR}/firefox/"
fi

if [ ! -d "${I2P_CONFIG_DIR}" ] || [ -z "$(ls -A "${I2P_CONFIG_DIR}" 2>/dev/null)" ]; then
    cp -a /defaults/config/.i2p/. "${I2P_CONFIG_DIR}/" 2>/dev/null || true
fi

if [ "$(id -u)" -eq 0 ]; then
    chown -R "${APP_USER}:${APP_USER}" "${CONFIG_DIR}"
fi

cleanup() {
    set +e
    if [ -f "${ROUTER_PID_FILE}" ]; then
        router_pid="$(cat "${ROUTER_PID_FILE}" 2>/dev/null || true)"
        if [ -n "${router_pid}" ]; then
            run_as_app /bin/sh -c "kill ${router_pid}" >/dev/null 2>&1 || true
            for _ in $(seq 1 10); do
                if ! run_as_app /bin/sh -c "kill -0 ${router_pid}" >/dev/null 2>&1; then
                    break
                fi
                sleep 1
            done
            run_as_app /bin/sh -c "kill -9 ${router_pid}" >/dev/null 2>&1 || true
        fi
        rm -f "${ROUTER_PID_FILE}"
    fi
}
trap cleanup EXIT INT TERM

if [ -n "${EXT_PORT:-}" ]; then
    find "${I2P_CONFIG_DIR}" -name 'router.config' -exec sed -i "s|12345|${EXT_PORT}|g" {} \;
fi

launcher_script="$(mktemp)"
cat <<'EOF' > "${launcher_script}"
#!/bin/sh
set -e
cd "${I2P_HOME}"
CLASSPATH="."
for jar in "${I2P_HOME}"/lib/*.jar; do
    CLASSPATH="${CLASSPATH}:${jar}"
done
mkdir -p "${I2P_LOG_DIR}"
LOGFILE="${I2P_LOG_DIR}/router.log"
PID_FILE="${I2P_PID_DIR}/router.pid"
nohup java \
    -cp "${CLASSPATH}" \
    -Djava.net.preferIPv4Stack=false \
    -Djava.library.path="${I2P_HOME}:${I2P_HOME}/lib" \
    -Di2p.dir.base="${I2P_HOME}" \
    -Di2p.dir.config="${I2P_CONFIG_DIR}" \
    -DloggerFilenameOverride="${I2P_LOG_DIR}/log-router-@.txt" \
    -Xmx"${JVM_XMX}" \
    net.i2p.router.RouterLaunch >> "${LOGFILE}" 2>&1 &
echo $! > "${PID_FILE}"
EOF
chmod 755 "${launcher_script}"

echo "[startapp] Launching I2P router from ${I2P_HOME}"
run_as_app env \
    HOME="${CONFIG_DIR}" \
    I2P_HOME="${I2P_HOME}" \
    I2P_CONFIG_DIR="${I2P_CONFIG_DIR}" \
    I2P_LOG_DIR="${I2P_LOG_DIR}" \
    I2P_PID_DIR="${I2P_PID_DIR}" \
    JVM_XMX="${JVM_XMX}" \
    XAUTHORITY="${XAUTHORITY}" \
    "${launcher_script}"
rm -f "${launcher_script}"

echo "[startapp] Starting Firefox with profile ${PROFILE_DIR}"
run_as_app "${FIREFOX_BIN}" --no-remote --profile "${PROFILE_DIR}" &
browser_pid=$!

has_xdotool=0
has_wmctrl=0
if command -v xdotool >/dev/null 2>&1; then
    has_xdotool=1
fi
if command -v wmctrl >/dev/null 2>&1; then
    has_wmctrl=1
fi

if [ "${has_xdotool}" -eq 1 ] || [ "${has_wmctrl}" -eq 1 ]; then
    for _ in $(seq 1 30); do
        if [ "${has_xdotool}" -eq 1 ]; then
            window_id="$(run_as_app xdotool search --name "${FIREFOX_WINDOW_NAME}" 2>/dev/null | head -n1 || true)"
            if [ -n "${window_id}" ]; then
                if [ "${has_wmctrl}" -eq 1 ]; then
                    wmctrl_id="$(printf '0x%08x' "${window_id}")"
                    run_as_app wmctrl -ir "${wmctrl_id}" -b remove,maximized_vert,maximized_horz >/dev/null 2>&1 || true
                    run_as_app wmctrl -ir "${wmctrl_id}" -b add,maximized_vert,maximized_horz >/dev/null 2>&1 || true
                    run_as_app wmctrl -ir "${wmctrl_id}" -e 0,0,0,-1,-1 >/dev/null 2>&1 || true
                fi
                run_as_app xdotool windowactivate "${window_id}" >/dev/null 2>&1 || true
                break
            fi
        elif [ "${has_wmctrl}" -eq 1 ]; then
            wmctrl_id="$(run_as_app wmctrl -l 2>/dev/null | awk -v name="${FIREFOX_WINDOW_NAME}" '$0 ~ name {print $1; exit}')" || true
            if [ -n "${wmctrl_id}" ]; then
                run_as_app wmctrl -ir "${wmctrl_id}" -b remove,maximized_vert,maximized_horz >/dev/null 2>&1 || true
                run_as_app wmctrl -ir "${wmctrl_id}" -b add,maximized_vert,maximized_horz >/dev/null 2>&1 || true
                run_as_app wmctrl -ir "${wmctrl_id}" -e 0,0,0,-1,-1 >/dev/null 2>&1 || true
                break
            fi
        fi
        sleep 1
    done
fi

wait "${browser_pid}"
