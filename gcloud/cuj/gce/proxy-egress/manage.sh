#!/bin/bash
#
# CUJ: GCE Cluster with Proxy Egress
#
# This script manages the lifecycle of a Dataproc cluster that is configured
# to use a pre-existing Squid proxy for all its outbound internet traffic.
# It assumes the proxy was created by the 'gcloud/onboarding/create_squid_proxy.sh' script.

set -e

function main() {
  local SCRIPT_DIR
  SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
  source "${SCRIPT_DIR}/../../../lib/common.sh"
  load_config

  # --- Define derived resource names ---
  # This CUJ is self-contained. All resource names are derived from a static
  # base name, not from env.json.
  local base_name="cuj-proxy-egress"
  local cluster_name="${base_name}-cluster"
  local network_name="${base_name}-net"
  local subnet_name="${base_name}-subnet"
  local subnet_range="10.200.0.0/24" # A distinct CIDR for this CUJ
  local test_client_name="${base_name}-test-client"
  # Name of the shared proxy VM *is* read from config.
  local squid_vm_name="${CONFIG[SQUID_PROXY_VM_NAME]}"

  # --- Helper Functions ---

  function get_squid_ip() {
    gcloud compute instances describe "${squid_vm_name}" \
      --zone="${CONFIG[ZONE]}" \
      --format='get(networkInterfaces[0].networkIP)'
  }

  function validate() {
    header "Validating prerequisites for Proxy Egress CUJ"
    echo "Checking for Squid Proxy VM: ${squid_vm_name}..."
    if ! gcloud compute instances describe "${squid_vm_name}" --zone="${CONFIG[ZONE]}" &>/dev/null; then
      echo "ERROR: Squid Proxy VM '${squid_vm_name}' not found." >&2
      echo "Please run 'gcloud/onboarding/create_squid_proxy.sh' first." >&2
      exit 1
    fi
    echo "Prerequisites met."
  }

  function up() {
    header "Provisioning environment for CUJ: ${base_name}"
    validate
    create_network "${network_name}"
    # Create a subnet with Private Google Access disabled to force traffic through the proxy.
    create_subnet "${network_name}" "${subnet_name}" "${subnet_range}" "${CONFIG[REGION]}" "false"

    local squid_ip
    squid_ip=$(get_squid_ip)
    local proxy_uri="http://${squid_ip}:3128"
    
    # Define the flags needed to configure the cluster for proxy usage.
    local proxy_properties="core:fs.gs.proxy.address=${squid_ip}:3128"
    local proxy_metadata="http_proxy=${proxy_uri},https_proxy=${proxy_uri},no_proxy=metadata.google.internal,localhost,127.0.0.1"
    local extra_flags="--no-address --properties='${proxy_properties}' --metadata='${proxy_metadata}' --tags='${CONFIG[CUJ_TAG]}'"

    create_gce_cluster "${cluster_name}" "${CONFIG[REGION]}" "${subnet_name}" "${extra_flags}"
    echo "Environment for '${base_name}' is UP."
  }

  function down() {
    header "Tearing down environment for CUJ: ${base_name}"
    delete_gce_cluster "${cluster_name}" "${CONFIG[REGION]}"
    delete_network "${network_name}"
    echo "Environment for '${base_name}' is DOWN."
  }

  function test_client_up() {
    header "Creating test client VM: ${test_client_name}"
    if ! gcloud compute instances describe "${test_client_name}" --zone="${CONFIG[ZONE]}" &>/dev/null; then
       gcloud compute instances create "${test_client_name}" \
        --zone="${CONFIG[ZONE]}" --machine-type="e2-small" \
        --image-family="debian-12" --image-project="debian-cloud" \
        --subnet="${subnet_name}" --no-address --tags="${CONFIG[CUJ_TAG]}"
    else
        echo "Test client '${test_client_name}' already exists."
    fi
  }

  function test_client_down() {
    header "Deleting test client VM: ${test_client_name}"
    delete_gce_instance "${test_client_name}" "${CONFIG[ZONE]}"
  }

  function test_client_run() {
    header "Running proxy connectivity test from '${test_client_name}'"
    local squid_ip
    squid_ip=$(get_squid_ip)
    echo "Proxy IP determined to be: ${squid_ip}"
    gcloud compute ssh "${test_client_name}" \
      --zone="${CONFIG[ZONE]}" \
      --command="echo 'Testing proxy connectivity to google.com...' && curl -s --fail --verbose --proxy http://${squid_ip}:3128 https://www.google.com" \
      -- -q # -q suppresses host key warnings
    echo "Proxy test completed successfully."
  }

  # --- Main command handler ---
  case "$1" in
    validate) validate ;;
    up) up ;;
    down) confirm "This will delete cluster '${cluster_name}' and its dedicated private network." && down ;;
    rebuild) down || true; up ;;
    test-client-up) test_client_up ;;
    test-client-down) confirm "This will delete the test client VM '${test_client_name}'." && test_client_down ;;
    test-client-run) test_client_run ;;
    *)
      echo "Usage: $0 {validate|up|down|rebuild|test-client-up|test-client-down|test-client-run}"
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
