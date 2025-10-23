#!/bin/bash
#
# IAM related functions

function create_service_account() {
  local phase_name="create_service_account"
  local sentinel_name="${SA_NAME}_done"

  if check_sentinel "${phase_name}" "${sentinel_name}"; then
    print_status "Checking Service Account ${GSA} and roles..."
    report_result "Exists"
    return 0
  fi

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
    # print_status "    Binding ${role}..."
    if ! run_gcloud "${role_log}" gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
      --member="serviceAccount:${GSA}" \
      --role="${role}" --condition=None; then
      all_roles_bound=false
      # report_result "Fail"
    fi
  done

  if [[ "${all_roles_bound}" = true ]]; then
     report_result "Pass" # Overall role binding status
     create_sentinel "${phase_name}" "${sentinel_name}"
  else
     report_result "Fail"
     return 1
  fi
}
export -f create_service_account

function delete_service_account() {
  print_status "Deleting Service Account ${GSA}..."
  SA_EXISTS=$(gcloud iam service-accounts list \
    --project="${PROJECT_ID}" \
    --filter="email=${GSA}" \
    --format="value(email)" 2>/dev/null)

  if [[ -z "${SA_EXISTS}" ]]; then
    report_result "Not Found"
    return 0
  fi

  local log_file="delete_service_account_${SA_NAME}.log"
  # Attempt to remove bindings - ignore errors if not found
  for svc in spark-executor spark-driver agent ; do
    gcloud iam service-accounts remove-iam-policy-binding \
      --role=roles/iam.workloadIdentityUser \
      --member="serviceAccount:${PROJECT_ID}.svc.id.goog[${DPGKE_NAMESPACE}/${svc}]" \
      "${GSA}" > /dev/null 2>&1 || true
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
    gcloud projects remove-iam-policy-binding \
      --role="${role}" \
      --member="serviceAccount:${GSA}" \
      "${PROJECT_ID}" --condition=None > /dev/null 2>&1 || true
  done

   gcloud iam service-accounts remove-iam-policy-binding "${GSA}" \
    --member="serviceAccount:${GSA}" \
    --role=roles/iam.serviceAccountUser > /dev/null 2>&1 || true

  # Delete the service account
  if run_gcloud "${log_file}" gcloud iam service-accounts delete --quiet "${GSA}"; then
    report_result "Deleted"
    remove_sentinel "create_service_account" "${SA_NAME}_done"
  else
    report_result "Fail"
  fi
}

function grant_kms_roles(){
      print_status "Granting KMS Roles to ${GSA}..."
      local log_file="grant_kms_roles_${SA_NAME}.log"
      if run_gcloud "${log_file}" gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
        --member="serviceAccount:${GSA}" \
        --role=roles/cloudkms.cryptoKeyDecrypter; then
        report_result "Pass"
      else
        report_result "Fail"
      fi
    }
    export -f grant_kms_roles

    function grant_mysql_roles(){
      print_status "Granting MySQL/Cloud SQL Roles to ${GSA}..."
      local log_file="grant_mysql_roles_${SA_NAME}.log"
      if run_gcloud "${log_file}" gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
        --member="serviceAccount:${GSA}" \
        --role=roles/cloudsql.editor; then
        report_result "Pass"
      else
        report_result "Fail"
      fi
    }
    export -f grant_mysql_roles

    function grant_bigtables_roles(){
      print_status "Granting Bigtable Roles to ${GSA}..."
      local log_file="grant_bigtable_roles_${SA_NAME}.log"
      local all_ok=true
      if ! run_gcloud "${log_file}" gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
        --member="serviceAccount:${GSA}" \
        --role=roles/bigtable.user; then
        all_ok=false
      fi
      if ! run_gcloud "${log_file}" gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
        --member="serviceAccount:${GSA}" \
        --role=roles/bigtable.admin; then
        all_ok=false
      fi
      if [[ "${all_ok}" = true ]]; then report_result "Pass"; else report_result "Fail"; fi
    }
    export -f grant_bigtables_roles

    function grant_gke_roles(){
      print_status "Granting GKE Roles to ${GSA}..."
      local log_file="grant_gke_roles_${SA_NAME}.log"
      local all_ok=true
      for svc in agent spark-driver spark-executor ; do
        if ! run_gcloud "${log_file}" gcloud iam service-accounts add-iam-policy-binding \
          --role=roles/iam.workloadIdentityUser \
          --member="serviceAccount:${PROJECT_ID}.svc.id.goog[${DPGKE_NAMESPACE}/${svc}]" \
          "${GSA}"; then
          all_ok=false
        fi
      done
      if ! run_gcloud "${log_file}" gcloud artifacts repositories add-iam-policy-binding "${ARTIFACT_REPOSITORY}" \
          --location="${REGION}" \
          --member="serviceAccount:${GSA}" \
          --role=roles/artifactregistry.writer; then
          all_ok=false
      fi
      if [[ "${all_ok}" = true ]]; then report_result "Pass"; else report_result "Fail"; fi
    }
    export -f grant_gke_roles


