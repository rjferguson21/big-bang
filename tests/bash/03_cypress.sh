#!/usr/bin/env bash

# exit on error
set -e

mkdir -p cypress-tests/

#Cloning core
yq e '. | keys | .[] | ... comments=""' "tests/ci/k3d/values.yaml" | while IFS= read -r package; do
  if [[ "$(yq e ".${package}.enabled" "tests/ci/k3d/values.yaml")" == "true" ]]; then
    #Checking for branch not tag
    if [ "$(yq e ".${package}.git.tag" "chart/values.yaml")" != null ]; then
      echo "Cloning ${package} into cypress-tests"
      git -C cypress-tests/ clone -b $(yq e ".${package}.git.tag" "chart/values.yaml") $(yq e ".${package}.git.repo" "chart/values.yaml")
    else
      echo "Cloning ${package} into cypress-tests"
      git -C cypress-tests/ clone -b $(yq e ".${package}.git.branch" "chart/values.yaml") $(yq e ".${package}.git.repo" "chart/values.yaml")
    fi
  fi
done

#Cloning addons
IFS=","
for package in $CI_MERGE_REQUEST_LABELS; do
  echo "Cloning enabled add-ons"
  if [ "$(yq e ".addons.${package}.enabled" "tests/ci/k3d/values.yaml" 2>/dev/null)" != null ]; then
    #Checking for branch not tag
    if [ "$(yq e ".${package}.git.tag" "chart/values.yaml")" != null ]; then
      echo "Cloning ${package} into cypress-tests"
      git -C cypress-tests/ clone -b $(yq e "addons.${package}.git.tag" "chart/values.yaml") $(yq e "addons.${package}.git.repo" "chart/values.yaml")
    else
      echo "Cloning ${package} into cypress-tests"
      git -C cypress-tests/ clone -b $(yq e "addons.${package}.git.branch" "chart/values.yaml") $(yq e "addons.${package}.git.repo" "chart/values.yaml")
    fi
  fi
done

#Running Cypress tests
for dir in cypress-tests/*/
do
  if [ -f "${dir}tests/cypress.json" ]; then
    echo "Running cypress tests in ${dir}"
    cypress run --project "${dir}"tests
  fi
done