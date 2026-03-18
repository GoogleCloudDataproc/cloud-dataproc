#!/bin/bash

function exists_firewall_rule() {
  local rule_name="$1"
  _check_exists gcloud compute firewall-rules describe "${rule_name}" --project="${PROJECT_ID}" --format="json(name,direction)"
}
export -f exists_firewall_rule

function create_allow_swp_ingress_rule() {
  local rule_name="${1:-allow-swp-ingress-${CLUSTER_NAME}}"
  local network_name="${2:-${NETWORK}}"
  local source_range="${3:-${PRIVATE_RANGE}}"
  print_status "Creating Firewall Rule ${rule_name}..."
  local log_file="create_firewall_${rule_name}.log"
  if run_gcloud "${log_file}" gcloud compute firewall-rules create "${rule_name}" \
    --project="${PROJECT_ID}" \
    --network="${network_name}" \
    --direction=INGRESS \
    --action=ALLOW \
    --rules=tcp:${SWP_PORT} \
    --source-ranges="${source_range}" \
    --destination-ranges="${SWP_RANGE}"; then
    report_result "Created"
  else
    report_result "Fail"
    return 1
  fi
}
export -f create_allow_swp_ingress_rule

function delete_allow_swp_ingress_rule() {
  local rule_name="${1:-allow-swp-ingress-${CLUSTER_NAME}}"
  print_status "Deleting Firewall Rule ${rule_name}..."
  local log_file="delete_firewall_${rule_name}.log"
  if run_gcloud "${log_file}" gcloud compute firewall-rules delete "${rule_name}" --project="${PROJECT_ID}" --quiet; then
    report_result "Deleted"
  else
    report_result "Fail"
  fi
}
export -f delete_allow_swp_ingress_rule

function create_allow_internal_subnets_rule() {
  local rule_name="${1:-allow-internal-${CLUSTER_NAME}}"
  local network_name="${2:-${NETWORK}}"
  local source_range="${3:-${PRIVATE_RANGE}}"
  local dest_range="${4:-${SWP_RANGE}}"
  print_status "Creating Firewall Rule ${rule_name}..."
  local log_file="create_firewall_${rule_name}.log"
  if run_gcloud "${log_file}" gcloud compute firewall-rules create "${rule_name}" \
    --project="${PROJECT_ID}" \
    --network="${network_name}" \
    --direction=INGRESS \
    --action=ALLOW \
    --rules=all \
    --source-ranges="${source_range}" \
    --destination-ranges="${dest_range}" \
    --priority=100; then # High priority
    report_result "Created"
  else
    report_result "Fail"
    return 1
  fi
}
export -f create_allow_internal_subnets_rule

function delete_allow_internal_subnets_rule() {
  local rule_name="${1:-allow-internal-${CLUSTER_NAME}}"
  print_status "Deleting Firewall Rule ${rule_name}..."
  local log_file="delete_firewall_${rule_name}.log"
  if run_gcloud "${log_file}" gcloud compute firewall-rules delete "${rule_name}" --project="${PROJECT_ID}" --quiet; then
    report_result "Deleted"
  else
    report_result "Fail"
  fi
}
export -f delete_allow_internal_subnets_rule