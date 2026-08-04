#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ---------------------------------------------------------------------------
# CertMate client for Home Assistant
#
# Polls CertMate's certificate download API for the configured domain and
# installs the certificate and private key into /ssl, so Home Assistant can
# serve HTTPS with a centrally issued and renewed certificate.
#
# This is an independent implementation of CertMate's publicly documented
# HTTP API (https://www.certmate.org/docs/api-reference.html and
# https://github.com/fabriziosalmi/certmate/blob/main/docs/api.md).
# It shares no code with, and is not derived from, CertMate or the CertMate
# client.
# ---------------------------------------------------------------------------
set -e
set -o pipefail

readonly SSL_DIR="/ssl"
readonly CERT_FILE="${SSL_DIR}/fullchain.pem"
readonly KEY_FILE="${SSL_DIR}/privkey.pem"
readonly API_PATH="api/certificates"
readonly SUPERVISOR_API="http://supervisor"
readonly TIME_RE='^([01][0-9]|2[0-3]):[0-5][0-9]$'
# How close to expiry the installed certificate must be before a failing check
# is treated as an emergency rather than a transient annoyance.
readonly EXPIRY_ALARM_SECONDS=$(( 21 * 86400 ))
# Keep these in step with the int(...) bounds on check_interval in config.yaml.
readonly CHECK_INTERVAL_MIN=5
readonly CHECK_INTERVAL_MAX=43200
readonly CHECK_INTERVAL_DEFAULT=10080
# How soon to retry a restart request that failed, regardless of check interval.
readonly RESTART_RETRY_SECONDS=300

# Resolved from add-on options by validate_config().
SERVER=""
DOMAIN=""
API_TOKEN=""
WINDOW_START=""
WINDOW_END=""
CHECK_INTERVAL=""
RESTART_CORE=""

WORK_DIR=""
SLEEP_PID=""
TERMINATE="false"
# Set when a new certificate is available but the update window is shut. The loop
# then waits for the window to open rather than for the full check interval --
# without this, any interval that does not divide into a day would land outside
# the window every time and the certificate would be deferred forever.
INSTALL_PENDING="false"
# Set when a certificate has been installed but Home Assistant has not yet been
# asked to restart, so a failed restart request is retried instead of leaving
# Core serving the old certificate indefinitely.
RESTART_NEEDED="false"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

validate_config() {
    bashio::config.require 'server' \
        "Set it to the https:// address of your CertMate server."
    bashio::config.require 'domain' \
        "Set it to the domain name of the certificate to retrieve, as configured in CertMate."
    bashio::config.require 'api_token' \
        "Copy an API token issued with the Operator role from CertMate's Settings -> API Keys page."

    SERVER="$(bashio::config 'server')"
    SERVER="${SERVER%/}"
    if [[ "${SERVER}" != https://* ]]; then
        bashio::exit.nok "Option 'server' must start with https:// (got: ${SERVER})"
    fi

    DOMAIN="$(bashio::config 'domain')"
    API_TOKEN="$(bashio::config 'api_token')"

    WINDOW_START="$(bashio::config 'certificate_update_window_start' '03:00')"
    if [[ ! "${WINDOW_START}" =~ ${TIME_RE} ]]; then
        bashio::exit.nok \
            "Option 'certificate_update_window_start' must be a 24-hour HH:MM time (got: '${WINDOW_START}')"
    fi

    WINDOW_END="$(bashio::config 'certificate_update_window_end' '05:00')"
    if [[ ! "${WINDOW_END}" =~ ${TIME_RE} ]]; then
        bashio::exit.nok \
            "Option 'certificate_update_window_end' must be a 24-hour HH:MM time (got: '${WINDOW_END}')"
    fi

    CHECK_INTERVAL="$(bashio::config 'check_interval' "${CHECK_INTERVAL_DEFAULT}")"
    if [[ ! "${CHECK_INTERVAL}" =~ ^[0-9]+$ ]] \
        || (( CHECK_INTERVAL < CHECK_INTERVAL_MIN )) \
        || (( CHECK_INTERVAL > CHECK_INTERVAL_MAX )); then
        bashio::exit.nok \
            "Option 'check_interval' must be a whole number of minutes between ${CHECK_INTERVAL_MIN} and ${CHECK_INTERVAL_MAX} (got: '${CHECK_INTERVAL}')"
    fi

    RESTART_CORE="$(bashio::config 'restart_home_assistant' 'true')"

    if [[ ! -d "${SSL_DIR}" ]]; then
        bashio::exit.nok "${SSL_DIR} does not exist; the add-on requires the 'ssl' folder mapping."
    fi
    if [[ ! -w "${SSL_DIR}" ]]; then
        bashio::exit.nok "${SSL_DIR} is not writable; the 'ssl' folder mapping must be read-write."
    fi
}

log_banner() {
    bashio::log.info "CertMate server ....: ${SERVER}"
    bashio::log.info "Domain .............: ${DOMAIN}"
    bashio::log.info "Install to .........: ${CERT_FILE}, ${KEY_FILE}"
    bashio::log.info "Check interval .....: every ${CHECK_INTERVAL} minute(s)"
    bashio::log.info "Update window ......: ${WINDOW_START}-${WINDOW_END} (local time)"
    bashio::log.info "Restart HA on update: ${RESTART_CORE}"
}

# ---------------------------------------------------------------------------
# Update window
# ---------------------------------------------------------------------------

# Minutes since midnight. 10# forces base 10 so "08"/"09" are not read as octal.
to_minutes() {
    local hhmm="${1}"
    echo $(( 10#${hhmm%%:*} * 60 + 10#${hhmm##*:} ))
}

in_update_window() {
    local now start end
    now="$(to_minutes "$(date +%H:%M)")"
    start="$(to_minutes "${WINDOW_START}")"
    end="$(to_minutes "${WINDOW_END}")"

    if (( start <= end )); then
        (( now >= start && now <= end ))
    else
        # The window wraps midnight, e.g. 23:00-01:00.
        (( now >= start || now <= end ))
    fi
}

# Seconds from now until the update window next opens. Used so a deferred
# install is picked up when the window opens instead of waiting out a check
# interval that may never coincide with it.
seconds_until_window_start() {
    local now start delta
    now=$(( $(date +%-H) * 3600 + $(date +%-M) * 60 + $(date +%-S) ))
    start=$(( $(to_minutes "${WINDOW_START}") * 60 ))
    delta=$(( start - now ))
    if (( delta <= 0 )); then
        delta=$(( delta + 86400 ))
    fi
    # A small cushion so we wake just inside the window, not on its edge.
    echo $(( delta + 30 ))
}

# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------

# fetch_certs <cert-destination> <key-destination>
#
# CertMate's domain-certificate download endpoint supports a JSON mode
# (?format=json) that returns the certificate and private key together in a
# single response -- https://github.com/fabriziosalmi/certmate/blob/main/docs/api.md
# documents this as "the preferred automation shape for ... any ... client
# that wants to write PEM files directly." One request instead of two, and it
# avoids a path-style per-file download URL that CertMate's own API reference
# advertises for domain certificates but that its own API guide does not
# actually document for that resource (only for the unrelated client-cert and
# CRL endpoints) -- so it is not relied on here.
fetch_certs() {
    local dest_cert="${1}" dest_key="${2}"
    local cfg="${WORK_DIR}/curl.cfg"
    local err="${WORK_DIR}/curl.err"
    local json="${WORK_DIR}/download.json"
    local url="${SERVER}/${API_PATH}/${DOMAIN}/download?format=json"
    local rc=0
    local http_code=""

    # The API token goes in a 0600 config file rather than on the command line,
    # so it never appears in the process list.
    ( umask 077; printf 'header = "Authorization: Bearer %s"\n' "${API_TOKEN}" > "${cfg}" )

    http_code="$(curl --config "${cfg}" \
        --fail --silent --show-error \
        --proto '=https' \
        --user-agent 'certmate-ha-client (Home Assistant add-on)' \
        --max-time 30 \
        --retry 3 --retry-delay 5 --retry-connrefused \
        --output "${json}" \
        --write-out '%{http_code}' \
        "${url}" 2>"${err}")" || rc=$?

    rm -f "${cfg}"

    if (( rc != 0 )); then
        case "${http_code}" in
            401)
                bashio::log.error \
                    "CertMate did not accept the API token (HTTP 401)."
                bashio::log.error \
                    "Check the 'api_token' option against a key on CertMate's Settings -> API Keys page."
                ;;
            403)
                # The token is valid; it is the key's role that is not. This
                # download returns the private key inline, which CertMate
                # allows only to the Operator role -- so a Viewer token gets
                # this far and then fails on every single check.
                bashio::log.error \
                    "CertMate accepted the API token but refused the download (HTTP 403)."
                bashio::log.error \
                    "The token must be issued with the Operator role: downloading a private key is denied to Viewer tokens."
                ;;
            404)
                bashio::log.error \
                    "CertMate has no certificate for domain '${DOMAIN}' (HTTP 404). Check the 'domain' option."
                ;;
            *)
                bashio::log.error \
                    "Could not download the certificate from ${url}: $(tr '\n' ' ' < "${err}")"
                ;;
        esac
        return 1
    fi

    if [[ ! -s "${json}" ]]; then
        bashio::log.error "CertMate returned an empty response from ${url}."
        return 1
    fi

    if ! jq -e '(.fullchain_pem // empty) != "" and (.private_key_pem // empty) != ""' \
        "${json}" >/dev/null 2>&1; then
        bashio::log.error \
            "CertMate's response did not include both 'fullchain_pem' and 'private_key_pem'; refusing to install."
        return 1
    fi

    jq -r '.fullchain_pem' "${json}" > "${dest_cert}"
    jq -r '.private_key_pem' "${json}" > "${dest_key}"

    if [[ ! -s "${dest_cert}" || ! -s "${dest_key}" ]]; then
        bashio::log.error "CertMate returned an empty certificate or private key from ${url}."
        return 1
    fi

    return 0
}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

# Never write a certificate/key pair that Home Assistant cannot serve: a bad
# pair here takes the HTTPS listener down until someone fixes it by hand.
validate_pair() {
    local cert="${1}" key="${2}"
    local cert_pub key_pub

    if ! openssl x509 -in "${cert}" -noout >/dev/null 2>&1; then
        bashio::log.error "The downloaded certificate is not valid PEM; refusing to install it."
        return 1
    fi

    if ! openssl pkey -in "${key}" -noout >/dev/null 2>&1; then
        bashio::log.error "The downloaded private key is not valid PEM; refusing to install it."
        return 1
    fi

    cert_pub="$(openssl x509 -in "${cert}" -noout -pubkey 2>/dev/null)" || cert_pub=""
    key_pub="$(openssl pkey -in "${key}" -pubout 2>/dev/null)" || key_pub=""
    if [[ -z "${cert_pub}" || "${cert_pub}" != "${key_pub}" ]]; then
        bashio::log.error \
            "The downloaded certificate and private key do not match; refusing to install them."
        bashio::log.error \
            "This can happen if a renewal completed between the two downloads. It will be retried on the next check."
        return 1
    fi

    if ! openssl x509 -in "${cert}" -noout -checkend 0 >/dev/null 2>&1; then
        bashio::log.error "The downloaded certificate has already expired; refusing to install it."
        return 1
    fi

    return 0
}

# Is what we just downloaded already what is on disk?
local_is_current() {
    local cert="${1}" key="${2}"
    [[ -f "${CERT_FILE}" && -f "${KEY_FILE}" ]] || return 1
    cmp -s "${cert}" "${CERT_FILE}" || return 1
    cmp -s "${key}" "${KEY_FILE}" || return 1
}

# Is there a certificate on disk that Home Assistant can actually serve?
local_is_usable() {
    [[ -s "${CERT_FILE}" && -s "${KEY_FILE}" ]] || return 1
    openssl x509 -in "${CERT_FILE}" -noout >/dev/null 2>&1 || return 1
    openssl pkey -in "${KEY_FILE}" -noout >/dev/null 2>&1 || return 1
}

# A failing check barely matters while the installed certificate is still valid
# for months, and matters enormously once it is not. Without this, a wrong API
# token would sit in the log at warning level and the first real symptom would
# be Home Assistant serving an expired certificate.
warn_if_expiring() {
    local enddate
    [[ -f "${CERT_FILE}" ]] || return 0
    if openssl x509 -in "${CERT_FILE}" -noout -checkend "${EXPIRY_ALARM_SECONDS}" >/dev/null 2>&1; then
        return 0
    fi
    enddate="$(openssl x509 -in "${CERT_FILE}" -noout -enddate 2>/dev/null | cut -d= -f2-)"
    bashio::log.error \
        "The certificate installed in ${SSL_DIR} expires on ${enddate:-an unknown date} and renewal is failing."
    bashio::log.error \
        "Home Assistant will serve an expired certificate unless this is fixed."
    return 0
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

install_certs() {
    local cert="${1}" key="${2}"
    local tmp_cert="${SSL_DIR}/.fullchain.pem.tmp"
    local tmp_key="${SSL_DIR}/.privkey.pem.tmp"

    rm -f "${tmp_cert}" "${tmp_key}"

    # Stage next to the target, then rename. A rename within one filesystem is
    # atomic, so Home Assistant can never read a partially written file.
    if ! ( umask 077; cat "${key}" > "${tmp_key}" ); then
        bashio::log.error "Failed to stage the private key in ${SSL_DIR}."
        rm -f "${tmp_key}"
        return 1
    fi
    if ! ( umask 022; cat "${cert}" > "${tmp_cert}" ); then
        bashio::log.error "Failed to stage the certificate in ${SSL_DIR}."
        rm -f "${tmp_cert}" "${tmp_key}"
        return 1
    fi

    chmod 0600 "${tmp_key}"
    chmod 0644 "${tmp_cert}"

    # Deliberately no sync here. What protects Home Assistant from reading a
    # half-written file is the atomicity of rename(), not durability. A bare
    # sync(1) flushes every mounted filesystem, and on a FUSE-backed /ssl it
    # blocks indefinitely -- observed hanging the install step outright, leaving
    # the staging files in place and the certificate never installed. If power
    # is lost before the data reaches disk, the next poll simply refetches.
    if ! mv -f "${tmp_key}" "${KEY_FILE}"; then
        bashio::log.error "Failed to install the private key at ${KEY_FILE}."
        rm -f "${tmp_cert}" "${tmp_key}"
        return 1
    fi
    if ! mv -f "${tmp_cert}" "${CERT_FILE}"; then
        bashio::log.error "Failed to install the certificate at ${CERT_FILE}."
        rm -f "${tmp_cert}"
        return 1
    fi

    bashio::log.info "Installed ${CERT_FILE} and ${KEY_FILE}."
    bashio::log.info "Certificate valid until: $(openssl x509 -in "${CERT_FILE}" -noout -enddate 2>/dev/null | cut -d= -f2-)"
    return 0
}

# ---------------------------------------------------------------------------
# Home Assistant restart
# ---------------------------------------------------------------------------

# Is Home Assistant Core actually up?
#
# GET /core/info cannot answer this: it returns version, arch, port, ssl and so
# on, and carries no run-state field at all, so the obvious-looking .data.state
# is always empty. Probe the Core API proxy instead -- Supervisor checks Core's
# own API state before serving /core/api, so success here is a real liveness
# signal. It does need its own permission: Supervisor gates the Core API proxy
# on homeassistant_api, separately from the hassio_role that covers /core/restart,
# so config.yaml sets both. Without it this probe gets a 401 and reports Core as
# down forever, silently skipping every restart.
core_is_running() {
    curl --fail --silent --max-time 15 \
        --header "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        --output /dev/null \
        "${SUPERVISOR_API}/core/api/" 2>/dev/null
}

restart_core() {
    if [[ "${RESTART_CORE}" != "true" ]]; then
        bashio::log.notice \
            "Automatic restart is disabled. Restart Home Assistant yourself to start using the new certificate."
        RESTART_NEEDED="false"
        return 0
    fi

    if [[ -z "${SUPERVISOR_TOKEN:-}" ]]; then
        bashio::log.warning \
            "SUPERVISOR_TOKEN is not set, so Home Assistant cannot be restarted automatically."
        RESTART_NEEDED="false"
        return 0
    fi

    # Under 'startup: services' this add-on runs before Core, so on a cold boot
    # there may be nothing up to restart yet -- and nothing to do either, because
    # Core reads the certificate when it starts. Clearing the debt here is
    # therefore correct, not a shortcut.
    if ! core_is_running; then
        bashio::log.info \
            "Home Assistant Core is not up yet; it will read the new certificate when it starts."
        RESTART_NEEDED="false"
        return 0
    fi

    bashio::log.info "Restarting Home Assistant Core to load the new certificate..."
    if bashio::core.restart; then
        bashio::log.info "Home Assistant Core restart requested."
        RESTART_NEEDED="false"
    else
        # Keep the debt and retry. The certificate on disk now matches the
        # server, so no later check would reinstall it -- without a retry Home
        # Assistant would keep serving the old certificate until something else
        # restarted it.
        bashio::log.warning \
            "Could not restart Home Assistant Core; will retry shortly. The new certificate is installed."
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

check_once() {
    local cert="${WORK_DIR}/fullchain.pem"
    local key="${WORK_DIR}/privkey.pem"

    bashio::log.debug "Checking CertMate for a new certificate..."

    fetch_certs "${cert}" "${key}" || return 1
    validate_pair "${cert}" "${key}" || return 1

    if local_is_current "${cert}" "${key}"; then
        bashio::log.debug "The installed certificate is already up to date."
        INSTALL_PENDING="false"
        # A restart owed from an earlier cycle still has to happen: the disk
        # already matches the server, so this branch is the only one that runs
        # from here on.
        if [[ "${RESTART_NEEDED}" == "true" ]]; then
            restart_core
        fi
        return 0
    fi

    if ! local_is_usable; then
        bashio::log.info \
            "No usable certificate found in ${SSL_DIR}; installing now and ignoring the update window."
    elif in_update_window; then
        bashio::log.info "A new certificate is available and we are inside the update window; installing."
    else
        bashio::log.info \
            "A new certificate is available, but the update window (${WINDOW_START}-${WINDOW_END}) is closed; deferring."
        INSTALL_PENDING="true"
        return 0
    fi

    install_certs "${cert}" "${key}" || return 1
    INSTALL_PENDING="false"
    RESTART_NEEDED="true"
    restart_core
    return 0
}

interruptible_sleep() {
    local seconds="${1}"
    sleep "${seconds}" &
    SLEEP_PID=$!
    wait "${SLEEP_PID}" || true
    SLEEP_PID=""
}

on_terminate() {
    TERMINATE="true"
    if [[ -n "${SLEEP_PID}" ]]; then
        kill "${SLEEP_PID}" 2>/dev/null || true
    fi
}

cleanup() {
    if [[ -n "${WORK_DIR}" && -d "${WORK_DIR}" ]]; then
        rm -rf "${WORK_DIR}"
    fi
}

configure_logging() {
    local level
    # bashio::log.level treats an unrecognised value as fatal, and an empty
    # string is unrecognised. bashio::config returns empty when the Supervisor
    # API is briefly unavailable, which would otherwise kill the add-on with a
    # misleading "Unknown log_level:" instead of a usable message.
    level="$(bashio::config 'log_level' 'info')"
    if [[ -z "${level}" || "${level}" == "null" ]]; then
        level="info"
    fi
    bashio::log.level "${level}"
}

main() {
    configure_logging

    validate_config
    log_banner

    WORK_DIR="$(mktemp -d)"
    trap cleanup EXIT
    trap on_terminate TERM INT

    local sleep_seconds until_window
    while true; do
        # Every per-cycle failure is contained here: a transient network or
        # server problem must never take the poll loop down.
        if ! check_once; then
            bashio::log.warning "Check failed; retrying in ${CHECK_INTERVAL} minute(s)."
            warn_if_expiring
        fi

        if [[ "${TERMINATE}" == "true" ]]; then
            break
        fi

        sleep_seconds=$(( CHECK_INTERVAL * 60 ))

        # With an install deferred, wake when the window opens if that is sooner
        # than the next scheduled check. Taking the minimum means the configured
        # interval is still an upper bound on how long we sleep, and a long
        # interval can no longer step over the window indefinitely.
        if [[ "${INSTALL_PENDING}" == "true" ]]; then
            until_window="$(seconds_until_window_start)"
            if (( until_window < sleep_seconds )); then
                sleep_seconds="${until_window}"
                bashio::log.info \
                    "Waiting $(( (sleep_seconds + 59) / 60 )) minute(s) for the update window to open."
            fi
        fi

        # A restart still owed must not wait out a long check interval.
        if [[ "${RESTART_NEEDED}" == "true" ]] && (( sleep_seconds > RESTART_RETRY_SECONDS )); then
            sleep_seconds="${RESTART_RETRY_SECONDS}"
            bashio::log.info \
                "Retrying the Home Assistant restart in $(( sleep_seconds / 60 )) minute(s)."
        fi

        interruptible_sleep "${sleep_seconds}"

        if [[ "${TERMINATE}" == "true" ]]; then
            break
        fi
    done

    bashio::log.info "Shutting down."
}

main "$@"
