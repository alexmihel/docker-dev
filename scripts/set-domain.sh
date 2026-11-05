#!/usr/bin/env bash
set -e
# Switches this machine to another project domain.
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

NEW_DOMAIN="$1"
ENV_FILE="$ROOT_DIR/.env.local"

if [[ ! "$NEW_DOMAIN" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$ ]]; then
  echo "❌ Usage: make domain name=srv.loc"
  exit 1
fi

touch "$ENV_FILE"
TMP="$(mktemp "${ENV_FILE}.XXXXXX")"
grep -v '^DEV_DOMAIN=' "$ENV_FILE" > "$TMP" || true
echo "DEV_DOMAIN=${NEW_DOMAIN}" >> "$TMP"
cat "$TMP" > "$ENV_FILE"
rm -f "$TMP"

"$ROOT_DIR/scripts/sync.sh"

# Generated projects have the domain written into their files.
for dir in "$ROOT_DIR"/projects/*/; do
  [ -d "$dir" ] || continue
  case "$(basename "$dir")" in
    *."$NEW_DOMAIN") ;;
    *) echo "⚠️  $(basename "$dir") stays on its old domain" ;;
  esac
done
