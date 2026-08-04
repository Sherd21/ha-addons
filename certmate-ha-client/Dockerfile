# https://developers.home-assistant.io/docs/add-ons/configuration#add-on-dockerfile
#
# The base image, the build arguments and the labels used to live in build.yaml.
# That file is deprecated -- the builder reads none of it any more -- so they
# belong here now. This is the multi-arch base: each build runs on a runner of
# its own architecture and resolves the tag to that architecture's image, which
# is the same image build.yaml used to name explicitly (ghcr.io/home-assistant/
# base:3.24 for amd64 is byte for byte ghcr.io/home-assistant/amd64-base:3.24).
#
# Alpine 3.24 is the current base. Home Assistant only publishes 3.23/3.24 for
# the 64-bit architectures -- armhf, armv7 and i386 stop at 3.22 and Supervisor
# reports all three as deprecated -- so dropping them is what allows this to
# track the current base instead of being held back at 3.22.
FROM ghcr.io/home-assistant/base:3.24

# The Home Assistant base image already ships bash, curl, jq, ca-certificates,
# tzdata and bashio. openssl is the only thing this add-on adds.
#
# Deliberately not version-pinned. Alpine keeps exactly one version of a package
# per release branch, so `openssl=3.5.7-r0` would break this build the day
# 3.5.8-r0 replaces it -- there is no version archive to fall back on. The pin
# that matters is the base image tag above, which bounds openssl to that
# branch's series; letting the patch level float is what makes a rebuild pick up
# openssl security fixes, which is what you want for a TLS tool.
RUN apk add --no-cache openssl

COPY run.sh /run.sh

# run.sh is mode 100644 in the git index (core.filemode is false on the
# maintainer's machine), so CI checks out a non-executable file. This chmod is
# required, not cosmetic.
RUN chmod a+x /run.sh

# The builder adds io.hass.arch, io.hass.version and the org.opencontainers
# created/source/version labels; these are the ones only the add-on knows.
LABEL \
    io.hass.type="addon" \
    org.opencontainers.image.title="CertMate client for Home Assistant" \
    org.opencontainers.image.description="Keeps the Home Assistant TLS certificate up to date from a local CertMate service (https://www.certmate.org)" \
    org.opencontainers.image.licenses="Apache-2.0"

CMD ["/run.sh"]
