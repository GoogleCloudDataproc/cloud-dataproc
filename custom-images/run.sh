#!/bin/bash

# Copyright 2019 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#            http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# run.sh will be used by Daisy workflow to run custom initialization
# script when creating a custom image.
#
# Immediately after Daisy workflow creates an GCE instance, it will
# execute run.sh on the GCE instance that it just created:
# 1. Download user's custom init action script from daisy sourth path.
# 2. Run the custom init action script.
# 3. Check for init action script output, and print success or failure
#    message. This message will get picked up by Daisy workflow on the
#    client machine.
# 4. Shutdown GCE instance.

# get daisy-sources-path
DAISY_SOURCES_PATH=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/daisy-sources-path" -H "Metadata-Flavor: Google")
# get time to wait for stdout to flush
SHUTDOWN_TIMER_IN_SEC=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/shutdown-timer-in-sec" -H "Metadata-Flavor: Google")

ready=""

function wait_until_ready() {
  # For Ubuntu, wait until /snap is mounted, so that gsutil is unavailable.
  if [[ "$(. /etc/os-release && echo ${ID})" == 'ubuntu' ]]; then
    for i in {0..10}; do
      sleep 5

      if command -v gsutil >/dev/null; then
        ready="true"
        break
      fi

      if (( $i == 10 )); then
        echo "BuildFailed: timed out waiting for gsutil to be available on Ubuntu."
      fi
    done
  else
    ready="true"
  fi
}

function run_custom_script() {
  # copy down all sources (along with init_actions.sh script)
  gsutil -m cp -r "${DAISY_SOURCES_PATH}/*" ./

  # run init actions
  bash -x ./init_actions.sh

  # get return code
  RET_CODE=$?

  # print failure message if install fails
  if [[ $RET_CODE -ne 0 ]]; then
    echo "BuildFailed: Dataproc Initialization Actions Failed. Please check your initialization script."
  else
    echo "BuildSucceeded: Dataproc Initialization Actions Succeeded."
  fi
}

function main() {
  wait_until_ready

  if [[ "${ready}" == "true" ]]; then
    run_custom_script
  fi

  sleep ${SHUTDOWN_TIMER_IN_SEC} # wait for stdout to flush
  shutdown -h now
}

main "$@"
