#!/bin/bash
#
# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# This library contains functions for managing Dataproc resources.
# It is sourced by the main 'common.sh' library.

# --- Dataproc on GCE Functions ---

# A comprehensive GCE cluster creation function.
# It takes required arguments for name, region, and subnet, and a single
# string containing all other optional gcloud flags.
# This allows for maximum flexibility for different CUJs.
#
# Example extra_flags:
#   --tags="foo,bar" --properties="core:fs.gs.proxy.address=1.2.3.4:3128"
#   --master-machine-type="e2-standard-4" --worker-accelerator="type=nvidia-tesla-t4,count=1"
#   --service-account="my-sa@..." --shielded-secure-boot
#
function create_gce_cluster() {
  local cluster_name="$1"
  local region="$2"
  local subnet_name="$3"
  local extra_flags="$4" # A single string for all other flags

  if ! gcloud dataproc clusters describe "${cluster_name}" --region="${region}" &>/dev/null; then
    header "Creating Dataproc on GCE cluster '${cluster_name}'"
    # Using 'eval' is necessary here to correctly parse the string of extra flags.
    eval gcloud dataproc clusters create "'${cluster_name}'" \
      --region="'${region}'" \
      --subnet="'${subnet_name}'" \
      ${extra_flags}
  else
    echo "Dataproc on GCE cluster '${cluster_name}' already exists."
  fi
}

function delete_gce_cluster() {
  local cluster_name="$1"
  local region="$2"
  if gcloud dataproc clusters describe "${cluster_name}" --region="${region}" &>/dev/null; then
    header "Deleting Dataproc on GCE cluster '${cluster_name}'"
    gcloud dataproc clusters delete --quiet "${cluster_name}" --region="${region}"
  else
    echo "Dataproc on GCE cluster '${cluster_name}' not found."
  fi
}


# --- Dataproc on GKE Functions ---

function create_gke_cluster() {
  local gke_cluster_name="$1"
  local zone="$2"
  local machine_type="${3:-e2-standard-4}"
  local tags="${4:-cuj-gke-node}"

  if ! gcloud container clusters describe "${gke_cluster_name}" --zone="${zone}" &>/dev/null; then
    header "Creating GKE cluster '${gke_cluster_name}' for Dataproc"
    gcloud container clusters create "${gke_cluster_name}" \
      --zone="${zone}" \
      --machine-type="${machine_type}" \
      --num-nodes=1 \
      --enable-dataproc \
      --tags="${tags}"
  else
    echo "GKE cluster '${gke_cluster_name}' already exists."
  fi
}

function delete_gke_cluster() {
  local gke_cluster_name="$1"
  local zone="$2"
  if gcloud container clusters describe "${gke_cluster_name}" --zone="${zone}" &>/dev/null; then
    header "Deleting GKE cluster '${gke_cluster_name}'"
    gcloud container clusters delete --quiet "${gke_cluster_name}" --zone="${zone}"
  else
    echo "GKE cluster '${gke_cluster_name}' not found."
  fi
}

function create_dpgke_virtual_cluster() {
  local virtual_cluster_name="$1"
  local region="$2"
  local gke_cluster_name="$3"
  local gke_cluster_zone="$4"
  local staging_bucket="$5"

  if ! gcloud dataproc virtual-clusters describe "${virtual_cluster_name}" --region="${region}" &>/dev/null; then
    header "Creating Dataproc virtual cluster '${virtual_cluster_name}'"
    # The --enable-dataproc flag on the GKE cluster creates the 'dataproc' node pool by default.
    gcloud dataproc virtual-clusters create "${virtual_cluster_name}" \
      --region="${region}" \
      --gke-cluster-name="${gke_cluster_name}" \
      --gke-cluster-zone="${gke_cluster_zone}" \
      --gke-node-pool="dataproc" \
      --staging-bucket="${staging_bucket}"
  else
    echo "Dataproc virtual cluster '${virtual_cluster_name}' already exists."
  fi
}

function delete_dpgke_virtual_cluster() {
  local virtual_cluster_name="$1"
  local region="$2"
  if gcloud dataproc virtual-clusters describe "${virtual_cluster_name}" --region="${region}" &>/dev/null; then
    header "Deleting Dataproc virtual cluster '${virtual_cluster_name}'"
    gcloud dataproc virtual-clusters delete --quiet "${virtual_cluster_name}" --region="${region}"
  else
    echo "Dataproc virtual cluster '${virtual_cluster_name}' not found."
  fi
}

# --- Dataproc Helper Functions ---

# Gets the full JSON representation of a cluster.
# Arguments: $1=cluster_name, $2=region
function get_cluster_json() {
  gcloud dataproc clusters describe "$1" --region="$2" --format=json
}

# Gets just the UUID of a cluster.
# Arguments: $1=cluster_name, $2=region
function get_cluster_uuid() {
  get_cluster_json "$1" "$2" | jq -r .clusterUuid
}
