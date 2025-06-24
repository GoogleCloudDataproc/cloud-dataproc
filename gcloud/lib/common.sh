#!/bin/bash
#
# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# This is the main entrypoint for the CUJ shell script library.
# It sources all other library components, making them available to any
# script that sources this file.

# Determine the directory where this script resides to reliably source other files.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# Source all library components.
source "${SCRIPT_DIR}/_core.sh"
source "${SCRIPT_DIR}/_network.sh"
source "${SCRIPT_DIR}/_dataproc.sh"
source "${SCRIPT_DIR}/_database.sh"
source "${SCRIPT_DIR}/_security.sh"
