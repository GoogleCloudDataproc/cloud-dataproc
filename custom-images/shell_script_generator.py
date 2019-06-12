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


class Generator:
  """Shell script based image creation workflow generator."""

  def _generate_flags(self):
    return ["#!/usr/bin/env bash", "set -euxo pipefail"]

  def _generate_exit_handler(self):
    body = self._generate_upload_logs() + self._generate_delete_instance(
    ) + self._generate_delete_disk()
    lines = ([
        "", "# Exit trap.", "function exit_handler() {",
        "  echo 'Cleaning up before exiting.'"
    ] + ["  " + line
         for line in body] + ["  sleep 5", "}", "", "trap exit_handler EXIT"])
    return lines

  def _generate_create_log_dir(self):
    return ["", "mkdir -p {log_dir}".format(**self.args)]

  def _generate_upload_logs(self):
    template = ("gsutil -m rsync -r "
                "{log_dir} gs://{bucket_name}/{run_id}/logs/")
    return [
        "echo 'Uploading local logs to GCS bucket.'",
        template.format(**self.args)
    ]

  def _generate_upload_files(self):
    template1 = ("gsutil cp"
                 " {customization_script}"
                 " gs://{bucket_name}/{run_id}/sources/init_actions.sh")
    template2 = "gsutil cp run.sh gs://{bucket_name}/{run_id}/sources/"
    return [
        "echo 'Uploading files to GCS bucket.'",
        template1.format(**self.args),
        template2.format(**self.args)
    ]

  def _generate_create_disk(self):
    template = (
        "gcloud compute disks create {image_name}-install"
        " --project={project_id} --zone={zone}"
        " --image={dataproc_base_image} --type=pd-ssd --size={disk_size}GB")
    return ["echo 'Creating disk.'", template.format(**self.args)]

  def _generate_create_instance(self):
    template = (
        "gcloud compute instances create {image_name}-install"
        " --project={project_id} "
        " --zone={zone}"
        " --machine-type={machine_type}"
        " --disk=auto-delete=yes,boot=yes,mode=rw,name={image_name}-install"
        " --scopes=cloud-platform"
        " --metadata=shutdown-timer-in-sec={shutdown_timer_in_sec},daisy-sources-path={daisy_sources_path},startup-script-url={startup_script_url}"
    )
    if self.args["subnetwork"]:
      template = template + " --subnet={subnetwork}"
    elif self.args["network"]:
      template = template + " --network={network}"
    return [
        "echo 'Creating VM instance to run customization script.'",
        template.format(**self.args)
    ]

  def _generate_wait_for_instance_shutdown(self):
    template = (
        "gcloud compute instances tail-serial-port-output {image_name}-install"
        " --project={project_id} "
        " --zone={zone}"
        " --port=1"
        " 2>&1 | tee {startup_script_log_file}"
        " || true")
    return [
        "echo 'Waiting for VM instance to shutdown.'",
        template.format(**self.args)
    ]

  def _generate_create_image(self):
    template = ("gcloud compute images create {image_name}"
                " --project={project_id} "
                " --source-disk-zone={zone}"
                " --source-disk={image_name}-install"
                " --family={family}")
    return ["echo 'Creating custom image.'", template.format(**self.args)]

  def _generate_delete_instance(self):
    template = ("gcloud compute instances describe {image_name}-install"
                " --project={project_id} --zone={zone} >/dev/null 2>&1"
                " && gcloud compute instances delete {image_name}-install"
                " --project={project_id} --zone={zone} -q")
    return [
        "echo 'Deleting VM instance if needed.'",
        template.format(**self.args)
    ]

  def _generate_delete_disk(self):
    template = ("gcloud compute disks describe {image_name}-install"
                " --project={project_id} --zone={zone} >/dev/null 2>&1"
                " && gcloud compute disks delete {image_name}-install"
                " --project={project_id} --zone={zone} -q")
    return ["echo 'Deleting disk if needed.'", template.format(**self.args)]

  def _generate_main(self):
    body = ([""] + self._generate_upload_files() + [""] +
            self._generate_create_disk() + [""] +
            self._generate_create_instance() + [""] +
            self._generate_wait_for_instance_shutdown() + [""] +
            self._generate_create_image())
    indented_body = ["  " + line for line in body]
    return ([""] + ["function main() {"] + indented_body + ["}"] + [""] +
            self._generate_create_log_dir() +
            ['main "$@" 2>&1 | tee {workflow_log_file}'.format(**self.args)])

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
    self.args["workflow_log_file"] = "{log_dir}/workflow.log".format(
        **self.args)
    self.args[
        "startup_script_log_file"] = "{log_dir}/startup-script.log".format(
            **self.args)

  def generate(self, args):
    self._init_args(args)
    return (self._generate_flags() + self._generate_exit_handler() +
            self._generate_main())
