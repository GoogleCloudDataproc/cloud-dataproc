#!/bin/bash
#
# Dataproc Autoscaling Policy functions

function exists_autoscaling_policy() {
  _check_exists "gcloud dataproc autoscaling-policies describe '${AUTOSCALING_POLICY_NAME}' --region='${REGION}' --format='json(id,name)'"
}
export -f exists_autoscaling_policy

function create_autoscaling_policy() {
  print_status "Creating Autoscaling Policy ${AUTOSCALING_POLICY_NAME}..."
  local log_file="create_autoscaling_${AUTOSCALING_POLICY_NAME}.log"
  if run_gcloud "${log_file}" gcloud dataproc autoscaling-policies import "${AUTOSCALING_POLICY_NAME}" --region="${REGION}" --source=autoscaling-policy.yaml; then
    report_result "Created"
  else
    report_result "Fail"
    return 1
  fi
}
export -f create_autoscaling_policy

function delete_autoscaling_policy() {
  print_status "Deleting Autoscaling Policy ${AUTOSCALING_POLICY_NAME}..."
  local log_file="delete_autoscaling_${AUTOSCALING_POLICY_NAME}.log"
  if run_gcloud "${log_file}" gcloud dataproc autoscaling-policies delete --quiet "${AUTOSCALING_POLICY_NAME}" --region="${REGION}"; then
    report_result "Deleted"
  else
    report_result "Fail"
  fi
}
export -f delete_autoscaling_policy
