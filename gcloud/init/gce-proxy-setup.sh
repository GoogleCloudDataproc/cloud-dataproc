#!/bin/bash

set -euo pipefail

# Idempotency Check
if grep -q "http_proxy=" /etc/environment && [[ -n "${http_proxy:-}" ]]; then
  echo "INFO: Proxy already configured in /etc/environment. Skipping setup."
  exit 0
fi

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

# --- Version Comparison Helpers ---
function version_le(){ [[ "$1" = "$(echo -e "$1\n$2"|sort -V|head -n1)" ]]; }
function version_lt(){ [[ "$1" = "$2" ]] && return 1 || version_le "$1" "$2"; }
# --- End Version Comparison Helpers ---

function execute_with_retries() {
  local -r cmd="$*"
  local retries=3
  local delay=5
  for ((i = 0; i < retries; i++)); do
    eval "${cmd}" && return 0
    echo "Command failed. Retrying in ${delay} seconds..." >&2
    sleep "${delay}"
  done
  echo "Command failed after ${retries} retries: ${cmd}" >&2
  return 1
}

function set_proxy(){
  local meta_http_proxy meta_https_proxy meta_proxy_uri
  meta_http_proxy=$(get_metadata_attribute 'http-proxy' '')
  meta_https_proxy=$(get_metadata_attribute 'https-proxy' '')
  meta_proxy_uri=$(get_metadata_attribute 'proxy-uri' '')

  echo "DEBUG: set_proxy: meta_http_proxy='${meta_http_proxy}'"
  echo "DEBUG: set_proxy: meta_https_proxy='${meta_https_proxy}'"
  echo "DEBUG: set_proxy: meta_proxy_uri='${meta_proxy_uri}'"

  local http_proxy_val=""
  local https_proxy_val=""

  # Determine HTTP_PROXY value
  if [[ -n "${meta_http_proxy}" ]] && [[ "${meta_http_proxy}" != ":" ]]; then
    http_proxy_val="${meta_http_proxy}"
  elif [[ -n "${meta_proxy_uri}" ]] && [[ "${meta_proxy_uri}" != ":" ]]; then
    http_proxy_val="${meta_proxy_uri}"
  fi

  # Determine HTTPS_PROXY value
  if [[ -n "${meta_https_proxy}" ]] && [[ "${meta_https_proxy}" != ":" ]]; then
    https_proxy_val="${meta_https_proxy}"
  elif [[ -n "${meta_proxy_uri}" ]] && [[ "${meta_proxy_uri}" != ":" ]]; then
    https_proxy_val="${meta_proxy_uri}"
  fi

  if [[ -z "${http_proxy_val}" && -z "${https_proxy_val}" ]]; then
    echo "DEBUG: set_proxy: No valid proxy metadata found (http-proxy, https-proxy, or proxy-uri). Skipping proxy setup."
    return 0
  fi



    local default_no_proxy_list=(

      "localhost"

      "127.0.0.1"

      "::1"

      "metadata.google.internal"

      "169.254.169.254"

      # *** Add Google APIs to NO_PROXY for Private Google Access ***

      ".google.com"

      ".googleapis.com"

    )



    local user_no_proxy

    user_no_proxy=$(get_metadata_attribute 'no-proxy' '')

    local user_no_proxy_list=()

    if [[ -n "${user_no_proxy}" ]]; then

      # Replace spaces with commas, then split by comma

      IFS=',' read -r -a user_no_proxy_list <<< "${user_no_proxy// /,}"

    fi



    local combined_no_proxy_list=( "${default_no_proxy_list[@]}" "${user_no_proxy_list[@]}" )

    local no_proxy

    no_proxy=$( IFS=',' ; echo "${combined_no_proxy_list[*]}" )

    export NO_PROXY="${no_proxy}"

    export no_proxy="${no_proxy}"



  # Export environment variables
  if [[ -n "${http_proxy_val}" ]]; then
    export HTTP_PROXY="http://${http_proxy_val}"
    export http_proxy="http://${http_proxy_val}"
  else
    unset HTTP_PROXY
    unset http_proxy
  fi
  echo "DEBUG: set_proxy: Initial HTTP_PROXY='${HTTP_PROXY:-}'"

  if [[ -n "${https_proxy_val}" ]]; then
    export HTTPS_PROXY="http://${https_proxy_val}"
    export https_proxy="http://${https_proxy_val}"
  else
    unset HTTPS_PROXY
    unset https_proxy
  fi
  echo "DEBUG: set_proxy: Initial HTTPS_PROXY='${HTTPS_PROXY:-}'"

  # Clear existing proxy settings in /etc/environment
  sed -i -e '/^http_proxy=/d' -e '/^https_proxy=/d' -e '/^no_proxy=/d' \
    -e '/^HTTP_PROXY=/d' -e '/^HTTPS_PROXY=/d' -e '/^NO_PROXY=/d' /etc/environment

  # Add current proxy environment variables to /etc/environment
  if [[ -n "${HTTP_PROXY:-}" ]]; then echo "HTTP_PROXY=${HTTP_PROXY}" >> /etc/environment; fi
  if [[ -n "${http_proxy:-}" ]]; then echo "http_proxy=${http_proxy}" >> /etc/environment; fi
  if [[ -n "${HTTPS_PROXY:-}" ]]; then echo "HTTPS_PROXY=${HTTPS_PROXY}" >> /etc/environment; fi
  if [[ -n "${https_proxy:-}" ]]; then echo "https_proxy=${https_proxy}" >> /etc/environment; fi
  echo "DEBUG: set_proxy: Effective HTTP_PROXY=${HTTP_PROXY:-}"
  echo "DEBUG: set_proxy: Effective HTTPS_PROXY=${HTTPS_PROXY:-}"
  echo "DEBUG: set_proxy: Effective NO_PROXY=${NO_PROXY:-}"

  if [[ -n "${http_proxy_val}" ]]; then
    local proxy_host=$(echo "${http_proxy_val}" | cut -d: -f1)
    local proxy_port=$(echo "${http_proxy_val}" | cut -d: -f2)

    echo "DEBUG: set_proxy: Testing TCP connection to proxy ${proxy_host}:${proxy_port}..."
    if ! nc -zv -w 5 "${proxy_host}" "${proxy_port}"; then
      echo "ERROR: Failed to establish TCP connection to proxy ${proxy_host}:${proxy_port}."
      exit 1
    else
      echo "DEBUG: set_proxy: TCP connection to proxy successful."
    fi

    echo "DEBUG: set_proxy: Testing external site access via proxy..."
    local test_url="https://www.google.com"
    if curl -vL --retry 3 --retry-delay 5 -o /dev/null "${test_url}"; then
      echo "DEBUG: set_proxy: Successfully fetched ${test_url} via proxy."
    else
      echo "ERROR: Failed to fetch ${test_url} via proxy ${HTTP_PROXY}."
      exit 1
    fi
  fi

  # Configure package managers
  local pkg_proxy_conf_file
  local effective_proxy="${http_proxy_val:-${https_proxy_val}}" # Use a single value for apt/dnf

  if [[ -z "${effective_proxy}" ]]; then
      echo "DEBUG: set_proxy: No HTTP or HTTPS proxy set for package managers."
  elif is_debuntu ; then
    pkg_proxy_conf_file="/etc/apt/apt.conf.d/99proxy"
    echo "Acquire::http::Proxy \"http://${effective_proxy}\";" > "${pkg_proxy_conf_file}"
    echo "Acquire::https::Proxy \"http://${effective_proxy}\";" >> "${pkg_proxy_conf_file}"
    echo "DEBUG: set_proxy: Configured apt proxy: ${pkg_proxy_conf_file}"
  elif is_rocky ; then
    pkg_proxy_conf_file="/etc/dnf/dnf.conf"
    touch "${pkg_proxy_conf_file}"
    sed -i.bak '/^proxy=/d' "${pkg_proxy_conf_file}"
    if grep -q "^\[main\]" "${pkg_proxy_conf_file}"; then
      sed -i.bak "/^\\\[main\\\\]/a proxy=http://${effective_proxy}" "${pkg_proxy_conf_file}"
    else
      echo -e "[main]\nproxy=http://${effective_proxy}" >> "${pkg_proxy_conf_file}"
    fi
    echo "DEBUG: set_proxy: Configured dnf proxy: ${pkg_proxy_conf_file}"
  fi

  # Configure dirmngr to use the HTTP proxy if set
  if is_debuntu ; then
    if ! dpkg -l | grep -q dirmngr; then
      echo "DEBUG: set_proxy: dirmngr package not found, installing..."
      execute_with_retries apt-get install -y -qq dirmngr
    fi
  elif is_rocky ; then
    if ! rpm -q gnupg2-smime; then
      echo "DEBUG: set_proxy: gnupg2-smime package not found, installing..."
      execute_with_retries dnf install -y -q gnupg2-smime
    fi
  fi

  mkdir -p /etc/gnupg
  local dirmngr_conf="/etc/gnupg/dirmngr.conf"
  touch "${dirmngr_conf}" # Ensure the file exists

  sed -i.bak '/^http-proxy/d' "${dirmngr_conf}"
  if [[ -n "${http_proxy_val}" ]]; then
    echo "http-proxy http://${http_proxy_val}" >> "${dirmngr_conf}"
    echo "DEBUG: set_proxy: Configured dirmngr proxy in ${dirmngr_conf}"
  fi

  # Install the HTTPS proxy's certificate
  METADATA_HTTP_PROXY_PEM_URI="$(get_metadata_attribute http-proxy-pem-uri '')"
  if [[ -z "${METADATA_HTTP_PROXY_PEM_URI}" ]] ; then
    echo "DEBUG: set_proxy: No http-proxy-pem-uri metadata found. Skipping cert install."
    return 0
  fi
  if [[ ! "${METADATA_HTTP_PROXY_PEM_URI}" =~ ^gs:// ]] ; then echo "ERROR: http-proxy-pem-uri value must start with gs://" ; exit 1 ; fi

  echo "DEBUG: set_proxy: http-proxy-pem-uri='${METADATA_HTTP_PROXY_PEM_URI}'"
  local trusted_pem_dir proxy_ca_pem ca_subject
  if is_debuntu ; then
    trusted_pem_dir="/usr/local/share/ca-certificates"
    proxy_ca_pem="${trusted_pem_dir}/proxy_ca.crt"
    gsutil cp "${METADATA_HTTP_PROXY_PEM_URI}" "${proxy_ca_pem}"
    update-ca-certificates
    export trusted_pem_path="/etc/ssl/certs/ca-certificates.crt"
    if [[ -n "${effective_proxy}" ]]; then
      sed -i -e 's|http://|https://|' "${pkg_proxy_conf_file}"
    fi
  elif is_rocky ; then
    trusted_pem_dir="/etc/pki/ca-trust/source/anchors"
    proxy_ca_pem="${trusted_pem_dir}/proxy_ca.crt"
    gsutil cp "${METADATA_HTTP_PROXY_PEM_URI}" "${proxy_ca_pem}"
    update-ca-trust
    export trusted_pem_path="/etc/ssl/certs/ca-bundle.crt"
     if [[ -n "${effective_proxy}" ]]; then
        sed -i -e "s|^proxy=http://|proxy=https://|" "${pkg_proxy_conf_file}"
    fi
  fi
  export REQUESTS_CA_BUNDLE="${trusted_pem_path}"
  echo "DEBUG: set_proxy: trusted_pem_path='${trusted_pem_path}'"

  local proxy_host="${http_proxy_val:-${https_proxy_val}}"

  # Update env vars to use https
  if [[ -n "${http_proxy_val}" ]]; then
    export HTTP_PROXY="https://${http_proxy_val}"
    export http_proxy="https://${http_proxy_val}"
  fi
  if [[ -n "${https_proxy_val}" ]]; then
    export HTTPS_PROXY="https://${https_proxy_val}"
    export https_proxy="https://${https_proxy_val}"
  fi
  sed -i -e 's|http://|https://|g' /etc/environment
  echo "DEBUG: set_proxy: Final HTTP_PROXY='${HTTP_PROXY:-}'"
  echo "DEBUG: set_proxy: Final HTTPS_PROXY='${HTTPS_PROXY:-}'"

  if [[ -n "${http_proxy_val}" ]]; then
    sed -i -e "s|^http-proxy http://.*|http-proxy https://${http_proxy_val}|" /etc/gnupg/dirmngr.conf
  fi

  # Verification steps from original script...
  ca_subject="$(openssl crl2pkcs7 -nocrl -certfile "${proxy_ca_pem}" | openssl pkcs7 -print_certs -noout | grep ^subject)"
  openssl s_client -connect "${proxy_host}" -CAfile "${proxy_ca_pem}" < /dev/null || { echo "ERROR: proxy cert verification failed" ; exit 1 ; }
  openssl s_client -connect "${proxy_host}" -CAfile "${trusted_pem_path}" < /dev/null || { echo "ERROR: proxy ca not in system bundle" ; exit 1 ; }

  curl --verbose --cacert "${trusted_pem_path}" -x "${HTTPS_PROXY}" -fsSL --retry-connrefused --retry 10 --retry-max-time 30 --head "https://google.com" || { echo "ERROR: curl rejects proxy config for google.com" ; exit 1 ; }
  curl --verbose --cacert "${trusted_pem_path}" -x "${HTTPS_PROXY}" -fsSL --retry-connrefused --retry 10 --retry-max-time 30 --head "https://developer.download.nvidia.com" || { echo "ERROR: curl rejects proxy config for nvidia.com" ; exit 1 ; }

  pip install pip-system-certs
  unset REQUESTS_CA_BUNDLE

  if command -v conda &> /dev/null ; then
    local conda_cert_file="/opt/conda/default/ssl/cacert.pem"
    if [[ -f "${conda_cert_file}" ]]; then
      openssl crl2pkcs7 -nocrl -certfile "${conda_cert_file}" | openssl pkcs7 -print_certs -noout | grep -Fxq "${ca_subject}" || {
        cat "${proxy_ca_pem}" >> "${conda_cert_file}"
      }
    fi
  fi

  if [[ -f "/etc/environment" ]]; then
      JAVA_HOME="$(awk -F= '/^JAVA_HOME=/ {print $2}' /etc/environment)"
      if [[ -n "${JAVA_HOME:-}" && -f "${JAVA_HOME}/bin/keytool" ]]; then
          "${JAVA_HOME}/bin/keytool" -import -cacerts -storepass changeit -noprompt -alias swp_ca -file "${proxy_ca_pem}"
      fi
  fi

  # Configure boto (gsutil)
  local boto_file="/etc/boto.cfg"
  if [[ -f "${boto_file}" ]]; then
    echo "DEBUG: set_proxy: Repairing and configuring ${boto_file}" >&2
    
    # Deduplicate sections (fix for DuplicateSectionError)
    perl -i -ne 'if (/^\[(.*)\]/) { $skip = $seen{$1}++; } print unless $skip;' "${boto_file}"
    
    if [[ -n "${effective_proxy}" ]]; then
      local proxy_host="${effective_proxy%:*}"
      local proxy_port="${effective_proxy##*:}"
      
      sed -i -e '/^proxy =/d' -e '/^proxy_port =/d' "${boto_file}"
      if grep -q "^\[Boto\]" "${boto_file}"; then
        sed -i "/^\[Boto\]/a proxy = ${proxy_host}\nproxy_port = ${proxy_port}" "${boto_file}"
      else
        echo -e "\n[Boto]\nproxy = ${proxy_host}\nproxy_port = ${proxy_port}" >> "${boto_file}"
      fi
    fi
    echo "DEBUG: set_proxy: Updated ${boto_file}" >&2
  fi

  echo "DEBUG: set_proxy: Verifying proxy connectivity..."

  # Test fetching a file through the proxy
  local test_url="https://www.gstatic.com/generate_204"
#  local test_url="https://raw.githubusercontent.com/GoogleCloudDataproc/initialization-actions/master/README.md"
  local test_output="${tmpdir}/proxy_test.md"

  echo "DEBUG: set_proxy: Attempting to download ${test_url} via proxy ${HTTPS_PROXY}"
#  if curl --verbose --cacert "${trusted_pem_path}" -x "${HTTPS_PROXY}" -fsSL --retry-connrefused --retry 3 --retry-max-time 10 -o "${test_output}" "${test_url}"; then
  if curl -vL --retry 3 --retry-delay 5 -o /dev/null "${test_url}"; then
    echo "DEBUG: set_proxy: Successfully downloaded test file through proxy."
    rm -f "${test_output}"
  else
    echo "ERROR: Proxy test failed. Unable to download ${test_url} via ${HTTPS_PROXY}"
    # Optionally print more debug info from curl if needed
    exit 1
  fi

  echo "DEBUG: set_proxy: Proxy verification successful."

  echo "DEBUG: set_proxy: Proxy setup complete."
}

set_proxy
