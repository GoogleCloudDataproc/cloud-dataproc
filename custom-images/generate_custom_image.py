# Copyright 2017 Google Inc. All Rights Reserved.
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
"""Generate custom Dataproc image.

This python script is used to generate a custom Dataproc image for the user.

With the required arguments such as custom install packages script and
Dataproc version, this script will run the following steps in order:
  1. Get user's gcloud project ID.
  2. Get Dataproc's base image name with Dataproc version.
  3. Run Daisy workflow (on GCE) to create a custom Dataproc image.
    1. Create a disk with Dataproc's base image.
    2. Create an GCE instance with the disk.
    3. Run custom install packages script to install custom packages.
    4. Shutdown instance.
    5. Create custom Dataproc image from the disk.
  4. Set the custom image label (required for launching custom Dataproc image).
  5. Run a Dataproc workflow to smoke test the custom image.

Once this script is completed, the custom Dataproc image should be ready to use.

"""

import argparse
import datetime
import logging
import os
import re
import subprocess
import tempfile
import uuid

import constants

_VERSION_REGEX = re.compile(r"^\d+\.\d+\.\d+$")
_IMAGE_URI = "projects/cloud-dataproc/global/images/{}"
logging.basicConfig()
_LOG = logging.getLogger(__name__)
_LOG.setLevel(logging.INFO)

def _version_regex_type(s):
  """Check if version string matches regex."""
  if not _VERSION_REGEX.match(s):
    raise argparse.ArgumentTypeError
  return s


def get_project_id():
  """Get project id from gcloud config."""
  gcloud_command = ["gcloud", "config", "get-value", "project"]
  with tempfile.NamedTemporaryFile() as temp_file:
    pipe = subprocess.Popen(gcloud_command, stdout=temp_file)
    pipe.wait()
    if pipe.returncode != 0:
      raise RuntimeError("Cannot find gcloud project ID. "
                         "Please setup the project ID in gcloud SDK")
    # get proejct id
    temp_file.seek(0)
    stdout = temp_file.read()
    return stdout.decode('utf-8').strip()


def get_dataproc_base_image(version):
  """Get Dataproc base image name from version."""
  # version regex already checked in arg parser
  parsed_version = version.split(".")
  filter_arg = "--filter=labels.goog-dataproc-version=\'{}-{}-{}\'".format(
      parsed_version[0], parsed_version[1], parsed_version[2])
  command = ["gcloud", "compute", "images", "list", "--project",
             "cloud-dataproc", filter_arg,
             "--format=csv[no-heading=true](name,status)"]

  # get stdout from compute images list --filters
  with tempfile.NamedTemporaryFile() as temp_file:
    pipe = subprocess.Popen(command, stdout=temp_file)
    pipe.wait()
    if pipe.returncode != 0:
      raise RuntimeError(
          "Cannot find dataproc base image, please check and verify "
          "[--dataproc-version]")

    temp_file.seek(0)  # go to start of the stdout
    stdout = temp_file.read()
    # parse the first ready image with the dataproc version attached in labels
    if stdout:
      parsed_line = stdout.decode('utf-8').strip().split(",")  # should only be one image
      if len(parsed_line) == 2 and parsed_line[0] and parsed_line[1] == "READY":
        return _IMAGE_URI.format(parsed_line[0])

  raise RuntimeError("Cannot find dataproc base image with "
                     "dataproc-version=%s.", version)


def run_daisy(daisy_path, workflow):
  """Run Daisy workflow."""
  if not os.path.isfile(daisy_path):
    raise RuntimeError("Invalid path to Daisy binary: '%s' is not a file.",
                       daisy_path)

  # write workflow to file
  temp_file = tempfile.NamedTemporaryFile(delete=False)
  try:
    temp_file.write(workflow.encode("utf-8"))
    temp_file.flush()
    temp_file.close()  # close this file but do not delete

    # run daisy workflow, which reads the temp file
    pipe = subprocess.Popen([daisy_path, temp_file.name])
    pipe.wait()  # wait for daisy workflow to complete
    if pipe.returncode != 0:
      raise RuntimeError("Error building custom image.")
  finally:
    try:
      os.remove(temp_file.name)  # delete temp file
    except OSError:
      pass


def set_custom_image_label(image_name, version, project_id):
  """Set Dataproc version label in the newly built custom image."""
  # version regex already checked in arg parser
  parsed_version = version.split(".")
  filter_arg = "--labels=goog-dataproc-version={}-{}-{}".format(
      parsed_version[0], parsed_version[1], parsed_version[2])
  command = ["gcloud", "compute", "images", "add-labels",
             image_name, "--project", project_id, filter_arg]

  # get stdout from compute images list --filters
  pipe = subprocess.Popen(command)
  pipe.wait()
  if pipe.returncode != 0:
    raise RuntimeError(
        "Cannot set dataproc version to image label.")


def get_custom_image_creation_timestamp(image_name, project_id):
  """Get the creation timestamp of the custom image."""
  # version regex already checked in arg parser
  command = [
      "gcloud", "compute", "images", "describe", image_name, "--project",
      project_id, "--format=csv[no-heading=true](creationTimestamp)"
  ]

  with tempfile.NamedTemporaryFile() as temp_file:
    pipe = subprocess.Popen(command, stdout=temp_file)
    pipe.wait()
    if pipe.returncode != 0:
      raise RuntimeError("Cannot get custom image creation timestamp.")

    # get creation timestamp
    temp_file.seek(0)
    stdout = temp_file.read()
    return stdout.decode('utf-8').strip()


def _parse_date_time(timestamp_string):
  """Parse a timestamp string (RFC3339) to datetime format."""
  return datetime.datetime.strptime(timestamp_string[:-6],
                                    "%Y-%m-%dT%H:%M:%S.%f")


def _create_workflow_template(workflow_name, image_name, project_id, zone):
  """Create a Dataproc workflow template for testing."""

  create_command = [
      "gcloud", "beta", "dataproc", "workflow-templates", "create",
      workflow_name, "--project", project_id
  ]
  set_cluster_command = [
      "gcloud", "beta", "dataproc", "workflow-templates", "set-managed-cluster",
      workflow_name, "--project", project_id, "--image", image_name, "--zone",
      zone
  ]
  add_job_command = [
      "gcloud", "beta", "dataproc", "workflow-templates", "add-job", "spark",
      "--workflow-template", workflow_name, "--project", project_id,
      "--step-id", "001", "--class", "org.apache.spark.examples.SparkPi",
      "--jars", "file:///usr/lib/spark/examples/jars/spark-examples.jar", "--",
      "1000"
  ]
  pipe = subprocess.Popen(create_command)
  pipe.wait()
  if pipe.returncode != 0:
    raise RuntimeError("Error creating Dataproc workflow template '%s'.",
                       workflow_name)

  pipe = subprocess.Popen(set_cluster_command)
  pipe.wait()
  if pipe.returncode != 0:
    raise RuntimeError(
        "Error setting cluster for Dataproc workflow template '%s'.",
        workflow_name)

  pipe = subprocess.Popen(add_job_command)
  pipe.wait()
  if pipe.returncode != 0:
    raise RuntimeError("Error adding job to Dataproc workflow template '%s'.",
                       workflow_name)


def _instantiate_workflow_template(workflow_name, project_id):
  """Run a Dataproc workflow template to test the newly built custom image."""
  command = [
      "gcloud", "beta", "dataproc", "workflow-templates", "instantiate",
      workflow_name, "--project", project_id
  ]
  pipe = subprocess.Popen(command)
  pipe.wait()
  if pipe.returncode != 0:
    raise RuntimeError("Unable to instantiate workflow template.")


def _delete_workflow_template(workflow_name, project_id):
  """Delete a Dataproc workflow template."""
  command = [
      "gcloud", "beta", "dataproc", "workflow-templates", "delete",
      workflow_name, "-q", "--project", project_id
  ]
  pipe = subprocess.Popen(command)
  pipe.wait()
  if pipe.returncode != 0:
    raise RuntimeError("Error deleting workfloe template %s.", workflow_name)


def verify_custom_image(image_name, project_id, zone):
  """Verifies if custom image works with Dataproc."""

  date = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
  # Note: workflow_name can collide if the script runs more than 10000
  # times/second.
  workflow_name = "verify-image-{}-{}".format(date, uuid.uuid4().hex[-8:])
  try:
    _LOG.info("Creating Dataproc workflow-template %s with image %s...",
              workflow_name, image_name)
    _create_workflow_template(workflow_name, image_name, project_id, zone)
    _LOG.info(
        "Successfully created Dataproc workflow-template %s with image %s...",
        workflow_name, image_name)
    _LOG.info("Smoke testing Dataproc workflow-template %s...")
    _instantiate_workflow_template(workflow_name, project_id)
    _LOG.info("Successfully smoke tested Dataproc workflow-template %s...",
              workflow_name)
  except RuntimeError as e:
    err_msg = "Verification of custom image {} failed: {}".format(image_name, e)
    _LOG.error(err_msg)
    raise RuntimeError(err_msg)
  finally:
    try:
      _LOG.info("Deleting Dataproc workflow-template %s...", workflow_name)
      _delete_workflow_template(workflow_name, project_id)
      _LOG.info("Successfully deleted Dataproc workflow-template %s...",
                workflow_name)
    except RuntimeError:
      pass


def run():
  """Generate custom image."""
  parser = argparse.ArgumentParser()
  required_args = parser.add_argument_group("required named arguments")
  required_args.add_argument(
      "--image-name",
      type=str,
      required=True,
      help="""The image name for the Dataproc custom image.""")
  required_args.add_argument(
      "--dataproc-version",
      type=_version_regex_type,
      required=True,
      help=constants.version_help_text)
  required_args.add_argument(
      "--customization-script",
      type=str,
      required=True,
      help="""User's script to install custom packages.""")
  required_args.add_argument(
      "--daisy-path", type=str, required=True, help="""Path to daisy binary.""")
  required_args.add_argument(
      "--zone",
      type=str,
      required=True,
      help="""GCE zone used to build the custom image.""")
  required_args.add_argument(
      "--gcs-bucket",
      type=str,
      required=True,
      help="""GCS bucket used by daisy to store files and logs when
      building custom image.""")
  parser.add_argument(
      "--project-id",
      type=str,
      required=False,
      help="""The project Id of the project where the custom image will be
      created and saved. The default value will be set to the project id
      specified by `gcloud config get-value project`.""")
  parser.add_argument(
      "--oauth",
      type=str,
      required=False,
      help="""A local path to JSON credentials for your GCE project.
      The default oauth is the application-default credentials from gcloud.""")
  parser.add_argument(
      "--machine-type",
      type=str,
      required=False,
      default="n1-standard-1",
      help="""(Optional) Machine type used to build custom image.
      Default machine type is n1-standard-1.""")
  parser.add_argument(
      "--no-smoke-test",
      action="store_true",
      help="""(Optional) Disables smoke test to verify if the custom image
      can create a functional Dataproc cluster.""")
  parser.add_argument(
      "--network",
      type=str,
      required=False,
      default="global/networks/default",
      help="""(Optional) Network interface used to launch the VM instance that
      builds the custom image. Default network is 'global/networks/default'.
      If the default network does not exist in your project, please specify
      a valid network interface.""")
  parser.add_argument(
      "--subnetwork",
      type=str,
      required=False,
      default="",
      help="""(Optional) The subnetwork that is used to launch the VM instance
      that builds the custom image. A full subnetwork URL is required.
      Default subnetwork is None.""")
  parser.add_argument(
      "--service-account",
      type=str,
      required=False,
      default="default",
      help=
      """(Optional) The service account that is used to launch the VM instance
      that builds the custom image. If not specified, Daisy would use the
      default service account under the GCE project. The scope of this service
      account is defaulted to /auth/cloud-platform.""")

  args = parser.parse_args()

  # get dataproc base image from dataproc version
  project_id = get_project_id() if not args.project_id else args.project_id
  _LOG.info("Getting Dataproc base image name...")
  dataproc_base_image = get_dataproc_base_image(args.dataproc_version)
  _LOG.info("Returned Dataproc base image: %s", dataproc_base_image)

  run_script_path = os.path.join(
      os.path.dirname(os.path.realpath(__file__)), "run.sh")

  oauth = ""
  if args.oauth:
    oauth = "\n    \"OAuthPath\": \"{}\",".format(
        os.path.abspath(args.oauth))

  # create daisy workflow
  _LOG.info("Created Daisy workflow...")
  workflow = constants.daisy_wf.format(
      image_name=args.image_name,
      project_id=project_id,
      install_script=os.path.abspath(args.customization_script),
      run_script=run_script_path,
      zone=args.zone,
      oauth=oauth,
      gcs_bucket=args.gcs_bucket,
      dataproc_base_image=dataproc_base_image,
      machine_type=args.machine_type,
      network=args.network,
      subnetwork=args.subnetwork,
      service_account=args.service_account)

  _LOG.info("Successfully created Daisy workflow...")

  # run daisy to build custom image
  _LOG.info("Creating custom image with Daisy workflow...")
  run_daisy(os.path.abspath(args.daisy_path), workflow)
  _LOG.info("Successfully created custom image with Daisy workflow...")

  # set custom image label
  _LOG.info("Setting label on custom image...")
  set_custom_image_label(args.image_name, args.dataproc_version,
                         project_id)
  _LOG.info("Successfully set label on custom image...")

  # perform test on the newly built image
  if not args.no_smoke_test:
    _LOG.info("Verifying the custom image...")
    verify_custom_image(args.image_name, project_id, args.zone)
    _LOG.info("Successfully verified the custom image...")

  _LOG.info("Successfully built Dataproc custom image: %s",
            args.image_name)

  # notify when the image will expire.
  creation_date = _parse_date_time(
      get_custom_image_creation_timestamp(args.image_name, project_id))
  expiration_date = creation_date + datetime.timedelta(days=30)
  _LOG.info(
      constants.notify_expiration_text.format(args.image_name,
                                              str(expiration_date)))


if __name__ == "__main__":
  run()
