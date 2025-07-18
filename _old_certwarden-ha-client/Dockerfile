# https://developers.home-assistant.io/docs/add-ons/configuration#add-on-dockerfile
ARG BUILD_FROM
FROM $BUILD_FROM

# Setup base
RUN \
    set -x && \
    apk add --no-cache \
        apparmor-utils


# Copy data
COPY rootfs /

RUN set -x && \
    chmod a+x /usr/bin/banner && \
    chmod a+x /usr/bin/certwarden-ha-client && \
    chmod a+x /etc/s6-overlay/s6-rc.d/certwarden-ha-client/*