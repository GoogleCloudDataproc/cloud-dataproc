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
# This library contains functions for managing database resources like
# Cloud SQL and Bigtable.

# --- Cloud SQL Instance Management ---
# These functions manage the lifecycle of the entire instance and are typically
# called by onboarding scripts.

# Creates a Cloud SQL for MySQL instance with production-ready settings.
# Assumes VPC Peering has already been established on the network.
# Arguments:
#   $1: The name of the Cloud SQL instance.
#   $2: The name of the VPC network to peer with.
#   $3: The region for the instance.
#   $4: The availability type (e.g., "HA" for regional).
function create_mysql_instance() {
  local instance_name="$1"
  local network_name="$2"
  local region="$3"
  local availability_type="$4"

  local ha_flag=""
  if [[ "${availability_type}" == "HA" ]]; then
    ha_flag="--availability-type=REGIONAL"
  fi

  if ! gcloud sql instances describe "${instance_name}" &>/dev/null; then
    echo "Creating Cloud SQL MySQL instance: ${instance_name}"
    gcloud sql instances create "${instance_name}" \
      --database-version="MYSQL_8_0" \
      --region="${region}" \
      --network="projects/${CONFIG[PROJECT_ID]}/global/networks/${network_name}" \
      --no-assign-ip \
      --enable-point-in-time-recovery \
      ${ha_flag}
  else
    echo "Cloud SQL MySQL instance '${instance_name}' already exists."
  fi
}

# Creates a Cloud SQL for PostgreSQL instance with production-ready settings.
function create_postgres_instance() {
  local instance_name="$1"
  local network_name="$2"
  local region="$3"
  local availability_type="$4"

  local ha_flag=""
  if [[ "${availability_type}" == "HA" ]]; then
    ha_flag="--availability-type=REGIONAL"
  fi

  if ! gcloud sql instances describe "${instance_name}" &>/dev/null; then
    echo "Creating Cloud SQL PostgreSQL instance: ${instance_name}"
    # Ensure peering is set up first.
    create_peering_ip_allocation "${network_name}"
    create_vpc_peering_connection "${network_name}"

    gcloud sql instances create "${instance_name}" \
      --database-version="POSTGRES_14" \
      --region="${region}" \
      --network="projects/${CONFIG[PROJECT_ID]}/global/networks/${network_name}" \
      --no-assign-ip \
      --enable-point-in-time-recovery \
      ${ha_flag}
  else
    echo "Cloud SQL PostgreSQL instance '${instance_name}' already exists."
  fi
}

# Deletes any Cloud SQL instance.
function delete_sql_instance() {
  local instance_name="$1"
  if gcloud sql instances describe "${instance_name}" &>/dev/null; then
    echo "Deleting Cloud SQL instance: ${instance_name}"
    gcloud sql instances delete --quiet "${instance_name}"
  else
    echo "Cloud SQL instance '${instance_name}' not found."
  fi
}


# --- Database Management ---
# These functions manage individual databases within a Cloud SQL instance and
# are typically called by CUJ scripts.

function create_database_on_instance() {
  local instance_name="$1"
  local db_name="$2"
  if ! gcloud sql databases describe "${db_name}" --instance="${instance_name}" &>/dev/null; then
    echo "Creating database '${db_name}' on instance '${instance_name}'"
    gcloud sql databases create "${db_name}" --instance="${instance_name}"
  else
    echo "Database '${db_name}' already exists on instance '${instance_name}'."
  fi
}

function delete_database_from_instance() {
  local instance_name="$1"
  local db_name="$2"
  if gcloud sql databases describe "${db_name}" --instance="${instance_name}" &>/dev/null; then
    echo "Deleting database '${db_name}' from instance '${instance_name}'"
    gcloud sql databases delete "${db_name}" --instance="${instance_name}" --quiet
  else
    echo "Database '${db_name}' not found on instance '${instance_name}'."
  fi
}


# --- Bigtable Functions ---

function create_bigtable_instance() {
  local instance_name="$1"
  local display_name="$2"
  local cluster_config="$3" # e.g., "id=my-cluster,zone=us-central1-b,nodes=1"

  if ! gcloud bigtable instances describe "${instance_name}" &>/dev/null; then
    echo "Creating Bigtable instance: ${instance_name}"
    gcloud bigtable instances create "${instance_name}" \
      --display-name="${display_name}" \
      --cluster-config="${cluster_config}"
  else
    echo "Bigtable instance '${instance_name}' already exists."
  fi
}

function delete_bigtable_instance() {
  local instance_name="$1"
  if gcloud bigtable instances describe "${instance_name}" &>/dev/null; then
    echo "Deleting Bigtable instance: ${instance_name}"
    gcloud bigtable instances delete --quiet "${instance_name}"
  else
    echo "Bigtable instance '${instance_name}' not found."
  fi
}
