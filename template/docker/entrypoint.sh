#!/bin/bash
set -e

# Give www-data the host user's UID/GID so bind-mounted files stay editable on the host.
APP_USER=www-data
APP_HOME=/home/$APP_USER
if [ -n "$HOST_UID" ] && [ "$HOST_UID" != "0" ]; then
  [ "$(id -g "$APP_USER")" = "${HOST_GID:-$HOST_UID}" ] || groupmod -o -g "${HOST_GID:-$HOST_UID}" "$APP_USER"
  [ "$(id -u "$APP_USER")" = "$HOST_UID" ] || usermod -o -u "$HOST_UID" "$APP_USER"
fi
usermod -d "$APP_HOME" "$APP_USER"
mkdir -p "$APP_HOME"

if [ -f /tmp/ssh/id_rsa ]; then
  mkdir -p "$APP_HOME/.ssh"
  cp /tmp/ssh/id_rsa "$APP_HOME/.ssh/id_rsa"
  cp /tmp/ssh/id_rsa.pub "$APP_HOME/.ssh/id_rsa.pub" 2>/dev/null || true
  cp /tmp/ssh/known_hosts "$APP_HOME/.ssh/known_hosts" 2>/dev/null || true
  chmod 700 "$APP_HOME/.ssh"
  chmod 600 "$APP_HOME/.ssh/id_rsa"
  chmod 644 "$APP_HOME/.ssh/id_rsa.pub" 2>/dev/null || true
  chmod 644 "$APP_HOME/.ssh/known_hosts" 2>/dev/null || true
fi
chown -R "$APP_USER:$APP_USER" "$APP_HOME"

exec "$@"
