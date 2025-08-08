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
# This library contains all common functions for managing network resources.

# --- VPC Network Functions ---

function create_network() {
  local network_name="$1"
  if ! gcloud compute networks describe "${network_name}" &>/dev/null; then
    echo "Creating VPC Network: ${network_name}"
    gcloud compute networks create "${network_name}" \
      --subnet-mode=custom \
      --bgp-routing-mode="regional" \
      --description="VPC for CUJ workloads"
  else
    echo "VPC Network '${network_name}' already exists."
  fi
}

function delete_network() {
  local network_name="$1"
  if gcloud compute networks describe "${network_name}" &>/dev/null; then
    echo "Deleting VPC Network: ${network_name}"
    gcloud compute networks delete --quiet "${network_name}"
  else
    echo "VPC Network '${network_name}' not found."
  fi
}

# --- Subnet Functions ---

function create_subnet() {
  local network_name="$1"
  local subnet_name="$2"
  local subnet_range="$3"
  local region="$4"
  local enable_private_access="${5:-true}"

  if ! gcloud compute networks subnets describe "${subnet_name}" --region="${region}" &>/dev/null; then
    echo "Creating Subnet: ${subnet_name}"
    local private_access_flag=""
    if [[ "${enable_private_access}" == "true" ]]; then
      private_access_flag="--enable-private-ip-google-access"
    fi
    gcloud compute networks subnets create "${subnet_name}" \
      --network="${network_name}" \
      --range="${subnet_range}" \
      --region="${region}" \
      ${private_access_flag}
  else
    echo "Subnet '${subnet_name}' already exists."
  fi
}

function delete_subnet() {
    local subnet_name="$1"
    local region="$2"
    if gcloud compute networks subnets describe "${subnet_name}" --region="${region}" &>/dev/null; then
        echo "Deleting subnet '${subnet_name}'..."
        gcloud compute networks subnets delete --quiet "${subnet_name}" --region="${region}"
    else
        echo "Subnet '${subnet_name}' not found."
    fi
}

# --- Firewall Rule Functions ---

function create_firewall_rule() {
  local rule_name="$1"
  local network_name="$2"
  # direction, action, rules, source_ranges, target_tags are passed in a single string
  local other_flags="$3"

  if ! gcloud compute firewall-rules describe "${rule_name}" &>/dev/null; then
    echo "Creating firewall rule '${rule_name}'..."
    eval gcloud compute firewall-rules create "'${rule_name}'" --network="'${network_name}'" ${other_flags}
  else
    echo "Firewall rule '${rule_name}' already exists."
  fi
}

function delete_firewall_rule() {
  local rule_name="$1"
  if gcloud compute firewall-rules describe "${rule_name}" &>/dev/null; then
    echo "Deleting firewall rule '${rule_name}'..."
    gcloud compute firewall-rules delete --quiet "${rule_name}"
  else
    echo "Firewall rule '${rule_name}' not found."
  fi
}


# --- Router and NAT Functions ---

function create_router() {
  local router_name="$1"
  local network_name="$2"
  local region="$3"
  local asn="$4"
  if ! gcloud compute routers describe "${router_name}" --region="${region}" &>/dev/null; then
    echo "Creating Cloud Router: ${router_name}"
    gcloud compute routers create "${router_name}" \
      --network="${network_name}" --asn="${asn}" --region="${region}"
  else
    echo "Cloud Router '${router_name}' already exists."
  fi
}

function delete_router() {
  local router_name="$1"
  local region="$2"
  if gcloud compute routers describe "${router_name}" --region="${region}" &>/dev/null; then
    echo "Deleting Cloud Router: ${router_name}"
    gcloud compute routers delete --quiet "${router_name}" --region="${region}"
  else
    echo "Cloud Router '${router_name}' not found."
  fi
}

function add_nat_gateway_to_router() {
  local router_name="$1"
  local region="$2"
  local nat_name="${router_name}-nat"
  if ! gcloud compute routers nats describe "${nat_name}" --router="${router_name}" --region="${region}" &>/dev/null; then
    echo "Adding NAT Gateway '${nat_name}' to router '${router_name}'"
    gcloud compute routers nats create "${nat_name}" \
      --router="${router_name}" --region="${region}" \
      --nat-all-subnet-ip-ranges --auto-allocate-nat-external-ips
  else
    echo "NAT Gateway '${nat_name}' already exists."
  fi
}


# --- VPC Peering Functions for Cloud SQL ---

function create_peering_ip_allocation() {
    local network_name="$1"
    local allocation_name="${network_name}-sql-peer"
    if ! gcloud compute addresses describe "${allocation_name}" --global &>/dev/null; then
        echo "Creating IP Allocation for SQL Peering: ${allocation_name}"
        gcloud compute addresses create "${allocation_name}" \
            --global --purpose=VPC_PEERING --prefix-length=16 --network="${network_name}"
    else
        echo "IP Allocation '${allocation_name}' already exists."
    fi
}

function delete_peering_ip_allocation() {
    local network_name="$1"
    local allocation_name="${network_name}-sql-peer"
    if gcloud compute addresses describe "${allocation_name}" --global &>/dev/null; then
        echo "Deleting IP Allocation '${allocation_name}'..."
        gcloud compute addresses delete --quiet "${allocation_name}" --global
    else
        echo "IP Allocation '${allocation_name}' not found."
    fi
}

function create_vpc_peering_connection() {
    local network_name="$1"
    local allocation_name="${network_name}-sql-peer"
    # The name of the peering connection is fixed by the service.
    if ! gcloud services vpc-peerings list --network="${network_name}" | grep -q "servicenetworking-googleapis-com"; then
        echo "Creating VPC Peering Connection for Service Networking..."
        gcloud services vpc-peerings connect --service=servicenetworking.googleapis.com \
            --ranges="${allocation_name}" --network="${network_name}"
    else
        echo "VPC Peering Connection already exists for network '${network_name}'."
    fi
}
