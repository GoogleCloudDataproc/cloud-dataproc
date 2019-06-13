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
Shell script based custom image creator.
"""

import logging
import os

import shell_script_generator
import shell_script_executor


logging.basicConfig()
_LOG = logging.getLogger(__name__)
_LOG.setLevel(logging.INFO)

def create(args):
  """Creates a custom image with generated Shell script."""

  # Generate Shell script.
  _LOG.info("Generating Shell script...")
  script = shell_script_generator.Generator().generate(vars(args))
  _LOG.info("#" * 60)
  _LOG.info(script)
  _LOG.info("#" * 60)
  _LOG.info("Successfully generated Shell script...")

  # Run the script to build custom image.
  if not args.dry_run:
    _LOG.info("Creating custom image...")
    shell_script_executor.run(script)
    _LOG.info("Successfully created custom image...")
  else:
    _LOG.info("Skip creating custom image (dry run).")
