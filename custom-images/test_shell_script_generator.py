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

import unittest
import shell_script_generator

_expected_script = """
#!/usr/bin/env bash

# Script for creating Dataproc custom image.

set -euxo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

function exit_handler() {
  echo 'Cleaning up before exiting.'

  if [[ -f /tmp/custom-image-my-image-20190611-160823/vm_created ]]; then
    echo 'Deleting VM instance.'
    gcloud compute instances delete my-image-install         --project=my-project --zone=us-west1-a -q
  elif [[ -f /tmp/custom-image-my-image-20190611-160823/disk_created ]]; then
    echo 'Deleting disk.'
    gcloud compute disks delete my-image-install --project=my-project --zone=us-west1-a -q
  fi

  echo 'Uploading local logs to GCS bucket.'
  gsutil -m rsync -r /tmp/custom-image-my-image-20190611-160823/logs/ gs://my-bucket/custom-image-my-image-20190611-160823/logs/

  if [[ -f /tmp/custom-image-my-image-20190611-160823/image_created ]]; then
    echo -e "${GREEN}Workflow succeeded, check logs at /tmp/custom-image-my-image-20190611-160823/logs/ or gs://my-bucket/custom-image-my-image-20190611-160823/logs/${NC}"
    exit 0
  else
    echo -e "${RED}Workflow failed, check logs at /tmp/custom-image-my-image-20190611-160823/logs/ or gs://my-bucket/custom-image-my-image-20190611-160823/logs/${NC}"
    exit 1
  fi
}

function main() {
  echo 'Uploading files to GCS bucket.'
  gsutil cp       /tmp/my-script.sh       gs://my-bucket/custom-image-my-image-20190611-160823/sources/init_actions.sh
  gsutil cp run.sh gs://my-bucket/custom-image-my-image-20190611-160823/sources/

  echo 'Creating disk.'
  gcloud compute disks create my-image-install       --project=my-project       --zone=us-west1-a       --image=projects/cloud-dataproc/global/images/dataproc-1-4-deb9-20190510-000000-rc01       --type=pd-ssd       --size=40GB
  touch /tmp/custom-image-my-image-20190611-160823/disk_created

  echo 'Creating VM instance to run customization script.'
  gcloud compute instances create my-image-install       --project=my-project       --zone=us-west1-a              --subnet=my-subnet       --no-address       --machine-type=n1-standard-2       --disk=auto-delete=yes,boot=yes,mode=rw,name=my-image-install       --scopes=cloud-platform       --metadata=shutdown-timer-in-sec=500,daisy-sources-path=gs://my-bucket/custom-image-my-image-20190611-160823/sources,startup-script-url=gs://my-bucket/custom-image-my-image-20190611-160823/sources/run.sh
  touch /tmp/custom-image-my-image-20190611-160823/vm_created

  echo 'Waiting for customization script to finish and VM shutdown.'
  gcloud compute instances tail-serial-port-output my-image-install       --project=my-project       --zone=us-west1-a       --port=1 2>&1       | grep 'startup-script'       | tee /tmp/custom-image-my-image-20190611-160823/logs/startup-script.log       || true

  echo 'Checking customization script result.'
  if grep 'BuildFailed:' /tmp/custom-image-my-image-20190611-160823/logs/startup-script.log; then
    echo -e "${RED}Customization script failed.${NC}"
    exit 1
  elif grep 'BuildSucceeded:' /tmp/custom-image-my-image-20190611-160823/logs/startup-script.log; then
    echo -e "${GREEN}Customization script succeeded.${NC}"
  else
    echo 'Unable to determine the customization script result.'
    exit 1
  fi

  echo 'Creating custom image.'
  gcloud compute images create my-image       --project=my-project       --source-disk-zone=us-west1-a       --source-disk=my-image-install       --family=debian9
  touch /tmp/custom-image-my-image-20190611-160823/image_created
}

trap exit_handler EXIT
mkdir -p /tmp/custom-image-my-image-20190611-160823/logs
main "$@" 2>&1 | tee /tmp/custom-image-my-image-20190611-160823/logs/workflow.log
"""


class TestShellScriptGenerator(unittest.TestCase):
  def test_generate_shell_script(self):
    args = {
        'run_id': 'custom-image-my-image-20190611-160823',
        'family': 'debian9',
        'image_name': 'my-image',
        'customization_script': '/tmp/my-script.sh',
        'machine_type': 'n1-standard-2',
        'disk_size': 40,
        'gcs_bucket': 'gs://my-bucket',
        'network': 'my-network',
        'subnetwork': 'my-subnet',
        'no_external_ip': True,
        'zone': 'us-west1-a',
        'dataproc_base_image':
        'projects/cloud-dataproc/global/images/dataproc-1-4-deb9-20190510-000000-rc01',
        'service_account': 'my-service-account',
        'oauth': '',
        'project_id': 'my-project',
        'shutdown_timer_in_sec': 500
    }

    script = shell_script_generator.Generator().generate(args)

    self.assertEqual(script, _expected_script)


if __name__ == '__main__':
  unittest.main()
