package pairing

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"math/big"
	"net"
	"os"
	"path/filepath"
	"time"
)

type Identity struct {
	HubID          string `json:"hub_id"`
	CertificatePEM string `json:"certificate_pem"`
	PrivateKeyPEM  string `json:"private_key_pem"`
}

func LoadIdentity(path string) (*Identity, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return nil, err
	}
	info, err := os.Stat(filepath.Dir(path))
	if err != nil || info.Mode().Perm()&0o077 != 0 {
		return nil, errors.New("direktori identity TLS harus berizin 0700")
	}
	info, err = os.Lstat(path)
	if errors.Is(err, os.ErrNotExist) {
		identity, err := newIdentity()
		if err != nil {
			return nil, err
		}
		contents, err := json.Marshal(identity)
		if err != nil {
			return nil, err
		}
		file, err := os.CreateTemp(filepath.Dir(path), ".tls-identity-*")
		if err != nil {
			return nil, err
		}
		defer os.Remove(file.Name())
		defer file.Close()
		if _, err := file.Write(contents); err != nil {
			return nil, err
		}
		if err := file.Sync(); err != nil {
			return nil, err
		}
		if err := file.Close(); err != nil {
			return nil, err
		}
		if err := os.Link(file.Name(), path); err != nil && !errors.Is(err, os.ErrExist) {
			return nil, err
		}
		return LoadIdentity(path)
	}
	if err != nil {
		return nil, err
	}
	if !info.Mode().IsRegular() || info.Mode().Perm() != 0o600 || info.Size() > 16_384 {
		return nil, errors.New("identity TLS harus berupa file regular berizin 0600")
	}
	contents, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var identity Identity
	if err := json.Unmarshal(contents, &identity); err != nil {
		return nil, errors.New("identity TLS tidak valid")
	}
	if !validID(identity.HubID) {
		return nil, errors.New("hub_id TLS tidak valid")
	}
	if _, err := identity.TLSConfig(); err != nil {
		return nil, err
	}
	return &identity, nil
}

func newIdentity() (*Identity, error) {
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return nil, err
	}
	serial, err := rand.Int(rand.Reader, new(big.Int).Lsh(big.NewInt(1), 128))
	if err != nil {
		return nil, err
	}
	now := time.Now().UTC()
	template := &x509.Certificate{
		SerialNumber: serial, Subject: pkix.Name{CommonName: "Tagihan Vendra sync hub"},
		NotBefore: now.Add(-5 * time.Minute), NotAfter: now.AddDate(1, 0, 0),
		KeyUsage:    x509.KeyUsageDigitalSignature,
		ExtKeyUsage: []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
		DNSNames:    []string{"localhost"},
		IPAddresses: []net.IP{net.ParseIP("127.0.0.1"), net.ParseIP("::1")},
	}
	der, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
	if err != nil {
		return nil, err
	}
	privateDER, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		return nil, err
	}
	return &Identity{HubID: newID(), CertificatePEM: string(pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der})), PrivateKeyPEM: string(pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: privateDER}))}, nil
}

func (identity *Identity) TLSConfig() (*tls.Config, error) {
	pair, err := tls.X509KeyPair([]byte(identity.CertificatePEM), []byte(identity.PrivateKeyPEM))
	if err != nil {
		return nil, errors.New("sertifikat dan private key hub tidak sesuai")
	}
	certificate, err := x509.ParseCertificate(pair.Certificate[0])
	if err != nil {
		return nil, err
	}
	now := time.Now()
	if now.Before(certificate.NotBefore) || !now.Before(certificate.NotAfter) {
		return nil, errors.New("sertifikat hub belum berlaku atau kedaluwarsa; verifikasi dan pairing ulang diperlukan")
	}
	return &tls.Config{MinVersion: tls.VersionTLS13, Certificates: []tls.Certificate{pair}, NextProtos: []string{"http/1.1"}}, nil
}

func (identity *Identity) Fingerprint() string {
	block, _ := pem.Decode([]byte(identity.CertificatePEM))
	hash := sha256.Sum256(block.Bytes)
	return hex.EncodeToString(hash[:])
}

func newID() string {
	var value [16]byte
	rand.Read(value[:])
	milliseconds := time.Now().UnixMilli()
	for i := 5; i >= 0; i-- {
		value[i] = byte(milliseconds)
		milliseconds >>= 8
	}
	value[6] = value[6]&0x0f | 0x70
	value[8] = value[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", value[:4], value[4:6], value[6:8], value[8:10], value[10:])
}
