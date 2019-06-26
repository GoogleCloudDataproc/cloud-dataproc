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
import unittest
import args_parser


class TestArgsParser(unittest.TestCase):

  def test_missing_required_args(self):
    """Verifies it fails if missing required args."""
    with self.assertRaises(SystemExit) as e:
      args_parser.parse_args([])

  def test_minimal_required_args(self):
    """Verifies it succeeds if all required args are present."""
    image_name = 'my-image'
    customization_script = '/tmp/my-script.sh'
    daisy_path = '/opt/daisy'
    zone = 'us-west1-a'
    gcs_bucket = 'gs://my-bucket'

    args = args_parser.parse_args([
        '--image-name', image_name,
        '--customization-script', customization_script,
        '--daisy-path', daisy_path,
        '--zone', zone,
        '--gcs-bucket', gcs_bucket])

    expected_result = self._make_expected_result(
        base_image_uri="None",
        customization_script="'{}'".format(customization_script),
        daisy_path="'{}'".format(daisy_path),
        dataproc_version="None",
        disk_size="15",
        dry_run=False,
        extra_sources="{}",
        family="'dataproc-custom-image'",
        gcs_bucket="'{}'".format(gcs_bucket),
        image_name="'{}'".format(image_name),
        machine_type="'n1-standard-1'",
        network="'{}'".format(''),
        no_external_ip="False",
        no_smoke_test="False",
        oauth="None",
        project_id="None",
        service_account="'default'",
        shutdown_instance_timer_sec="300",
        subnetwork="''",
        zone="'{}'".format(zone)
    )
    self.assertEqual(str(args), expected_result)

  def test_optional_args(self):
    """Verifies it succeeds with optional arguments specified."""
    image_name = 'my-image'
    customization_script = '/tmp/my-script.sh'
    daisy_path = '/opt/daisy'
    zone = 'us-west1-a'
    gcs_bucket = 'gs://my-bucket'
    dataproc_version = '1.4.5-debian9'
    project_id = 'my-project'
    oauth = 'xyz'
    family = 'debian9'
    machine_type = 'n1-standard-4'
    disk_size = 40
    network = 'my-network'
    subnetwork = 'my-subnetwork'
    no_external_ip = True
    no_smoke_test = True
    dry_run = True
    service_account = "my-service-account"
    shutdown_instance_timer_sec = 567

    args = args_parser.parse_args([
        '--customization-script', customization_script,
        '--daisy-path', daisy_path,
        '--dataproc-version', dataproc_version,
        '--disk-size', str(disk_size),
        '--dry-run',
        '--family', family,
        '--gcs-bucket', gcs_bucket,
        '--image-name', image_name,
        '--machine-type', machine_type,
        '--network', network,
        '--no-external-ip',
        '--no-smoke-test',
        '--oauth', oauth,
        '--project-id', project_id,
        '--service-account', service_account,
        '--shutdown-instance-timer-sec', str(shutdown_instance_timer_sec),
        '--subnetwork', subnetwork,
        '--zone', zone,
    ])

    expected_result = self._make_expected_result(
        base_image_uri="None",
        customization_script="'{}'".format(customization_script),
        daisy_path="'{}'".format(daisy_path),
        dataproc_version="'{}'".format(dataproc_version),
        disk_size="{}".format(disk_size),
        dry_run="{}".format(dry_run),
        extra_sources="{}",
        family="'{}'".format(family),
        gcs_bucket="'{}'".format(gcs_bucket),
        image_name="'{}'".format(image_name),
        machine_type="'{}'".format(machine_type),
        network="'{}'".format(network),
        no_external_ip="{}".format(no_external_ip),
        no_smoke_test="{}".format(no_smoke_test),
        oauth="'{}'".format(oauth),
        project_id="'{}'".format(project_id),
        service_account="'{}'".format(service_account),
        shutdown_instance_timer_sec="{}".format(shutdown_instance_timer_sec),
        subnetwork="'{}'".format(subnetwork),
        zone="'{}'".format(zone)
    )
    self.assertEqual(str(args), expected_result)

  def _make_expected_result(
      self,
      base_image_uri,
      customization_script,
      daisy_path,
      dataproc_version,
      disk_size,
      dry_run,
      extra_sources,
      family,
      gcs_bucket,
      image_name,
      machine_type,
      network,
      no_external_ip,
      no_smoke_test,
      oauth,
      project_id,
      service_account,
      shutdown_instance_timer_sec,
      subnetwork,
      zone):
    expected_result_template = (
        "Namespace("
        "base_image_uri={}, "
        "customization_script={}, "
        "daisy_path={}, "
        "dataproc_version={}, "
        "disk_size={}, "
        "dry_run={}, "
        "extra_sources={}, "
        "family={}, "
        "gcs_bucket={}, "
        "image_name={}, "
        "machine_type={}, "
        "network={}, "
        "no_external_ip={}, "
        "no_smoke_test={}, "
        "oauth={}, "
        "project_id={}, "
        "service_account={}, "
        "shutdown_instance_timer_sec={}, "
        "subnetwork={}, "
        "zone={})")
    return expected_result_template.format(
        base_image_uri,
        customization_script,
        daisy_path,
        dataproc_version,
        disk_size,
        dry_run,
        extra_sources,
        family,
        gcs_bucket,
        image_name,
        machine_type,
        network,
        no_external_ip,
        no_smoke_test,
        oauth,
        project_id,
        service_account,
        shutdown_instance_timer_sec,
        subnetwork,
        zone)


  if __name__ == '__main__':
    unittest.main()
