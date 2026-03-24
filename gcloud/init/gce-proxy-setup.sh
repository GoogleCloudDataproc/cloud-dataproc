#!/bin/bash
set -euo pipefail

echo "DEBUG: gce-proxy-setup.sh started." >&2

# --- Metadata Helpers ---
function get_metadata_attribute() {
  local -r attribute_name="$1"
  local -r default_value="${2:-}"
  local -r url="http://metadata.google.internal/computeMetadata/v1/instance/attributes/${attribute_name}"
  curl -s -H "Metadata-Flavor: Google" "${url}" || echo -n "${default_value}"
}

# --- OS Detection Helpers ---
function os_id()       { grep '^ID='               /etc/os-release | cut -d= -f2 | xargs ; }
function is_debuntu()  {  [[ "$(os_id)" == "debian" || "$(os_id)" == "ubuntu" ]] ; }
function is_rocky()    {  [[ "$(os_id)" == "rocky" ]] ; }

# --- Main Proxy Setup ---
function set_proxy(){
  local meta_http_proxy meta_https_proxy meta_proxy_uri
  meta_http_proxy=$(get_metadata_attribute 'http-proxy' '')
  meta_https_proxy=$(get_metadata_attribute 'https-proxy' '')
  meta_proxy_uri=$(get_metadata_attribute 'proxy-uri' '')

  echo "DEBUG: set_proxy: meta_http_proxy='${meta_http_proxy}'" >&2
  echo "DEBUG: set_proxy: meta_https_proxy='${meta_https_proxy}'" >&2
  echo "DEBUG: set_proxy: meta_proxy_uri='${meta_proxy_uri}'" >&2

  local http_proxy_val=""
  local https_proxy_val=""

  # Determine HTTP_PROXY value
  if [[ -n "${meta_http_proxy}" ]]; then
    http_proxy_val="${meta_http_proxy}"
  elif [[ -n "${meta_proxy_uri}" ]]; then
    http_proxy_val="${meta_proxy_uri}"
  fi

  # Determine HTTPS_PROXY value
  if [[ -n "${meta_https_proxy}" ]]; then
    https_proxy_val="${meta_https_proxy}"
  elif [[ -n "${meta_proxy_uri}" ]]; then
    https_proxy_val="${meta_proxy_uri}"
  fi

  if [[ -z "${http_proxy_val}" && -z "${https_proxy_val}" ]]; then
    echo "DEBUG: set_proxy: No valid proxy metadata found. Skipping proxy setup." >&2
    return 0
  fi

  local default_no_proxy_list=(
    "localhost"
    "127.0.0.1"
    "::1"
    "metadata.google.internal"
    "169.254.169.254"
    ".google.com"
    ".googleapis.com"
    "$(hostname -f)"
    "$(hostname -s)"
  )

  local user_no_proxy
  user_no_proxy=$(get_metadata_attribute 'no-proxy' '')
  local user_no_proxy_list=()
  if [[ -n "${user_no_proxy}" ]]; then
    IFS=',' read -r -a user_no_proxy_list <<< "${user_no_proxy// /,}"
  fi

  local combined_no_proxy_list=( "${default_no_proxy_list[@]}" "${user_no_proxy_list[@]}" )
  local no_proxy
  no_proxy=$( IFS=',' ; echo "${combined_no_proxy_list[*]}" )
  
  # Export for current script
  export NO_PROXY="${no_proxy}"
  export no_proxy="${no_proxy}"
  if [[ -n "${http_proxy_val}" ]]; then
    export HTTP_PROXY="http://${http_proxy_val}"
    export http_proxy="http://${http_proxy_val}"
  fi
  if [[ -n "${https_proxy_val}" ]]; then
    export HTTPS_PROXY="http://${https_proxy_val}"
    export https_proxy="http://${https_proxy_val}"
  fi

  echo "DEBUG: set_proxy: Effective HTTP_PROXY=${HTTP_PROXY:-}" >&2
  echo "DEBUG: set_proxy: Effective HTTPS_PROXY=${HTTPS_PROXY:-}" >&2
  echo "DEBUG: set_proxy: Effective NO_PROXY=${NO_PROXY:-}" >&2

  # Persist for system
  local env_file="/etc/environment"
  sed -i -e '/^http_proxy=/d' -e '/^https_proxy=/d' -e '/^no_proxy=/d' 
    -e '/^HTTP_PROXY=/d' -e '/^HTTPS_PROXY=/d' -e '/^NO_PROXY=/d' "${env_file}"

  if [[ -n "${HTTP_PROXY:-}" ]]; then echo "HTTP_PROXY=${HTTP_PROXY}" >> "${env_file}"; fi
  if [[ -n "${http_proxy:-}" ]]; then echo "http_proxy=${http_proxy}" >> "${env_file}"; fi
  if [[ -n "${HTTPS_PROXY:-}" ]]; then echo "HTTPS_PROXY=${HTTPS_PROXY}" >> "${env_file}"; fi
  if [[ -n "${https_proxy:-}" ]]; then echo "https_proxy=${https_proxy}" >> "${env_file}"; fi
  if [[ -n "${NO_PROXY:-}" ]]; then echo "NO_PROXY=${NO_PROXY}" >> "${env_file}"; fi
  if [[ -n "${no_proxy:-}" ]]; then echo "no_proxy=${no_proxy}" >> "${env_file}"; fi
  echo "DEBUG: set_proxy: Updated ${env_file}" >&2

  # Persist for all shell sessions
  local profile_script="/etc/profile.d/proxy.sh"
  echo "# Proxy settings from Dataproc init action" > "${profile_script}"
  if [[ -n "${HTTP_PROXY:-}" ]]; then echo "export HTTP_PROXY='${HTTP_PROXY}'" >> "${profile_script}"; fi
  if [[ -n "${http_proxy:-}" ]]; then echo "export http_proxy='${http_proxy}'" >> "${profile_script}"; fi
  if [[ -n "${HTTPS_PROXY:-}" ]]; then echo "export HTTPS_PROXY='${HTTPS_PROXY}'" >> "${profile_script}"; fi
  if [[ -n "${https_proxy:-}" ]]; then echo "export https_proxy='${https_proxy}'" >> "${profile_script}"; fi
  if [[ -n "${NO_PROXY:-}" ]]; then echo "export NO_PROXY='${NO_PROXY}'" >> "${profile_script}"; fi
  if [[ -n "${no_proxy:-}" ]]; then echo "export no_proxy='${no_proxy}'" >> "${profile_script}"; fi
  echo "DEBUG: set_proxy: Created ${profile_script}" >&2

  # Source the script to apply settings to the current shell
  source "${profile_script}"
  echo "DEBUG: set_proxy: Sourced ${profile_script}" >&2

  # Configure package managers
  local effective_proxy="${http_proxy_val:-${https_proxy_val}}"
  if [[ -z "${effective_proxy}" ]]; then
      echo "DEBUG: set_proxy: No HTTP or HTTPS proxy set for package managers." >&2
  elif is_debuntu ; then
    local apt_proxy_conf="/etc/apt/apt.conf.d/99proxy"
    echo "Acquire::http::Proxy "http://${effective_proxy}";" > "${apt_proxy_conf}"
    echo "Acquire::https::Proxy "http://${effective_proxy}";" >> "${apt_proxy_conf}"
    echo "DEBUG: set_proxy: Configured apt proxy: ${apt_proxy_conf}" >&2
  elif is_rocky ; then
    local dnf_proxy_conf="/etc/dnf/dnf.conf"
    touch "${dnf_proxy_conf}"
    sed -i.bak '/^proxy=/d' "${dnf_proxy_conf}"
    if grep -q "^\[main\]" "${dnf_proxy_conf}"; then
      sed -i.bak "/^\[main\]/a proxy=http://${effective_proxy}" "${dnf_proxy_conf}"
    else
      echo -e "[main]
proxy=http://${effective_proxy}" >> "${dnf_proxy_conf}"
    fi
    echo "DEBUG: set_proxy: Configured dnf proxy: ${dnf_proxy_conf}" >&2
  fi

  # TODO: Add gcloud proxy config if needed
  # TODO: Add certificate handling if proxy uses custom CA
}

set_proxy

echo "DEBUG: gce-proxy-setup.sh complete." >&2
