#!/usr/bin/env bash

set -ex
trap 'echo exit at $0:$LINENO command: $_ 1>&2' EXIT

# install flux with the dedicated helper script
# test: force failure to test trap
./scripts/install_flux.sh \
  --registry-username 'robot$bb-dev-imagepullonly' \
  --registry-password "${REGISTRY1_PASSWORD}" \
  --registry-email bigbang@bigbang.dev