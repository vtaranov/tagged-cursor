#!/bin/bash
# Создаёт самоподписанный сертификат подписи кода «Tagged Cursor Dev» в связке «Вход».
# С ним разрешение Универсального доступа переживает пересборку. Достаточно один раз.
set -euo pipefail

IDENTITY="Tagged Cursor Dev"
KEYCHAIN="${KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"

if security find-identity -p codesigning "$KEYCHAIN" | grep -q "\"$IDENTITY\""; then
    echo "Сертификат \"$IDENTITY\" уже есть"
    exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $IDENTITY
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

# Системный openssl (LibreSSL) пишет PKCS#12 в формате, который понимает `security import`.
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -config "$TMP/cert.cnf" -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
PASS=$(/usr/bin/openssl rand -hex 16)
/usr/bin/openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -name "$IDENTITY" -passout "pass:$PASS" -out "$TMP/cert.p12"
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "$PASS" -T /usr/bin/codesign >/dev/null

echo "Создан сертификат \"$IDENTITY\""
