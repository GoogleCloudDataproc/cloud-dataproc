#!/bin/bash

function create_allow_swp_ingress_rule() {
  local rule_name="${1:-allow-swp-ingress-${CLUSTER_NAME}}"
  local network_name="${2:-${NETWORK}}"
  local source_range="${3:-${PRIVATE_RANGE}}"
  local phase_name="create_allow_swp_ingress_rule"

  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating Firewall Rule ${rule_name}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating Firewall Rule ${rule_name}..."
  if ! gcloud compute firewall-rules describe "${rule_name}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
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
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
      return 1
    fi
  else
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
  fi
}
export -f create_allow_swp_ingress_rule

function delete_allow_swp_ingress_rule() {
  local rule_name="${1:-allow-swp-ingress-${CLUSTER_NAME}}"
  local phase_name="create_allow_swp_ingress_rule"
  remove_sentinel "${phase_name}" "done"

  print_status "Deleting Firewall Rule ${rule_name}..."
  if gcloud compute firewall-rules describe "${rule_name}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    local log_file="delete_firewall_${rule_name}.log"
    if run_gcloud "${log_file}" gcloud compute firewall-rules delete "${rule_name}" --project="${PROJECT_ID}" --quiet; then
      report_result "Deleted"
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
  fi
}
export -f delete_allow_swp_ingress_rule

function create_allow_internal_subnets_rule() {
  local rule_name="${1:-allow-internal-${CLUSTER_NAME}}"
  local network_name="${2:-${NETWORK}}"
  local source_range="${3:-${PRIVATE_RANGE}}"
  local dest_range="${4:-${SWP_RANGE}}"
  local phase_name="create_allow_internal_subnets_rule"

  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating Firewall Rule ${rule_name}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating Firewall Rule ${rule_name}..."
  if ! gcloud compute firewall-rules describe "${rule_name}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
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
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
      return 1
    fi
  else
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
  fi
}
export -f create_allow_internal_subnets_rule

function delete_allow_internal_subnets_rule() {
  local rule_name="${1:-allow-internal-${CLUSTER_NAME}}"
  local phase_name="create_allow_internal_subnets_rule"
  remove_sentinel "${phase_name}" "done"

  print_status "Deleting Firewall Rule ${rule_name}..."
  if gcloud compute firewall-rules describe "${rule_name}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    local log_file="delete_firewall_${rule_name}.log"
    if run_gcloud "${log_file}" gcloud compute firewall-rules delete "${rule_name}" --project="${PROJECT_ID}" --quiet; then
      report_result "Deleted"
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
  fi
}
export -f delete_allow_internal_subnets_rule