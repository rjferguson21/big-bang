#!/usr/bin/env bash

# exit on error
set -e

# Running in cluster config testing tools
echo "======================================"
echo "Popeye"
echo "======================================"
popeye
echo "======================================"
echo "Clusterlint"
echo "======================================"
clusterlint run
