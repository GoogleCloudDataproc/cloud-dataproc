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
# This library contains the core, universal utility functions for the CUJ
# framework. It is sourced by the main common.sh library file.

# A global associative array to hold configuration values.
declare -A CONFIG

# Loads configuration from env.json into the CONFIG array.
# It also includes logic to dynamically generate a project ID if the
# default placeholder is found in the configuration file.
function load_config() {
  local env_file
  env_file="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)/../env.json"
  if [[ ! -f "${env_file}" ]]; then
    echo "ERROR: env.json not found at ${env_file}" >&2
    exit 1
  fi
  while IFS='=' read -r key value; do
    CONFIG["$key"]="$value"
  done < <(jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' < "${env_file}")

  # Dynamically generate project ID if the default placeholder is present.
  if [[ "${CONFIG[PROJECT_ID]}" == "your-gcp-project-id" ]]; then
    local user_prefix
    # Sanitize the username to be a valid part of a project ID.
    user_prefix=$(gcloud config get-value account | cut -d'@' -f1 | tr -c '[:alnum:]' '-')
    CONFIG["PROJECT_ID"]="${user_prefix}-cuj-$(date +%Y%m%d)"
    echo "NOTE: PROJECT_ID not set in env.json, dynamically generating: ${CONFIG[PROJECT_ID]}"
  fi

  gcloud config set project "${CONFIG[PROJECT_ID]}"
}

# Prints a formatted header message.
function header() {
  echo "========================================================================"
  echo " $1"
  echo "========================================================================"
}

# Prompts the user for confirmation before proceeding.
# Skips the prompt if the CI_TEST environment variable is set.
function confirm() {
  if [[ -z "${CI_TEST}" ]]; then
    read -p "$1 (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Operation cancelled."
      exit 1
    fi
  fi
}

# Validates that a list of necessary APIs are enabled, and enables them if not.
function validate_apis() {
  header "Validating required APIs: $*"
  gcloud services enable "$@" --project="${CONFIG[PROJECT_ID]}"
}
