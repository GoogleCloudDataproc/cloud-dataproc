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
# This library contains common functions related to security configurations,
# such as KMS and Secret Manager, often used as prerequisites for
# secure Dataproc environments like Kerberos.

# --- KMS Functions ---

# Creates a KMS KeyRing if it does not already exist.
#
# $1: KeyRing name
# $2: Location (e.g., "global" or a specific region)
function create_kms_keyring() {
  local keyring_name="$1"
  local location="$2"
  if ! gcloud kms keyrings describe "${keyring_name}" --location="${location}" &>/dev/null; then
    echo "Creating KMS KeyRing: ${keyring_name}"
    gcloud kms keyrings create "${keyring_name}" --location="${location}"
  else
    echo "KMS KeyRing '${keyring_name}' already exists."
  fi
}

# Creates a KMS Key within a KeyRing if it does not already exist.
#
# $1: Key name
# $2: KeyRing name
# $3: Location (e.g., "global" or a specific region)
function create_kms_key() {
  local key_name="$1"
  local keyring_name="$2"
  local location="$3"
  if ! gcloud kms keys describe "${key_name}" --keyring="${keyring_name}" --location="${location}" &>/dev/null; then
    echo "Creating KMS Key: ${key_name}"
    gcloud kms keys create "${key_name}" \
      --keyring="${keyring_name}" \
      --location="${location}" \
      --purpose="encryption"
  else
    echo "KMS Key '${key_name}' already exists."
  fi
}

# --- Secret Manager Functions ---

# Creates a secret with a given payload if it does not already exist.
#
# $1: Secret name
# $2: The secret data/payload as a string
function create_secret_from_string() {
  local secret_name="$1"
  local secret_data="$2"

  if ! gcloud secrets describe "${secret_name}" &>/dev/null; then
    echo "Creating Secret: ${secret_name}"
    # Create the secret container
    gcloud secrets create "${secret_name}" --replication-policy="automatic"
    # Add the first version of the secret from the provided string
    printf "%s" "${secret_data}" | gcloud secrets versions add "${secret_name}" --data-file=-
  else
    echo "Secret '${secret_name}' already exists."
  fi
}

# Deletes a secret and all its versions.
#
# $1: Secret name
function delete_secret() {
    local secret_name="$1"
    if gcloud secrets describe "${secret_name}" &>/dev/null; then
        echo "Deleting Secret: ${secret_name}"
        gcloud secrets delete --quiet "${secret_name}"
    else
        echo "Secret '${secret_name}' not found."
    fi
}

# --- Kerberos-Specific Prerequisite Functions ---

# Generates a random password and stores it as a new secret in Secret Manager.
#
# $1: Secret name for the password
function create_kerberos_password_secret() {
  local secret_name="$1"
  if ! gcloud secrets describe "${secret_name}" &>/dev/null; then
    header "Generating and storing Kerberos password in Secret Manager"
    # Generate a random 32-character alphanumeric password
    local random_password
    random_password=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 32)
    create_secret_from_string "${secret_name}" "${random_password}"
  else
    echo "Kerberos password secret '${secret_name}' already exists."
  fi
}
