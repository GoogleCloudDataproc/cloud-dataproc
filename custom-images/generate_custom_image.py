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
  3. Run Shell script or Daisy workflow to create a custom Dataproc image.
    1. Create a disk with Dataproc's base image.
    2. Create an GCE instance with the disk.
    3. Run custom install packages script to install custom packages.
    4. Shutdown instance.
    5. Create custom Dataproc image from the disk.
  4. Set the custom image label (required for launching custom Dataproc image).
  5. Run a Dataproc workflow to smoke test the custom image.

Once this script is completed, the custom Dataproc image should be ready to use.

"""

import datetime
import logging
import os
import re
import subprocess
import sys
import tempfile
import uuid

import args_parser
import constants
import daisy_image_creator
import shell_image_creator


_IMAGE_URI = "projects/{}/global/images/{}"
_FULL_IMAGE_URI = re.compile(r"https:\/\/www\.googleapis\.com\/compute\/([^\/]+)\/projects\/([^\/]+)\/global\/images\/([^\/]+)$")
logging.basicConfig()
_LOG = logging.getLogger(__name__)
_LOG.setLevel(logging.INFO)

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


def _create_workflow_template(workflow_name, image_name, project_id, zone, network, subnet):
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
  if network and not subnet:
    set_cluster_command.extend(["--network", network])
  else:
    set_cluster_command.extend(["--subnet", subnet])
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


def verify_custom_image(image_name, project_id, zone, network, subnetwork):
  """Verifies if custom image works with Dataproc."""

  date = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
  # Note: workflow_name can collide if the script runs more than 10000
  # times/second.
  workflow_name = "verify-image-{}-{}".format(date, uuid.uuid4().hex[-8:])
  try:
    _LOG.info("Creating Dataproc workflow-template %s with image %s...",
              workflow_name, image_name)
    _create_workflow_template(
        workflow_name, image_name, project_id, zone, network, subnetwork)
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


def infer_args(args):
  if not args.project_id:
    args.project_id = get_project_id()

  # get dataproc base image from dataproc version
  _LOG.info("Getting Dataproc base image name...")
  args.parsed_image_version = False
  if args.base_image_uri:
    args.dataproc_base_image = get_partial_image_uri(args.base_image_uri)
    args.dataproc_version = get_dataproc_image_version(args.base_image_uri)
    args.parsed_image_version = True
  else:
    args.dataproc_base_image = get_dataproc_base_image(args.dataproc_version)
    args.dataproc_version = args.dataproc_version
  _LOG.info("Returned Dataproc base image: %s", args.dataproc_base_image)

  if args.oauth:
    args.oauth = "\n    \"OAuthPath\": \"{}\",".format(
        os.path.abspath(args.oauth))
  else:
    args.oauth = ""

  # Daisy sources
  if args.daisy_path:
    run_script_path = os.path.join(
        os.path.dirname(os.path.realpath(__file__)), "run.sh")
    daisy_sources = {
      "run.sh": run_script_path,
      "init_actions.sh": os.path.abspath(args.customization_script)
    }
    daisy_sources.update(args.extra_sources)
    args.sources = ",\n".join(["\"{}\": \"{}\"".format(source, path)
                          for source, path in daisy_sources.items()])

  # When the user wants to create a VM in a shared VPC,
  # only the subnetwork argument has to be provided whereas
  # the network one has to be left empty.
  if not args.network and not args.subnetwork:
    args.network = 'global/networks/default'
  # The --network flag requires format global/networks/<network>, which works
  # for Daisy but not for gcloud, here we convert it to
  # projects/<project>/global/networks/<network>, so that works for both.
  if args.network.startswith('global/networks/'):
    args.network = 'projects/{}/{}'.format(args.project_id, args.network)

  args.shutdown_timer_in_sec = args.shutdown_instance_timer_sec


def parse_args(raw_args):
  """Parses and infers command line arguments."""

  args = args_parser.parse_args(raw_args)
  _LOG.info("Parsed args: {}".format(args))
  infer_args(args)
  _LOG.info("Inferred args: {}".format(args))
  return args


def perform_sanity_checks(args):
  _LOG.info("Performing sanity checks...")

  # Daisy binary
  if args.daisy_path and not os.path.isfile(args.daisy_path):
    raise Exception("Invalid path to Daisy binary: '{}' is not a file.".format(
        args.daisy_path))

  # Customization script
  if not os.path.isfile(args.customization_script):
    raise Exception("Invalid path to customization script: '{}' is not a file.".format(
        args.customization_script))

  # Check the image doesn't already exist.
  command = "gcloud compute images describe {} --project={}".format(
      args.image_name, args.project_id)
  with open(os.devnull, 'w') as devnull:
    pipe = subprocess.Popen(
        [command], stdout=devnull, stderr=devnull, shell=True)
    pipe.wait()
    if pipe.returncode == 0:
      raise RuntimeError("Image {} already exists.".format(args.image_name))

  _LOG.info("Passed sanity checks...")


def add_label(args):
  """Sets custom image label."""

  if not args.dry_run:
    _LOG.info("Setting label on custom image...")
    set_custom_image_label(args.image_name, args.dataproc_version,
                           args.project_id, args.parsed_image_version)
    _LOG.info("Successfully set label on custom image...")
  else:
    _LOG.info("Skip setting label on custom image (dry run).")


def run_smoke_test(args):
  """Runs smoke test."""

  if not args.dry_run:
    if not args.no_smoke_test:
      _LOG.info("Verifying the custom image...")
      verify_custom_image(
          args.image_name,
          args.project_id,
          args.zone,
          args.network,
          args.subnetwork)
      _LOG.info("Successfully verified the custom image...")
  else:
    _LOG.info("Skip running smoke test (dry run).")


def notify_expiration(args):
  """Notifies when the image will expire."""

  if not args.dry_run:
    _LOG.info("Successfully built Dataproc custom image: %s", args.image_name)
    creation_date = _parse_date_time(
        get_custom_image_creation_timestamp(args.image_name, args.project_id))
    expiration_date = creation_date + datetime.timedelta(days=60)
    _LOG.info(
        constants.notify_expiration_text.format(args.image_name,
                                                str(expiration_date)))
  else:
    _LOG.info("Dry run succeeded.")

def run():
  """Generates custom image."""

  args = parse_args(sys.argv[1:])
  perform_sanity_checks(args)
  if args.daisy_path:
    daisy_image_creator.create(args)
  else:
    shell_image_creator.create(args)
  add_label(args)
  run_smoke_test(args)
  notify_expiration(args)


if __name__ == "__main__":
  run()
