#!/bin/bash
#
# IAM related functions

function exists_service_account() {
  _check_exists "gcloud iam service-accounts describe '${GSA}' --project='${PROJECT_ID}' --format='json(email,name)'"
}
export -f exists_service_account

function create_service_account() {
  print_status "Creating/Verifying Service Account ${GSA}..."
  local log_file="create_service_account_${SA_NAME}.log"

  SA_EXISTS=$(gcloud iam service-accounts list \
    --project="${PROJECT_ID}" \
    --filter="email=${GSA}" \
    --format="value(email)" 2>/dev/null)

  if [[ -z "${SA_EXISTS}" ]]; then
    if ! run_gcloud "${log_file}" gcloud iam service-accounts create "${SA_NAME}" \
      --project="${PROJECT_ID}" \
      --description="Service account for use with cluster ${CLUSTER_NAME}" \
      --display-name="${SA_NAME}"; then
      report_result "Fail"
      return 1
    fi
    report_result "Created"
    sleep 10
  else
    report_result "Exists"
  fi

  # Bind roles
  print_status "  Ensuring roles for ${GSA}... "
  ROLES=(
    roles/dataproc.worker
    roles/dataproc.editor
    roles/dataproc.admin
    roles/bigquery.dataEditor
    roles/bigquery.dataViewer
    roles/bigquery.user
    roles/storage.admin
    roles/secretmanager.secretAccessor
    roles/compute.admin
    roles/iam.serviceAccountUser
  )
  local all_roles_bound=true
  for role in "${ROLES[@]}"; do
    local role_file_name=$(echo "${role}" | tr '/' '_')
    local role_log="bind_roles/bind_${role_file_name}_${SA_NAME}.log"
    if ! run_gcloud "${role_log}" gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
      --member="serviceAccount:${GSA}" \
      --role="${role}" --condition=None; then
      all_roles_bound=false
    fi
  done

  if [[ "${all_roles_bound}" = true ]]; then
     report_result "Pass"
  else
     report_result "Fail"
     return 1
  fi
}
export -f create_service_account

function delete_service_account() {
  print_status "Deleting Service Account ${GSA}..."
  local log_file="delete_service_account_${SA_NAME}.log"
  
  for svc in spark-executor spark-driver agent ; do
    run_gcloud "${log_file}" gcloud iam service-accounts remove-iam-policy-binding "${GSA}" \
      --role=roles/iam.workloadIdentityUser \
      --member="serviceAccount:${PROJECT_ID}.svc.id.goog[${DPGKE_NAMESPACE}/${svc}]" || true
  done

  ROLES=(
    roles/dataproc.worker
    roles/dataproc.editor
    roles/dataproc.admin
    roles/bigquery.dataEditor
    roles/bigquery.dataViewer
    roles/bigquery.user
    roles/storage.admin
    roles/secretmanager.secretAccessor
    roles/compute.admin
    roles/iam.serviceAccountUser
  )
  for role in "${ROLES[@]}"; do
    run_gcloud "${log_file}" gcloud projects remove-iam-policy-binding "${PROJECT_ID}" \
      --role="${role}" \
      --member="serviceAccount:${GSA}" \
      --condition=None || true
  done

   run_gcloud "${log_file}" gcloud iam service-accounts remove-iam-policy-binding "${GSA}" \
    --member="serviceAccount:${GSA}" \
    --role=roles/iam.serviceAccountUser || true

  if run_gcloud "${log_file}" gcloud iam service-accounts delete --quiet "${GSA}"; then
    report_result "Deleted"
  else
    report_result "Fail"
    echo "  - Failed to delete service account ${GSA}. Log content:" >&2
    cat "${log_file}" >&2
    return 1
  fi
}
export -f delete_service_account
