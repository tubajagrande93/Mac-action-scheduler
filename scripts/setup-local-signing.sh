#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
CERT_NAME="Mac Action Scheduler Local Code Signing"

if security find-identity -v -p codesigning "$KEYCHAIN" | grep -Fq "\"$CERT_NAME\""; then
    echo "Local code-signing identity already available: $CERT_NAME"
    exit 0
fi

echo "Installing a self-signed code-signing identity in your login Keychain."
echo "Certificate trust will be scoped to code signing, not SSL."
echo "macOS may ask you to approve access to your Keychain."

umask 077
TMP="$(mktemp -d -t mas-sign)"
trap 'rm -rf "$TMP"' EXIT

openssl req -x509 -newkey rsa:3072 -sha256 -days 1825 -nodes \
    -keyout "$TMP/key.pem" \
    -out "$TMP/cert.pem" \
    -subj "/CN=$CERT_NAME" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,digitalSignature,keyCertSign" \
    -addext "extendedKeyUsage=codeSigning" \
    >/dev/null 2>&1

P12_PASSWORD="$(openssl rand -hex 32)"

openssl pkcs12 -export \
    -inkey "$TMP/key.pem" \
    -in "$TMP/cert.pem" \
    -out "$TMP/identity.p12" \
    -keypbe PBE-SHA1-3DES \
    -certpbe PBE-SHA1-3DES \
    -macalg sha256 \
    -passout "pass:$P12_PASSWORD"

security import "$TMP/identity.p12" \
    -k "$KEYCHAIN" \
    -P "$P12_PASSWORD" \
    -T /usr/bin/codesign

unset P12_PASSWORD

# User-level trust, scoped to the code-signing policy only.
security add-trusted-cert \
    -r trustRoot \
    -p codeSign \
    -k "$KEYCHAIN" \
    "$TMP/cert.pem"

echo "=== AVAILABLE CODE-SIGNING IDENTITIES ==="
security find-identity -v -p codesigning "$KEYCHAIN"

if ! security find-identity -v -p codesigning "$KEYCHAIN" | grep -Fq "\"$CERT_NAME\""; then
    echo "ERROR: The local identity is not valid for code signing."
    echo "Do not rebuild the app until the identity is listed as valid."
    exit 1
fi

echo "PASS: Stable local code-signing identity installed."
echo "Do not export or commit the private key."
