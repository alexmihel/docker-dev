#!/usr/bin/env bash
set -e
# chmod +x scripts/create-project.sh
# --------------------------------------------------
# Resolve project name
# --------------------------------------------------
PROJECT="$1"

if [ -z "$PROJECT" ]; then
  read -rp "Enter project name: " PROJECT
fi

if [ -z "$PROJECT" ]; then
  echo "❌ Project name cannot be empty"
  exit 1
fi

if [[ ! "$PROJECT" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
  echo "❌ Use letters, digits, dots and hyphens; start and end with a letter or digit"
  exit 1
fi

source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
DOMAIN="$DEV_DOMAIN"
PROJECT_HOST="${PROJECT}.${DOMAIN}"

# --------------------------------------------------
# Paths
# --------------------------------------------------
PROJECTS_DIR="$ROOT_DIR/projects"
PROJECT_DIR="$PROJECTS_DIR/$PROJECT_HOST"
APP_DIR="$PROJECT_DIR/$PROJECT"

TEMPLATE_COMPOSE="$ROOT_DIR/template/docker-compose.stub.yml"
TEMPLATE_ENV="$ROOT_DIR/template/env.stub"
TEMPLATE_MAKEFILE="$ROOT_DIR/template/Makefile.stub"
NGINX_TEMPLATE="$ROOT_DIR/shared/nginx/default.conf"
DOCKER_TEMPLATE_DIR="$ROOT_DIR/template/docker"

# --------------------------------------------------
# Load global personal env (.env.local)
# --------------------------------------------------
GLOBAL_ENV="$ROOT_DIR/.env.local"

if [ ! -f "$GLOBAL_ENV" ]; then
  echo "❌ Global .env.local not found: $GLOBAL_ENV"
  exit 1
fi

set -o allexport
source "$GLOBAL_ENV"
set +o allexport

if [ ! -f "$TEMPLATE_COMPOSE" ]; then
  echo "❌ docker-compose stub not found:"
  echo "   $TEMPLATE_COMPOSE"
  exit 1
fi

if [ ! -f "$TEMPLATE_ENV" ]; then
  echo "❌ env stub not found:"
  echo "   $TEMPLATE_ENV"
  exit 1
fi

if [ ! -f "$NGINX_TEMPLATE" ]; then
  echo "❌ nginx default.conf not found:"
  echo "   $NGINX_TEMPLATE"
  exit 1
fi

if [ ! -d "$DOCKER_TEMPLATE_DIR" ]; then
  echo "❌ docker template dir not found:"
  echo "   $DOCKER_TEMPLATE_DIR"
  exit 1
fi

if [ -d "$PROJECT_DIR" ]; then
  echo "⚠️  Directory '$PROJECT_HOST' already exists."
  read -rp "Delete and recreate? [y/N]: " CONFIRM_DELETE
  if [[ "$CONFIRM_DELETE" =~ ^[Yy]$ ]]; then
    rm -rf "$PROJECT_DIR"
    echo "🗑️  Removed '$PROJECT_HOST'"
  else
    echo "Aborted."
    exit 1
  fi
fi

# Certificates and Traefik must match DEV_DOMAIN before the project is reachable.
"$ROOT_DIR/scripts/sync.sh"

echo ""
read -rp "PHP version (default 8.3, e.g. 8.2): " PHP_VERSION
PHP_VERSION="${PHP_VERSION:-8.3}"

PHP_MAJOR_MINOR="${PHP_VERSION//./}"
COMPOSER_IMAGE="laravelsail/php${PHP_MAJOR_MINOR}-composer"

# Run composer as the host user: on Linux, bind-mounted files would otherwise be root-owned.
COMPOSER_RUN_ARGS="--user $(id -u):$(id -g) -e HOME=/tmp -e COMPOSER_HOME=/tmp/composer"

# --------------------------------------------------
# Optional PHP extensions
# --------------------------------------------------
echo ""
echo "Optional PHP extensions (y/N for each):"
read -rp "  GD (image processing):  " _GD
read -rp "  Imagick (ImageMagick):  " _IMAGICK
read -rp "  Exif (photo metadata):  " _EXIF

INSTALL_GD="false";      [[ "$_GD"      =~ ^[Yy]$ ]] && INSTALL_GD="true"
INSTALL_IMAGICK="false";  [[ "$_IMAGICK" =~ ^[Yy]$ ]] && INSTALL_IMAGICK="true"
INSTALL_EXIF="false";     [[ "$_EXIF"    =~ ^[Yy]$ ]] && INSTALL_EXIF="true"

echo ""
echo "🚀 Creating project: $PROJECT_HOST (PHP $PHP_VERSION)"
mkdir -p "$PROJECT_DIR"

# --------------------------------------------------
# Project type
# --------------------------------------------------
echo ""
echo "Select project type:"
echo "1) New Laravel project"
echo "2) Existing repository"
echo "3) Empty project (manual code later)"
read -rp "Choose [1/2/3]: " PROJECT_TYPE

# --------------------------------------------------
# Type handlers
# --------------------------------------------------
case "$PROJECT_TYPE" in

  1)
    read -rp "Laravel version (default ^13.0, e.g. ^11.0): " LARAVEL_VERSION
    LARAVEL_VERSION="${LARAVEL_VERSION:-^13.0}"

    docker run --rm $COMPOSER_RUN_ARGS \
      -v "$PROJECT_DIR:/${PROJECT}_app" \
      -w "/${PROJECT}_app" \
      $COMPOSER_IMAGE \
      composer create-project laravel/laravel "$PROJECT" "$LARAVEL_VERSION"
    ;;   

  2)
    read -rp "Repository URL (git or https): " REPO_URL

    if [ -z "$REPO_URL" ]; then
      echo "❌ Repository URL is required"
      exit 1
    fi

    echo "📥 Cloning repository"
    git clone "$REPO_URL" "$APP_DIR"
    ;;

  3)
    echo "📁 Creating empty project"
    mkdir -p "$APP_DIR"
    ;;

  *)
    echo "❌ Invalid choice"
    exit 1
    ;;
esac

# --------------------------------------------------
# docker-compose
# --------------------------------------------------
echo "⚙️ Generate docker-compose.yml"

DB_PORT=5433
# Skip ports in use now (Docker's are root-owned, so lsof can't see them) and those of stopped projects.
while (exec 3<>"/dev/tcp/127.0.0.1/$DB_PORT") 2>/dev/null \
  || grep -qs "\"$DB_PORT:5432\"" "$PROJECTS_DIR"/*/docker-compose.yml; do
  DB_PORT=$((DB_PORT + 1))
done

sed \
  -e "s/{{PROJECT}}/$PROJECT/g" \
  -e "s/{{PROJECT_HOST}}/$PROJECT_HOST/g" \
  -e "s/{{DOMAIN}}/$DOMAIN/g" \
  -e "s/{{DB_PORT}}/$DB_PORT/g" \
  "$TEMPLATE_COMPOSE" \
  > "$PROJECT_DIR/docker-compose.yml"

# --------------------------------------------------
# nginx config (PROJECT-SCOPED!)
# --------------------------------------------------
echo "🌐 Generate nginx config"

mkdir -p "$PROJECT_DIR/nginx"

sed \
  -e "s/{{PROJECT}}/$PROJECT/g" \
  -e "s/{{PROJECT_HOST}}/$PROJECT_HOST/g" \
  "$NGINX_TEMPLATE" \
  > "$PROJECT_DIR/nginx/default.conf"

# --------------------------------------------------
# Makefile
# --------------------------------------------------
echo "📋 Generate Makefile"

sed \
  -e "s/{{PROJECT}}/$PROJECT/g" \
  -e "s/{{DOMAIN}}/$DOMAIN/g" \
  "$TEMPLATE_MAKEFILE" \
  > "$PROJECT_DIR/Makefile"

# --------------------------------------------------
# docker/ (Dockerfile, configs, supervisor)
# --------------------------------------------------
echo "🐳 Generate docker/ (Dockerfile, configs, supervisor)"

mkdir -p "$PROJECT_DIR/docker/conf.d"
mkdir -p "$PROJECT_DIR/docker/php-fpm.d"
mkdir -p "$PROJECT_DIR/docker/supervisor"

sed \
  -e "s/{{PHP_VERSION}}/$PHP_VERSION/g" \
  "$DOCKER_TEMPLATE_DIR/Dockerfile.stub" \
  > "$PROJECT_DIR/docker/Dockerfile"

cp "$DOCKER_TEMPLATE_DIR/conf.d/xdebug.ini"               "$PROJECT_DIR/docker/conf.d/xdebug.ini"
cp "$DOCKER_TEMPLATE_DIR/php-fpm.d/zz-env.conf"           "$PROJECT_DIR/docker/php-fpm.d/zz-env.conf"
cp "$DOCKER_TEMPLATE_DIR/supervisor/supervisord.conf.stub" "$PROJECT_DIR/docker/supervisor/supervisord.conf"
cp "$DOCKER_TEMPLATE_DIR/entrypoint.sh"                    "$PROJECT_DIR/docker/entrypoint.sh"

# --------------------------------------------------
# .env
# --------------------------------------------------
echo "🧩 Generate .env"

#sed \
#  -e "s/{{PROJECT}}/$PROJECT/g" \
#  -e "s/{{PROJECT_HOST}}/$PROJECT_HOST/g" \
#  "$TEMPLATE_ENV" \
#  > "$PROJECT_DIR/.env"

#if [ -f "$APP_DIR/.env.example" ]; then
#  cp "$PROJECT_DIR/.env" "$APP_DIR/.env"
#fi

# --------------------------------------------------
# .env (project personal, gitignored)
# --------------------------------------------------
ENV_LOCAL="$PROJECT_DIR/.env"

if [ ! -f "$ENV_LOCAL" ]; then
  echo "🔐 Create .env (personal, gitignored)"

  cat > "$ENV_LOCAL" <<EOF
# Git
GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME}"
GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL}"
GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME}"
GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL}"

# SSH
SSH_PRIVATE_KEY_PATH="${SSH_PRIVATE_KEY_PATH}"
SSH_PUBLIC_KEY_PATH="${SSH_PUBLIC_KEY_PATH}"
SSH_KNOWN_HOSTS_PATH="${SSH_KNOWN_HOSTS_PATH}"

# Host user (containers run as this UID/GID so files stay editable on the host)
HOST_UID=$(id -u)
HOST_GID=$(id -g)

# Optional PHP extensions (set to "true" to enable, then run: make build)
INSTALL_GD=${INSTALL_GD}
INSTALL_IMAGICK=${INSTALL_IMAGICK}
INSTALL_EXIF=${INSTALL_EXIF}
EOF
fi

if [ -f "$APP_DIR/.env.example" ]; then
  echo "📄 Setup Laravel .env from .env.example"
  cp "$APP_DIR/.env.example" "$APP_DIR/.env"
fi

if [ -f "$APP_DIR/.env" ]; then
  echo "⚙️ Configure Laravel .env"

  # Update active/commented keys, append missing ones and avoid duplicates.
  # Write through a temporary file so a failed awk does not truncate .env.
  set_env_value() {
    local file="$1" key="$2" value="$3" tmp
    tmp="$(mktemp "${file}.XXXXXX")"
    if awk -v key="$key" -v value="$value" '
      $0 ~ "^[[:space:]]*#?[[:space:]]*" key "[[:space:]]*=" {
        if (!found) print key "=" value
        found = 1
        next
      }
      { print }
      END { if (!found) print key "=" value }
    ' "$file" > "$tmp"; then
      cat "$tmp" > "$file"
      rm -f "$tmp"
    else
      rm -f "$tmp"
      return 1
    fi
  }

  set_env_value "$APP_DIR/.env" APP_URL "https://${PROJECT_HOST}"
  set_env_value "$APP_DIR/.env" APP_ENV local
  set_env_value "$APP_DIR/.env" APP_DEBUG true
  set_env_value "$APP_DIR/.env" DB_CONNECTION pgsql
  set_env_value "$APP_DIR/.env" DB_HOST db
  set_env_value "$APP_DIR/.env" DB_PORT 5432
  set_env_value "$APP_DIR/.env" DB_DATABASE "db_${PROJECT}"
  set_env_value "$APP_DIR/.env" DB_USERNAME laravel
  set_env_value "$APP_DIR/.env" DB_PASSWORD laravel
  set_env_value "$APP_DIR/.env" REDIS_HOST redis
  set_env_value "$APP_DIR/.env" REDIS_PASSWORD null
  set_env_value "$APP_DIR/.env" REDIS_PORT 6379
fi


if [ -f "$APP_DIR/composer.json" ]; then
  echo "📦 Install composer dependencies"

  docker run --rm $COMPOSER_RUN_ARGS \
    -v "$APP_DIR:/app" \
    -w /app \
    $COMPOSER_IMAGE \
    composer install --no-interaction --prefer-dist
fi


# --------------------------------------------------
# APP_KEY (only if Laravel)
# --------------------------------------------------
if [ -f "$APP_DIR/artisan" ]; then
  echo "🔑 Generate APP_KEY"

  docker run --rm $COMPOSER_RUN_ARGS \
    -v "$APP_DIR:/${PROJECT}_app" \
    -w "/${PROJECT}_app" \
    $COMPOSER_IMAGE \
    php artisan key:generate --force
fi

# --------------------------------------------------
# Done
# --------------------------------------------------
echo ""
echo "✅ Project '$PROJECT_HOST' created"
echo "📁 Code directory: $APP_DIR"
echo "🌍 https://$PROJECT_HOST"
echo "🐘 Postgres (host): localhost:$DB_PORT"
