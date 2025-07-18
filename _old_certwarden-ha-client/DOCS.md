# Home Assistant Add-on: CertWarden client for Home Assistant

## How to use

CertWarden client add-on renews Home Assistant certificate, retrieved from CertWarden service (https://www.certwarden.com).

After installation, fill the Configuration options, and start the add-on.

The add-on would try to retrieve the certificate right away and compare it with the one installed in **/ssl** directory. If no local certificate present, or they are don't match retrieved, the add-on will update the Home Assistant certificate.

> **Important:** Home Assistant doesn't use new certificate without a restart. The add-on won't restart HA automatically, so you need to do that manually. Normally, certificates are renewed about a month before expiration date so you would have enought time.

## Enable SSL in Home Assistant

If this is your first time using certificates with Home Assistant, you need to update HA configuration.yaml file and add the following code:

```yaml
http:
  ssl_certificate: /ssl/fullchain.pem
  ssl_key: /ssl/privkey.pem
```

The easiest way to do that is by installing [Studio Code Server](https://github.com/hassio-addons/addon-vscode) add-on and edit _configuration.yaml_ file there.

## Configuration options

- **Check period:** This parameter defines how often the add-on check certificate status (hourly, daily, weekly, or monthly). Default is daily.
- **Server:** CertWarden server name (or IP) and port. E.g. "certwarden.example.com:4055"
- **Certificate name:** Name of certificate to retrieve from CertWarden
- **Certificate API key:** Certificate API access key
- **Private API key:** Private key API access key
