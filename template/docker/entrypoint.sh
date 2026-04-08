#!/bin/bash
set -e

if [ -f /tmp/ssh/id_rsa ]; then
  mkdir -p /root/.ssh
  cp /tmp/ssh/id_rsa /root/.ssh/id_rsa
  cp /tmp/ssh/id_rsa.pub /root/.ssh/id_rsa.pub 2>/dev/null || true
  cp /tmp/ssh/known_hosts /root/.ssh/known_hosts 2>/dev/null || true
  chmod 700 /root/.ssh
  chmod 600 /root/.ssh/id_rsa
  chmod 644 /root/.ssh/id_rsa.pub 2>/dev/null || true
  chmod 644 /root/.ssh/known_hosts 2>/dev/null || true
fi

exec "$@"
