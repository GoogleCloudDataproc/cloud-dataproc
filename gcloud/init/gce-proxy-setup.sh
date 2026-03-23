#!/bin/bash
set -euo pipefail

echo "DEBUG: gce-proxy-setup.sh started." >&2

# --- Workaround for Dataproc 2.3 universe_domain bug (b/488706340) ---
function patch_bdutil_universe() {
  local bdutil_universe="/usr/local/share/google/dataproc/bdutil/bdutil_universe.sh"
  if [[ -f "${bdutil_universe}" ]]; then
    echo "DEBUG: Applying bdutil_universe.sh patch..." >&2
    # Check if patch is already applied
    if grep -q "get_universe_domain() {" "${bdutil_universe}" && grep -q "core/universe_domain 2> /dev/null || true" "${bdutil_universe}"; then
        echo "DEBUG: Patch already applied to ${bdutil_universe}." >&2
        return 0
    fi
    cat << 'EOF' > /tmp/patch_universe.py
import os
import re

path = "/usr/local/share/google/dataproc/bdutil/bdutil_universe.sh"
if os.path.exists(path):
    print(f"DEBUG: Patching {path}", flush=True)
    try:
        with open(path, "r") as f:
            content = f.read()
    except Exception as e:
        print(f"Error reading {path}: {e}", flush=True)
        exit(1)

    old_func = """function get_universe_domain() {
  local -r universe_domain="$(gcloud config get core/universe_domain 2> /dev/null)"
  echo "${universe_domain}"
}"""

    new_func = """function get_universe_domain() {
  local universe_domain
  universe_domain="$(gcloud config get core/universe_domain 2> /dev/null || true)"
  if [[ -z "${universe_domain}" ]]; then
    echo "googleapis.com"
  else
    echo "${universe_domain}"
  fi
}"""

    if old_func in content:
        content = content.replace(old_func, new_func)
        try:
            with open(path, "w") as f:
                f.write(content)
            print(f"DEBUG: Patch applied to {path}", flush=True)
        except Exception as e:
            print(f"Error writing to {path}: {e}", flush=True)
            exit(1)
    else:
        print(f"DEBUG: Pattern not found, patch not needed or already applied to {path}", flush=True)
else:
    print(f"DEBUG: {path} not found, skipping patch.", flush=True)
EOF
    if python3 /tmp/patch_universe.py; then
      echo "DEBUG: Python patch script succeeded." >&2
    else
      echo "DEBUG: Python patch script failed." >&2
    fi
    rm -f /tmp/patch_universe.py
    echo "DEBUG: bdutil_universe.sh patch complete." >&2
  else
    echo "DEBUG: ${bdutil_universe} not found, skipping patch." >&2
  fi

  echo "DEBUG: Removing potentially corrupt /etc/boto.cfg to force regeneration" >&2
  rm -f /etc/boto.cfg
}

# Comment out the call since the base image seems to have the fix
# patch_bdutil_universe

echo "DEBUG: gce-proxy-setup.sh complete." >&2
