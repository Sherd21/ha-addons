# https://developers.home-assistant.io/docs/add-ons/configuration#add-on-dockerfile
ARG BUILD_FROM
FROM ${BUILD_FROM}

# The Home Assistant base image already ships bash, curl, jq, ca-certificates,
# tzdata and bashio. openssl is the only thing this add-on adds.
#
# Deliberately not version-pinned. Alpine keeps exactly one version of a package
# per release branch, so `openssl=3.5.7-r0` would break this build the day
# 3.5.8-r0 replaces it -- there is no version archive to fall back on. The pin
# that matters is the base image tag in build.yaml, which bounds openssl to that
# branch's series; letting the patch level float is what makes a rebuild pick up
# openssl security fixes, which is what you want for a TLS tool.
RUN apk add --no-cache openssl

COPY run.sh /run.sh

# run.sh is mode 100644 in the git index (core.filemode is false on the
# maintainer's machine), so CI checks out a non-executable file. This chmod is
# required, not cosmetic.
RUN chmod a+x /run.sh

CMD ["/run.sh"]
