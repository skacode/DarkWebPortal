FROM geti2p/i2p:latest

USER root

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    DISPLAY_WIDTH=1280 \
    DISPLAY_HEIGHT=800 \
    TZ=Etc/UTC \
    HOME=/config \
    APP_USER=i2p \
    CONFIG_DIR=/config \
    I2P_HOME=/i2p \
    I2P_CONFIG_DIR=/config/.i2p \
    I2P_LOG_DIR=/config/.i2p/logs \
    I2P_PID_DIR=/config/.i2p \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    XDG_RUNTIME_DIR=/tmp/runtime-i2p \
    XAUTHORITY=/config/.Xauthority

RUN set -eux; \
    if command -v apt-get >/dev/null 2>&1; then \
        apt-get update; \
        apt-get install -y --no-install-recommends \
            ca-certificates \
            dbus-x11 \
            firefox-esr \
            fonts-dejavu-core \
            su-exec \
            gosu \
            novnc \
            openbox \
            supervisor \
            wmctrl \
            x11vnc \
            xdotool \
            python3 \
            python3-pip \
            xvfb \
            xauth; \
        apt-get clean; \
        rm -rf /var/lib/apt/lists/*; \
    elif command -v dnf >/dev/null 2>&1; then \
        dnf -y update; \
        dnf -y install \
            ca-certificates \
            dbus-x11 \
            firefox \
            dejavu-sans-fonts \
            gosu \
            novnc \
            openbox \
            supervisor \
            python3 \
            python3-pip \
            xdotool \
            wmctrl \
            xorg-x11-server-Xvfb \
            xorg-x11-server-utils \
            xorg-x11-utils \
            x11vnc \
            which \
            xauth; \
        dnf clean all; \
        rm -rf /var/cache/dnf; \
    elif command -v yum >/dev/null 2>&1; then \
        yum update -y; \
        yum install -y \
            ca-certificates \
            dbus-x11 \
            firefox \
            dejavu-sans-fonts \
            gosu \
            python3 \
            python3-pip \
            novnc \
            openbox \
            supervisor \
            xdotool \
            wmctrl \
            xorg-x11-server-Xvfb \
            xorg-x11-server-utils \
            xorg-x11-utils \
            x11vnc \
            which \
            xauth; \
        yum clean all; \
        rm -rf /var/cache/yum; \
    elif command -v apk >/dev/null 2>&1; then \
        apk add --no-cache \
            ca-certificates \
            dbus-x11 \
            su-exec \
            firefox-esr \
            font-dejavu \
            novnc \
            openbox \
            supervisor \
            x11vnc \
            xdotool \
            xvfb \
            python3 \
            py3-pip \
            which \
            xauth; \
    else \
        echo "Unsupported base image: no known package manager found" >&2; \
        exit 1; \
    fi; \
    python3 -m pip install --no-cache-dir websockify; \
    mkdir -p /var/log/supervisor /config

RUN set -eux; \
    mkdir -p /config; \
    if command -v groupadd >/dev/null 2>&1; then \
        groupadd -r "${APP_USER}" || true; \
        useradd -r -g "${APP_USER}" -d /config -s /bin/sh "${APP_USER}" || true; \
    else \
        addgroup -S "${APP_USER}" || true; \
        adduser -S -G "${APP_USER}" -h /config -s /bin/sh "${APP_USER}" || true; \
    fi; \
    chown -R "${APP_USER}:${APP_USER}" /config

RUN set -eux; \
    mkdir -p /defaults/config/firefox/i2p.default; \
    cat <<'EOF' > /defaults/config/firefox/profiles.ini
[General]
StartWithLastProfile=1
Version=2

[Profile0]
Name=i2p
IsRelative=1
Path=firefox/i2p.default
Default=1
EOF

RUN set -eux; \
    cat <<'EOF' > /defaults/config/firefox/i2p.default/user.js
user_pref("browser.startup.homepage", "http://127.0.0.1:7657/");
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.warnOnQuit", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("network.proxy.http", "127.0.0.1");
user_pref("network.proxy.http_port", 4444);
user_pref("network.proxy.share_proxy_settings", true);
user_pref("network.proxy.socks", "127.0.0.1");
user_pref("network.proxy.socks_port", 4447);
user_pref("network.proxy.socks_version", 5);
user_pref("network.proxy.ssl", "127.0.0.1");
user_pref("network.proxy.ssl_port", 4444);
user_pref("network.proxy.type", 1);
user_pref("network.proxy.no_proxies_on", "");
user_pref("network.proxy.allow_hijacking_localhost", true);
user_pref("network.proxy.socks_remote_dns", true);
user_pref("signon.rememberSignons", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("browser.sessionstore.resume_from_crash", false);
EOF

RUN set -eux; \
    mkdir -p /defaults/config; \
    if [ -d /i2p/.i2p ]; then \
        cp -a /i2p/.i2p /defaults/config/.i2p; \
    else \
        mkdir -p /defaults/config/.i2p; \
    fi; \
    mkdir -p /defaults/config/.i2p/logs

RUN set -eux; \
    rm -rf /i2p/.i2p; \
    ln -sfn /config/.i2p /i2p/.i2p

RUN set -eux; \
    chmod +x /i2p/i2prouter

COPY startapp.sh /usr/local/bin/startapp.sh
RUN chmod +x /usr/local/bin/startapp.sh

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

COPY novnc-index.html /usr/share/novnc/index.html
RUN sed -i "/UI\\.initSetting('resize', resize);/c\        const resizeSetting = UI.initSetting('resize', resize);\n        if (resizeSetting !== 'remote') {\n            WebUtil.writeSetting('resize', 'remote');\n            UI.updateSetting('resize');\n        }" /usr/share/novnc/app/ui.js

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 5800 5900 4444 4447 7657

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
