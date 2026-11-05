# Sourced by the other scripts: loads .env.local and derives host names from DEV_DOMAIN.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_DOMAIN="prj.loc"

if [ -f "$ROOT_DIR/.env.local" ]; then
  set -o allexport
  source "$ROOT_DIR/.env.local"
  set +o allexport
fi

DEV_DOMAIN="${DEV_DOMAIN:-$DEFAULT_DOMAIN}"

# prj.loc keeps its historic traefik.loc / whoami.loc names.
if [ "$DEV_DOMAIN" = "$DEFAULT_DOMAIN" ]; then
  TRAEFIK_HOST="traefik.loc"
  WHOAMI_HOST="whoami.loc"
else
  TRAEFIK_HOST="traefik.${DEV_DOMAIN}"
  WHOAMI_HOST="whoami.${DEV_DOMAIN}"
fi
