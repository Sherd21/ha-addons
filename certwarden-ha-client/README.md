# Home Assistant Add-on: CertWarden client for Home Assistant

CertWarden client add-on to retrieve and renew certs for Home Assistant from local CertWarden service (https://www.certwarden.com)

This add-on retrieves certificate from CertWarden service, installs it in **/ssl** folder where Home Assitant can use it for HTTPS protocol.

After the inital certificate installation, the add-on start listening on port 5055/tcp for certificate updates from a CertWarden server. 

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]
![Supports armhf Architecture][armhf-shield]
![Supports armv7 Architecture][armv7-shield]
![Supports i386 Architecture][i386-shield]

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[armhf-shield]: https://img.shields.io/badge/armhf-yes-green.svg
[armv7-shield]: https://img.shields.io/badge/armv7-yes-green.svg
[i386-shield]: https://img.shields.io/badge/i386-yes-green.svg
