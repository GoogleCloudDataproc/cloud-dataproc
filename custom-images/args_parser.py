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
This is a utility module which defines and parses the command-line arguments
for the generate_custom_image.py script.
"""

import argparse
import json
import re

import constants


# Old style images: 1.2.3
# New style images: 1.2.3-deb8, 1.2.3-debian9, 1.2.3-RC10-debian9
_VERSION_REGEX = re.compile(r"^\d+\.\d+\.\d+(-RC\d+)?(-[a-z]+\d+)?$")
_FULL_IMAGE_URI = re.compile(r"https:\/\/www\.googleapis\.com\/compute\/([^\/]+)\/projects\/([^\/]+)\/global\/images\/([^\/]+)$")


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

def parse_args(args):
  """Parses command-line arguments."""
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
      "--daisy-path", type=str, required=False, help="""Path to daisy binary.""")
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
      "--no-external-ip",
      action="store_true",
      help="""(Optional) Disables external IP for the image build VM. The VM
      will not be able to access the internet, but if Private Google
      Access is enabled for the subnetwork, it can still access Google services
      (e.g., GCS) through internal IP of the VPC. This flag is ignored when
      --daisy-path is specified.""")
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
      "--dry-run",
      action="store_true",
      help="""(Optional) Only generates script without creating image.""")

  return parser.parse_args(args)
