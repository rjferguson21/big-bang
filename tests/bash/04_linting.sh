#!/usr/bin/env bash

# exit on error
set -e

# Running in cluster config testing tools
echo "======================================"
echo "Clusterlint"
echo "======================================"
clusterlint run
echo "======================================"
echo "Istioctl Analyze"
echo "======================================"
istioctl analyze --all-namespaces --suppress "IST0102"
echo "======================================"
echo "Popeye"
echo "======================================"
popeye -A
