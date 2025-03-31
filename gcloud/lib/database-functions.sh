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

function create_mysql_instance() {
  # Create SQL Instance
  set -x
  gcloud sql instances create ${MYSQL_INSTANCE} \
    --no-assign-ip \
    --project=${PROJECT_ID} \
    --network=${NETWORK_URI_PARTIAL} \
    --database-version="MYSQL_5_7" \
    --activation-policy=ALWAYS \
    --zone ${ZONE}
  set +x

  echo "======================"
  echo "MySQL Instance Created"
  echo "======================"
}

function delete_mysql_instance() {
  set -x
  gcloud sql instances delete --quiet ${MYSQL_INSTANCE}
  set +x

  echo "MySQL instance deleted"
}

function create_legacy_mssql_instance() {
  set -x
  # Create legacy SQL Server Instance
  # Microsoft SQL Server 2014 Enterprise
  # Windows Server 2012
  # 64-bit
  local METADATA="kdc-root-passwd=${INIT_ACTIONS_ROOT}/${KDC_ROOT_PASSWD_KEY}.encrypted"
  METADATA="${METADATA},kms-keyring=${KMS_KEYRING}"
  METADATA="${METADATA},kdc-root-passwd-key=${KDC_ROOT_PASSWD_KEY}"
  METADATA="${METADATA},startup-script-url=${INIT_ACTIONS_ROOT}/kdc-server.sh"
  METADATA="service-account-user=${GSA}"
  gcloud compute instances create ${MSSQL_INSTANCE} \
    --zone ${ZONE} \
    --subnet ${SUBNET} \
    --service-account=${GSA} \
    --boot-disk-type pd-ssd \
    --image-family=${MSSQL_IMAGE_FAMILY} \
    --image-project=${MSSQL_IMAGE_PROJECT} \
    --machine-type=${MSSQL_MACHINE_TYPE} \
    --scopes='cloud-platform' \
    --metadata ${METADATA}
  set +x
}

function delete_legacy_mssql_instance() {
  set -x
  gcloud compute instances delete ${MSSQL_INSTANCE} \
    --quiet
  set +x
  echo "mssql legacy instance deleted"
}

function create_mssql_instance() {
  # Create CloudSQL Instance
  set -x
  # This only works for:

  # SQLSERVER_2017_ENTERPRISE, SQLSERVER_2017_EXPRESS, SQLSERVER_2017_STANDARD,
  # SQLSERVER_2017_WEB, SQLSERVER_2019_ENTERPRISE, SQLSERVER_2019_EXPRESS,
  # SQLSERVER_2019_STANDARD, SQLSERVER_2019_WEB

  gcloud sql instances create ${MSSQL_INSTANCE} \
    --no-assign-ip \
    --project=${PROJECT_ID} \
    --network=${NETWORK_URI_PARTIAL} \
    --database-version=${MSSQL_DATABASE_VERSION} \
    --activation-policy=ALWAYS \
    --zone ${ZONE}
  set +x

  echo "======================"
  echo "mssql Instance Created"
  echo "======================"
}

function delete_mssql_instance() {
  set -x
  gcloud sql instances delete --quiet ${MSSQL_INSTANCE}
  set +x

  echo "mssql instance deleted"
}

function create_pgsql_instance() {
  # Create CloudSQL Instance
  set -x

  gcloud sql instances create ${PGSQL_INSTANCE} \
    --no-assign-ip \
    --project=${PROJECT_ID} \
    --network=${NETWORK_URI_PARTIAL} \
    --database-version=${PGSQL_DATABASE_VERSION} \
    --activation-policy=ALWAYS \
    --root-password="${PGSQL_ROOT_PASSWORD}" \
    --zone ${ZONE}
  set +x

  echo "======================"
  echo "pgsql Instance Created"
  echo "======================"
}

function delete_pgsql_instance() {
  set -x
  gcloud sql instances delete --quiet ${PGSQL_INSTANCE}
  set +x

  echo "pgsql instance deleted"
}

