#!/bin/bash

function create_managed_certificate() {
  local region="${1:-${REGION}}"
  local project_id="${2:-${PROJECT_ID}}"
  local swp_hostname="${3:-${SWP_HOSTNAME}}"
  local cert_name="swp-cert-${CLUSTER_NAME}-${TIMESTAMP}"
  local ca_pool_name="swp-ca-pool-${CLUSTER_NAME}-${TIMESTAMP}"
  local cic_name="swp-cic-${CLUSTER_NAME}-${TIMESTAMP}"
  local ca_name="swp-root-ca-${CLUSTER_NAME}-${TIMESTAMP}"
  local ca_pool_full_name="projects/${project_id}/locations/${region}/caPools/${ca_pool_name}"
  local log_file="swp_managed_cert_${CLUSTER_NAME}.log"

  print_status "Creating SWP Certificate components for ${CLUSTER_NAME}..."
  report_result ""

  print_status "  Creating CA Pool ${ca_pool_name}..."
  local pool_cmd=(
    gcloud privateca pools create "${ca_pool_name}"
    --location="${region}"
    --tier=devops
    --project="${project_id}"
  )
  if run_gcloud "${log_file}" "${pool_cmd[@]}"; then
    report_result "Created"
    refresh_resource_state "swpCaPool" "lib/swp/certs.sh" exists_swp_ca_pool
    echo "      -> Waiting 60s for CA Pool creation and IAM propagation..."
    sleep 60
    local project_number=$(gcloud projects describe "${project_id}" --format="value(projectNumber)")
    local network_security_sa="service-${project_number}@gcp-sa-networksecurity.iam.gserviceaccount.com"
    if ! gcloud beta services identity describe --service=networksecurity.googleapis.com --project="${project_id}" > /dev/null 2>&1; then
        print_status "      Creating Network Security P4SA for ${project_id}..."
        local p4sa_cmd=(gcloud beta services identity create --service=networksecurity.googleapis.com --project="${project_id}")
        run_gcloud "${log_file}" "${p4sa_cmd[@]}" && report_result "Pass"
        echo "      -> Waiting 30s for IAM propagation..."
        sleep 30
    fi
    print_status "      Granting privateca.certificateManager role to P4SA on ${ca_pool_name}..."
    local iam_cmd=(
      gcloud privateca pools add-iam-policy-binding "${ca_pool_name}"
      --location="${region}"
      --project="${project_id}"
      --member="serviceAccount:${network_security_sa}"
      --role='roles/privateca.certificateManager'
    )
    run_gcloud "${log_file}" "${iam_cmd[@]}" && report_result "Pass"
  else
    report_result "Fail"; return 1;
  fi

  print_status "  Creating Root CA ${ca_name} in ${ca_pool_name}..."
  local ca_cmd=(
    gcloud privateca roots create "${ca_name}" --pool="${ca_pool_name}"
    --location="${region}"
    --project="${project_id}"
    --subject="CN=swp-ca.internal.local, O=Dataproc SWP Test" --auto-enable --quiet
  )
  if run_gcloud "${log_file}" "${ca_cmd[@]}"; then
    report_result "Created"
    refresh_resource_state "swpRootCa" "lib/swp/certs.sh" exists_swp_root_ca
  else
    report_result "Fail"; return 1;
  fi

  print_status "  Creating CIC ${cic_name}..."
  local cic_cmd=(
    gcloud certificate-manager issuance-configs create "${cic_name}"
    --location="${region}"
    --project="${project_id}"
    --ca-pool="${ca_pool_full_name}"
    --lifetime="2592000s"
    --rotation-window-percentage=66
    --key-algorithm="rsa-2048"
  )
  if run_gcloud "${log_file}" "${cic_cmd[@]}"; then
    report_result "Created"
    refresh_resource_state "swpCic" "lib/swp/certs.sh" exists_swp_cic
  else
    report_result "Fail"; return 1;
  fi

  print_status "  Creating Certificate Manager Certificate ${cert_name}..."
  local cert_log_file="create_managed_cert_${cert_name}.log"
  local desired_cic="projects/${project_id}/locations/${region}/certificateIssuanceConfigs/${cic_name}"
  local cert_cmd=(
    gcloud certificate-manager certificates create "${cert_name}"
    --location="${region}"
    --project="${project_id}"
    --domains="${swp_hostname}"
    --issuance-config="${desired_cic}"
  )
  if run_gcloud "${cert_log_file}" "${cert_cmd[@]}"; then
    report_result "Created"
    refresh_resource_state "swpManagedCertificate" "lib/swp/certs.sh" exists_swp_managed_certificate
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
  local cert_name="swp-cert-${CLUSTER_NAME}-${TIMESTAMP}"
  local cic_name="swp-cic-${CLUSTER_NAME}-${TIMESTAMP}"
  local ca_pool_name="swp-ca-pool-${CLUSTER_NAME}-${TIMESTAMP}"
  local ca_name="swp-root-ca-${CLUSTER_NAME}-${TIMESTAMP}"

  print_status "Deleting SWP Certificate components for ${CLUSTER_NAME}-${TIMESTAMP}..."
  report_result ""

  print_status "  Deleting versioned certificate ${cert_name}..."
  local del_cert_cmd=(gcloud certificate-manager certificates delete "${cert_name}" --location="${region}" --project="${project_id}" --quiet)
  if ! run_gcloud "delete_managed_cert_${cert_name}.log" "${del_cert_cmd[@]}"; then
    report_result "Fail";
  else
    report_result "Deleted";
  fi

  print_status "  Deleting CIC ${cic_name}..."
  local del_cic_cmd=(gcloud certificate-manager issuance-configs delete "${cic_name}" --location="${region}" --project="${project_id}" --quiet)
  run_gcloud "${log_file}" "${del_cic_cmd[@]}" || true

  print_status "    Disabling and Deleting CA ${ca_name}..."
  local disable_ca_cmd=(gcloud privateca roots disable "${ca_name}" --pool="${ca_pool_name}" --location="${region}" --project="${project_id}" --quiet)
  run_gcloud "delete_ca_${ca_name}.log" "${disable_ca_cmd[@]}" || true
  local delete_ca_cmd=(gcloud privateca roots delete "${ca_name}" --pool="${ca_pool_name}" --location="${region}" --project="${project_id}" --quiet --skip-grace-period)
  run_gcloud "delete_ca_${ca_name}.log" "${delete_ca_cmd[@]}" || true

  print_status "  Attempting to delete CA Pool ${ca_pool_name}..."
  local del_pool_cmd=(gcloud privateca pools delete "${ca_pool_name}" --location="${region}" --project="${project_id}" --quiet --ignore-dependent-resources)
  run_gcloud "${log_file}" "${del_pool_cmd[@]}" || true
}
export -f delete_managed_certificate

function exists_swp_ca_pool() {
  local region="${1:-${REGION}}"
  local project_id="${2:-${PROJECT_ID}}"
  local ca_pool_prefix="swp-ca-pool-${CLUSTER_NAME}-"
  # List all CA pools in the location and filter for those starting with the prefix
  gcloud privateca pools list --location="${region}" --project="${project_id}" --format="json(name,tier)" \
    | jq --arg prefix "${ca_pool_prefix}" 'if type == "array" then map(select(.name | split("/") | last | startswith($prefix))) | if length > 0 then .[0] else null end else null end'
}
export -f exists_swp_ca_pool

function exists_swp_root_ca() {
  local region="${1:-${REGION}}"
  local project_id="${2:-${PROJECT_ID}}"
  # We first need to find the CA pool since the root CA is nested within it
  local ca_pool_json=$(exists_swp_ca_pool "${region}" "${project_id}")
  if [[ "${ca_pool_json}" == "null" || -z "${ca_pool_json}" ]]; then
    echo "null"
    return 1
  fi
  local ca_pool_name=$(echo "${ca_pool_json}" | jq -r '.name | split("/") | last')
  local ca_prefix="swp-root-ca-${CLUSTER_NAME}-"

  # List all roots in the discovered pool
  gcloud privateca roots list --pool="${ca_pool_name}" --location="${region}" --project="${project_id}" --format="json(name,state)" \
    | jq --arg prefix "${ca_prefix}" 'if type == "array" then map(select(.name | split("/") | last | startswith($prefix))) | if length > 0 then .[0] else null end else null end'
}
export -f exists_swp_root_ca

function exists_swp_cic() {
  local region="${1:-${REGION}}"
  local project_id="${2:-${PROJECT_ID}}"
  local cic_prefix="swp-cic-${CLUSTER_NAME}-"
  # List issuance configs and filter
  gcloud certificate-manager issuance-configs list --location="${region}" --project="${project_id}" --format="json(name)" \
    | jq --arg prefix "${cic_prefix}" 'if type == "array" then map(select(.name | split("/") | last | startswith($prefix))) | if length > 0 then .[0] else null end else null end'
}
export -f exists_swp_cic

function exists_swp_managed_certificate() {
  local region="${1:-${REGION}}"
  local project_id="${2:-${PROJECT_ID}}"
  local cert_prefix="swp-cert-${CLUSTER_NAME}-"
  # List certificates and filter
  gcloud certificate-manager certificates list --location="${region}" --project="${project_id}" --format="json(name,managed.state)" \
    | jq --arg prefix "${cert_prefix}" 'if type == "array" then map(select(.name | split("/") | last | startswith($prefix))) | if length > 0 then .[0] else null end else null end'
}
export -f exists_swp_managed_certificate
