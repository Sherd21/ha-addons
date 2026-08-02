# Home Assistant Add-on: CertWarden client for Home Assistant

Automatically keeps the Home Assistant TLS certificate up to date from a local [CertWarden](https://www.certwarden.com) service.

This add-on polls CertWarden's download API for your certificate and private key, installs them into the **/ssl** folder where Home Assistant can use them for HTTPS, and restarts Home Assistant so the new certificate takes effect.

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg

64-bit only. See the changelog if you are running a 32-bit Home Assistant installation.

---

This add-on is an independent implementation of CertWarden's [publicly documented HTTP API][api-docs].
It is not affiliated with, endorsed by, or derived from CertWarden or the CertWarden client.

[api-docs]: https://www.certwarden.com/docs/using_certificates/api_calls/
