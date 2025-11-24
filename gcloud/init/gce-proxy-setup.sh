#!/bin/bash

set -euo pipefail

# --- Metadata Helpers ---
function print_metadata_value() {
  local readonly tmpfile=$(mktemp)
  # Capture stdout and http_code separately
  http_code=$(curl -f "${1}" -H "Metadata-Flavor: Google" -w '%{http_code}' \
    -s -o ${tmpfile} --connect-timeout 5 --max-time 10)
  local readonly return_code=$?
  # If the command completed successfully, print the metadata value to stdout.
  if [[ ${return_code} == 0 && "${http_code}" == "200" ]]; then
    cat ${tmpfile}
  fi
  rm -f ${tmpfile}
  return ${return_code}
}

function print_metadata_value_if_exists() {
  local return_code=1
  local readonly url=$1
  print_metadata_value "${url}"
  return_code=$?
  return ${return_code}
}

# replicates /usr/share/google/get_metadata_value
function get_metadata_value() {
  local readonly varname=$1
  local -r MDS_PREFIX=http://metadata.google.internal/computeMetadata/v1
  # Print the instance metadata value.
  print_metadata_value_if_exists ${MDS_PREFIX}/instance/${varname}
  return_code=$?
  # If the instance doesn't have the value, try the project.
  if [[ ${return_code} != 0 ]]; then
    print_metadata_value_if_exists ${MDS_PREFIX}/project/${varname}
    return_code=$?
  fi
  return ${return_code}
}

function get_metadata_attribute() {
  local -r attribute_name="$1"
  local -r default_value="${2:-}"
  set +e
  get_metadata_value "attributes/${attribute_name}" || echo -n "${default_value}"
  set -e
}
# --- End Metadata Helpers ---

# --- OS Detection Helpers ---
function os_id()       { grep '^ID='               /etc/os-release | cut -d= -f2 | xargs ; }
function is_debuntu()  {  [[ "$(os_id)" == "debian" || "$(os_id)" == "ubuntu" ]] ; }
function is_rocky()    {  [[ "$(os_id)" == "rocky" ]] ; }
# --- End OS Detection Helpers ---

function set_proxy(){
  METADATA_HTTP_PROXY="$(get_metadata_attribute http-proxy '')"

  if [[ -z "${METADATA_HTTP_PROXY}" ]] ; then return ; fi

default_no_proxy_list=("localhost" "127.0.0.0/8" "::1" "*.googleapis.com"
			"metadata.google.internal" "169.254.169.254")

  user_no_proxy=$(get_metadata_attribute 'no-proxy' '')
  user_no_proxy_list=()
  if [[ -n "${user_no_proxy}" ]]; then
    # Replace spaces with commas, then split by comma
    IFS=',' read -r -a user_no_proxy_list <<< "${user_no_proxy// /,}"
  fi

  combined_no_proxy_list=("${default_no_proxy_list[@]}" "${user_no_proxy_list[@]}")
  no_proxy=$( IFS=',' ; echo "${combined_no_proxy_list[*]}" )

  export http_proxy="http://${METADATA_HTTP_PROXY}"
  export https_proxy="http://${METADATA_HTTP_PROXY}"
  export no_proxy
  export HTTP_PROXY="http://${METADATA_HTTP_PROXY}"
  export HTTPS_PROXY="http://${METADATA_HTTP_PROXY}"
  export NO_PROXY="${no_proxy}"

  # configure gcloud
  # There is no no_proxy config for gcloud so we cannot use these settings until https://github.com/psf/requests/pull/7068 is merged
#  gcloud config set proxy/type http
#  gcloud config set proxy/address "${METADATA_HTTP_PROXY%:*} "
#  gcloud config set proxy/port "${METADATA_HTTP_PROXY#*:}"

  # add proxy environment variables to /etc/environment
  grep http_proxy /etc/environment || echo "http_proxy=${http_proxy}" >> /etc/environment
  grep https_proxy /etc/environment || echo "https_proxy=${https_proxy}" >> /etc/environment
  grep no_proxy /etc/environment || echo "no_proxy=${no_proxy}" >> /etc/environment
  grep HTTP_PROXY /etc/environment || echo "HTTP_PROXY=${HTTP_PROXY}" >> /etc/environment
  grep HTTPS_PROXY /etc/environment || echo "HTTPS_PROXY=${HTTPS_PROXY}" >> /etc/environment
  grep NO_PROXY /etc/environment || echo "NO_PROXY=${NO_PROXY}" >> /etc/environment

  local pkg_proxy_conf_file
  if is_debuntu ; then
    # configure Apt to use the proxy:
    pkg_proxy_conf_file="/etc/apt/apt.conf.d/99proxy"
    cat > "${pkg_proxy_conf_file}" <<EOF
Acquire::http::Proxy "http://${METADATA_HTTP_PROXY}";
Acquire::https::Proxy "http://${METADATA_HTTP_PROXY}";
EOF
elif is_rocky ; then
    pkg_proxy_conf_file="/etc/dnf/dnf.conf"

    touch "${pkg_proxy_conf_file}"

    if grep -q "^proxy=" "${pkg_proxy_conf_file}"; then
      sed -i.bak "s@^proxy=.*@proxy=${HTTP_PROXY}@" "${pkg_proxy_conf_file}"
    elif grep -q "^\\\[main\\\\]" "${pkg_proxy_conf_file}"; then
      sed -i.bak "/^\\\[main\\\\]/a proxy=${HTTP_PROXY}" "${pkg_proxy_conf_file}"
    else
      local TMP_FILE=$(mktemp)
      printf "[main]\nproxy=%s\n" "${HTTP_PROXY}" > "${TMP_FILE}"

      cat "${TMP_FILE}" "${pkg_proxy_conf_file}" > "${pkg_proxy_conf_file}".new
      mv "${pkg_proxy_conf_file}".new "${pkg_proxy_conf_file}"

      rm "${TMP_FILE}"
    fi
  else
    echo "unknown OS"
    exit 1
  fi
  # configure gpg to use the proxy:
  if ! grep 'keyserver-options http-proxy' /etc/gnupg/dirmngr.conf ; then
    mkdir -p /etc/gnupg
    cat >> /etc/gnupg/dirmngr.conf <<EOF
http-proxy http://${METADATA_HTTP_PROXY}
EOF
  fi

  # Install the HTTPS proxy's certificate in the system and Java trust databases
  METADATA_HTTP_PROXY_PEM_URI="$(get_metadata_attribute http-proxy-pem-uri '')"

  if [[ -z "${METADATA_HTTP_PROXY_PEM_URI}" ]] ; then return ; fi
  if [[ ! "${METADATA_HTTP_PROXY_PEM_URI}" =~ ^gs ]] ; then echo "http-proxy-pem-uri value should start with gs://" ; exit 1 ; fi

  local trusted_pem_dir
  # Add this certificate to the OS trust database
  # When proxy cert is provided, speak to the proxy over https
  if is_debuntu ; then
    trusted_pem_dir="/usr/local/share/ca-certificates"
    mkdir -p "${trusted_pem_dir}"
    proxy_ca_pem="${trusted_pem_dir}/proxy_ca.crt"
    gsutil cp "${METADATA_HTTP_PROXY_PEM_URI}" "${proxy_ca_pem}"
    update-ca-certificates
    trusted_pem_path="/etc/ssl/certs/ca-certificates.crt"
    sed -i -e 's|http://|https://|' "${pkg_proxy_conf_file}"
elif is_rocky ; then
    trusted_pem_dir="/etc/pki/ca-trust/source/anchors"
    mkdir -p "${trusted_pem_dir}"
    proxy_ca_pem="${trusted_pem_dir}/proxy_ca.crt"
    gsutil cp "${METADATA_HTTP_PROXY_PEM_URI}" "${proxy_ca_pem}"
    update-ca-trust
    trusted_pem_path="/etc/ssl/certs/ca-bundle.crt"
    sed -i -e 's|^proxy=http://|proxy=https://|' "${pkg_proxy_conf_file}"
  else
    echo "unknown OS"
    exit 1
  fi

  # configure gcloud to respect proxy ca cert
  #gcloud config set core/custom_ca_certs_file "${proxy_ca_pem}"

  ca_subject="$(openssl crl2pkcs7 -nocrl -certfile "${proxy_ca_pem}" | openssl pkcs7 -print_certs -noout | grep ^subject)"
  # Verify that the proxy certificate is trusted
  local output
  output=$(echo | openssl s_client \
           -connect "${METADATA_HTTP_PROXY}" \
           -proxy "${METADATA_HTTP_PROXY}" \
           -CAfile "${proxy_ca_pem}") || {
    echo "proxy certificate verification failed"
    echo "${output}"
    exit 1
  }
  output=$(echo | openssl s_client \
           -connect "${METADATA_HTTP_PROXY}" \
           -proxy "${METADATA_HTTP_PROXY}" \
           -CAfile "${trusted_pem_path}") || {
    echo "proxy ca certificate not included in system bundle"
    echo "${output}"
    exit 1
  }
  output=$(curl --verbose -fsSL --retry-connrefused --retry 10 --retry-max-time 30 --head "https://google.com" 2>&1)|| {
    echo "curl rejects proxy configuration"
    echo "${output}"
    exit 1
  }
  output=$(curl --verbose -fsSL --retry-connrefused --retry 10 --retry-max-time 30 --head "https://developer.download.nvidia.com/compute/cuda/12.6.3/local_installers/cuda_12.6.3_560.35.05_linux.run" 2>&1)|| {
    echo "curl rejects proxy configuration"
    echo "${output}"
    exit 1
  }

  # Instruct conda to use the system certificate
  echo "Attempting to install pip-system-certs using the proxy certificate..."
  export REQUESTS_CA_BUNDLE="${trusted_pem_path}"
  pip install pip-system-certs
  unset REQUESTS_CA_BUNDLE

  # For the binaries bundled with conda, append our certificate to the bundle
  openssl crl2pkcs7 -nocrl -certfile /opt/conda/default/ssl/cacert.pem | openssl pkcs7 -print_certs -noout | grep -Fx "${ca_subject}" || {
    cat "${proxy_ca_pem}" >> /opt/conda/default/ssl/cacert.pem
  }

  sed -i -e 's|http://|https://|' /etc/gnupg/dirmngr.conf
  export http_proxy="https://${METADATA_HTTP_PROXY}"
  export https_proxy="https://${METADATA_HTTP_PROXY}"
  export HTTP_PROXY="https://${METADATA_HTTP_PROXY}"
  export HTTPS_PROXY="https://${METADATA_HTTP_PROXY}"
  sed -i -e 's|proxy=http://|proxy=https://|'  -e 's|PROXY=http://|PROXY=https://|' /etc/environment

  # Instruct the JRE to trust the certificate
  JAVA_HOME="$(awk -F= '/^JAVA_HOME=/ {print $2}' /etc/environment)"
  "${JAVA_HOME}/bin/keytool" -import -cacerts -storepass changeit -noprompt -alias swp_ca -file "${proxy_ca_pem}"
}

set_proxy