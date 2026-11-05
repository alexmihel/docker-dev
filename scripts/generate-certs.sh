#!/usr/bin/env bash
set -e
# chmod +x scripts/generate-certs.sh
# ----------------------------
# Config
# ----------------------------
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
DOMAIN="$DEV_DOMAIN"
CERTS_DIR="$ROOT_DIR/shared/certs"

CRT="${CERTS_DIR}/local.crt"
KEY="${CERTS_DIR}/local.key"

# ----------------------------
# Preconditions
# ----------------------------
if ! command -v mkcert >/dev/null 2>&1; then
  echo "❌ mkcert not installed"
  echo "👉 macOS: brew install mkcert nss | Ubuntu: sudo apt install mkcert"
  exit 1
fi

mkdir -p "$CERTS_DIR"

echo "🔐 Installing local CA (if needed)"
mkcert -install

echo "📜 Generating certificates for:"
echo "   *.${DOMAIN}"
echo "   ${DOMAIN}"
echo "   ${TRAEFIK_HOST}"
echo "   ${WHOAMI_HOST}"
echo "   localhost, 127.0.0.1, ::1"

# ----------------------------
# Generate certs
# ----------------------------
mkcert \
  -cert-file "$CRT" \
  -key-file  "$KEY" \
  "*.${DOMAIN}" \
  "${DOMAIN}" \
  "${TRAEFIK_HOST}" \
  "${WHOAMI_HOST}" \
  localhost \
  127.0.0.1 \
  ::1

echo "✅ Certificates generated:"
echo "   $CRT"
echo "   $KEY"

echo "🔍 SAN check:"
openssl x509 -in "$CRT" -text -noout | grep -A2 "Subject Alternative Name"
