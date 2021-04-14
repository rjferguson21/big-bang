#!/usr/bin/env bash

# exit on error
set -e

echo "======================================"
echo "Popeye"
echo "======================================"
popeye
echo "======================================"
echo "Clusterlint"
echo "======================================"
clusterlint run
