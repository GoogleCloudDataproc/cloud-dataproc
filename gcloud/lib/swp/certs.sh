#!/bin/bash

function create_managed_certificate() {
  local cert_name="${SWP_CERT_NAME}" # Use unique name
  local region="${1:-${REGION}}"
  local project_id="${2:-${PROJECT_ID}}"
  local swp_hostname="${3:-${SWP_HOSTNAME}}"
  local log_file="swp_managed_cert_${CLUSTER_NAME}-${RESOURCE_SUFFIX}.log"
  local suffix="${RESOURCE_SUFFIX}"
  local ca_pool_name="swp-ca-pool-${CLUSTER_NAME}-${suffix}"
  local cic_name="swp-cic-${CLUSTER_NAME}-${suffix}"
  local ca_name="swp-root-ca-${CLUSTER_NAME}-${suffix}"
  local ca_pool_full_name="projects/${project_id}/locations/${region}/caPools/${ca_pool_name}"

  print_status "Creating SWP Certificate components for ${CLUSTER_NAME} (Suffix: ${suffix})..."
  report_result "" 

  print_status "  Creating CA Pool ${ca_pool_name}..."
  if run_gcloud "${log_file}" gcloud privateca pools create "${ca_pool_name}" --location="${region}" --tier=devops --project="${project_id}"; then
    report_result "Created"
    echo "      -> Waiting 60s for CA Pool creation and IAM propagation..."
    sleep 60
    local project_number=$(gcloud projects describe "${project_id}" --format="value(projectNumber)")
    local network_security_sa="service-${project_number}@gcp-sa-networksecurity.iam.gserviceaccount.com"
    if ! gcloud beta services identity describe --service=networksecurity.googleapis.com --project="${project_id}" > /dev/null 2>&1; then
        print_status "      Creating Network Security P4SA for ${project_id}..."
        run_gcloud "${log_file}" gcloud beta services identity create --service=networksecurity.googleapis.com --project="${project_id}" && report_result "Pass"
        echo "      -> Waiting 30s for IAM propagation..."
        sleep 30
    fi
    print_status "      Granting privateca.certificateManager role to P4SA on ${ca_pool_name}..."
    run_gcloud "${log_file}" gcloud privateca pools add-iam-policy-binding "${ca_pool_name}" \
      --location="${region}" \
      --project="${project_id}" \
      --member="serviceAccount:${network_security_sa}" \
      --role='roles/privateca.certificateManager' && report_result "Pass"
  else
    report_result "Fail"; return 1;
  fi

  print_status "  Creating Root CA ${ca_name} in ${ca_pool_name}..."
  if run_gcloud "${log_file}" gcloud privateca roots create "${ca_name}" --pool="${ca_pool_name}" \
    --location="${region}" \
    --project="${project_id}" \
    --subject="CN=swp-ca.internal.local, O=Dataproc SWP Test" --auto-enable --quiet; then
    report_result "Created"
  else
    report_result "Fail"; return 1;
  fi

  print_status "  Creating CIC ${cic_name}..."
  if run_gcloud "${log_file}" gcloud certificate-manager issuance-configs create "${cic_name}" \
    --location="${region}" \
    --project="${project_id}" \
    --ca-pool="${ca_pool_full_name}" \
    --lifetime="2592000s" \
    --rotation-window-percentage=66 \
    --key-algorithm="rsa-2048"; then
    report_result "Created"
  else
    report_result "Fail"; return 1;
  fi

  print_status "  Creating Certificate Manager Certificate ${cert_name}..."
  local cert_log_file="create_managed_cert_${cert_name}.log"
  local desired_cic="projects/${project_id}/locations/${region}/certificateIssuanceConfigs/${cic_name}"
  if run_gcloud "${cert_log_file}" gcloud certificate-manager certificates create "${cert_name}" \
    --location="${region}" \
    --project="${project_id}" \
    --domains="${swp_hostname}" \
    --issuance-config="${desired_cic}"; then
    report_result "Created"
  else
    report_result "Fail"; return 1;
  fi
  export SWP_CERT_URI_PARTIAL="projects/${project_id}/locations/${region}/certificates/${cert_name}"
}
export -f create_managed_certificate

function delete_managed_certificate() {
  local region="${1:-${REGION}}"
  local project_id="${2:-${PROJECT_ID}}"
  local log_file="delete_managed_certificate_${CLUSTER_NAME}.log"
  local cic_prefix="swp-cic-${CLUSTER_NAME}-"
  local pool_prefix="swp-ca-pool-${CLUSTER_NAME}-"
  local ca_prefix="swp-root-ca-${CLUSTER_NAME}-"
  local cert_prefix="swp-cert-${CLUSTER_NAME}-"

  print_status "Deleting SWP Certificate components for ${CLUSTER_NAME}..."
  report_result ""

  local cert_names=$(gcloud certificate-manager certificates list --location="${region}" --project="${project_id}" --filter="name ~ /${cert_prefix}" --format="value(name)" 2>/dev/null)
  if [[ -n "${cert_names}" ]]; then
    while read -r cert_full_name; do
      local short_cert_name=$(basename "${cert_full_name}")
      print_status "  Deleting versioned certificate ${short_cert_name}..."
      if ! run_gcloud "delete_managed_cert_${short_cert_name}.log" gcloud certificate-manager certificates delete "${short_cert_name}" --location="${region}" --project="${project_id}" --quiet; then
        report_result "Fail";
      else
        report_result "Deleted";
      fi
    done <<< "${cert_names}"
  fi

  local cic_names=$(gcloud certificate-manager issuance-configs list --location="${region}" --project="${project_id}" --format="value(name)" 2>/dev/null | grep "${cic_prefix}" || true)
  if [[ -n "${cic_names}" ]]; then
    while read -r cic; do
      local short_cic_name=$(basename "${cic}")
      print_status "  Deleting CIC ${short_cic_name}..."
      run_gcloud "${log_file}" gcloud certificate-manager issuance-configs delete "${short_cic_name}" --location="${region}" --project="${project_id}" --quiet || true
    done <<< "${cic_names}"
  fi

  local pool_names=$(gcloud privateca pools list --location="${region}" --project="${project_id}" --format="value(name)" 2>/dev/null | grep "${pool_prefix}" || true)
  if [[ -n "${pool_names}" ]]; then
    while read -r pool_full_name; do
      local short_pool_name=$(basename "${pool_full_name}")
      local ca_names=$(gcloud privateca roots list --pool="${short_pool_name}" --location="${region}" --project="${project_id}" --format="value(name)" 2>/dev/null | grep "${ca_prefix}" || true)
      if [[ -n "${ca_names}" ]]; then
        while read -r ca_full_name; do
          local short_ca_name=$(basename "${ca_full_name}")
          local ca_log_file="delete_ca_${short_ca_name}.log"
          print_status "    Disabling and Deleting CA ${short_ca_name}..."
          run_gcloud "${ca_log_file}" gcloud privateca roots disable "${short_ca_name}" --pool="${short_pool_name}" --location="${region}" --project="${project_id}" --quiet || true
          run_gcloud "${ca_log_file}" gcloud privateca roots delete "${short_ca_name}" --pool="${short_pool_name}" --location="${region}" --project="${project_id}" --quiet --skip-grace-period || true
        done <<< "${ca_names}"
      fi
      print_status "  Attempting to delete CA Pool ${short_pool_name}..."
      run_gcloud "${log_file}" gcloud privateca pools delete "${short_pool_name}" --location="${region}" --project="${project_id}" --quiet --ignore-dependent-resources || true
    done <<< "${pool_names}"
  fi
}
export -f delete_managed_certificate

function exists_swp_ca_pool() {
  local region="${1:-${REGION}}"
  local project_id="${2:-${PROJECT_ID}}"
  local suffix="${3:-${RESOURCE_SUFFIX}}"
  local ca_pool_name="swp-ca-pool-${CLUSTER_NAME}-${suffix}"
  _check_exists "gcloud privateca pools describe '${ca_pool_name}' --location='${region}' --project='${project_id}' --format='json(name,tier)'"
}
export -f exists_swp_ca_pool

function exists_swp_root_ca() {
  local region="${1:-${REGION}}"
  local project_id="${2:-${PROJECT_ID}}"
  local suffix="${3:-${RESOURCE_SUFFIX}}"
  local ca_pool_name="swp-ca-pool-${CLUSTER_NAME}-${suffix}"
  local ca_name="swp-root-ca-${CLUSTER_NAME}-${suffix}"
  _check_exists "gcloud privateca roots describe '${ca_name}' --pool='${ca_pool_name}' --location='${region}' --project='${project_id}' --format='json(name,state)'"
}
export -f exists_swp_root_ca

function exists_swp_cic() {
  local region="${1:-${REGION}}"
  local project_id="${2:-${PROJECT_ID}}"
  local suffix="${3:-${RESOURCE_SUFFIX}}"
  local cic_name="swp-cic-${CLUSTER_NAME}-${suffix}"
  _check_exists "gcloud certificate-manager issuance-configs describe '${cic_name}' --location='${region}' --project='${project_id}' --format='json(name)'"
}
export -f exists_swp_cic

function exists_swp_managed_certificate() {
  local region="${1:-${REGION}}"
  local project_id="${2:-${PROJECT_ID}}"
  local cert_name="${SWP_CERT_NAME}"
  _check_exists gcloud certificate-manager certificates describe "${cert_name}" --location="${region}" --project="${project_id}" --format="json(name,managed.state)"
}
export -f exists_swp_managed_certificate