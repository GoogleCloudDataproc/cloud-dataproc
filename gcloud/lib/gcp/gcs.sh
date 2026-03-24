#!/bin/bash
#
# GCS Bucket functions

function exists_gcs_bucket() {
  local bucket_name="$1"
  if gcloud storage ls --buckets "gs://${bucket_name}" > /dev/null 2>&1; then
    echo "{\"name\": \"${bucket_name}\", \"exists\": true}"
  else
    echo "null"
  fi
}
export -f exists_gcs_bucket

function create_bucket () {
  local phase_name="create_bucket"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating GCS Buckets gs://${BUCKET} & gs://${TEMP_BUCKET}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating GCS Staging Bucket gs://${BUCKET}..."
  local log_file="create_bucket_${BUCKET}.log"
  if ! gcloud storage ls --buckets "gs://${BUCKET}" > /dev/null 2>&1 ; then
    if run_gcloud "${log_file}" gcloud storage buckets create --location ${REGION} gs://${BUCKET}; then
      report_result "Created"
      local cache_key="gcsBucket-${bucket_name}"
      if [[ "${bucket_name}" == "${BUCKET}" ]]; then cache_key="gcsBucket"; fi
      if [[ "${bucket_name}" == "${TEMP_BUCKET}" ]]; then cache_key="gcsTempBucket"; fi
      refresh_resource_state "${cache_key}" "exists_gcs_bucket ${bucket_name}" "lib/gcp/gcs.sh"
    else
      report_result "Fail"
      return 1
    fi
  else
    report_result "Exists"
  fi

  # Grant SA permissions on BUCKET
  print_status "  Granting Storage Admin on gs://${BUCKET}..."
  if run_gcloud "${log_file}" gcloud storage buckets add-iam-policy-binding "gs://${BUCKET}" --member="serviceAccount:${GSA}" --role="roles/storage.admin"; then
    report_result "Pass"
  else
    report_result "Fail"
  fi

  print_status "Creating GCS Temp Bucket gs://${TEMP_BUCKET}..."
  local temp_log_file="create_bucket_${TEMP_BUCKET}.log"
  if ! gcloud storage ls --buckets "gs://${TEMP_BUCKET}" > /dev/null 2>&1 ; then
     if run_gcloud "${temp_log_file}" gcloud storage buckets create --location ${REGION} gs://${TEMP_BUCKET}; then
      report_result "Created"
    else
      report_result "Fail"
      return 1
    fi
  else
    report_result "Exists"
  fi

  # Grant SA permissions on TEMP_BUCKET
  print_status "  Granting Storage Admin on gs://${TEMP_BUCKET}..."
  if run_gcloud "${temp_log_file}" gcloud storage buckets add-iam-policy-binding "gs://${TEMP_BUCKET}" --member="serviceAccount:${GSA}" --role="roles/storage.admin"; then
    report_result "Pass"
  else
    report_result "Fail"
  fi
}

function grant_gcs_bucket_perms() {
  local bucket_name="$1"
  local log_file="grant_perms_${bucket_name}.log"
  print_status "  Granting Storage Admin on gs://${bucket_name}..."
  if run_gcloud "${log_file}" gcloud storage buckets add-iam-policy-binding "gs://${bucket_name}" --member="serviceAccount:${GSA}" --role="roles/storage.admin"; then
    report_result "Pass"
  else
    report_result "Fail"
  fi
}


function upload_init_actions() {
  if [[ -d init ]] ; then
    print_status "Copying init scripts to ${INIT_ACTIONS_ROOT}..."
    local cp_log="copy_init_scripts.log"
    if run_gcloud "${cp_log}" gcloud storage cp --recursive "init/*" "${INIT_ACTIONS_ROOT}/"; then
      report_result "Pass"
    else
      report_result "Fail"
    fi
  fi
}

function delete_bucket () {
  print_status "Deleting GCS Bucket gs://${BUCKET}..."
  local log_file="delete_bucket_${BUCKET}.log"
  if gcloud storage ls --buckets "gs://${BUCKET}" > /dev/null 2>&1; then
    if run_gcloud "${log_file}" gcloud storage rm --recursive "gs://${BUCKET}"; then
      report_result "Deleted"
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
  fi
  #  gcloud storage rm --recursive "gs://${TEMP_BUCKET}" > /dev/null 2>&1 || true # huge cache here, not so great to lose it
}
