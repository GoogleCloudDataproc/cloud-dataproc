#!/bin/bash
#
# Misc utility functions

function set_cluster_name() {
  print_status "Setting Cluster Name..."
  cluster_name="$(jq -r .CLUSTER_NAME env.json)"

  if [[ -z "${cluster_name}" || "${cluster_name}" == "null" || "${cluster_name}" == "" ]]; then
    local new_cluster_ts=$(date +%s)
    export CLUSTER_NAME="cluster-${new_cluster_ts}"
    # env.json is the source of truth.  modify and reload env.sh
    cp env.json env.json.tmp
    cat env.json.tmp | jq ".CLUSTER_NAME |= \"${CLUSTER_NAME}\"" > env.json
    rm env.json.tmp
    # Re-source env.sh to update all variables depending on CLUSTER_NAME
    source lib/env.sh
    report_result "Set"
  else
    export CLUSTER_NAME="${cluster_name}" # Ensure it's exported
    report_result "Exists"
  fi
}

function execute_with_retries() {
  local -r cmd=$1
  local retries=${2:-10}
  local sleep_time=${3:-5}
  print_status "Executing with retries: ${cmd}..."
  for ((i = 0; i < retries; i++)); do
    if eval "$cmd"; then
      report_result "Pass"
      return 0
    fi
    sleep ${sleep_time}
  done
  report_result "Fail"
  return 1
}

function reproduce {
  # Run some job on the cluster which triggers the failure state
  # Spark?
  # Map/Reduce?
  # repro: steady load 15K containers
  # zero
  # containers finish
  # customer's use case increased to or above 55K pending containers
  # customer sustained load, increased, completed work, added more work
  # churns but stays high
  # as final work is completed
  # simulate gradual decrease of memory
  # simulate continued increase of containers until yarn pending memory reaches
  # When yarn pending memory should reach zero, it instead decreases below 0

  # https://linux.die.net/man/1/stress

  # consider dd if=/dev/zero | launch_job -
  :
}
export -f reproduce
