#!/usr/bin/env bash

# exit on error
set -e

#Clear out folder if present
rm -rf cypress-tests/
#Create folder for cypress tests
mkdir -p cypress-tests/

#Cloning core
yq e '. | keys | .[] | ... comments=""' "${CI_VALUES_FILE}" | while IFS= read -r package; do
  if [[ "$(yq e ".${package}.enabled" "${CI_VALUES_FILE}")" == "true" ]]; then
    #Checking for branch not tag
    if [ "$(yq e ".${package}.git.tag" "${VALUES_FILE}")" != null ]; then
      echo "Cloning ${package} into cypress-tests"
      git -C cypress-tests/ clone -b $(yq e ".${package}.git.tag" "${VALUES_FILE}") $(yq e ".${package}.git.repo" "${VALUES_FILE}")
    else
      echo "Cloning ${package} into cypress-tests"
      git -C cypress-tests/ clone -b $(yq e ".${package}.git.branch" "${VALUES_FILE}") $(yq e ".${package}.git.repo" "${VALUES_FILE}")
    fi
  fi
done

#Cloning addons
yq e '.addons | keys | .[] | ... comments=""' "${CI_VALUES_FILE}" | while IFS= read -r package; do
  if [ "$(yq e ".addons.${package}.enabled" "${CI_VALUES_FILE}")" == "true" ]; then
    #Checking for branch not tag
    if [ "$(yq e ".addons.${package}.git.tag" "${VALUES_FILE}")" != null ]; then
      echo "Cloning ${package} into cypress-tests"
      git -C cypress-tests/ clone -b $(yq e ".addons.${package}.git.tag" "${VALUES_FILE}") $(yq e ".addons.${package}.git.repo" "${VALUES_FILE}")
    else
      echo "Cloning ${package} into cypress-tests"
      git -C cypress-tests/ clone -b $(yq e ".addons.${package}.git.branch" "${VALUES_FILE}") $(yq e ".addons.${package}.git.repo" "${VALUES_FILE}")
    fi
  fi
done

#Running Cypress tests
for dir in cypress-tests/*/
do
  if [ -f "${dir}tests/cypress.json" ]; then
    if [ "$(yq e ".addons.keycloak.enabled" "${CI_VALUES_FILE}")" == "true" ]; then
      echo "Running cypress tests. Keycloak is enabled. Directory is ${dir}"
      if [ "${dir}" == "cypress-tests/elasticsearch-kibana/" ]; then
        echo "Keycloak is enabled and cypress directory is ${dir}"
        echo "Running cypress tests in ${dir}"
        CYPRESS_kibana_url=kibana.admin.bigbang.dev cypress run --project "${dir}"tests
      fi
      if [ "${dir}" == "cypress-tests/monitoring/" ]; then
        echo "Keycloak is enabled and cypress directory is ${dir}"
        echo "Running cypress tests in ${dir}"
        CYPRESS_prometheus_url=prometheus.admin.bigbang.dev CYPRESS_grafana_url=grafana.admin.bigbang.dev cypress run --project "${dir}"tests
      fi
      if [ "${dir}" == "cypress-tests/twistlock/" ]; then
        echo "Keycloak is enabled and cypress directory is ${dir}"
        echo "Running cypress tests in ${dir}"
        CYPRESS_twistlock_url=twistlock.admin.bigbang.dev cypress run --project "${dir}"tests
      fi
    else
      echo "Keycloak not enabled"
      echo "Running cypress tests in ${dir}"
      cypress run --project "${dir}"tests
    fi
  fi
done

