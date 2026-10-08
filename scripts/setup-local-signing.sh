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

P12_PASSWORD="$(openssl rand -hex 16)"

# macOS Security.framework still expects older PKCS#12 MAC/PBE formats.
# SHA-1/3DES apply ONLY to this temporary, randomly password-protected
# Keychain transfer container; code signing itself still uses SHA-256.
openssl pkcs12 -export \
    -inkey "$TMP/key.pem" \
    -in "$TMP/cert.pem" \
    -out "$TMP/identity.p12" \
    -name "$CERT_NAME" \
    -keypbe PBE-SHA1-3DES \
    -certpbe PBE-SHA1-3DES \
    -macalg sha1 \
    -passout "pass:$P12_PASSWORD"

# Verify the container with the same password before handing it to macOS.
openssl pkcs12 -in "$TMP/identity.p12" \
    -noout \
    -passin "pass:$P12_PASSWORD" \
    >"$TMP/verify.log" 2>&1 || {
        echo "ERROR: OpenSSL could not verify the generated PKCS#12."
        cat "$TMP/verify.log"
        exit 1
    }

echo "PKCS#12 format: SHA-1 MAC, SHA-1/3DES encrypted payload."
echo "PKCS#12 integrity: verified."

security import "$TMP/identity.p12" \
    -k "$KEYCHAIN" \
    -f pkcs12 \
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
