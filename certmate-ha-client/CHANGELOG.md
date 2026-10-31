# Changelog

## 1.0.1

- chore: rebuilt on Home Assistant base image 2026.10.3 (was 2026.06.1)
- chore: bumped bashio from 0.17.5 to 0.19.0
- chore: bumped s6-overlay from 3.2.2.0 to 3.2.3.2
- fix(security): bumped curl from 8.20.0 to 8.23.0
- fix(security): bumped OpenSSL from 3.5.7 to 3.5.9
- fix(security): bumped jq from 1.8.1 to 1.8.2
- fix(security): updated the remaining Alpine system packages, clearing 210
  known vulnerabilities (1 critical, 60 high)

## 1.0.0

- Initial release. Polls CertMate's certificate download API
  (`GET /api/certificates/<domain>/download?format=json`) for the configured
  domain and installs the certificate and private key into `/ssl`.
- Ships a custom AppArmor profile that confines the add-on to the few paths
  and binaries it actually needs, giving it a security rating of 6.
