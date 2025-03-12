#!/bin/bash
#
# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS-IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
function create_logging_firewall_rules () {
  set -x
  gcloud compute firewall-rules create ${FIREWALL}-inlog \
    --direction ingress \
    --network ${NETWORK_URI} \
    --source-ranges 0.0.0.0/0 \
    --priority 65534 \
    --enable-logging \
    --action deny \
    --rules tcp:0-65535,udp:0-65535,icmp

  gcloud compute firewall-rules create ${FIREWALL}-outlog \
    --direction egress \
    --network ${NETWORK_URI} \
    --source-ranges 0.0.0.0/0 \
    --priority 65534 \
    --enable-logging \
    --action deny \
    --rules tcp:0-65535,udp:0-65535,icmp
  set +x

  echo "=============================="
  echo "Logging Firewall rules created"
  echo "=============================="

}

function delete_logging_firewall_rules () {
  set -x
  gcloud compute firewall-rules delete --quiet ${FIREWALL}-outlog
  set +x

  echo "egress logging firewall rule deleted"

  set -x
  gcloud compute firewall-rules delete --quiet ${FIREWALL}-inlog
  set +x

  echo "ingress logging firewall rule deleted"
}

function create_firewall_rules () {
# Create egress firewall rules

  set -x
  gcloud compute firewall-rules describe ${FIREWALL}-out > /dev/null \
  && echo "firewall rule ${FIREWALL}-out already exists" \
  || gcloud compute firewall-rules create ${FIREWALL}-out \
    --direction egress \
    --network ${NETWORK_URI} \
    --target-tags=${TAGS} \
    --action allow \
    --rules all

  gcloud compute firewall-rules describe ${FIREWALL}-default-allow-internal-out > /dev/null \
  && echo "firewall rule ${FIREWALL}-default-allow-internal-out already exists" \
  || gcloud compute firewall-rules create ${FIREWALL}-default-allow-internal-out > /dev/null \
    --direction egress \
    --network ${NETWORK_URI} \
    --source-ranges 10.0.0.0/8 \
    --rules all \
    --action allow
  set +x

  echo "============================="
  echo "Egress Firewall rules created"
  echo "============================="

# Create ingress firewall rules

  set -x
  gcloud compute firewall-rules describe ${FIREWALL}-in > /dev/null \
  && echo "firewall rule ${FIREWALL}-in already exists" \
  || gcloud compute firewall-rules create ${FIREWALL}-in \
    --direction ingress \
    --network ${NETWORK_URI} \
    --source-tags=${TAGS} \
    --action allow \
    --rules all

  gcloud compute firewall-rules describe ${FIREWALL}-default-allow-internal-in > /dev/null \
  && echo "firewall rule ${FIREWALL}-default-allow-internal-in already exists" \
  || gcloud compute firewall-rules create ${FIREWALL}-default-allow-internal-in \
    --direction ingress \
    --network ${NETWORK_URI} \
    --source-ranges 10.0.0.0/8 \
    --rules all \
    --action allow
  set +x

  echo "=============================="
  echo "Ingress Firewall rules created"
  echo "=============================="
}

function delete_firewall_rules () {
  gcloud compute firewall-rules delete --quiet ${FIREWALL}-out
  gcloud compute firewall-rules delete --quiet ${FIREWALL}-default-allow-internal-out

  echo "egress firewall rule deleted"

  gcloud compute firewall-rules delete --quiet ${FIREWALL}-in
  gcloud compute firewall-rules delete --quiet ${FIREWALL}-default-allow-internal-in

  echo "ingress firewall rule deleted"
}

function create_subnet () {
  set -x
  gcloud compute networks subnets describe "${SUBNET}" > /dev/null \
  && echo "subnet ${SUBNET} already exists" \
  || gcloud compute networks subnets create ${SUBNET} \
    --network=${NETWORK} \
    --range="$RANGE" \
    --enable-private-ip-google-access \
    --region=${REGION} \
    --description="subnet for use with Dataproc cluster ${CLUSTER_NAME}"
  set +x

  echo "=================="
  echo "Subnetwork created"
  echo "=================="
}

function delete_subnet () {
  set -x
  gcloud compute networks subnets delete --quiet --region ${REGION} ${SUBNET}
  set +x

  echo "subnetwork deleted"
}

function add_nat_policy () {
  set -x
  gcloud compute routers nats describe nat-config --router="${ROUTER_NAME}" > /dev/null \
  && echo "nat-config exists for router ${ROUTER_NAME}" \
  || gcloud compute routers nats create nat-config \
    --router-region ${REGION} \
    --router ${ROUTER_NAME} \
    --nat-all-subnet-ip-ranges \
    --auto-allocate-nat-external-ips
  set +x

  echo "=========================="
  echo "NAT policy added to Router"
  echo "=========================="
}

function create_router () {
  set -x

  gcloud compute routers describe "${ROUTER_NAME}" > /dev/null \
  && echo "router ${ROUTER_NAME} already exists" \
  || gcloud compute routers create ${ROUTER_NAME} \
    --project=${PROJECT_ID} \
    --network=${NETWORK} \
    --asn=${ASN_NUMBER} \
    --region=${REGION}
  set +x

  echo "=============="
  echo "Router created"
  echo "=============="
}

function delete_router () {
  set -x
  gcloud compute routers delete --quiet --region ${REGION} ${ROUTER_NAME}
  set +x

  echo "router deleted"
}

function create_vpc_peering () {
  set -x
  gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=${ALLOCATION_NAME} \
    --network=${NETWORK} \
    --project=${PROJECT_ID}
  set +x

  echo "==================="
  echo "VPC peering created"
  echo "==================="
}

function delete_vpc_peering () {
  set -x
  gcloud services vpc-peerings delete \
    --service=servicenetworking.googleapis.com \
    --network=${NETWORK} \
    --project=${PROJECT_ID}
  set +x

  echo "removed vpc peering"
}

function create_ip_allocation () {
  set -x
  gcloud compute addresses create ${ALLOCATION_NAME} \
    --global \
    --purpose=VPC_PEERING \
    --prefix-length=24 \
    --network=${NETWORK_URI_PARTIAL} \
    --project=${PROJECT_ID}
  set +x

  echo "=================="
  echo "Allocation created"
  echo "=================="
}

function delete_ip_allocation () {
  set -x
  gcloud compute addresses delete --quiet --global ${ALLOCATION_NAME}
  set +x

  echo "allocation released"
}

function create_vpc_network () {
  # Create VPC network

  set -x

  gcloud compute networks describe "${NETWORK}" > /dev/null \
  && echo "network ${NETWORK} already exists" \
  || gcloud compute networks create "${NETWORK}" \
    --subnet-mode=custom \
    --bgp-routing-mode="regional" \
    --description="network for use with Dataproc cluster ${CLUSTER_NAME}"
  set +x

  echo "==================="
  echo "VPC Network created"
  echo "==================="
}

function delete_vpc_network () {
  set -x
  gcloud compute networks delete --quiet ${NETWORK}
  set +x

  echo "network deleted"
}

function perform_connectivity_tests () {
  echo incomplete
  # https://cloud.google.com/network-intelligence-center/docs/connectivity-tests/how-to/running-connectivity-tests#testing-between-ips


  #gcloud network-management connectivity-tests create ${CONNECTIVITY_TEST}-spark-inbound \
    #  --source-ip-address=SOURCE_IP_ADDRESS \
    #  --source-network=SOURCE_NETWORK
  #  --destination-ip-address=DESTINATION_IP_ADDRESS \
    #  --destination-network=DESTINATION_NETWORK \
    #  --protocol=PROTOCOL

  # https://cloud.google.com/network-intelligence-center/docs/connectivity-tests/concepts/test-google-managed-services

}
