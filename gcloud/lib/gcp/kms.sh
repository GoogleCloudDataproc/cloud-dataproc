#!/bin/bash
#
# KMS and Secret Manager functions

function enable_secret_manager() {
  print_status "Enabling Secret Manager API..."
  local log_file="enable_secret_manager.log"
  if run_gcloud "${log_file}" gcloud services enable \
    secretmanager.googleapis.com \
    --project=${PROJECT_ID}; then
    report_result "Pass"
  else
    report_result "Fail"
  fi
}
export -f enable_secret_manager

function create_secret() {
  local secret_name="${1:-${MYSQL_SECRET_NAME}}"
  print_status "Creating Secret ${secret_name}..."
  local log_file="create_secret_${secret_name}.log"
  if echo -n "super secret" | run_gcloud "${log_file}" gcloud secrets create "${secret_name}" \
    --project="${PROJECT_ID}" \
    --replication-policy="automatic" \
    --data-file=-; then
    report_result "Created"
  else
    report_result "Fail"
  fi
}
export -f create_secret

function create_kms_keyring() {
  print_status "Creating KMS Keyring ${KMS_KEYRING}..."
  local log_file="create_kms_keyring_${KMS_KEYRING}.log"
  if run_gcloud "${log_file}" gcloud kms keyrings create "${KMS_KEYRING}" --location=global --project="${PROJECT_ID}"; then
    report_result "Created"
    refresh_resource_state "kmsKeyring" "exists_kms_keyring" "lib/gcp/kms.sh"
  else
    report_result "Fail"
    return 1
  fi
}
export -f create_kms_keyring

function create_kerberos_kdc_key() {
  print_status "Creating KMS Key ${KDC_ROOT_PASSWD_KEY}..."
  local log_file="create_kms_key_${KDC_ROOT_PASSWD_KEY}.log"
  if run_gcloud "${log_file}" gcloud kms keys create "${KDC_ROOT_PASSWD_KEY}" \
    --location=global \
    --keyring="${KMS_KEYRING}" \
    --purpose=encryption --project="${PROJECT_ID}"; then
    report_result "Created"
  else
    report_result "Fail"
    return 1
  fi
}
export -f create_kerberos_kdc_key

function exists_kms_key() {
  local key_name="$1"
  _check_exists "gcloud kms keys describe '${key_name}' --keyring='${KMS_KEYRING}' --location=global --project='${PROJECT_ID}' --format='json(name,primary.state)'"
}
export -f exists_kms_key

function create_mysql_admin_password() {
    print_status "Creating Encrypted MySQL Admin Password..."
    local log_file="create_mysql_admin_password.log"
    if dd if=/dev/urandom bs=8 count=4 | xxd -p | \
      run_gcloud "${log_file}" gcloud kms encrypt \
      --location=global \
      --keyring="projects/${PROJECT_ID}/locations/global/keyRings/${KMS_KEYRING}" \
      --key="projects/${PROJECT_ID}/locations/global/keyRings/${KMS_KEYRING}/cryptoKeys/${KDC_ROOT_PASSWD_KEY}" \
      --plaintext-file=- \
      --ciphertext-file=init/mysql_admin_password.encrypted; then
      report_result "Created"
    else
      report_result "Fail"
      return 1
    fi
}
export -f create_mysql_admin_password

function create_kerberos_kdc_password() {
  print_status "Creating Encrypted KDC Root Password..."
  local log_file="create_kdc_root_password.log"
  if dd if=/dev/urandom bs=8 count=4 | xxd -p | \
    run_gcloud "${log_file}" gcloud kms encrypt \
    --location=global \
    --keyring="${KMS_KEYRING}" \
    --key="${KDC_ROOT_PASSWD_KEY}" \
    --plaintext-file=- \
    --ciphertext-file="init/${KDC_ROOT_PASSWD_KEY}.encrypted"; then
    report_result "Created"
  else
    report_result "Fail"
    return 1
  fi
}
export -f create_kerberos_kdc_password

function create_kerberos_sa_password() {
    print_status "Creating Encrypted KDC SA Password..."
    local log_file="create_kdc_sa_password.log"
    if dd if=/dev/urandom bs=8 count=4 | xxd -p | \
      run_gcloud "${log_file}" gcloud kms encrypt \
      --location=global \
      --keyring="${KMS_KEYRING}" \
      --key="${KDC_ROOT_PASSWD_KEY}" \
      --plaintext-file=- \
      --ciphertext-file="init/${KDC_SA_PASSWD_KEY}.encrypted"; then
      report_result "Created"
    else
      report_result "Fail"
      return 1
    fi
}
export -f create_kerberos_sa_password
