FROM jlesage/baseimage-gui:debian-12-v4

ENV DISPLAY_WIDTH=1280 \
    DISPLAY_HEIGHT=800 \
    KEEP_APP_RUNNING=1 \
    TZ=Europe/Madrid

ARG TOR_BROWSER_VERSION=15.0
ARG TOR_BROWSER_URL="https://www.torproject.org/dist/torbrowser/${TOR_BROWSER_VERSION}/tor-browser-linux-x86_64-${TOR_BROWSER_VERSION}.tar.xz"
ARG TOR_BROWSER_SHA256="23674da2180d7e1b5c35aa9b39988f739e4e6e9727d3b7fa547a55123cc8fea0"

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
        xz-utils \
        gnupg \
        file \
        libgtk-3-0 \
        libdbus-glib-1-2 \
        libxt6 \
        libasound2 \
        libpulse0 \
        xdotool \
        wmctrl; \
    apt-get clean && rm -rf /var/lib/apt/lists/*; \
    \
    tmpdir="$(mktemp -d)"; \
    cd "${tmpdir}"; \
    wget -O tor-browser.tar.xz "${TOR_BROWSER_URL}"; \
    echo "${TOR_BROWSER_SHA256}  tor-browser.tar.xz" | sha256sum -c -; \
    mkdir -p /opt/tor-browser; \
    tar -xf tor-browser.tar.xz --strip-components=1 -C /opt/tor-browser; \
    rm -rf "${tmpdir}"; \
    chown -R 1000:1000 /opt/tor-browser

COPY startapp.sh /startapp.sh
RUN chmod +x /startapp.sh

RUN set-cont-env APP_NAME "Tor Browser"

RUN perl -0pi -e "s@        UI\.initSetting\('resize', resize\);\n@        const resizeSetting = UI.initSetting('resize', resize);\n        if (resizeSetting !== 'remote') {\n            WebUtil.writeSetting('resize', 'remote');\n            UI.updateSetting('resize');\n        }\n@" /opt/noVNC/app/ui.js
