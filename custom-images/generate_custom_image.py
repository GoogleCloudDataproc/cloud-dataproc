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
import json
import logging
import os
import re
import subprocess
import tempfile
import uuid

import constants

# Old style images: 1.2.3
# New style images: 1.2.3-deb8, 1.2.3-debian9, 1.2.3-RC10-debian9
_VERSION_REGEX = re.compile(r"^\d+\.\d+\.\d+(-RC\d+)?(-[a-z]+\d+)?$")
_IMAGE_URI = "projects/{}/global/images/{}"
_FULL_IMAGE_URI = re.compile(r"https:\/\/www\.googleapis\.com\/compute\/([^\/]+)\/projects\/([^\/]+)\/global\/images\/([^\/]+)$")
logging.basicConfig()
_LOG = logging.getLogger(__name__)
_LOG.setLevel(logging.INFO)

def _version_regex_type(s):
  """Check if version string matches regex."""
  if not _VERSION_REGEX.match(s):
    raise argparse.ArgumentTypeError("Invalid version: {}.".format(s))
  return s

def _full_image_uri_regex_type(s):
  """Check if the partial image uri string matches regex."""
  if not _FULL_IMAGE_URI.match(s):
    raise argparse.ArgumentTypeError("Invalid image URI: {}.".format(s))
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

def _get_image_name_and_project(uri):
  """Get Dataproc image name and project."""
  m = _FULL_IMAGE_URI.match(uri)
  return m.group(2), m.group(3) # project, image_name

def get_dataproc_image_version(uri):
  """Get Dataproc image version from image URI."""
  project, image_name = _get_image_name_and_project(uri)
  command = ["gcloud", "compute", "images", "describe",
             image_name, "--project", project,
             "--format=value(labels.goog-dataproc-version)"]

  # get stdout from compute images list --filters
  with tempfile.NamedTemporaryFile() as temp_file:
    pipe = subprocess.Popen(command, stdout=temp_file)
    pipe.wait()
    if pipe.returncode != 0:
      raise RuntimeError(
          "Cannot find dataproc base image, please check and verify "
          "the base image URI.")

    temp_file.seek(0)  # go to start of the stdout
    stdout = temp_file.read()
    # parse the first ready image with the dataproc version attached in labels
    if stdout:
      parsed_line = stdout.decode('utf-8').strip()  # should be just one value
      return parsed_line

  raise RuntimeError("Cannot find dataproc base image: %s", uri)


def get_partial_image_uri(uri):
  """Get the partial image URI from the full image URI."""
  project, image_name = _get_image_name_and_project(uri)
  return _IMAGE_URI.format(project, image_name)

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
        return _IMAGE_URI.format('cloud-dataproc', parsed_line[0])

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


def set_custom_image_label(image_name, version, project_id, parsed=False):
  """Set Dataproc version label in the newly built custom image."""
  # parse the verions if version is still in the format of
  # <major>.<minor>.<subminor>.
  if not parsed:
    # version regex already checked in arg parser
    parsed_version = version.split(".")
    filter_arg = "--labels=goog-dataproc-version={}-{}-{}".format(
        parsed_version[0], parsed_version[1], parsed_version[2])
  else:
    # in this case, the version is already in the format of
    # <major>-<minor>-<subminor>
    filter_arg = "--labels=goog-dataproc-version={}".format(version)
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


def _create_workflow_template(workflow_name, image_name, project_id, zone, subnet):
  """Create a Dataproc workflow template for testing."""

  create_command = [
      "gcloud", "beta", "dataproc", "workflow-templates", "create",
      workflow_name, "--project", project_id
  ]
  set_cluster_command = [
      "gcloud", "beta", "dataproc", "workflow-templates", "set-managed-cluster",
      workflow_name, "--project", project_id, "--image", image_name, "--zone",
      zone, "--subnet", subnet
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


def verify_custom_image(image_name, project_id, zone, subnetwork):
  """Verifies if custom image works with Dataproc."""

  date = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
  # Note: workflow_name can collide if the script runs more than 10000
  # times/second.
  workflow_name = "verify-image-{}-{}".format(date, uuid.uuid4().hex[-8:])
  try:
    _LOG.info("Creating Dataproc workflow-template %s with image %s...",
              workflow_name, image_name)
    _create_workflow_template(workflow_name, image_name, project_id, zone, subnetwork)
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
  image_args = required_args.add_mutually_exclusive_group()
  image_args.add_argument(
      "--dataproc-version",
      type=_version_regex_type,
      help=constants.version_help_text)
  image_args.add_argument(
      "--base-image-uri",
      type=_full_image_uri_regex_type,
      help="""The full image URI for the base Dataproc image. The
      customiziation script will be executed on top of this image instead of
      an out-of-the-box Dataproc image. This image must be a valid Dataproc
      image.
      """)
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
      "--family",
      type=str,
      required=False,
      default='dataproc-custom-image',
      help="""(Optional) The family of the image.""")
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
      default="",
      help="""(Optional) Network interface used to launch the VM instance that
      builds the custom image. Default network is 'global/networks/default'
      when no network and subnetwork arguments are provided.
      If the default network does not exist in your project, please specify
      a valid network interface.""")
  parser.add_argument(
      "--subnetwork",
      type=str,
      required=False,
      default="",
      help="""(Optional) The subnetwork that is used to launch the VM instance
      that builds the custom image. A full subnetwork URL is required.
      Default subnetwork is None. For shared VPC only provide this parameter and
      do not use the --network argument.""")
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
  parser.add_argument(
      "--extra-sources",
      type=json.loads,
      required=False,
      default={},
      help=
      """(Optional) Additional files/directories uploaded along with
      customization script. This argument is evaluated to a json dictionary.
      Read more about sources in daisy https://googlecloudplatform.github.io/
      compute-image-tools/daisy-workflow-config-spec.html#sources.
      For example:
      '--extra-sources "{\\"notes.txt\\": \\"/path/to/notes.txt\\"}"'
      """)
  parser.add_argument(
      "--disk-size",
      type=int,
      required=False,
      default=15,
      help=
      """(Optional) The size in GB of the disk attached to the VM instance
      that builds the custom image. If not specified, the default value of
      15 GB will be used.""")
  parser.add_argument(
      "--shutdown-instance-timer-sec",
      type=int,
      required=False,
      default=300,
      help=
      """(Optional) The time to wait in seconds before shutting down the VM
      instance. This value may need to be increased if your init script
      generates a lot of output on stdout. If not specified, the default value
      of 300 seconds will be used.""")
  parser.add_argument(
       "--expire-days",
       type=int,
       required=False,
       default=30,
       help=
       """(Optional) The number of days from creation date when the custom image
       will expire. If not specified, the default value of 30 days will be
       used.""")

  args = parser.parse_args()

  # get dataproc base image from dataproc version
  project_id = get_project_id() if not args.project_id else args.project_id
  _LOG.info("Getting Dataproc base image name...")
  parsed_image_version = False
  if args.base_image_uri:
    dataproc_base_image = get_partial_image_uri(args.base_image_uri)
    dataproc_version = get_dataproc_image_version(args.base_image_uri)
    parsed_image_version = True
  else:
    dataproc_base_image = get_dataproc_base_image(args.dataproc_version)
    dataproc_version = args.dataproc_version
  _LOG.info("Returned Dataproc base image: %s", dataproc_base_image)
  run_script_path = os.path.join(
      os.path.dirname(os.path.realpath(__file__)), "run.sh")

  oauth = ""
  if args.oauth:
    oauth = "\n    \"OAuthPath\": \"{}\",".format(
        os.path.abspath(args.oauth))

  daisy_sources = {
    "run.sh": run_script_path,
    "init_actions.sh": os.path.abspath(args.customization_script)
  }
  daisy_sources.update(args.extra_sources)

  sources = ",\n".join(["\"{}\": \"{}\"".format(source, path)
                        for source, path in daisy_sources.items()])
  network = args.network
  # When the user wants to create a VM in a shared VPC,
  # only the subnetwork argument has to be provided whereas
  # the network one has to be left empty.
  if not args.network and not args.subnetwork:
    network = 'global/networks/default'

  # create daisy workflow
  _LOG.info("Created Daisy workflow...")
  workflow = constants.daisy_wf.format(
      image_name=args.image_name,
      project_id=project_id,
      sources=sources,
      zone=args.zone,
      oauth=oauth,
      gcs_bucket=args.gcs_bucket,
      family=args.family,
      dataproc_base_image=dataproc_base_image,
      machine_type=args.machine_type,
      network=network,
      subnetwork=args.subnetwork,
      service_account=args.service_account,
      disk_size=args.disk_size,
      shutdown_timer_in_sec=args.shutdown_instance_timer_sec)

  _LOG.info("Successfully created Daisy workflow...")

  # run daisy to build custom image
  _LOG.info("Creating custom image with Daisy workflow...")
  run_daisy(os.path.abspath(args.daisy_path), workflow)
  _LOG.info("Successfully created custom image with Daisy workflow...")

  # set custom image label
  _LOG.info("Setting label on custom image...")
  set_custom_image_label(args.image_name, dataproc_version,
                         project_id, parsed_image_version)
  _LOG.info("Successfully set label on custom image...")

  # perform test on the newly built image
  if not args.no_smoke_test:
    _LOG.info("Verifying the custom image...")
    verify_custom_image(args.image_name, project_id, args.zone, args.subnetwork)
    _LOG.info("Successfully verified the custom image...")

  _LOG.info("Successfully built Dataproc custom image: %s",
            args.image_name)

  # notify when the image will expire.
  creation_date = _parse_date_time(
      get_custom_image_creation_timestamp(args.image_name, project_id))
  expiration_date = creation_date + datetime.timedelta(days=args.expire_days)
  _LOG.info(
      constants.notify_expiration_text.format(args.image_name,
                                              str(expiration_date)))


if __name__ == "__main__":
  run()
