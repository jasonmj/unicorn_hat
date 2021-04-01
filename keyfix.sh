#!/usr/bin/env bash
set -e

cp -R /tmp/.ssh /home/nerves/.ssh
chmod 700 /home/nerves/.ssh

cp -R /tmp/.ssh /root/.ssh
chmod 700 /root/.ssh

exec "$@"

cd /app && /bin/bash
