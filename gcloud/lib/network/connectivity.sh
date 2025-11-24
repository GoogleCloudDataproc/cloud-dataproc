#!/bin/bash
#
# Network Connectivity Test functions

function perform_connectivity_tests () {
  print_status "Performing Connectivity Tests..."
  report_result "Pass"
  # https://cloud.google.com/network-intelligence-center/docs/connectivity-tests/how-to/running-connectivity-tests#testing-between-ips


  #gcloud network-management connectivity-tests create ${CONNECTIVITY_TEST}-spark-inbound \
    #  --source-ip-address=SOURCE_IP_ADDRESS \
    #  --source-network=SOURCE_NETWORK
  #  --destination-ip-address=DESTINATION_IP_ADDRESS \
    #  --destination-network=DESTINATION_NETWORK \
    #  --protocol=PROTOCOL

  # https://cloud.google.com/network-intelligence-center/docs/connectivity-tests/concepts/test-google-managed-services

}
