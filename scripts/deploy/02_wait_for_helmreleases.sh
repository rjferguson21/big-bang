#!/usr/bin/env bash

set -e

## This is an array to instantiate the order of wait conditions
CORE_HELMRELEASES=("gatekeeper" "istio-operator" "istio" "monitoring" "eck-operator" "ek" "fluent-bit" "twistlock" "cluster-auditor" "jaeger" "kiali")

ADD_ON_HELMRELEASES=("argocd" "authservice" "gitlab" "gitlabrunner" "anchore" "sonarqube" "minio-operator" "minio" "mattermost-operator" "mattermost" "nexus" "velero")

## Function to test an array contains an element
## Args:
## $1: array to search
## $2: element to search for
function array_contains() {
    local array="$1[@]"
    local seeking=$2
    local in=1
    for element in ${!array}; do
        if [[ $element == "$seeking" ]]; then
            in=0
            break
        fi
    done
    return $in
}

function check_if_exist() {
    timeElapsed=0
    echo "Checking if $1 HR exists"
    until kubectl get hr -n bigbang $1 &> /dev/null; do
      sleep 5
      timeElapsed=$(($timeElapsed+5))
      if [[ $timeElapsed -ge 60 ]]; then
         echo "Timed out while waiting for $1 to exist"
         exit 1
      fi
    done
}

function wait_all_hr() {
    timeElapsed=0
    while true; do
        if [[ "$(kubectl get hr -A -o jsonpath='{.items[*].status.conditions[0].reason}')" =~ Failed ]]; then
            echo "Found a failed Helm Release. Exiting now."
            exit 1
        fi
        if [[ "$(kubectl get hr -A -o jsonpath='{.items[*].status.conditions[0].reason}')" != *DependencyNotReady* ]]; then
            if [[ "$(kubectl get hr -A -o jsonpath='{.items[*].status.conditions[0].reason}')" != *Failed* ]]; then
                echo "All HR's deployed"
                break
            fi
        fi
        sleep 5
        timeElapsed=$(($timeElapsed+5))
        if [[ $timeElapsed -ge 1800 ]]; then
            echo "Timed out while waiting for hr's to be ready."
            exit 1
        fi
    done
}

## Function to wait on all statefulsets
function wait_sts() {
   timeElapsed=0
   while true; do
      sts=$(kubectl get sts -A -o jsonpath='{.items[*].status.replicas}' | xargs)
      totalSum=$(echo $sts | awk '{for (i=1; i<=NF; i++) c+=$i} {print c}')
      readySts=$(kubectl get sts -A -o jsonpath='{.items[*].status.readyReplicas}' | xargs)
      readySum=$(echo $readySts | awk '{for (i=1; i<=NF; i++) c+=$i} {print c}')
      if [[ $totalSum -eq $readySum ]]; then
         break
      fi
      sleep 5
      timeElapsed=$(($timeElapsed+5))
      if [[ $timeElapsed -ge 600 ]]; then
         echo "Timed out while waiting for stateful sets to be ready."
         exit 1
      fi
   done
}

## Function to wait on all daemonsets
function wait_daemonset(){
   timeElapsed=0
   while true; do
      dmnset=$(kubectl get daemonset -A -o jsonpath='{.items[*].status.desiredNumberScheduled}' | xargs)
      totalSum=$(echo $dmnset | awk '{for (i=1; i<=NF; i++) c+=$i} {print c}')
      readyDmnset=$(kubectl get daemonset -A -o jsonpath='{.items[*].status.numberReady}' | xargs)
      readySum=$(echo $readyDmnset | awk '{for (i=1; i<=NF; i++) c+=$i} {print c}')
      if [[ $totalSum -eq $readySum ]]; then
         break
      fi
      sleep 5
      timeElapsed=$(($timeElapsed+5))
      if [[ $timeElapsed -ge 600 ]]; then
         echo "Timed out while waiting for daemon sets to be ready."
         exit 1
      fi
   done
}

## Untested - rough outline
## Intent: Append all add-ons to hr list if "all-packages" or default branch. Else, add specific ci labels to hr list
# HELMRELEASES+=(${CORE_HELMRELEASES[@]})
# if [[ "${CI_COMMIT_BRANCH}" == "${CI_DEFAULT_BRANCH}" ]] || [[ ! -z "$CI_COMMIT_TAG" ]] || [[ $CI_MERGE_REQUEST_LABELS =~ "all-packages" ]]; then
#     HELMRELEASES+=(${ADD_ON_HELMRELEASES[@]})
# elif [[ -z "$CI_MERGE_REQUEST_LABELS" ]]; then
#     for package in $CI_MERGE_REQUEST_LABELS; do
#         # Check if package is in core
#         if array_contains CORE_HELMRELEASES "$package"; then
#             break
#         else
#             HELMRELEASES+=($package)
#         fi
#     done
# fi

for package in "${HELMRELEASES[@]}";
do
    check_if_exist "$package"
done

echo "Waiting on helm releases..."
wait_all_hr
kubectl get helmreleases,kustomizations,gitrepositories -A

echo "Waiting on Secrets Kustomization"
kubectl wait --for=condition=Ready --timeout 300s kustomizations.kustomize.toolkit.fluxcd.io -n bigbang secrets

# In case some helm releases are marked as ready before all objects are live...
echo "Waiting on all jobs, deployments, statefulsets, and daemonsets"
kubectl wait --for=condition=available --timeout 660s -A deployment --all > /dev/null
wait_sts
wait_daemonset
if kubectl get job -A -o jsonpath='{.items[].metadata.name}' &> /dev/null; then
  kubectl wait --for=condition=complete --timeout 300s -A job --all > /dev/null
fi
