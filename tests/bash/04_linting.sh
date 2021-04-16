#!/usr/bin/env bash

# exit on error
set -e

# Running in cluster config testing tools
echo "======================================"
echo "Istioctl Analyze"
echo "======================================"
istioctl analyze --all-namespaces
echo "======================================"
echo "Clusterlint"
echo "======================================"
clusterlint run
echo "======================================"
echo "Popeye"
echo "======================================"
popeye -A
