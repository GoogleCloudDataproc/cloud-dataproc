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
"""Constant variables for building custom image."""

version_help_text = """\
    The dataproc image version to be used for building the custom Dataproc
    image. The image version is in the format of:

        version_major.version_minor.version_patch

    Example:
        1.2.13

    Please refer to https://cloud.google.com/dataproc/docs/concepts/versioning/overview
    for more information on image versions.
    """

notify_expiration_text = """\


#####################################################################
  WARNING: DATAPROC CUSTOM IMAGE '{}'
           WILL EXPIRE ON {}.
#####################################################################

"""

daisy_wf = """\
{{
    "Name": "{image_name}",
    "Project": "{project_id}",
    "Sources": {{
        {sources}
    }},
    "Zone": "{zone}",{oauth}
    "GCSPath": "{gcs_bucket}",
    "Steps": {{
        "create-disks": {{
            "CreateDisks": [
                {{
                    "Name": "{image_name}-install",
                    "SourceImage": "{dataproc_base_image}",
                    "Type": "pd-ssd",
                    "SizeGb": "{disk_size}"
                }}
            ]
        }},
        "create-inst-install": {{
            "CreateInstances": [
                {{
                    "Name": "{image_name}-install",
                    "Disks": [{{"Source": "{image_name}-install"}}],
                    "MachineType": "{machine_type}",
                    "NetworkInterfaces": [{{"network": "{network}", "subnetwork": "{subnetwork}"}}],
                    "ServiceAccounts": [{{"Email": "{service_account}", "Scopes": ["https://www.googleapis.com/auth/cloud-platform"]}}],
                    "StartupScript": "run.sh",
                    "Metadata": {{"shutdown-timer-in-sec" : "{shutdown_timer_in_sec}"}}
                }}
            ]
        }},
        "wait-for-inst-install": {{
            "TimeOut": "2h",
            "waitForInstancesSignal": [
                {{
                    "Name": "{image_name}-install",
                    "SerialOutput": {{
                      "Port": 1,
                      "FailureMatch": "BuildFailed:",
                      "SuccessMatch": "BuildSucceeded:"
                    }}
                }}
            ]
        }},
        "wait-for-inst-shutdown": {{
            "TimeOut": "2h",
            "waitForInstancesSignal": [
                {{
                    "Name": "{image_name}-install",
                    "Stopped": true
                }}
            ]
        }},
        "create-image": {{
            "CreateImages": [
                {{
                    "Name": "{image_name}",
                    "SourceDisk": "{image_name}-install",
                    "NoCleanup": true,
                    "ExactName": true,
                    "Family": "{family}"
                }}
            ]
        }},
        "delete-inst-install": {{
            "DeleteResources": {{
                "Instances": ["{image_name}-install"]
            }}
        }}
    }},
    "Dependencies": {{
        "create-inst-install": ["create-disks"],
        "wait-for-inst-install": ["create-inst-install"],
        "wait-for-inst-shutdown": ["wait-for-inst-install"],
        "create-image": ["wait-for-inst-shutdown"],
        "delete-inst-install": ["create-image"]
    }}
}}\
"""
