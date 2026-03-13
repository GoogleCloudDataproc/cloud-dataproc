#!/bin/bash
#
# Firewall rule functions

function exists_firewall() {
    # This is a basic check. A more robust version might check for a list of rules.
    _check_exists "gcloud compute firewall-rules describe '${FIREWALL}-in-ssh' --project='${PROJECT_ID}' --format='json(name,selfLink)'"
}

function create_firewall_rules() {
  print_status "Creating base Firewall Rules for ${NETWORK}..."
  local log_file="create_firewalls_${NETWORK}.log"
  local created_some=false
  local failed_some=false

  # Egress rules
  if ! gcloud compute firewall-rules describe "${FIREWALL}-out" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    if run_gcloud "${log_file}" gcloud compute firewall-rules create "${FIREWALL}-out" \
      --project="${PROJECT_ID}" --network="${NETWORK}" --action=ALLOW --direction=EGRESS --destination-ranges=0.0.0.0/0 --rules=all; then
      created_some=true
    else
      failed_some=true
    fi
  fi
  if ! gcloud compute firewall-rules describe "${FIREWALL}-default-allow-internal-out" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    if run_gcloud "${log_file}" gcloud compute firewall-rules create "${FIREWALL}-default-allow-internal-out" \
      --project="${PROJECT_ID}" --network="${NETWORK}" --action=ALLOW --direction=EGRESS --destination-ranges="${RANGE}" --rules=all; then
      created_some=true
    else
      failed_some=true
    fi
  fi

  # Ingress rules
  local iap_range="35.235.240.0/20"
  local internal_ranges="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"

  if ! gcloud compute firewall-rules describe "${FIREWALL}-in-ssh" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    if run_gcloud "${log_file}" gcloud compute firewall-rules create "${FIREWALL}-in-ssh" \
      --project="${PROJECT_ID}" --network="${NETWORK}" --action=ALLOW --direction=INGRESS --source-ranges="${iap_range},${internal_ranges}" --rules=tcp:22; then
      created_some=true
    else
      failed_some=true
    fi
  else
    # Check if IAP range is missing and add it
    EXISTING_RANGES=$(gcloud compute firewall-rules describe "${FIREWALL}-in-ssh" --project="${PROJECT_ID}" --format="value(sourceRanges)")
    if [[ ! "${EXISTING_RANGES}" == *"${iap_range}"* ]]; then
      if run_gcloud "${log_file}" gcloud compute firewall-rules update "${FIREWALL}-in-ssh" --project="${PROJECT_ID}" --source-ranges="${EXISTING_RANGES},${iap_range}"; then
        created_some=true # Considered an update as creation
      else
        failed_some=true
      fi
    fi
  fi

  if ! gcloud compute firewall-rules describe "${FIREWALL}-in-internal" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    if run_gcloud "${log_file}" gcloud compute firewall-rules create "${FIREWALL}-in-internal" \
      --project="${PROJECT_ID}" --network="${NETWORK}" --action=ALLOW --direction=INGRESS --source-ranges="${internal_ranges}" --rules=tcp:443,icmp; then
      created_some=true
    else
      failed_some=true
    fi
  fi

  if ! gcloud compute firewall-rules describe "${FIREWALL}-default-allow-internal-in" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    if run_gcloud "${log_file}" gcloud compute firewall-rules create "${FIREWALL}-default-allow-internal-in" \
      --project="${PROJECT_ID}" --network="${NETWORK}" --action=ALLOW --direction=INGRESS --source-ranges="${RANGE}" --rules=all; then
      created_some=true
    else
      failed_some=true
    fi
  fi

  if [[ "${failed_some}" = true ]]; then
    report_result "Fail"
    return 1
  else
    if [[ "${created_some}" = true ]]; then
      report_result "Created"
    else
      report_result "Exists"
    fi
  fi
}
export -f create_firewall_rules

function delete_firewall_rules () {
  print_status "Deleting Cluster Firewall Rules..."
  local log_file="delete_firewalls_${NETWORK}.log"
  # Delete any rule containing the cluster name
  FW_RULES=$(gcloud compute firewall-rules list --project="${PROJECT_ID}" --filter="network ~ ${NETWORK}$ AND name ~ ${CLUSTER_NAME}" --format="value(name)" 2>/dev/null || true)
  local deleted_some=false
  local all_ok=true
  if [[ -n "${FW_RULES}" ]]; then
    deleted_some=true
    while read -r rule; do
      if ! run_gcloud "${log_file}" gcloud compute firewall-rules delete --quiet "${rule}" --project="${PROJECT_ID}"; then
        all_ok=false
      fi
    done <<< "${FW_RULES}"
  fi

  # Delete other known rules
  if gcloud compute firewall-rules describe "allow-internal-s8s" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    deleted_some=true
    if ! run_gcloud "${log_file}" gcloud compute firewall-rules delete --quiet "allow-internal-s8s" --project="${PROJECT_ID}"; then
      all_ok=false
    fi
  fi

  if [[ "${deleted_some}" = false ]]; then
    report_result "Not Found"
  elif [[ "${all_ok}" = true ]]; then
    report_result "Deleted"
  else
    report_result "Fail"
  fi
}
export -f delete_firewall_rules
