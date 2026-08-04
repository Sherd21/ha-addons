# Changelog

## 1.0.0

- Initial release. Polls CertMate's certificate download API
  (`GET /api/certificates/<domain>/download?format=json`) for the configured
  domain and installs the certificate and private key into `/ssl`.
- Ships a custom AppArmor profile that confines the add-on to the few paths
  and binaries it actually needs, giving it a security rating of 6.
