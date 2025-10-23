#!/bin/bash
#
# KMS and Secret Manager functions

function enable_secret_manager() {
  local phase_name="enable_secret_manager"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Enabling Secret Manager API..."
    report_result "Exists"
    return 0
  fi

  print_status "Enabling Secret Manager API..."
  local log_file="enable_secret_manager.log"
  if run_gcloud "${log_file}" gcloud services enable \
    secretmanager.googleapis.com \
    --project=${PROJECT_ID}; then
    report_result "Pass"
    create_sentinel "${phase_name}" "done"
  else
    report_result "Fail"
  fi
}
export -f enable_secret_manager

function create_secret() {
  local secret_name="${1:-${MYSQL_SECRET_NAME}}"
  local phase_name="create_secret_${secret_name}"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating Secret ${secret_name}..."
    report_result "Exists"
    return 0
  fi

  print_status "Creating Secret ${secret_name}..."
  local log_file="create_secret_${secret_name}.log"
  if gcloud secrets describe "${secret_name}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
  else
    if echo -n "super secret" | run_gcloud "${log_file}" gcloud secrets create "${secret_name}" \
      --project="${PROJECT_ID}" \
      --replication-policy="automatic" \
      --data-file=-; then
      report_result "Created"
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
    fi
  fi
}
export -f create_secret

function create_kms_keyring() {
  local phase_name="create_kms_keyring"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating KMS Keyring ${KMS_KEYRING}..."
    report_result "Exists"
    return 0
  fi
  print_status "Creating KMS Keyring ${KMS_KEYRING}..."
  if gcloud kms keyrings list --location global --project="${PROJECT_ID}" | grep "${KMS_KEYRING}" > /dev/null 2>&1; then
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
  else
    local log_file="create_kms_keyring_${KMS_KEYRING}.log"
    if run_gcloud "${log_file}" gcloud kms keyrings create "${KMS_KEYRING}" --location=global --project="${PROJECT_ID}"; then
      report_result "Created"
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
      return 1
    fi
  fi
}
export -f create_kms_keyring

function create_kerberos_kdc_key() {
  local phase_name="create_kerberos_kdc_key"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating KMS Key ${KDC_ROOT_PASSWD_KEY}..."
    report_result "Exists"
    return 0
  fi
  print_status "Creating KMS Key ${KDC_ROOT_PASSWD_KEY}..."
  if gcloud kms keys list --location global --keyring="${KMS_KEYRING}" --project="${PROJECT_ID}" | grep "${KDC_ROOT_PASSWD_KEY}" > /dev/null 2>&1; then
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
  else
    local log_file="create_kms_key_${KDC_ROOT_PASSWD_KEY}.log"
    if run_gcloud "${log_file}" gcloud kms keys create "${KDC_ROOT_PASSWD_KEY}" \
      --location=global \
      --keyring="${KMS_KEYRING}" \
      --purpose=encryption --project="${PROJECT_ID}"; then
      report_result "Created"
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
      return 1
    fi
  fi
}
export -f create_kerberos_kdc_key

function create_mysql_admin_password() {
    local phase_name="create_mysql_admin_password"
    if check_sentinel "${phase_name}" "done"; then
      print_status "Creating Encrypted MySQL Admin Password..."
      report_result "Exists"
      return 0
    fi
    print_status "Creating Encrypted MySQL Admin Password..."
    local log_file="create_mysql_admin_password.log"
    if dd if=/dev/urandom bs=8 count=4 | xxd -p | \
      run_gcloud "${log_file}" gcloud kms encrypt \
      --location=global \
      --keyring=projects/${PROJECT_ID}/locations/global/keyRings/${KMS_KEYRING} \
      --key=projects/${PROJECT_ID}/locations/global/keyRings/${KMS_KEYRING}/cryptoKeys/${KDC_ROOT_PASSWD_KEY} \
      --plaintext-file=- \
      --ciphertext-file=init/mysql_admin_password.encrypted; then
      report_result "Created"
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
      return 1
    fi
}
export -f create_mysql_admin_password

function create_kerberos_kdc_password() {
  local phase_name="create_kerberos_kdc_password"
  if check_sentinel "${phase_name}" "done"; then
    print_status "Creating Encrypted KDC Root Password..."
    report_result "Exists"
    return 0
  fi
  if [[ -f init/${KDC_ROOT_PASSWD_KEY}.encrypted ]]; then
    print_status "Creating Encrypted KDC Root Password..."
    report_result "Exists"
    create_sentinel "${phase_name}" "done"
  else
    print_status "Creating Encrypted KDC Root Password..."
    local log_file="create_kdc_root_password.log"
    if dd if=/dev/urandom bs=8 count=4 | xxd -p | \
      run_gcloud "${log_file}" gcloud kms encrypt \
      --location=global \
      --keyring=${KMS_KEYRING} \
      --key=${KDC_ROOT_PASSWD_KEY} \
      --plaintext-file=- \
      --ciphertext-file=init/${KDC_ROOT_PASSWD_KEY}.encrypted; then
      report_result "Created"
      create_sentinel "${phase_name}" "done"
    else
      report_result "Fail"
      return 1
    fi
  fi
}
export -f create_kerberos_kdc_password

function create_kerberos_sa_password() {
    local phase_name="create_kerberos_sa_password"
    # This one always re-creates, so no sentinel check
    print_status "Creating Encrypted KDC SA Password..."
    local log_file="create_kdc_sa_password.log"
    if dd if=/dev/urandom bs=8 count=4 | xxd -p | \
      run_gcloud "${log_file}" gcloud kms encrypt \
      --location=global \
      --keyring=${KMS_KEYRING} \
      --key=${KDC_ROOT_PASSWD_KEY} \
      --plaintext-file=- \
      --ciphertext-file=init/${KDC_SA_PASSWD_KEY}.encrypted; then
      report_result "Created"
    else
      report_result "Fail"
      return 1
    fi
}
export -f create_kerberos_sa_password
