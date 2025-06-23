#!/bin/bash
#
# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# This library contains common functions for use in CUJ scripts.

# A global associative array to hold configuration values.
declare -A CONFIG

# Loads configuration from env.json into the CONFIG array.
function load_config() {
  # This assumes env.json is in the gcloud/ directory, two levels above the cuj/*/ directory
  local env_file
  env_file="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)/../env.json"

  if [[ ! -f "${env_file}" ]]; then
    echo "ERROR: env.json not found at ${env_file}" >&2
    exit 1
  fi

  # Read all keys and values from JSON into the CONFIG array
  while IFS='=' read -r key value; do
    CONFIG["$key"]="$value"
  done < <(jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' < "${env_file}")

  # Set the project for all subsequent gcloud commands
  gcloud config set project "${CONFIG[PROJECT_ID]}"
}

# Prints a formatted header message.
function header() {
  echo "========================================================================"
  echo " $1"
  echo "========================================================================"
}

# Prompts the user for confirmation before proceeding.
function confirm() {
  # When running in an automated test, skip the confirmation.
  if [[ -z "${CI_TEST}" ]]; then
    read -p "$1 (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Operation cancelled."
      exit 1
    fi
  fi
}

# Creates the VPC network and a subnet within it.
# (Inside common.sh)
function create_network_and_subnet() {
  # ... (logic to check if network exists)
  gcloud compute networks create "${CONFIG[NETWORK]}" \
      --subnet-mode=custom \
      --description="Network for CUJ testing" \
      --bgp-routing-mode="regional"

  # ... (logic to check if subnet exists)
  gcloud compute networks subnets create "${CONFIG[SUBNET]}" \
       --network="${CONFIG[NETWORK]}" \
       --range="${CONFIG[SUBNET_CIDR]}" \
       --region="${CONFIG[REGION]}"
  
  # Add firewall rule with the tag to allow SSH
  gcloud compute firewall-rules create "${CONFIG[CUJ_TAG]}-allow-ssh" \
    --network="${CONFIG[NETWORK]}" \
    --allow=tcp:22 \
    --source-ranges="0.0.0.0/0" \
    --description="Allow SSH for CUJ test" \
    --target-tags="${CONFIG[CUJ_TAG]}"
}

# Deletes the VPC network. Subnets are deleted automatically with the network.
function delete_network_and_subnet() {
  header "Deleting VPC Network: ${CONFIG[NETWORK]}"
  if gcloud compute networks describe "${CONFIG[NETWORK]}" &>/dev/null; then
    gcloud compute networks delete --quiet "${CONFIG[NETWORK]}"
    echo "Network ${CONFIG[NETWORK]} and its subnets have been deleted."
  else
    echo "Network ${CONFIG[NETWORK]} not found."
  fi
}
