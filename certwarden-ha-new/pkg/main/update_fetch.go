package main

import "fmt"

// Server Endpoints
const (
	serverEndpointDownloadKeys  = "/certwarden/api/v1/download/privatekeys"
	serverEndpointDownloadCerts = "/certwarden/api/v1/download/certificates"
)

// updateClientKeyAndCertchain queries the server and retrieves the specified key
// and certificate PEM from the server. it then updates the app with the new pem;
func (app *app) updateClientKeyAndCertchain(certIndex int) error {
	// get key
	keyPem, err := app.getPemWithApiKey(app.cfg.ServerAddress+serverEndpointDownloadKeys+"/"+app.cfg.Certs[certIndex].KeyName, app.cfg.Certs[certIndex].KeyApiKey)
	if err != nil {
		return fmt.Errorf("failed to get key pem %d from server (%s)", certIndex, err)
	}

	// get cert
	certPem, err := app.getPemWithApiKey(app.cfg.ServerAddress+serverEndpointDownloadCerts+"/"+app.cfg.Certs[certIndex].CertName, app.cfg.Certs[certIndex].CertApiKey)
	if err != nil {
		return fmt.Errorf("failed to get cert pem %d from server (%s)", certIndex, err)
	}

	// do update of local tls cert
	err = app.updateClientCert(keyPem, certPem, certIndex)
	if err != nil {
		return err
	}

	return nil
}
