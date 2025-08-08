#!/bin/bash
#
# Tears down the shared, persistent Squid Proxy VM and related networking.
# This script is idempotent and can be re-run safely.

set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/../lib/common.sh"
load_config

function main() {
  header "Onboarding Teardown: Deleting Squid Proxy Infrastructure"

  # 1. Define resource names from the config file.
  local squid_vm_name="${CONFIG[SQUID_PROXY_VM_NAME]}"
  local external_network_name="${CONFIG[EXTERNAL_VPC_NAME]}"
  local firewall_rule_name="${CONFIG[CUJ_TAG]}-allow-proxy-ingress"
  local zone="${CONFIG[ZONE]}"


  # 2. Delete the firewall rule that allows access to the proxy.
  if gcloud compute firewall-rules describe "${firewall_rule_name}" &>/dev/null; then
    echo "Deleting firewall rule '${firewall_rule_name}'..."
    gcloud compute firewall-rules delete --quiet "${firewall_rule_name}"
  else
    echo "Firewall rule '${firewall_rule_name}' not found, skipping."
  fi

  # 3. Delete the Squid Proxy VM.
  if gcloud compute instances describe "${squid_vm_name}" --zone="${zone}" &>/dev/null; then
    echo "Deleting Squid Proxy VM '${squid_vm_name}'..."
    gcloud compute instances delete --quiet "${squid_vm_name}" --zone="${zone}"
  else
    echo "Squid Proxy VM '${squid_vm_name}' not found, skipping."
  fi

  # 4. Delete the external VPC network.
  #    This script does not touch the main internal GCE network, as other CUJs may use it.
  if gcloud compute networks describe "${external_network_name}" &>/dev/null; then
    echo "Deleting external VPC '${external_network_name}'..."
    gcloud compute networks delete --quiet "${external_network_name}"
  else
    echo "External VPC '${external_network_name}' not found, skipping."
  fi

  echo "Teardown of Squid Proxy infrastructure is complete."
}

main
