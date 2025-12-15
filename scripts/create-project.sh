#!/usr/bin/env bash
set -e

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

# --------------------------------------------------
# Paths
# --------------------------------------------------
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECTS_DIR="$ROOT_DIR/projects"
PROJECT_DIR="$PROJECTS_DIR/$PROJECT"
APP_DIR="$PROJECT_DIR/$PROJECT"

TEMPLATE_COMPOSE="$ROOT_DIR/template/docker-compose.stub.yml"
TEMPLATE_ENV="$ROOT_DIR/template/env.stub"

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

if [ -d "$PROJECT_DIR" ]; then
  echo "❌ Project '$PROJECT' already exists"
  exit 1
fi

echo ""
echo "🚀 Creating project: $PROJECT"
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
    read -rp "Laravel version (default: latest): " LARAVEL_VERSION
    LARAVEL_VERSION=${LARAVEL_VERSION:-latest}

    echo "📦 Installing Laravel ($LARAVEL_VERSION)"

    docker run --rm \
      -v "$PROJECT_DIR:/app" \
      -w /app \
      laravelsail/php82-composer \
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

sed "s/{{PROJECT}}/$PROJECT/g" "$TEMPLATE_COMPOSE" \
  > "$PROJECT_DIR/docker-compose.yml"

# --------------------------------------------------
# .env
# --------------------------------------------------
echo "🧩 Generate .env"

sed "s/{{PROJECT}}/$PROJECT/g" "$TEMPLATE_ENV" \
  > "$PROJECT_DIR/.env"

# Sync env into app if exists
if [ -f "$APP_DIR/.env.example" ]; then
  cp "$PROJECT_DIR/.env" "$APP_DIR/.env"
fi

# --------------------------------------------------
# APP_KEY (only if Laravel)
# --------------------------------------------------
if [ -f "$APP_DIR/artisan" ]; then
  echo "🔑 Generate APP_KEY"

  docker run --rm \
    -v "$APP_DIR:/app" \
    -w /app \
    laravelsail/php82-composer \
    php artisan key:generate --force
fi

# --------------------------------------------------
# Done
# --------------------------------------------------
echo ""
echo "✅ Project '$PROJECT' created"
echo "📁 Code directory: $APP_DIR"
echo "🌍 https://$PROJECT.prj.loc"
