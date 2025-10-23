#!/bin/bash


function create_managed_certificate() {
  local cert_name="swp-cert" # Static name for the final cert
  local region="${1:-${REGION}}"
  local project_id="${2:-${PROJECT_ID}}"
  local swp_hostname="${3:-${SWP_HOSTNAME}}"

  local phase_name="swp_managed_cert"
  local log_file="${phase_name}_${CLUSTER_NAME}-${RESOURCE_SUFFIX}.log"

  local ca_pool_prefix="swp-ca-pool-${CLUSTER_NAME}-"
  local cic_prefix="swp-cic-${CLUSTER_NAME}-"
  local ca_prefix="swp-root-ca-${CLUSTER_NAME}-"

  local suffix="${RESOURCE_SUFFIX}"
  local ca_pool_name="${ca_pool_prefix}${suffix}"
  local cic_name="${cic_prefix}${suffix}"
  local ca_name="${ca_prefix}${suffix}"
  local ca_pool_full_name="projects/${project_id}/locations/${region}/caPools/${ca_pool_name}"

  print_status "Ensuring SWP Certificate components for ${CLUSTER_NAME} (Suffix: ${suffix})..."
  report_result "" # Newline

  # 1. CA Pool
  print_status "  Checking CA Pool ${ca_pool_name}..."
  if check_sentinel "${phase_name}" "01_ca_pool_created"; then
    report_result "Exists"
  elif gcloud privateca pools describe "${ca_pool_name}" --location="${region}" --project="${project_id}" > /dev/null 2>&1; then
    report_result "Exists"
    create_sentinel "${phase_name}" "01_ca_pool_created"
  else
    report_result "Not Found"
    print_status "    Creating CA Pool ${ca_pool_name}..."
    if run_gcloud "${log_file}" gcloud privateca pools create "${ca_pool_name}" --location="${region}" --tier=devops --project="${project_id}"; then
      report_result "Created"
      create_sentinel "${phase_name}" "01_ca_pool_created"
      echo "      -> Waiting 60s for CA Pool creation and IAM propagation..."
      sleep 60
      # Grant permissions - these are idempotent so okay to re-run
      local project_number=$(gcloud projects describe "${project_id}" --format="value(projectNumber)")
      local network_security_sa="service-${project_number}@gcp-sa-networksecurity.iam.gserviceaccount.com"
      if ! gcloud beta services identity describe --service=networksecurity.googleapis.com --project="${project_id}" > /dev/null 2>&1; then
          print_status "      Creating Network Security P4SA for ${project_id}..."
          run_gcloud "${log_file}" gcloud beta services identity create --service=networksecurity.googleapis.com --project="${project_id}" && report_result "Pass"
          echo "      -> Waiting 30s for IAM propagation..."
          sleep 30
      fi
      print_status "      Granting privateca.certificateManager role to P4SA on ${ca_pool_name}..."
      run_gcloud "${log_file}" gcloud privateca pools add-iam-policy-binding "${ca_pool_name}" --location="${region}" --project="${project_id}" --member="serviceAccount:${network_security_sa}" --role='roles/privateca.certificateManager' && report_result "Pass"
    else
      report_result "Fail"; return 1;
    fi
  fi

  # 2. Root CA
  print_status "  Checking Root CA ${ca_name} in ${ca_pool_name}..."
  if check_sentinel "${phase_name}" "02_root_ca_created"; then
    report_result "Exists"
  elif gcloud privateca roots describe "${ca_name}" --pool="${ca_pool_name}" --location="${region}" --project="${project_id}" > /dev/null 2>&1; then
    report_result "Exists"
    create_sentinel "${phase_name}" "02_root_ca_created"
  else
    report_result "Not Found"
    print_status "    Creating Root CA ${ca_name}..."
    if run_gcloud "${log_file}" gcloud privateca roots create "${ca_name}" --pool="${ca_pool_name}" --location="${region}" --project="${project_id}" --subject="CN=swp-ca.internal.local, O=Dataproc SWP Test" --auto-enable --quiet; then
      report_result "Created"
      create_sentinel "${phase_name}" "02_root_ca_created"
    else
      report_result "Fail"; return 1;
    fi
  fi

  # 3. CIC
  print_status "  Checking CIC ${cic_name}..."
  if check_sentinel "${phase_name}" "03_cic_created"; then
    report_result "Exists"
  elif gcloud certificate-manager issuance-configs describe "${cic_name}" --location="${region}" --project="${project_id}" > /dev/null 2>&1; then
    report_result "Exists"
    create_sentinel "${phase_name}" "03_cic_created"
  else
    report_result "Not Found"
    print_status "    Creating CIC ${cic_name}..."
    if run_gcloud "${log_file}" gcloud certificate-manager issuance-configs create "${cic_name}" --location="${region}" --project="${project_id}" --ca-pool="${ca_pool_full_name}" --lifetime="2592000s" --rotation-window-percentage=66 --key-algorithm="rsa-2048"; then
      report_result "Created"
      create_sentinel "${phase_name}" "03_cic_created"
    else
      report_result "Fail"; return 1;
    fi
  fi

  # 4. Certificate Manager Certificate (swp-cert)
  print_status "  Checking Certificate Manager Certificate ${cert_name}..."
  local cert_log_file="create_managed_cert_${cert_name}.log"
  local desired_cic="projects/${project_id}/locations/${region}/certificateIssuanceConfigs/${cic_name}"
  if check_sentinel "${phase_name}" "04_cert_created"; then
    report_result "Exists"
  elif gcloud certificate-manager certificates describe "${cert_name}" --location="${region}" --project="${project_id}" > /dev/null 2>&1; then
    local current_cic=$(gcloud certificate-manager certificates describe "${cert_name}" --location="${region}" --project="${project_id}" --format="value(managed.issuanceConfig)")
    if [[ "${current_cic}" == "${desired_cic}" ]]; then
      report_result "Exists"
      create_sentinel "${phase_name}" "04_cert_created"
    else
      report_result "Fail"
      return 1
    fi
  else
    report_result "Not Found"
    print_status "    Creating Certificate ${cert_name}..."
    if run_gcloud "${cert_log_file}" gcloud certificate-manager certificates create "${cert_name}" --location="${region}" --project="${project_id}" --domains="${swp_hostname}" --issuance-config="${desired_cic}"; then
      report_result "Created"
      create_sentinel "${phase_name}" "04_cert_created"
    else
      report_result "Fail"; return 1;
    fi
  fi
  export SWP_CERT_URI_PARTIAL="projects/${project_id}/locations/${region}/certificates/${cert_name}"
}
export -f create_managed_certificate

function _delete_swp_ca_resources() {
  local region="${1:-${REGION}}"
  local project_id="${2:-${PROJECT_ID}}"
  local log_file="${3:-delete_managed_certificate_${CLUSTER_NAME}.log}"

  local cic_prefix="swp-cic-${CLUSTER_NAME}-"
  local pool_prefix="swp-ca-pool-${CLUSTER_NAME}-"
  local ca_prefix="swp-root-ca-${CLUSTER_NAME}-"
  local overall_status="Pass"
  local found_some=false

  # --- Deleting Certificate Issuance Config(s) ---
  local cic_names=$(gcloud certificate-manager issuance-configs list --location="${region}" --project="${project_id}" --format="value(name)" 2>/dev/null | grep "${cic_prefix}" || true)
  if [[ -n "${cic_names}" ]]; then
    found_some=true
    while read -r cic; do
      local short_cic_name=$(basename "${cic}")
      print_status "  Deleting CIC ${short_cic_name}..."
      if ! run_gcloud "${log_file}" gcloud certificate-manager issuance-configs delete "${short_cic_name}" --location="${region}" --project="${project_id}" --quiet; then overall_status="Fail"; report_result "Fail"; else report_result "Deleted"; fi
    done <<< "${cic_names}"
  else
     print_status "  No CICs found with prefix ${cic_prefix}..."
     report_result "Not Found"
  fi

  # --- Deleting CA Pool(s) and Root CA(s) ---
  local pool_names=$(gcloud privateca pools list --location="${region}" --project="${project_id}" --format="value(name)" 2>/dev/null | grep "${pool_prefix}" || true)
  if [[ -n "${pool_names}" ]]; then
    found_some=true
    while read -r pool_full_name; do
      local short_pool_name=$(basename "${pool_full_name}")
      print_status "  Deleting CA Pool ${short_pool_name}..."
      local ca_names=$(gcloud privateca roots list --pool="${short_pool_name}" --location="${region}" --project="${project_id}" --format="value(name)" 2>/dev/null | grep "${ca_prefix}" || true)
      if [[ -n "${ca_names}" ]]; then
        while read -r ca_full_name; do
          local short_ca_name=$(basename "${ca_full_name}")
          local ca_log_file="delete_ca_${short_ca_name}.log"
          print_status "    Disabling CA ${short_ca_name}..."
          if run_gcloud "${ca_log_file}" gcloud privateca roots disable "${short_ca_name}" --pool="${short_pool_name}" --location="${region}" --project="${project_id}" --quiet; then
            report_result "Pass"
            print_status "    Deleting CA ${short_ca_name}..."
            if ! run_gcloud "${ca_log_file}" gcloud privateca roots delete "${short_ca_name}" --pool="${short_pool_name}" --location="${region}" --project="${project_id}" --quiet --skip-grace-period; then
              report_result "Fail"
              overall_status="Fail"
            else
              report_result "Deleted"
            fi
          else
            report_result "Fail" # Disable failed
            overall_status="Fail"
          fi
        done <<< "${ca_names}"
      fi
      print_status "  Attempting to delete CA Pool ${short_pool_name}..."
      if ! run_gcloud "${log_file}" gcloud privateca pools delete "${short_pool_name}" --location="${region}" --project="${project_id}" --quiet --ignore-dependent-resources; then overall_status="Fail"; report_result "Fail"; else report_result "Deleted"; fi
    done <<< "${pool_names}"
  else
     print_status "  No CA Pools found with prefix ${pool_prefix}..."
     report_result "Not Found"
  fi
  return $([[ "${overall_status}" == "Pass" ]] && echo 0 || echo 1)
}
export -f _delete_swp_ca_resources

function delete_managed_certificate() {
  local region="${1:-${REGION}}"
  local project_id="${2:-${PROJECT_ID}}"
  local phase_name="swp_managed_cert"
  local log_file="delete_managed_certificate_${CLUSTER_NAME}.log"

  print_status "Deleting SWP Certificate components for ${CLUSTER_NAME}..."
  report_result "" # Newline

  # Clear all sentinels for this cluster and phase, regardless of suffix
  if [[ -d "${SENTINEL_DIR}" ]]; then
    find "${SENTINEL_DIR}" -type f -name "${phase_name}-*" -exec rm -f {} + > /dev/null 2>&1
    print_status "  Cleared sentinels for ${phase_name}..."
    report_result "Pass"
  fi

  # --- Deleting the static-named Certificate Manager Certificate ---
  local static_cert_name="swp-cert"
  print_status "  Checking for static certificate ${static_cert_name}..."
  local cert_check=$(gcloud certificate-manager certificates list --location="${region}" --project="${project_id}" --filter="name='projects/${project_id}/locations/${region}/certificates/${static_cert_name}'" --format="value(name)" 2>/dev/null)

  if [[ -n "${cert_check}" ]]; then
    print_status "  Deleting static certificate ${static_cert_name}..."
    if ! run_gcloud "${log_file}" gcloud certificate-manager certificates delete "${static_cert_name}" --location="${region}" --project="${project_id}" --quiet; then
      report_result "Fail";
    else
      report_result "Deleted";
    fi
  else
    report_result "Not Found"
  fi

  if [[ "${FORCE_DELETE}" == "true" ]]; then
    print_status "  --force specified, deleting versioned CA/CIC components..."
    report_result ""
    _delete_swp_ca_resources "${region}" "${project_id}" "${log_file}"
  else
    print_status "  Skipping deletion of versioned CA/CIC components. Use --force to delete."
    report_result "Skipped"
  fi
}
export -f delete_managed_certificate

function create_certificate() {
  local cert_name="${1:-${SWP_CERT_NAME}}"
  local region="${2:-${REGION}}"
  local project_id="${3:-${PROJECT_ID}}"
  local swp_ip="${4:-${SWP_IP}}"
  local swp_hostname="${5:-${SWP_HOSTNAME}}"

  local ca_key_file="tls/swp_ca.key"
  local ca_cert_file="tls/swp_ca.crt"
  local server_key_file="tls/swp.key"
  local server_csr_file="tls/swp.csr"
  local server_cert_file="tls/swp.crt"
  local gcs_ca_cert_uri="${INIT_ACTIONS_ROOT}/swp_ca.crt"

  # ... (rest of create_certificate) ...
}

function delete_certificate() {
  local cert_name="${1:-${SWP_CERT_NAME}}"
  local region="${2:-${REGION}}"

  print_status "Deleting Self-Signed Certificate ${cert_name}..."
  if gcloud certificate-manager certificates describe "${cert_name}" --location="${region}" --project="${project_id}" > /dev/null 2>&1; then
    local log_file="delete_certificate_${cert_name}.log"
    if run_gcloud "${log_file}" gcloud certificate-manager certificates delete "${cert_name}" --location="${region}" --quiet; then
      report_result "Deleted"
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
  fi
}

function delete_ca_pool() {
  local pool_name="${1:-swp-ca-pool-${CLUSTER_NAME}}"
  local region="${2:-${REGION}}"
  local project_id="${3:-${PROJECT_ID}}"
  local ca_name="swp-root-ca-${CLUSTER_NAME}"
  local log_file="delete_ca_pool_${pool_name}.log"

  print_status "Deleting CA Pool ${pool_name}..."
  if gcloud privateca pools describe "${pool_name}" --location="${region}" --project="${project_id}" > /dev/null 2>&1; then
    if gcloud privateca roots describe "${ca_name}" --pool="${pool_name}" --location="${region}" --project="${project_id}" > /dev/null 2>&1; then
      run_gcloud "${log_file}" gcloud privateca roots disable "${ca_name}" --pool="${pool_name}" --location="${region}" --project="${project_id}" --quiet
      run_gcloud "${log_file}" gcloud privateca roots delete "${ca_name}" --pool="${pool_name}" --location="${region}" --project="${project_id}" --quiet --skip-grace-period
    fi
    if run_gcloud "${log_file}" gcloud privateca pools delete "${pool_name}" --location="${region}" --project="${project_id}" --quiet; then
      report_result "Deleted"
    else
      report_result "Fail"
    fi
  else
    report_result "Not Found"
  fi
}