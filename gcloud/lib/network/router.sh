#!/bin/bash
#
# Router and NAT functions

function create_router () {
  local phase_name="create_router"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating Router ${ROUTER_NAME}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating Router ${ROUTER_NAME}..."
  local log_file="create_router_${ROUTER_NAME}.log"
  if gcloud compute routers describe "${ROUTER_NAME}" --region="${REGION}" --project="${PROJECT_ID}" > /dev/null 2>&1;
 then
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
  else
    if run_gcloud "${log_file}" gcloud compute routers create ${ROUTER_NAME} \
      --project=${PROJECT_ID} \
      --network=${NETWORK} \
      --asn=${ASN_NUMBER} \
      --region=${REGION}; then
      report_result "Created"
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
      return 1
    fi
  fi
}
export -f create_router

function add_nat_policy () {
  local phase_name="add_nat_policy"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Adding NAT to Router ${ROUTER_NAME}..."
    report_result "Exists"
    return 0
  fi

  print_status "Adding NAT to Router ${ROUTER_NAME}..."
  local log_file="add_nat_${ROUTER_NAME}.log"
  if gcloud compute routers nats describe nat-config --router="${ROUTER_NAME}" --region="${REGION}" --project="${PROJECT_ID}" > /dev/null 2>&1;
 then
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
  else
    if run_gcloud "${log_file}" gcloud compute routers nats create nat-config \
      --router-region ${REGION} \
      --router ${ROUTER_NAME} \
      --project="${PROJECT_ID}" \
      --nat-custom-subnet-ip-ranges "${SUBNET}" \
      --auto-allocate-nat-external-ips; then
      report_result "Created"
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
      return 1
    fi
  fi
}
export -f add_nat_policy

function delete_nat_configs() {
  local phase_name="add_nat_policy"
  print_status "Deleting NAT Configs from ${ROUTER_NAME}..."
  local log_file="delete_nats_${ROUTER_NAME}.log"
  local found_some=false
  local all_ok=true

  if gcloud compute routers describe "${ROUTER_NAME}" --region="${REGION}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    NATS=$(gcloud compute routers nats list --router="${ROUTER_NAME}" --region="${REGION}" --project="${PROJECT_ID}" --format="value(name)" 2>/dev/null || true)
    if [[ -n "${NATS}" ]]; then
      found_some=true
      while read -r nat_name; do
        # print_status "  Deleting NAT ${nat_name} from ${ROUTER_NAME}..."
        if ! run_gcloud "${log_file}" gcloud compute routers nats delete "${nat_name}" --router="${ROUTER_NAME}" --region="${REGION}" --project="${PROJECT_ID}" --quiet; then
          all_ok=false
        fi
      done <<< "${NATS}"
    fi
  fi

  if [[ "${found_some}" = false ]]; then
    report_result "Not Found"
    remove_sentinel "${phase_name}" "done"
  elif [[ "${all_ok}" = true ]]; then
    report_result "Deleted"
    remove_sentinel "${phase_name}" "done"
  else
    report_result "Fail"
  fi
}
export -f delete_nat_configs

function delete_router () {
  local phase_name="create_router"
  print_status "Deleting Router ${ROUTER_NAME}..."
  local log_file="delete_router_${ROUTER_NAME}.log"

  local router_check=$(gcloud compute routers list --regions="${REGION}" --project="${PROJECT_ID}" --filter="name = ${ROUTER_NAME}" --format="value(name)" 2>/dev/null)
  if [[ -n "${router_check}" ]]; then
    if run_gcloud "${log_file}" gcloud compute routers delete --quiet --region ${REGION} "${ROUTER_NAME}" --project="${PROJECT_ID}"; then
      report_result "Deleted"
      remove_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
    remove_sentinel "${phase_name}" "done"
  fi
}
export -f delete_router