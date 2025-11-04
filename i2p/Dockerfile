FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    I2P_HOME=/opt/i2p \
    MOZ_DISABLE_AUTO_SAFE_MODE_INIT=1

RUN set -eux; \
    echo "Etc/UTC" > /etc/timezone; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        firefox \
        fluxbox \
        libdbus-1-3 \
        libfontconfig1 \
        libgtk-3-0 \
        libnss3 \
        libx11-xcb1 \
        libxcb-dri3-0 \
        libxtst6 \
        openjdk-11-jre-headless \
        tigervnc-standalone-server \
        tigervnc-common \
        unzip \
        xauth \
        wmctrl \
        xdotool \
        xz-utils; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

ARG I2P_VERSION=2.10.0
ARG I2P_DOWNLOAD_URL="https://files.i2p-projekt.de/${I2P_VERSION}/i2pinstall_${I2P_VERSION}.jar"

RUN set -eux; \
    install_dir="${I2P_HOME}"; \
    rm -rf "${install_dir}"; \
    curl -fSL "${I2P_DOWNLOAD_URL}" -o /tmp/i2pinstall.jar; \
    printf '0\n1\n1\n%s\nO\n1\n1\n' "${install_dir}" | java -jar /tmp/i2pinstall.jar -console; \
    rm -f /tmp/i2pinstall.jar

RUN set -eux; \
    PROFILE_DIR=/root/.mozilla/firefox/i2p.default; \
    mkdir -p "${PROFILE_DIR}"

RUN cat <<'EOF' > /root/.mozilla/firefox/profiles.ini
[General]
StartWithLastProfile=1
Version=2

[Profile0]
Name=i2p
IsRelative=0
Path=/root/.mozilla/firefox/i2p.default
Default=1
EOF

RUN cat <<'EOF' > /root/.mozilla/firefox/i2p.default/user.js
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
user_pref("signon.rememberSignons", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("browser.sessionstore.resume_from_crash", false);
EOF

RUN set -eux; \
    mkdir -p /root/.vnc; \
    echo "password" | vncpasswd -f > /root/.vnc/passwd; \
    chmod 600 /root/.vnc/passwd

RUN cat <<'EOF' > /root/.vnc/xstartup
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
fluxbox &
firefox --no-remote --profile /root/.mozilla/firefox/i2p.default &
wait
EOF

RUN chmod +x /root/.vnc/xstartup

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 5900 4444 4447 7657

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
