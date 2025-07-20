#!/usr/bin/with-contenv bashio

### Server parameters

#CW_CLIENT_SERVER_ADDRESS       - DNS name of the server. Must start with https and have a valid ssl certificate.
CW_CLIENT_SERVER_ADDRESS=$(bashio::config 'server')


### Certificate parameters

# CW_CLIENT_0_AES_KEY_BASE64    - base64 raw url encoding of AES key used for communication between server and client (generate one on server)
CW_CLIENT_0_AES_KEY_BASE64=$(bashio::config 'server_communication_key')

# CW_CLIENT_0_CERT_NAME         - Name of certificate in server
CW_CLIENT_0_CERT_NAME=$(bashio::config 'certificate_name')

# CW_CLIENT_0_CERT_APIKEY		- API Key of certificate in server
CW_CLIENT_0_CERT_APIKEY=$(bashio::config 'certificate_apikey')

# CW_CLIENT_0_KEY_NAME          - Name of private key in server
CW_CLIENT_0_KEY_NAME=$(bashio::config 'key_name')

# CW_CLIENT_0_KEY_APIKEY		- API Key of private key in server
CW_CLIENT_0_KEY_APIKEY=$(bashio::config 'key_apikey')


### Hidden parameters (certificate path defined and maped in config.yaml to /ssl. There are no benefits in exposing these parameters in add-on configuration.)
# CW_CLIENT_0_CERT_PATH			- the path to save all keys and certificates to. (default for Home Assistant is "/ssl")
CW_CLIENT_0_CERT_PATH="/ssl"

# CW_CLIENT_0_CERTCHAIN_PEM_FILENAME    - filename to save the certchain as (default for Home Assistant is "fullchain.pem")
CW_CLIENT_0_CERTCHAIN_PEM_FILENAME="fullchain.pem"

# CW_CLIENT_0_KEY_PEM_FILENAME	- filename to save the key pem as (default for Home Assistant is "privkey.pem")
CW_CLIENT_0_KEY_PEM_FILENAME="privkey.pem"

# CW_CLIENT_BIND_PORT			- Port, the addon will listen on for certificate updates. Default is 5055. (At the moment, CertWarden server doesn't support custom ports. 5055/TCP should be used.)
# CW_CLIENT_BIND_PORT=5055

### Optional parameters

# CW_CLIENT_0_FILE_UPDATE_TIME_START		- 24-hour time when window opens to write key/cert updates to filesystem
# CW_CLIENT_0_FILE_UPDATE_TIME_START=00:01
CW_CLIENT_0_FILE_UPDATE_TIME_START=$(bashio::config 'certificate_update_window_start')

# CW_CLIENT_0_FILE_UPDATE_TIME_END			- 24-hour time when window closes to write key/cert updates to filesystem
# CW_CLIENT_0_FILE_UPDATE_TIME_END=23:59
CW_CLIENT_0_FILE_UPDATE_TIME_END=$(bashio::config 'certificate_update_window_end')

# CW_CLIENT_0_FILE_UPDATE_DAYS_OF_WEEK	- Day(s) of the week to write updated key/cert to filesystem (blank is any) - separate multiple using spaces


### Export add-on parameters as environment variables
export CW_CLIENT_SERVER_ADDRESS
export CW_CLIENT_0_AES_KEY_BASE64
export CW_CLIENT_0_CERT_NAME
export CW_CLIENT_0_KEY_NAME
export CW_CLIENT_0_KEY_APIKEY
export CW_CLIENT_0_CERT_APIKEY
export CW_CLIENT_0_CERT_PATH
export CW_CLIENT_0_CERTCHAIN_PEM_FILENAME
export CW_CLIENT_0_KEY_PEM_FILENAME
export CW_CLIENT_0_FILE_UPDATE_TIME_START
export CW_CLIENT_0_FILE_UPDATE_TIME_END

bashio::log.info "Setting CW_CLIENT_SERVER_ADDRESS to: ${CW_CLIENT_SERVER_ADDRESS}"
bashio::log.info "Setting CW_CLIENT_0_CERT_NAME to: ${CW_CLIENT_0_CERT_NAME}"

exec /app/certwarden-client