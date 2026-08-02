<!-- https://developers.home-assistant.io/docs/add-ons/presentation#keeping-a-changelog -->

## 2.0.0

Complete rewrite. Version 1.x was a wrapper around the CertWarden client and
relied on the server pushing certificate updates to an open port. 2.0.0
replaces that with a simple script that uses CertWarden's download API: the
add-on polls the server on a schedule, validates the downloaded certificate
and key before installing them, and needs no open port, no Post Processing
configuration in CertWarden, and none of the CertWarden client's complexity.
Before updating, read **Migrating from 1.x** in the add-on documentation — the
Certificate and Private API keys are now used on every check, and 32-bit
systems (`armhf`, `armv7`, `i386`) are no longer supported.

## 1.0.0

- Initial release
