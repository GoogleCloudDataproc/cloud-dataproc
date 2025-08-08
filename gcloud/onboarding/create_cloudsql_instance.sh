#!/bin/bash
#
# Creates the shared, persistent Cloud SQL instance based on the engine
# specified in env.json.
#
# This script is idempotent and follows GCP best practices by setting up a
# High Availability (HA) instance with a Private IP, connected to the main
# GCE network via VPC Service Peering.

set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/../lib/common.sh"
load_config

function main() {
  header "Onboarding: Setting up Shared Cloud SQL Instance"

  # 1. Define resource names from the config file. Default to mysql if not set.
  local instance_name="${CONFIG[SHARED_SQL_INSTANCE_NAME]}"
  local db_engine="${CONFIG[SHARED_SQL_ENGINE]:-mysql}"
  local network_name="${CONFIG[GCE_STANDARD_NETWORK]}"
  local region="${CONFIG[REGION]}"

  # 2. Validate that the necessary APIs are enabled.
  validate_apis "sqladmin.googleapis.com" "servicenetworking.googleapis.com" "compute.googleapis.com"

  # 3. Ensure the main VPC network and the VPC Peering connection exist.
  # These library functions are idempotent.
  create_network "${network_name}"
  create_peering_ip_allocation "${network_name}"
  create_vpc_peering_connection "${network_name}"

  # 4. Dispatch to the correct library function based on the selected engine.
  #    We pass "HA" to enable the high-availability flag.
  header "Provisioning Cloud SQL instance '${instance_name}' with engine '${db_engine}'"
  case "${db_engine}" in
    mysql)
      create_mysql_instance "${instance_name}" "${network_name}" "${region}" "HA"
      ;;
    postgres)
      create_postgres_instance "${instance_name}" "${network_name}" "${region}" "HA"
      ;;
    *)
      echo "ERROR: Unsupported database engine '${db_engine}' specified in env.json." >&2
      echo "Supported values are 'mysql' or 'postgres'." >&2
      exit 1
      ;;
  esac

  echo "Onboarding of Cloud SQL infrastructure is complete."
  local private_ip
  private_ip=$(gcloud sql instances describe "${instance_name}" --format="value(ipAddresses.ipAddress)")
  echo "--> Private IP Address: ${private_ip}"
}

main
