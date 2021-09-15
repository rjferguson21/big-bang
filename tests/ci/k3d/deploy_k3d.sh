#!/usr/bin/env bash

set -ex

if [[ $CI_MERGE_REQUEST_LABELS =~ "keycloak" ||  $CI_MERGE_REQUEST_LABELS =~ "all-packages" ]]; then
  k3d cluster create ${CI_JOB_ID} --config tests/ci/k3d/disable-servicelb-config.yaml --network ${CI_JOB_ID}
else
  k3d cluster create ${CI_JOB_ID} --config tests/ci/k3d/config.yaml --network ${CI_JOB_ID}
fi
