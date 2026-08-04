# Home Assistant Add-on: CertMate client for Home Assistant

Automatically keeps the Home Assistant TLS certificate up to date from a local [CertMate](https://www.certmate.org) service.

This add-on polls CertMate's certificate download API for your domain's certificate and private key, installs them into the **/ssl** folder where Home Assistant can use them for HTTPS, and restarts Home Assistant so the new certificate takes effect.

Setup and configuration are covered on the add-on's **Documentation** tab in Home Assistant.

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg

64-bit only.

---

This add-on is an independent implementation of CertMate's publicly documented HTTP API ([API reference][api-docs]).
It is not affiliated with, endorsed by, or derived from CertMate or the CertMate client.

The add-on icon is the CertMate project logo, Copyright (c) 2025 Fabrizio Salmi, used under the MIT licence.

[api-docs]: https://www.certmate.org/docs/api-reference.html
