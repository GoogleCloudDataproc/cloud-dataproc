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
Daisy based custom image creator.
"""

import logging
import os

import daisy_workflow_generator
import daisy_workflow_executor


logging.basicConfig()
_LOG = logging.getLogger(__name__)
_LOG.setLevel(logging.INFO)

def create(args):
  """Creates a custom image with Daisy workflow."""

  # Create Daisy workflow.
  _LOG.info("Generating Daisy workflow script...")
  workflow_script = daisy_workflow_generator.generate(vars(args))
  _LOG.info(workflow_script)
  _LOG.info("Successfully generated Daisy workflow script...")

  # Run Daisy to build custom image.
  if not args.dry_run:
    _LOG.info("Creating custom image with Daisy workflow...")
    daisy_workflow_executor.run(
        os.path.abspath(args.daisy_path), workflow_script)
    _LOG.info("Successfully created custom image with Daisy workflow...")
  else:
    _LOG.info("Skip creating custom image with Daisy workflow (dry run).")
