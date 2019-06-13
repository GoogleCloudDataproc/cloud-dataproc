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
"""
Shell script based image creation workflow generator.
"""

from datetime import datetime


_template = """
#!/usr/bin/env bash

# Script for creating Dataproc custom image.

set -euxo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

function exit_handler() {{
  echo 'Cleaning up before exiting.'

  if [[ -f /tmp/{run_id}/vm_created ]]; then
    echo 'Deleting VM instance.'
    gcloud compute instances delete {image_name}-install \
        --project={project_id} --zone={zone} -q
  elif [[ -f /tmp/{run_id}/disk_created ]]; then
    echo 'Deleting disk.'
    gcloud compute disks delete {image_name}-install --project={project_id} --zone={zone} -q
  fi

  echo 'Uploading local logs to GCS bucket.'
  gsutil -m rsync -r {log_dir}/ {gcs_log_dir}/

  if [[ -f /tmp/{run_id}/image_created ]]; then
    echo -e "${{GREEN}}Workflow succeeded, check logs at {log_dir}/ or {gcs_log_dir}/${{NC}}"
    exit 0
  else
    echo -e "${{RED}}Workflow failed, check logs at {log_dir}/ or {gcs_log_dir}/${{NC}}"
    exit 1
  fi
}}

function main() {{
  echo 'Uploading files to GCS bucket.'
  gsutil cp \
      {customization_script} \
      gs://{bucket_name}/{run_id}/sources/init_actions.sh
  gsutil cp run.sh gs://{bucket_name}/{run_id}/sources/

  echo 'Creating disk.'
  gcloud compute disks create {image_name}-install \
      --project={project_id} \
      --zone={zone} \
      --image={dataproc_base_image} \
      --type=pd-ssd \
      --size={disk_size}GB
  touch /tmp/{run_id}/disk_created

  echo 'Creating VM instance to run customization script.'
  gcloud compute instances create {image_name}-install \
      --project={project_id} \
      --zone={zone} \
      {network_flag} \
      {subnetwork_flag} \
      {no_external_ip_flag} \
      --machine-type={machine_type} \
      --disk=auto-delete=yes,boot=yes,mode=rw,name={image_name}-install \
      --scopes=cloud-platform \
      --metadata=shutdown-timer-in-sec={shutdown_timer_in_sec},daisy-sources-path={daisy_sources_path},startup-script-url={startup_script_url}
  touch /tmp/{run_id}/vm_created

  echo 'Waiting for customization script to finish and VM shutdown.'
  gcloud compute instances tail-serial-port-output {image_name}-install \
      --project={project_id} \
      --zone={zone} \
      --port=1 2>&1 \
      | grep 'startup-script' \
      | tee {log_dir}/startup-script.log \
      || true

  echo 'Checking customization script result.'
  if grep 'BuildFailed:' {log_dir}/startup-script.log; then
    echo -e "${{RED}}Customization script failed.${{NC}}"
    exit 1
  elif grep 'BuildSucceeded:' {log_dir}/startup-script.log; then
    echo -e "${{GREEN}}Customization script succeeded.${{NC}}"
  else
    echo 'Unable to determine the customization script result.'
    exit 1
  fi

  echo 'Creating custom image.'
  gcloud compute images create {image_name} \
      --project={project_id} \
      --source-disk-zone={zone} \
      --source-disk={image_name}-install \
      --family={family}
  touch /tmp/{run_id}/image_created
}}

trap exit_handler EXIT
mkdir -p {log_dir}
main "$@" 2>&1 | tee {log_dir}/workflow.log
"""

class Generator:
  """Shell script based image creation workflow generator."""

  def _init_args(self, args):
    self.args = args
    if "run_id" not in self.args:
      self.args["run_id"] = "custom-image-{image_name}-{timestamp}".format(
          timestamp=datetime.now().strftime("%Y%m%d-%H%M%S"), **self.args)
    self.args["bucket_name"] = self.args["gcs_bucket"].replace("gs://", "")
    self.args[
        "daisy_sources_path"] = "gs://{bucket_name}/{run_id}/sources".format(
            **self.args)
    self.args[
        "startup_script_url"] = "gs://{bucket_name}/{run_id}/sources/run.sh".format(
            **self.args)
    self.args["log_dir"] = "/tmp/{run_id}/logs".format(**self.args)
    self.args["gcs_log_dir"] = "gs://{bucket_name}/{run_id}/logs".format(**self.args)
    if self.args["subnetwork"]:
      self.args["subnetwork_flag"] = "--subnet={subnetwork}".format(**self.args)
      self.args["network_flag"] = ""
    elif self.args["network"]:
      self.args["network_flag"] = "--network={network}".format(**self.args)
      self.args["subnetwork_flag"] = ""
    self.args["no_external_ip_flag"] = "--no-address" if self.args["no_external_ip"] else ""


  def generate(self, args):
    self._init_args(args)
    return _template.format(**args)
