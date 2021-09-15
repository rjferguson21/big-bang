#!/usr/bin/env bash

set -ex

k3d cluster create ${CI_JOB_ID} --config tests/ci/k3d/config.yaml --network ${CI_JOB_ID}