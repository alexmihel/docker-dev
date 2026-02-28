#!/usr/bin/env bash
set -e
# chmod +x scripts/generate-certs.sh
# ----------------------------
# Config
# ----------------------------
DOMAIN="prj.loc"
CERTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/shared/certs"

CRT="${CERTS_DIR}/local.crt"
KEY="${CERTS_DIR}/local.key"

# ----------------------------
# Preconditions
# ----------------------------
if ! command -v mkcert >/dev/null 2>&1; then
  echo "❌ mkcert not installed"
  echo "👉 brew install mkcert nss"
  exit 1
fi

mkdir -p "$CERTS_DIR"

echo "🔐 Installing local CA (if needed)"
mkcert -install

echo "📜 Generating certificates for:"
echo "   *.${DOMAIN}"
echo "   ${DOMAIN}"
echo "   traefik.loc"
echo "   whoami.loc"
echo "   localhost, 127.0.0.1, ::1"

# ----------------------------
# Generate certs
# ----------------------------
mkcert \
  -cert-file "$CRT" \
  -key-file  "$KEY" \
  "*.${DOMAIN}" \
  "${DOMAIN}" \
  traefik.loc \
  whoami.loc \
  localhost \
  127.0.0.1 \
  ::1

echo "✅ Certificates generated:"
echo "   $CRT"
echo "   $KEY"

echo "🔍 SAN check:"
openssl x509 -in "$CRT" -text -noout | grep -A2 "Subject Alternative Name"
