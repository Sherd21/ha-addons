package main

import (
	"encoding/base64"
	"encoding/json"
	"net/http"
)

const (
	postRoute = "/certwardenclient/api/v1/install"
)

// innerPayload is the struct for the unencrypted data that is inside the payload sent from
// server to the client
type innerPayload struct {
	KeyPem  string `json:"key_pem"`
	CertPem string `json:"cert_pem"`
}

// postPayload is the actual payload sent from server to the client
type postPayload struct {
	// Payload is the base64 encoded string of the cipherData produced from encrypting innerPayload
	Payload string `json:"payload"`
}

func (app *app) postKeyAndCert(w http.ResponseWriter, r *http.Request) {
	// only allow POST
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusNotFound)
		return
	}

	// verify route is correct, else 404
	if r.URL.Path == postRoute || r.URL.Path == postRoute+"/" {
		// correct route, no-op

	} else {
		// bad route
		w.WriteHeader(http.StatusNotFound)
		return
	}

	// decode body into payload
	payload := postPayload{}
	err := json.NewDecoder(r.Body).Decode(&payload)
	if err != nil {
		w.WriteHeader(http.StatusUnauthorized)
		app.logger.Debugf("failed to umarshal body (%s)", err)
		return
	}

	bodyDecoded, err := base64.RawURLEncoding.DecodeString(payload.Payload)
	if err != nil {
		w.WriteHeader(http.StatusUnauthorized)
		app.logger.Debugf("failed to decode inner payload (%s)", err)
		return
	}

	// decrypt (find the correct decrypter to determine the index)
	certIndex := -1
	bodyDecrypted := []byte{}
	for i := range app.cipherAEAD {
		nonceSize := app.cipherAEAD[i].NonceSize()
		nonce, ciphertext := bodyDecoded[:nonceSize], bodyDecoded[nonceSize:]

		bodyDecrypted, err = app.cipherAEAD[i].Open(nil, nonce, ciphertext, nil)
		if err != nil {
			// no-op, continue
		} else {
			certIndex = i
			break
		}
	}
	// decryption failed
	if certIndex < 0 {
		w.WriteHeader(http.StatusUnauthorized)
		app.logger.Debugf("failed to decrypt inner payload (%s)", err)
		return
	}

	// right route & authorized, try to do work
	app.logger.Infof("authenticated payload received from %s for cert %d", r.RemoteAddr, certIndex)

	// decode payload
	innerPayload := innerPayload{}

	// unmarshal decrypted data into payload
	err = json.Unmarshal(bodyDecrypted, &innerPayload)
	if err != nil {
		app.logger.Errorf("failed to umarshal decrypted inner payload (%s)", err)
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	// process and install new key/cert in client (will error if bad)
	err = app.updateClientCert([]byte(innerPayload.KeyPem), []byte(innerPayload.CertPem), certIndex)
	if err != nil {
		app.logger.Errorf("failed to process key and/or cert %d file(s) from server post (%s)", certIndex, err)
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	// run go routine to update files; first run update immediately to check for missing files
	// which also returns if the disk needs an update. Then schedule job if the disk needs an
	// update. If no disk update is needed, ensure cancel any old pending job.
	go func() {
		// write files to disk now if file(s) are missing
		diskNeedsUpdate := app.updateCertFilesAndRestartContainers(certIndex, true)

		// schedule job if disk still needs an update
		if diskNeedsUpdate {
			app.scheduleJobWriteCertsMemoryToDisk(certIndex)
		} else if app.pendingJobCancels[certIndex] != nil {
			// cancel any old pending job if no update needed and there is a job to cancel
			app.pendingJobCancels[certIndex]()
		}
	}()

	w.WriteHeader(http.StatusOK)
}
