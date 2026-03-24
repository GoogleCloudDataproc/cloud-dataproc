#!/bin/bash
#
# Router and NAT functions

function exists_router() {
    _check_exists gcloud compute routers describe "${ROUTER_NAME}" --region="${REGION}" --project="${PROJECT_ID}" --format="json(name,selfLink)"
}
export -f exists_router

function create_router () {
  print_status "Creating Router ${ROUTER_NAME}..."
  local log_file="create_router_${ROUTER_NAME}.log"
  if run_gcloud "${log_file}" gcloud compute routers create "${ROUTER_NAME}" \
    --project="${PROJECT_ID}" \
    --network="${NETWORK}" \
    --asn="${ASN_NUMBER}" \
    --region="${REGION}"; then
    report_result "Created"
    refresh_resource_state "cloudRouter" "lib/network/router.sh" exists_router
  else
    report_result "Fail"
    return 1
  fi
}
export -f create_router

function add_nat_to_router () {
  print_status "Adding NAT to Router ${ROUTER_NAME}..."
  local log_file="add_nat_${ROUTER_NAME}.log"

  # Attempt to delete nat-config first, ignore errors
  gcloud compute routers nats delete "nat-config" \
    --router-region "${REGION}" \
    --router "${ROUTER_NAME}" \
    --project="${PROJECT_ID}" --quiet > /dev/null 2>&1 || true
  sleep 5 # Brief pause to allow delete to propagate

  if run_gcloud "${log_file}" gcloud compute routers nats create "nat-config" \
    --router-region "${REGION}" \
    --router "${ROUTER_NAME}" \
    --project="${PROJECT_ID}" \
    --nat-custom-subnet-ip-ranges "${SUBNET}" \
    --auto-allocate-nat-external-ips; then
    report_result "Created"
    refresh_resource_state "cloudRouter" "lib/network/router.sh" exists_router
    refresh_resource_state "cloudRouterNAT" "lib/network/router.sh" exists_router_nat "nat-config"
  else
    report_result "Fail"
    return 1
  fi
}
export -f add_nat_to_router

function delete_router () {
  if [[ $(get_state "cloudRouterNAT") != "null" ]]; then
    print_status "Deleting NAT from Router ${ROUTER_NAME}..."
    local log_file="delete_nat_${ROUTER_NAME}.log"
    # Don't fail if the NAT doesn't exist in GCP, as state might be slightly stale
    run_gcloud "${log_file}" gcloud compute routers nats delete "nat-config" \
      --router-region "${REGION}" \
      --router "${ROUTER_NAME}" \
      --project="${PROJECT_ID}" --quiet || true
    update_state "cloudRouterNAT" "null"
  fi

  print_status "Deleting Router ${ROUTER_NAME}..."
  log_file="delete_router_${ROUTER_NAME}.log"
  if run_gcloud "${log_file}" gcloud compute routers delete --quiet "${ROUTER_NAME}" \
    --region="${REGION}" \
    --project="${PROJECT_ID}"; then
    report_result "Deleted"
    update_state "cloudRouter" "null"
  else
    report_result "Fail"
  fi
}
export -f delete_router

function exists_router_nat() {
  local nat_name="$1"
  # gcloud compute routers nats describe returns non-zero if not found
  _check_exists gcloud compute routers nats describe "${nat_name}" --router="${ROUTER_NAME}" --region="${REGION}" --project="${PROJECT_ID}"
}
export -f exists_router_nat
