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

DOMAIN="prj.loc"
PROJECT_HOST="${PROJECT}.${DOMAIN}"

# --------------------------------------------------
# Paths
# --------------------------------------------------
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECTS_DIR="$ROOT_DIR/projects"
PROJECT_DIR="$PROJECTS_DIR/$PROJECT_HOST"
APP_DIR="$PROJECT_DIR/$PROJECT"

TEMPLATE_COMPOSE="$ROOT_DIR/template/docker-compose.stub.yml"
TEMPLATE_ENV="$ROOT_DIR/template/env.stub"
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
  echo "❌ Project '$PROJECT_HOST' already exists"
  exit 1
fi

echo ""
read -rp "PHP version (default 8.2, e.g. 8.3): " PHP_VERSION
PHP_VERSION="${PHP_VERSION:-8.2}"

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
    read -rp "Laravel version (empty = latest, e.g. ^11.0): " LARAVEL_VERSION

    if [ -z "$LARAVEL_VERSION" ]; then
      docker run --rm \
        -v "$PROJECT_DIR:/{{PROJECT}}_app" \
        -w /{{PROJECT}}_app \
        laravelsail/php82-composer \
        composer create-project laravel/laravel "$PROJECT"
    else
      docker run --rm \
        -v "$PROJECT_DIR:/{{PROJECT}}_app" \
        -w /{{PROJECT}}_app \
        laravelsail/php82-composer \
        composer create-project laravel/laravel "$PROJECT" "$LARAVEL_VERSION"
    fi
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
while lsof -i :"$DB_PORT" &>/dev/null 2>&1; do
  DB_PORT=$((DB_PORT + 1))
done

sed \
  -e "s/{{PROJECT}}/$PROJECT/g" \
  -e "s/{{PROJECT_HOST}}/$PROJECT_HOST/g" \
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
EOF
fi

if [ -f "$APP_DIR/.env.example" ]; then
  echo "📄 Setup Laravel .env from .env.example"
  cp "$APP_DIR/.env.example" "$APP_DIR/.env"
fi

if [ -f "$APP_DIR/.env" ]; then
  echo "⚙️ Configure Laravel .env"

  sed -i '' \
    -e "s|^APP_URL=.*|APP_URL=https://${PROJECT_HOST}|" \
    -e "s|^APP_ENV=.*|APP_ENV=local|" \
    -e "s|^APP_DEBUG=.*|APP_DEBUG=true|" \
    \
    -e "s|^DB_CONNECTION=.*|DB_CONNECTION=pgsql|" \
    -e "s|^DB_HOST=.*|DB_HOST=db|" \
    -e "s|^DB_PORT=.*|DB_PORT=5432|" \
    -e "s|^DB_DATABASE=.*|DB_DATABASE=db_${PROJECT}|" \
    -e "s|^DB_USERNAME=.*|DB_USERNAME=laravel|" \
    -e "s|^DB_PASSWORD=.*|DB_PASSWORD=laravel|" \
    \
    -e "s|^REDIS_HOST=.*|REDIS_HOST=redis|" \
    -e "s|^REDIS_PASSWORD=.*|REDIS_PASSWORD=null|" \
    -e "s|^REDIS_PORT=.*|REDIS_PORT=6379|" \
    "$APP_DIR/.env"
fi


if [ -f "$APP_DIR/composer.json" ]; then
  echo "📦 Install composer dependencies"

  docker run --rm \
    -v "$APP_DIR:/app" \
    -w /app \
    laravelsail/php82-composer \
    composer install --no-interaction --prefer-dist
fi


# --------------------------------------------------
# APP_KEY (only if Laravel)
# --------------------------------------------------
if [ -f "$APP_DIR/artisan" ]; then
  echo "🔑 Generate APP_KEY"

  docker run --rm \
    -v "$APP_DIR:/{{PROJECT}}_app" \
    -w /{{PROJECT}}_app \
    laravelsail/php82-composer \
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
