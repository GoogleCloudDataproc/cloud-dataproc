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

#
# Example Dataproc Initialization Action
# AKA GCE Linux VM Startup script
# Example script follows
#
# https://cloud.google.com/compute/docs/instances/startup-scripts/linux
#
# startup-script-bash
#

set -x

readonly master_node=$(/usr/share/google/get_metadata_value attributes/dataproc-master)
readonly ROLE="$(/usr/share/google/get_metadata_value attributes/dataproc-role)"
if [[ "${ROLE}" == 'Master' ]]; then
  if [[ "${HOSTNAME}" == "$master_node" ]]; then
    echo "this instance will go first"
  else
    sleep 15s
  fi
fi

echo "PATH: ${PATH}" > /tmp/startup-script-path.log
which gcloud > /tmp/gcloud-path.log

set +x
