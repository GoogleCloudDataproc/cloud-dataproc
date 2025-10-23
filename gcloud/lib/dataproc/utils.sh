#!/bin/bash
#
# Dataproc Utility functions

function get_cluster_uuid() {
  get_cluster_json | jq -r .clusterUuid
}
export -f get_cluster_uuid

function get_cluster_json() {
  #  get_clusters_list | jq ".[] | select(.name | test(\"${BIGTABLE_INSTANCE}$\"))"
  if [[ -z "${THIS_CLUSTER_JSON}" ]]; then
    JQ_CMD=".[] | select(.clusterName | contains(\"${CLUSTER_NAME}\"))"
    THIS_CLUSTER_JSON=$(gcloud dataproc clusters list --region="${REGION}" --project="${PROJECT_ID}" --format json | jq -c "${JQ_CMD}")
  fi

  echo "${THIS_CLUSTER_JSON}"
}
export -f get_cluster_json
