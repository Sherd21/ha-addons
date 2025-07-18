# https://developers.home-assistant.io/docs/add-ons/configuration#add-on-dockerfile
ARG BUILD_FROM
ARG ALPINE_VERSION=3.21
ARG GO_VERSION=1.24.2

FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS build
WORKDIR /
COPY ./ ./src
RUN cd /src && \
    go build -o ./certwarden-client ./pkg/main


FROM $BUILD_FROM

WORKDIR /app

# timezone support
RUN apk add --no-cache tzdata

# copy app
COPY --from=build /src/certwarden-client .
COPY /run.sh /

# https server
EXPOSE 5055/tcp

RUN set -x && \
    chmod a+x /app/certwarden-client && \
    chmod a+x /run.sh

CMD ["/run.sh"]