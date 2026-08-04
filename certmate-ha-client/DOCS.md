# Home Assistant Add-on: CertMate client for Home Assistant

Automatically keeps the Home Assistant TLS certificate up to date from a local [CertMate](https://www.certmate.org) service.

The add-on asks your CertMate server for the current certificate and private key for a configured domain on a schedule, checks that they are valid and belong together, and installs them into **/ssl** where Home Assistant can serve them over HTTPS. When a new certificate is installed it restarts Home Assistant so the certificate actually takes effect.

## What you need in CertMate

A domain with a certificate already issued in CertMate, and an API token issued with the **Operator** role from Settings -> API Keys. A Viewer token is not enough: downloading a private key requires Operator, and CertMate rejects a Viewer token with HTTP 403. The add-on pulls; the server never needs to reach it, so Home Assistant does not need an inbound port, a port forward, or a firewall rule.

You will need three values:

| From CertMate | Used for |
| --- | --- |
| Server address | Server |
| Domain name (Certificates page) | Domain |
| API token with the Operator role (Settings -> API Keys) | API token |

## Configuration options

- **Server:** Address of the CertMate server. Must start with `https://` and present a certificate your system trusts. (E.g. `https://certmate.example.com:8000`)
- **Domain:** Domain name of the certificate to retrieve, as configured in CertMate.
- **API token:** Bearer token generated from CertMate's Settings -> API Keys page. The token must be issued with the **Operator** role — Viewer tokens cannot download private keys.
- **Check interval:** How often to ask CertMate for the current certificate, in minutes. **Minimum 5, maximum 43200** (30 days). Default is `10080` (weekly). Useful values: `1440` daily, `10080` weekly, `20160` fortnightly. Certificates are normally renewed well before they expire, so weekly leaves plenty of margin and there is little reason to check more often.
- **Update window start time / Update window end time:** The 24-hour local-time window during which a *changed* certificate may be written to disk. Default is `03:00`-`05:00`. Because installing a certificate restarts Home Assistant, this keeps the restart out of your waking hours. A window may cross midnight (e.g. `23:00`-`01:00`).
- **Restart Home Assistant:** Restart Home Assistant Core automatically after installing a new certificate. Default is on. Home Assistant only starts using a new certificate after a restart, so turning this off means restarting yourself.
- **Log level:** How much detail to write to the add-on log. Use `debug` when troubleshooting — it logs every check, including the ones that find nothing to do.

## How it behaves

- **On first start,** if there is no usable certificate in `/ssl` yet, the add-on installs one **immediately** and ignores the update window. Waiting until 03:00 for a Home Assistant instance that has no certificate at all would not be helpful.
- **Afterwards,** it checks every *Check interval* minutes. If the certificate on the server has not changed, it does nothing. If it has changed but the update window is shut, it waits for **the window to open** rather than for the next check — so a long check interval does not delay the install, and cannot skip past the window.
- **Nothing is written unless it is safe.** The certificate and key must both parse, the key must match the certificate, and the certificate must not have expired. If any check fails the download is discarded, the existing files are left alone, and the add-on tries again on the next check. Files are written to a temporary name and renamed into place, so Home Assistant never sees a half-written file.
- **Failures are not fatal.** A network problem, an unreachable server or a rejected API token is logged and retried on the next check.

## Enable SSL in Home Assistant

If this is your first time using certificates with Home Assistant, add the following to your _**configuration.yaml**_:

```yaml
http:
  ssl_certificate: /ssl/fullchain.pem
  ssl_key: /ssl/privkey.pem
```

The easiest way to edit it is with the [Studio Code Server](https://github.com/hassio-addons/addon-vscode) add-on.

---

This add-on is an independent implementation of CertMate's publicly documented HTTP API ([API reference][api-docs]).
It is not affiliated with, endorsed by, or derived from CertMate or the CertMate client.

[api-docs]: https://www.certmate.org/docs/api-reference.html
