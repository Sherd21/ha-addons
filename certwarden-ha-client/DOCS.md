# Home Assistant Add-on: CertWarden client for Home Assistant

Automatically keeps the Home Assistant TLS certificate up to date from a local [CertWarden](https://www.certwarden.com) service.

The add-on asks your CertWarden server for the current certificate and private key on a schedule, checks that they are valid and belong together, and installs them into **/ssl** where Home Assistant can serve them over HTTPS. When a new certificate is installed it restarts Home Assistant so the certificate actually takes effect.

## What you need in CertWarden

Only a certificate and a private key with API keys enabled — the same ones you would use for a manual `curl`. **No Post Processing configuration is required.** The add-on pulls; the server never needs to reach it, so Home Assistant does not need an inbound port, a port forward, or a firewall rule.

You will need four values:

| From CertWarden | Used for |
| --- | --- |
| Certificate name (Certificates page) | Certificate name |
| Certificate API key (Certificates page) | Certificate API key |
| Private key name (Private Keys page) | Key name |
| Private key API key (Private Keys page) | Private API key |

## Configuration options

- **Server:** Address of the CertWarden server. Must start with `https://` and present a certificate your system trusts. (E.g. `https://certwarden.example.com:4055`)
- **Certificate name:** Name of the certificate to retrieve, as shown on the CertWarden certificate page.
- **Key name:** Name of the private key to retrieve, as shown on the CertWarden private key page.
- **Certificate API key:** API key of the certificate.
- **Private API key:** API key of the private key.
- **Check interval:** How often to ask CertWarden for the current certificate, in minutes. **Minimum 5, maximum 43200** (30 days); default `10080` (weekly). Useful values: `1440` daily, `10080` weekly, `20160` fortnightly. Certificates are normally renewed about a month before they expire, so weekly leaves plenty of margin.
- **Update window start time / Update window end time:** The 24-hour local-time window during which a *changed* certificate may be written to disk. Default is `03:00`–`05:00`. Because installing a certificate restarts Home Assistant, this keeps the restart out of your waking hours. A window may cross midnight (e.g. `23:00`–`01:00`).
- **Restart Home Assistant:** Restart Home Assistant Core automatically after installing a new certificate. Default is on. Home Assistant only starts using a new certificate after a restart, so turning this off means restarting yourself.
- **Log level:** How much detail to write to the add-on log. Use `debug` when troubleshooting — it logs every check, including the ones that find nothing to do.

## How it behaves

- **On first start,** if there is no usable certificate in `/ssl` yet, the add-on installs one **immediately** and ignores the update window. Waiting until 03:00 for a Home Assistant instance that has no certificate at all would not be helpful.
- **Afterwards,** it checks every *Check interval* minutes. If the certificate on the server has not changed, it does nothing. If it has changed but the update window is shut, it waits for **the window to open** rather than for the next check — so a long check interval does not delay the install, and cannot skip past the window.
- **Nothing is written unless it is safe.** The certificate and key must both parse, the key must match the certificate, and the certificate must not have expired. If any check fails the download is discarded, the existing files are left alone, and the add-on tries again on the next check. Files are written to a temporary name and renamed into place, so Home Assistant never sees a half-written file.
- **Failures are not fatal.** A network problem, an unreachable server or a rejected API key is logged and retried on the next check.

## Enable SSL in Home Assistant

If this is your first time using certificates with Home Assistant, add the following to your _**configuration.yaml**_:

```yaml
http:
  ssl_certificate: /ssl/fullchain.pem
  ssl_key: /ssl/privkey.pem
```

The easiest way to edit it is with the [Studio Code Server](https://github.com/hassio-addons/addon-vscode) add-on.

## Migrating from 1.x

Version 1.x was a wrapper around the CertWarden client and waited for the server to *push* updates to it over port 5055. Version 2 polls CertWarden's download API instead.

> [!IMPORTANT]
> **Check your two API keys before or immediately after updating.**
>
> 1.x used the Certificate API key and Private API key only on its very first run, so a working 1.x install may hold keys that were never correct, or that have been rotated in CertWarden since. 2.0.0 uses them on every check. If they are wrong the add-on keeps serving the certificate already in `/ssl` and logs an error each time — **nothing breaks straight away; it breaks when that certificate expires.** After updating, open the add-on log and confirm you do not see `CertWarden rejected the API key`.
>
> To check a key without updating:
>
> ```bash
> curl -sS -o /dev/null -w '%{http_code}\n' -H "X-API-Key: <cert api key>" "https://certwarden.example.com/certwarden/api/v1/download/certificates/<cert name>"
> ```
>
> `200` means good. `401`/`403` means re-copy the key from the CertWarden certificate page. Repeat with the private key's API key against `.../download/privatekeys/<key name>`.

After updating:

1. **Re-check the add-on configuration.** Your server address, certificate/key names and API keys are kept, but see the API key note above. Three new options appear with sensible defaults.
2. **The Server Communication key is gone.** It only existed for the encrypted push channel. In CertWarden you can clear the certificate's Post Processing settings — the *HTTPS Address of Cert Warden Client* and the *Client AES Key* are no longer used.
3. **Port 5055 is no longer used.** Remove any port forward, firewall rule or router mapping you created for it.
4. **Restarts are now automatic** by default. If you would rather keep restarting Home Assistant by hand, turn off *Restart Home Assistant*.

**32-bit systems are no longer supported.** 2.0.0 builds for `aarch64` and `amd64` only, as Home Assistant has deprecated `armhf`, `armv7` and `i386`. If you are on a 32-bit system, stay on 1.0.0 and consider reinstalling Home Assistant as 64-bit.

---

This add-on is an independent implementation of CertWarden's [publicly documented HTTP API][api-docs].
It is not affiliated with, endorsed by, or derived from CertWarden or the CertWarden client.

[api-docs]: https://www.certwarden.com/docs/using_certificates/api_calls/
