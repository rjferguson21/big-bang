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
istioctl analyze --all-namespaces \
  --suppress "IST0101=VirtualService *" \
  --suppress "IST0104=Gateway *" \
  --suppress "IST0105=Pod *" \
  --suppress "IST0102=Namespace *" \
  --suppress "IST0118=Service *" \
  --suppress "IST0107=Deployment *"
echo "======================================"
echo "Popeye"
echo "======================================"
popeye -A
