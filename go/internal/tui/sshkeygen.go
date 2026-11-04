package tui

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/pem"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"golang.org/x/crypto/ssh"
)

// GeneratedSSHKey holds the generated private and public keys.
type GeneratedSSHKey struct {
	PrivateKeyPEM string
	PublicKey     string
	KeyType       string
}

// GenerateEd25519KeyPair creates an air-gapped Ed25519 SSH keypair natively in Go.
func GenerateEd25519KeyPair(comment string) (*GeneratedSSHKey, error) {
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return nil, fmt.Errorf("failed generating Ed25519 key: %w", err)
	}

	pemBlock, err := ssh.MarshalPrivateKey(priv, comment)
	if err != nil {
		return nil, fmt.Errorf("failed marshaling private key: %w", err)
	}

	privPEM := string(pem.EncodeToMemory(pemBlock))

	sshPub, err := ssh.NewPublicKey(pub)
	if err != nil {
		return nil, fmt.Errorf("failed creating SSH public key: %w", err)
	}

	pubBytes := ssh.MarshalAuthorizedKey(sshPub)
	pubStr := strings.TrimSpace(string(pubBytes))
	if comment != "" {
		pubStr = fmt.Sprintf("%s %s\n", pubStr, comment)
	} else {
		pubStr = pubStr + "\n"
	}

	return &GeneratedSSHKey{
		PrivateKeyPEM: privPEM,
		PublicKey:     pubStr,
		KeyType:       "Ed25519 (256-bit)",
	}, nil
}

// SaveSSHKeyPair writes private key (0600) and public key (0644) to disk.
func SaveSSHKeyPair(targetPrivatePath string, key *GeneratedSSHKey) error {
	dir := filepath.Dir(targetPrivatePath)
	if err := os.MkdirAll(dir, 0700); err != nil {
		return fmt.Errorf("failed creating directory %q: %w", dir, err)
	}

	if err := os.WriteFile(targetPrivatePath, []byte(key.PrivateKeyPEM), 0600); err != nil {
		return fmt.Errorf("failed saving private key: %w", err)
	}

	pubPath := targetPrivatePath + ".pub"
	if err := os.WriteFile(pubPath, []byte(key.PublicKey), 0644); err != nil {
		return fmt.Errorf("failed saving public key: %w", err)
	}

	return nil
}

