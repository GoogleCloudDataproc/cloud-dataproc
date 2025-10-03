export SWP_POLICY_NAME="swp-policy-${CLUSTER_NAME}"
export SWP_POLICY_URI_PARTIAL="projects/${PROJECT_ID}/locations/${REGION}/gatewaySecurityPolicies/${SWP_POLICY_NAME}"
export SWP_POLICY_URI="https://www.googleapis.com/compute/v1/${SWP_POLICY_URI_PARTIAL}"

export SWP_CERTIFICATE="tls/swp.crt"
export SWP_KEY="tls/swp.key"

export SWP_CERT_NAME="swp-cert"
export SWP_CERT_URI_PARTIAL="projects/${PROJECT_ID}/locations/${REGION}/certificates/${SWP_CERT_NAME}"
export SWP_CERT_URI="https://www.googleapis.com/compute/v1/${SWP_CERT_URI_PARTIAL}"

export SWP_INSTANCE_NAME="swp-${CLUSTER_NAME}"

export SWP_RANGE="$(jq -r .SWP_RANGE env.json)"
export SWP_HOSTNAME="$(jq -r .SWP_HOSTNAME env.json)"
export SWP_IP="$(jq -r .SWP_IP env.json)"
export SWP_PORT="$(jq -r .SWP_PORT env.json)"

export SWP_SUBNET="swp-subnet-${CLUSTER_NAME}"
export SWP_SUBNET_URI_PARTIAL="projects/${PROJECT_ID}/regions/${REGION}/subnetworks/${SWP_SUBNET}"
export SWP_SUBNET_URI="https://www.googleapis.com/compute/v1/${SWP_SUBNET_URI_PARTIAL}"

export PRIVATE_RANGE="$(jq -r .PRIVATE_RANGE env.json)"
export PRIVATE_SUBNET="private-subnet-${CLUSTER_NAME}"
export PRIVATE_SUBNET_URI_PARTIAL="projects/${PROJECT_ID}/regions/${REGION}/subnetworks/${PRIVATE_SUBNET}"
export PRIVATE_SUBNET_URI="https://www.googleapis.com/compute/v1/${PRIVATE_SUBNET_URI_PARTIAL}"

# Usage: create_gateway_security_policy <policy_name> <region> [project_id]
function create_gateway_security_policy() {
  set -x
  local policy_name="${1:-${SWP_POLICY_NAME}}"
  local region="${2:-${REGION}}"
  local project_id="${3:-${PROJECT_ID}}"
  local rule_name="allow-all-rule"
  local policy_full_name="projects/${project_id}/locations/${region}/gatewaySecurityPolicies/${policy_name}"

  # 1. Create the Gateway Security Policy via import if it doesn't exist
  if ! gcloud network-security gateway-security-policies describe "${policy_name}" --location="${region}" &>/dev/null; then
    echo "Creating Gateway Security Policy: ${policy_name} in region ${region}"
    policy_yaml=$(cat << EOF
name: ${policy_full_name}
description: "Allow all policy for SWP"
EOF
    )
    echo "${policy_yaml}" | gcloud network-security gateway-security-policies import "${policy_name}" \
      --location="${region}" \
      --source=-
    echo "Gateway Security Policy '${policy_name}' creation process initiated."
  else
    echo "Gateway Security Policy '${policy_name}' already exists in region ${region}."
  fi

  # 2. Create the "allow-all" rule via import if it doesn't exist
  if ! gcloud network-security gateway-security-policies rules describe "${rule_name}" --gateway-security-policy="${policy_name}" --location="${region}" &>/dev/null; then
    echo "Creating allow-all rule in policy: ${policy_name}"
    rule_yaml=$(cat << EOF
name: ${policy_full_name}/rules/${rule_name}
description: "Allow all traffic"
priority: 1000
enabled: true
basicProfile: ALLOW
sessionMatcher: "host() != 'none'"
EOF
    )
    # sessionMatcher: "true" # This should also work for allow-all

    echo "${rule_yaml}" | gcloud network-security gateway-security-policies rules import "${rule_name}" \
      --gateway-security-policy="${policy_name}" \
      --location="${region}" \
      --source=-
    echo "Rule '${rule_name}' creation process initiated."
  else
    echo "Rule '${rule_name}' already exists in policy '${policy_name}'."
  fi

  # Return the full URL
  echo "${policy_full_name}"
  set +x
}

# Usage: delete_gateway_security_policy <policy_name> <region>
function delete_gateway_security_policy() {
  local policy_name="${1:-${SWP_POLICY_NAME}}"
  local region="${2:-${REGION}}"
  local project_id="${3:-${PROJECT_ID}}"
  local rule_name="allow-all-rule"

  # Delete the rule first
  if gcloud network-security gateway-security-policies rules describe "${rule_name}" --gateway-security-policy="${policy_name}" --location="${region}" &>/dev/null; then
    echo "Deleting rule '${rule_name}' from policy '${policy_name}'"
    gcloud network-security gateway-security-policies rules delete "${rule_name}" \
      --gateway-security-policy="${policy_name}" \
      --location="${region}" \
      --quiet
  fi

  # Delete the policy
  if gcloud network-security gateway-security-policies describe "${policy_name}" --location="${region}" &>/dev/null; then
    echo "Deleting Gateway Security Policy: ${policy_name} in region ${region}"
    gcloud network-security gateway-security-policies delete "${policy_name}" \
      --location="${region}" \
      --quiet
    echo "Gateway Security Policy '${policy_name}' deleted."
  else
    echo "Gateway Security Policy '${policy_name}' not found in region ${region}."
  fi
}

function create_ca_pool() {
  local pool_name="${1:-swp-ca-pool-${CLUSTER_NAME}}"
  local region="${2:-${REGION}}"
  local project_id="${3:-${PROJECT_ID}}"

  if ! gcloud privateca pools describe "${pool_name}" --location="${region}" --project="${project_id}" &>/dev/null; then
    echo "Creating CA Pool: ${pool_name}"
    gcloud privateca pools create "${pool_name}" \
      --location="${region}" \
      --tier=devops \
      --project="${project_id}"

    # Grant the Network Security service account permission to use the CA pool
    local project_number=$(gcloud projects describe "${project_id}" --format="value(projectNumber)")
    local network_security_sa="service-${project_number}@gcp-sa-networksecurity.iam.gserviceaccount.com"

    echo "Granting privateca.certificateManager role to ${network_security_sa} on CA Pool ${pool_name}"
    gcloud privateca pools add-iam-policy-binding "${pool_name}" \
      --location="${region}" \
      --project="${project_id}" \
      --member="serviceAccount:${network_security_sa}" \
      --role='roles/privateca.certificateManager'

    # Create a Root CA in the pool
    local ca_name="swp-root-ca-${CLUSTER_NAME}"
    echo "Creating Root CA: ${ca_name} in pool ${pool_name}"
    gcloud privateca roots create "${ca_name}" \
      --pool="${pool_name}" \
      --location="${region}" \
      --project="${project_id}" \
      --subject="CN=swp-ca.internal.local, O=Dataproc SWP Test" \
      --auto-enable
  else
    echo "CA Pool '${pool_name}' already exists."
  fi
}

function delete_ca_pool() {
  local pool_name="${1:-swp-ca-pool-${CLUSTER_NAME}}"
  local region="${2:-${REGION}}"
  local project_id="${3:-${PROJECT_ID}}"
  local ca_name="swp-root-ca-${CLUSTER_NAME}"

  if gcloud privateca roots describe "${ca_name}" --pool="${pool_name}" --location="${region}" --project="${project_id}" &>/dev/null; then
    echo "Disabling CA ${ca_name}"
    gcloud privateca roots disable "${ca_name}" --pool="${pool_name}" --location="${region}" --project="${project_id}" --quiet
    echo "Deleting CA ${ca_name}"
    gcloud privateca roots delete "${ca_name}" --pool="${pool_name}" --location="${region}" --project="${project_id}" --quiet --skip-grace-period
  fi

  if gcloud privateca pools describe "${pool_name}" --location="${region}" --project="${project_id}" &>/dev/null; then
    echo "Deleting CA Pool: ${pool_name}"
    gcloud privateca pools delete "${pool_name}" --location="${region}" --project="${project_id}" --quiet
  fi
}

# Usage: create_managed_certificate [cert_name] [region] [project_id] [swp_hostname]
function create_managed_certificate() {
  local cert_name="${1:-${SWP_CERT_NAME}}"
  local region="${2:-${REGION}}"
  local project_id="${3:-${PROJECT_ID}}"
  local swp_hostname="${4:-${SWP_HOSTNAME}}"
  local pool_suffix="$(date +%s)"
  local ca_pool_name="swp-ca-pool-${CLUSTER_NAME}-${pool_suffix}"
  local ca_pool_full_name="projects/${project_id}/locations/${region}/caPools/${ca_pool_name}"
  local cic_name="swp-cic-${CLUSTER_NAME}-${pool_suffix}"
  local ca_name="swp-root-ca-${CLUSTER_NAME}-${pool_suffix}"
  local project_number=$(gcloud projects describe "${project_id}" --format="value(projectNumber)")
  local network_security_sa="service-${project_number}@gcp-sa-networksecurity.iam.gserviceaccount.com"

  echo "--- Ensuring CA Pool and Root CA exist ---"
  if ! gcloud privateca pools describe "${ca_pool_name}" --location="${region}" --project="${project_id}" &>/dev/null; then
    echo "Creating CA Pool: ${ca_pool_name}"
    gcloud privateca pools create "${ca_pool_name}" \
      --location="${region}" \
      --tier=devops \
      --project="${project_id}"

    echo "Waiting 60s for CA Pool creation and IAM propagation..."
    sleep 60

    if ! gcloud beta services identity describe --service=networksecurity.googleapis.com --project="${project_id}" &>/dev/null; then
        echo "Creating Network Security P4SA for ${project_id}"
        gcloud beta services identity create --service=networksecurity.googleapis.com --project="${project_id}"
        echo "Waiting 30s for IAM propagation..."
        sleep 30
    fi

    echo "Granting privateca.certificateManager role to ${network_security_sa} on CA Pool ${ca_pool_name}"
    gcloud privateca pools add-iam-policy-binding "${ca_pool_name}" \
      --location="${region}" \
      --project="${project_id}" \
      --member="serviceAccount:${network_security_sa}" \
      --role='roles/privateca.certificateManager'

    echo "Creating Root CA: ${ca_name} in pool ${ca_pool_name}"
    gcloud privateca roots create "${ca_name}" \
      --pool="${ca_pool_name}" \
      --location="${region}" \
      --project="${project_id}" \
      --subject="CN=swp-ca.internal.local, O=Dataproc SWP Test" \
      --auto-enable
  else
    echo "CA Pool '${ca_pool_name}' already exists."
  fi

  echo "--- Ensuring Certificate Issuance Config exists ---"
  if ! gcloud certificate-manager issuance-configs describe "${cic_name}" --location="${region}" --project="${project_id}" &>/dev/null; then
    echo "Creating Certificate Issuance Config: ${cic_name}"
    gcloud certificate-manager issuance-configs create "${cic_name}" \
      --location="${region}" \
      --project="${project_id}" \
      --ca-pool="${ca_pool_full_name}" \
      --lifetime="2592000s" \
      --rotation-window-percentage=66 \
      --key-algorithm="rsa-2048"
  else
    echo "Certificate Issuance Config '${cic_name}' already exists."
  fi

  echo "--- Ensuring Certificate Manager Certificate exists ---"
  set -x
  if ! gcloud certificate-manager certificates describe "${cert_name}" --location="${region}" --project="${project_id}" &>/dev/null; then
    echo "Creating Google-managed Certificate: ${cert_name} in region ${region} for Domain ${swp_hostname}"
    gcloud certificate-manager certificates create "${cert_name}" \
      --location="${region}" \
      --project="${project_id}" \
      --domains="${swp_hostname}" \
      --issuance-config="projects/${project_id}/locations/${region}/certificateIssuanceConfigs/${cic_name}"
    echo "Certificate '${cert_name}' creation process initiated. This may take several minutes to become active."
  else
    echo "Certificate Manager Certificate '${cert_name}' already exists in region ${region}."
  fi
  set +x
  # Return the full URL
  echo "projects/${project_id}/locations/${region}/certificates/${cert_name}"
}

function delete_managed_certificate() {
  local cert_name="${1:-${SWP_CERT_NAME}}"
  local region="${2:-${REGION}}"
  local project_id="${3:-${PROJECT_ID}}"
  local cic_prefix="swp-cic-${CLUSTER_NAME}-"
  local pool_prefix="swp-ca-pool-${CLUSTER_NAME}-"
  local ca_prefix="swp-root-ca-${CLUSTER_NAME}-"

  echo "--- Deleting Certificate Manager Certificate ---"
  if gcloud certificate-manager certificates describe "${cert_name}" --location="${region}" --project="${project_id}" &>/dev/null; then
    echo "Deleting Certificate Manager Certificate: ${cert_name}"
    gcloud certificate-manager certificates delete "${cert_name}" --location="${region}" --project="${project_id}" --quiet
  else
    echo "Certificate Manager Certificate '${cert_name}' not found."
  fi

  echo "--- Deleting Certificate Issuance Config(s) ---"
  local cic_names=$(gcloud certificate-manager issuance-configs list --location="${region}" --project="${project_id}" --filter="name~/${cic_prefix}" --format="value(name)")
  if [[ -z "${cic_names}" ]]; then
    echo "No Certificate Issuance Configs found with prefix '${cic_prefix}'."
  else
    local count=$(echo "${cic_names}" | wc -l)
    if [[ ${count} -gt 1 ]]; then
      echo "WARNING: Found multiple (${count}) Certificate Issuance Configs with prefix '${cic_prefix}'. Deleting all:"
      echo "${cic_names}"
    fi
    for cic in ${cic_names}; do
      local short_cic_name=$(basename "${cic}")
      echo "Deleting Certificate Issuance Config: ${short_cic_name}"
      gcloud certificate-manager issuance-configs delete "${short_cic_name}" --location="${region}" --project="${project_id}" --quiet
    done
  fi

  echo "--- Deleting CA Pool(s) and Root CA(s) ---"
  local pool_names=$(gcloud privateca pools list --location="${region}" --project="${project_id}" --filter="name~/${pool_prefix}" --format="value(name)")
  if [[ -z "${pool_names}" ]]; then
    echo "No CA Pools found with prefix '${pool_prefix}'."
  else
    local count=$(echo "${pool_names}" | wc -l)
    if [[ ${count} -gt 1 ]]; then
      echo "WARNING: Found multiple (${count}) CA Pools with prefix '${pool_prefix}'. Deleting all and their CAs:"
      echo "${pool_names}"
    fi
    for pool_full_name in ${pool_names}; do
      local short_pool_name=$(basename "${pool_full_name}")
      echo "Processing CA Pool: ${short_pool_name}"

      local ca_names=$(gcloud privateca roots list --pool="${short_pool_name}" --location="${region}" --project="${project_id}" --filter="name~/${ca_prefix}" --format="value(name)")
      if [[ -n "${ca_names}" ]]; then
        for ca_full_name in ${ca_names}; do
          local short_ca_name=$(basename "${ca_full_name}")
          echo "Disabling CA ${short_ca_name} in pool ${short_pool_name}"
          gcloud privateca roots disable "${short_ca_name}" --pool="${short_pool_name}" --location="${region}" --project="${project_id}" --quiet
          echo "Deleting CA ${short_ca_name} in pool ${short_pool_name}"
          gcloud privateca roots delete "${short_ca_name}" --pool="${short_pool_name}" --location="${region}" --project="${project_id}" --quiet --skip-grace-period
        done
      else
        echo "No matching Root CAs found in pool ${short_pool_name} with prefix ${ca_prefix}."
      fi

      echo "Deleting CA Pool: ${short_pool_name}"
      gcloud privateca pools delete "${short_pool_name}" --location="${region}" --project="${project_id}" --quiet
    done
  fi
  echo "Managed certificate resources deletion process complete."
}
 
# Usage: create_certificate [cert_name] [region] [project_id] [swp_ip] [swp_hostname]
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
  # This is the certificate that clients need to trust
  local gcs_ca_cert_uri="${INIT_ACTIONS_ROOT}/swp_ca.crt"

  mkdir -p tls

  # 1. Create Self-Signed CA if not exists
  if [[ ! -f "${ca_key_file}" ]] || [[ ! -f "${ca_cert_file}" ]]; then
    echo "Generating Self-Signed CA..."
    openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
      -keyout "${ca_key_file}" -out "${ca_cert_file}" \
      -subj "/CN=Dataproc SWP Test CA/O=My Company"
    echo "CA Certificate generated: ${ca_cert_file}"
  else
    echo "CA key and certificate already exist."
  fi

  # 2. Create SWP Server Key
  if [[ ! -f "${server_key_file}" ]]; then
    echo "Generating SWP server key..."
    openssl genrsa -out "${server_key_file}" 2048
  fi

  # 3. Create SWP Server CSR
  echo "Generating SWP server CSR for ${swp_hostname} and ${swp_ip}"
  local tmp_openssl_cnf="/tmp/swp_openssl.cnf"
  cat > "${tmp_openssl_cnf}" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = ${swp_hostname}

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${swp_hostname}
IP.1  = ${swp_ip}
EOF
  openssl req -new -key "${server_key_file}" -out "${server_csr_file}" -config "${tmp_openssl_cnf}"
  rm -f "${tmp_openssl_cnf}"

  # 4. Sign the Server Certificate with the CA
  echo "Signing SWP server certificate with CA..."
  # Create an extensions file for signing
  local ext_file="/tmp/swp_ext.cnf"
  cat > "${ext_file}" << EOF
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${swp_hostname}
IP.1  = ${swp_ip}
EOF
  openssl x509 -req -in "${server_csr_file}" -CA "${ca_cert_file}" -CAkey "${ca_key_file}" \
    -CAcreateserial -out "${server_cert_file}" -days 365 -sha256 \
    -extfile "${ext_file}"
  rm -f "${ext_file}"
  echo "SWP Server Certificate generated: ${server_cert_file}"

  # 5. Upload CA cert to GCS for client use
  echo "Uploading CA certificate to ${gcs_ca_cert_uri}"
  gsutil cp "${ca_cert_file}" "${gcs_ca_cert_uri}"

  # 6. Upload Server cert to Certificate Manager
  if ! gcloud certificate-manager certificates describe "${cert_name}" --location="${region}" --project="${project_id}" &>/dev/null; then
    echo "Creating Certificate Manager Certificate: ${cert_name} in region ${region}"
    gcloud certificate-manager certificates create "${cert_name}" \
      --certificate-file="${server_cert_file}" \
      --private-key-file="${server_key_file}" \
      --location="${region}" \
      --project="${project_id}"
    echo "Certificate '${cert_name}' created."
  else
    echo "Certificate Manager Certificate '${cert_name}' already exists in region ${region}."
    echo "If you need to update it, delete it first."
  fi

  # Return the full URL of the server certificate
  echo "projects/${project_id}/locations/${region}/certificates/${cert_name}"
}

# function create_certificate() {
#   local cert_name="${1:-${SWP_CERT_NAME}}"
#   local region="${2:-${REGION}}"
#   local cert_file="${3:-${SWP_CERTIFICATE}}"
#   local key_file="${4:-${SWP_KEY}}"
#   local project_id="${PROJECT_ID}"
#   local swp_hostname="${SWP_HOSTNAME}"

#   if [[ ! -f "${cert_file}" ]] ; then
#     openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
#       -keyout "${key_file}" -out "${cert_file}" \
#       -subj "/CN=${swp_hostname}" \
#       -addext "subjectAltName=IP:${SWP_IP},DNS:swp.internal.local"
#   fi

#   if ! gcloud certificate-manager certificates describe "${cert_name}" --location="${region}" &>/dev/null; then
#     echo "Creating Certificate Manager Certificate: ${cert_name} in region ${region}"
#     if [[ ! -f "${cert_file}" ]] || [[ ! -f "${key_file}" ]]; then
#       echo "ERROR: Certificate file (${cert_file}) or key file (${key_file}) not found." >&2
#       return 1
#     fi

#     gcloud certificate-manager certificates create "${cert_name}" \
#       --certificate-file="${cert_file}" \
#       --private-key-file="${key_file}" \
#       --location="${region}"
#     echo "Certificate '${cert_name}' created."
#   else
#     echo "Certificate Manager Certificate '${cert_name}' already exists in region ${region}."
#   fi

#   # Place the certificate in GCS to allow access by init actions
#   gsutil -m cp -r "${cert_file}" "${INIT_ACTIONS_ROOT}/"

#   # Return the full URL
#   echo "projects/${project_id}/locations/${region}/certificates/${cert_name}"
#   # gcloud certificate-manager certificates
# }

function delete_certificate() {
  local cert_name="${1:-${SWP_CERT_NAME}}"
  local region="${2:-${REGION}}"

  if gcloud certificate-manager certificates describe "${cert_name}" --location="${region}" &>/dev/null; then
    echo "Deleting Certificate Manager Certificate: ${cert_name} in region ${region}"
    gcloud certificate-manager certificates delete "${cert_name}" --location="${region}" --quiet
    echo "Certificate '${cert_name}' deleted."
  else
    echo "Certificate Manager Certificate '${cert_name}' not found in region ${region}."
  fi

  # Optionally delete local files
  # rm -f "${SWP_CERTIFICATE}" "${SWP_KEY}"
}

# Usage: create_swp_gateway <instance_name> <region> <network_name> <private_subnet_name> <private_range> <cert_url> <policy_url> [project_id]
function create_swp_gateway() {
  local swp_instance_name="${1:-${SWP_INSTANCE_NAME}}"
  local region="${2:-${REGION}}"
  local network_name="${3:-${NETWORK}}"
  # This is the subnet where the Gateway IP will reside
  local client_subnet_name="${4:-${PRIVATE_SUBNET}}"
  local client_range="${5:-${PRIVATE_RANGE}}"
  local certificate_url="${6:-${SWP_CERT_URI_PARTIAL}}"
  local gateway_security_policy_url="${7:-${SWP_POLICY_URI_PARTIAL}}"
  local project_id="${8:-${PROJECT_ID}}"
  set -x

  if gcloud network-services gateways describe "${swp_instance_name}" --location="${region}" &>/dev/null; then
    echo "Secure Web Proxy Gateway '${swp_instance_name}' already exists in region '${region}'."
    set +x
    return 0
  fi

  # Calculate the static IP address (.245 in the client range)
  local swp_address="${SWP_IP}"

  echo "Creating Secure Web Proxy Gateway: ${swp_instance_name} in region ${region} with IP ${swp_address} in subnet ${client_subnet_name}"

  local full_network_name="projects/${project_id}/global/networks/${network_name}"
  local full_client_subnet_name="projects/${project_id}/regions/${region}/subnetworks/${client_subnet_name}"
  local swp_full_name="projects/${project_id}/locations/${region}/gateways/${swp_instance_name}"

  gateway_yaml=$(cat << EOF
name: ${swp_full_name}
type: SECURE_WEB_GATEWAY
addresses:
- ${swp_address}
ports:
- ${SWP_PORT}
certificateUrls:
- ${certificate_url}
gatewaySecurityPolicy: ${gateway_security_policy_url}
network: ${full_network_name}
subnetwork: ${full_client_subnet_name} # Subnet where the IP is
scope: ${swp_instance_name}-scope
routingMode: EXPLICIT_ROUTING_MODE
EOF
  )
  echo "${gateway_yaml}" | gcloud network-services gateways import "${swp_instance_name}" \
    --source=- \
    --location="${region}"
  set +x
  echo "Secure Web Proxy Gateway '${swp_instance_name}' creation process initiated."
}

# Usage: delete_swp_gateway <instance_name> <region>
function delete_swp_gateway() {
  local swp_instance_name="${1:-${SWP_INSTANCE_NAME}}"
  local region="${2:-${REGION}}"

  if gcloud network-services gateways describe "${swp_instance_name}" --location="${region}" &>/dev/null; then
    echo "Deleting Secure Web Proxy Gateway: ${swp_instance_name} in region ${region}"
    gcloud network-services gateways delete "${swp_instance_name}" --location="${region}" --quiet
    echo "SWP Gateway '${swp_instance_name}' deleted."
  else
    echo "SWP Gateway '${swp_instance_name}' not found in region ${region}."
  fi
}

function create_swp_subnet() {
  local subnet_name="${1:-${SWP_SUBNET}}"
  local region="${2:-${REGION}}"
  local network_name="${3:-${NETWORK}}"
  local range="${4:-${SWP_RANGE}}"

  if ! gcloud compute networks subnets describe "${subnet_name}" --region="${region}" &>/dev/null; then
    echo "Creating proxy-only subnet: ${subnet_name}"
    gcloud compute networks subnets create "${subnet_name}" \
      --purpose=REGIONAL_MANAGED_PROXY \
      --role=ACTIVE \
      --region="${region}" \
      --network="${network_name}" \
      --range="${range}"
  else
    echo "Proxy-only subnet '${subnet_name}' already exists."
  fi
}

function delete_swp_subnet() {
  local subnet_name="${1:-${SWP_SUBNET}}"
  local region="${2:-${REGION}}"
  gcloud compute networks subnets delete "${subnet_name}" --region="${region}" --quiet
}

function create_allow_swp_ingress_rule() {
  local rule_name="${1:-allow-swp-ingress-${CLUSTER_NAME}}"
  local network_name="${2:-${NETWORK}}"
  local source_range="${3:-${PRIVATE_RANGE}}"
  local target_tags="${4:-swp-proxy}" # Optional: Tag the SWP subnet/instance

  # This rule allows ingress traffic on the SWP port (e.g., TCP:${SWP_PORT}) from the
  # private subnet range to the SWP proxy-only subnet range. This is
  # necessary for cluster nodes to be able to send traffic to the proxy for
  # egress to the internet. The rule is scoped to the specific source and
  # destination ranges for security.

  if ! gcloud compute firewall-rules describe "${rule_name}" &>/dev/null; then
    echo "Creating firewall rule: ${rule_name}"
    gcloud compute firewall-rules create "${rule_name}" \
      --network="${network_name}" \
      --direction=INGRESS \
      --action=ALLOW \
      --rules=tcp:3128 \
      --source-ranges="${source_range}" \
      --destination-ranges="${SWP_RANGE}"
  else
    echo "Firewall rule '${rule_name}' already exists."
  fi
}

function delete_allow_swp_ingress_rule() {
  local rule_name="${1:-allow-swp-ingress-${CLUSTER_NAME}}"
  if gcloud compute firewall-rules describe "${rule_name}" &>/dev/null; then
    gcloud compute firewall-rules delete "${rule_name}" --quiet
  fi
}

function create_allow_internal_subnets_rule() {
  local rule_name="${1:-allow-internal-${CLUSTER_NAME}}"
  local network_name="${2:-${NETWORK}}"
  local source_range="${3:-${PRIVATE_RANGE}}"
  local dest_range="${4:-${SWP_RANGE}}"

  if ! gcloud compute firewall-rules describe "${rule_name}" &>/dev/null; then
    echo "Creating firewall rule: ${rule_name}"
    gcloud compute firewall-rules create "${rule_name}" \
      --network="${network_name}" \
      --direction=INGRESS \
      --action=ALLOW \
      --rules=all \
      --source-ranges="${source_range}" \
      --destination-ranges="${dest_range}" \
      --priority=100 # High priority
  else
    echo "Firewall rule '${rule_name}' already exists."
  fi
}

function delete_allow_internal_subnets_rule() {
  local rule_name="${1:-allow-internal-${CLUSTER_NAME}}"
  if gcloud compute firewall-rules describe "${rule_name}" &>/dev/null; then
    gcloud compute firewall-rules delete "${rule_name}" --quiet
  fi
}

function create_private_subnet () {
  set -x
  if ! gcloud compute networks subnets describe "${PRIVATE_SUBNET}" --region "${REGION}" &>/dev/null; then
    gcloud compute networks subnets create ${PRIVATE_SUBNET} \
      --network=${NETWORK} \
      --range="${PRIVATE_RANGE}" \
      --enable-private-ip-google-access \
      --region=${REGION} \
      --description="subnet for use with Dataproc cluster ${CLUSTER_NAME}"
  else
    echo "private subnet ${PRIVATE_SUBNET} already exists"
  fi
  set +x

  echo "=========================="
  echo "Private Subnetwork created"
  echo "=========================="
}

function delete_private_subnet () {
  set -x
  gcloud compute networks subnets delete --quiet --region ${REGION} ${PRIVATE_SUBNET}
  set +x

  echo "private subnetwork deleted"
}
