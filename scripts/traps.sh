# meant to be sourced, so no #!<shell> here

# trap to show the k8s event log when the exit command is used
trap 'echo exit was run at ${0}:${LINENO}, showing k8s event log 1>&2; kubectl get events --all-namespaces' EXIT
# trap to show more information when a script fails due to "set -e"
trap 'echo exit at ${0}:${LINENO}, command was: ${BASH_COMMAND} 1>&2' ERR