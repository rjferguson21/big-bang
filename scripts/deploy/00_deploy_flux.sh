#!/usr/bin/env bash

set -ex

# install flux with the dedicated helper script
./scripts/install_flux.sh \
  --registry-username 'robot$bb-dev-imagepullonly' \
  --registry-password "$(echo "$REGISTRY1_PASSWORD" | base64 -d -)" \
  --registry-email bigbang@bigbang.dev 