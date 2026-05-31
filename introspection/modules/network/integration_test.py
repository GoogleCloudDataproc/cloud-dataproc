import unittest
import os
import subprocess
import time
from googleapiclient import discovery
import google.auth

class TestCheckNetworkIntegration(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        try:
            cls.credentials, cls.project_id = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
            cls.service = discovery.build('compute', 'v1', credentials=cls.credentials)
            cls.region = os.environ.get('REGION')
            if not cls.region:
                raise EnvironmentError("REGION env var not set")
            if not os.environ.get('GOOGLE_CLOUD_PROJECT'):
                raise EnvironmentError("GOOGLE_CLOUD_PROJECT env var not set")
            cls.project_id = os.environ['GOOGLE_CLOUD_PROJECT']
        except Exception as e:
            raise unittest.SkipTest(f"GCP setup failed: {e}")

    def run_check_network(self, env_vars={}):
        env = os.environ.copy()
        env.update(env_vars)
        # Ensure required env vars for check_network.py are set
        env["PROJECT_ID"] = self.project_id
        env["REGION"] = self.region
        env["INSPECT_MODULES"] = "network"

        process = subprocess.Popen(
            ['python', '../inspect_env.py'],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=env
        )
        stdout, stderr = process.communicate()
        return process.returncode, stdout, stderr

    def _wait_for_operation(self, operation):
        while operation['status'] != 'DONE':
            time.sleep(2)
            op_name = operation['name']
            try:
                if 'zone' in operation:
                    operation = self.service.zoneOperations().get(project=self.project_id, zone=operation['zone'].split('/')[-1], operation=op_name).execute()
                elif 'region' in operation:
                    operation = self.service.regionOperations().get(project=self.project_id, region=operation['region'].split('/')[-1], operation=op_name).execute()
                else:
                    operation = self.service.globalOperations().get(project=self.project_id, operation=op_name).execute()
            except Exception as e:
                print(f"Error fetching operation {op_name}: {e}")
                time.sleep(5) # Wait longer if get fails
                continue

            if 'error' in operation:
                raise Exception(f"Operation failed: {operation['error']}")
        return operation

    def test_01_detect_existing_network(self):
        network_name = f"test-net-exist-{int(time.time())}"
        env_vars = {
            "NETWORK": network_name,
            "SUBNET": "dummy-subnet"
        }

        # Setup: Create the network
        try:
            network_body = {
                "name": network_name,
                "autoCreateSubnetworks": False
            }
            insert_op = self.service.networks().insert(project=self.project_id, body=network_body).execute()
            self._wait_for_operation(insert_op)
            print(f"Network {network_name} created.")

            # Execute the tool
            returncode, stdout, stderr = self.run_check_network(env_vars)
            print(f"STDOUT:
{stdout}")
            print(f"STDERR:
{stderr}")

            # Assertions
            self.assertIn(f"Checking Network '{network_name}'", stdout)
            self.assertIn(f"[PASS] VPC '{network_name}' exists.", stdout)
            self.assertIn(f"[PASS] VPC '{network_name}' is in custom subnet mode.", stdout)
            self.assertEqual(returncode, 0, f"check_network.py failed with stderr: {stderr}")

        finally:
            # Teardown: Delete the network
            try:
                print(f"Deleting network {network_name}...")
                delete_op = self.service.networks().delete(project=self.project_id, network=network_name).execute()
                self._wait_for_operation(delete_op)
                print(f"Network {network_name} deleted.")
            except Exception as e:
                print(f"Warning: Failed to delete network {network_name}: {e}")

    def test_02_detect_missing_network(self):
        network_name = f"test-net-missing-{int(time.time())}"
        env_vars = {
            "NETWORK": network_name,
            "SUBNET": "dummy-subnet"
        }

        # Setup: Ensure network does not exist

        # Execute the tool
        returncode, stdout, stderr = self.run_check_network(env_vars)
        print(f"STDOUT:
{stdout}")
        print(f"STDERR:
{stderr}")

        # Assertions
        self.assertIn(f"Checking Network '{network_name}'", stdout)
        self.assertIn(f"[FAIL] VPC '{network_name}' does not exist.", stdout)
        # The script should return non-zero if any check fails
        self.assertNotEqual(returncode, 0, "check_network.py should indicate failure")

    # TODO: Add tests for subnetwork creation/detection and PGA status
    # TODO: Add tests for firewall rules

if __name__ == '__main__':
    unittest.main()
