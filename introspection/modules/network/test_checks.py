import unittest
from unittest import mock
import os
from googleapiclient.errors import HttpError
import io

# Mock google.auth before importing check_network
with mock.patch('google.auth.default', return_value=(mock.MagicMock(), None)):
    from modules.network.checks import check_vpc, check_subnetwork, run_checks

class TestCheckNetwork(unittest.TestCase):

    def setUp(self):
        self.mock_service = mock.MagicMock()
        self.project_id = "test-project"
        self.region = "us-central1"
        self.network_name = "test-network"
        self.subnet_name = "test-subnet"

        os.environ["PROJECT_ID"] = self.project_id
        os.environ["REGION"] = self.region
        os.environ["NETWORK"] = self.network_name
        os.environ["SUBNET"] = self.subnet_name

    def tearDown(self):
        del os.environ["PROJECT_ID"]
        del os.environ["REGION"]
        del os.environ["NETWORK"]
        del os.environ["SUBNET"]

    # --- check_vpc tests ---
    def test_check_vpc_success(self):
        self.mock_service.networks().get().execute.return_value = {
            "name": self.network_name,
            "autoCreateSubnetworks": False
        }
        results = check_vpc(self.mock_service, self.project_id, self.network_name)
        self.assertEqual(len(results), 2)
        self.assertTrue(results[0][0])
        self.assertIn(f"VPC '{self.network_name}' exists", results[0][1])
        self.assertTrue(results[1][0])
        self.assertIn("is in custom subnet mode", results[1][1])

    def test_check_vpc_not_found(self):
        mock_resp = mock.MagicMock()
        mock_resp.status = 404
        self.mock_service.networks().get().execute.side_effect = HttpError(mock_resp, b"not found")
        results = check_vpc(self.mock_service, self.project_id, self.network_name)
        self.assertEqual(len(results), 1)
        self.assertFalse(results[0][0])
        self.assertIn(f"VPC '{self.network_name}' does not exist", results[0][1])

    def test_check_vpc_auto_mode(self):
        self.mock_service.networks().get().execute.return_value = {
            "name": self.network_name,
            "autoCreateSubnetworks": True
        }
        results = check_vpc(self.mock_service, self.project_id, self.network_name)
        self.assertEqual(len(results), 2)
        self.assertTrue(results[0][0])
        self.assertFalse(results[1][0])
        self.assertIn("is NOT in custom subnet mode", results[1][1])

    def test_check_vpc_other_error(self):
        mock_resp = mock.MagicMock()
        mock_resp.status = 500
        self.mock_service.networks().get().execute.side_effect = HttpError(mock_resp, b"internal error")
        results = check_vpc(self.mock_service, self.project_id, self.network_name)
        self.assertEqual(len(results), 1)
        self.assertFalse(results[0][0])
        self.assertIn("Error checking VPC", results[0][1])

    # --- check_subnetwork tests ---
    def test_check_subnetwork_success(self):
        self.mock_service.subnetworks().get().execute.return_value = {
            "name": self.subnet_name,
            "network": f"https://www.googleapis.com/compute/v1/projects/{self.project_id}/global/networks/{self.network_name}",
            "privateIpGoogleAccess": True
        }
        results = check_subnetwork(self.mock_service, self.project_id, self.region, self.network_name, self.subnet_name)
        self.assertEqual(len(results), 2)
        self.assertTrue(results[0][0])
        self.assertIn(f"Subnetwork '{self.subnet_name}' exists", results[0][1])
        self.assertTrue(results[1][0])
        self.assertIn("has Private Google Access enabled", results[1][1])

    def test_check_subnetwork_not_found(self):
        mock_resp = mock.MagicMock()
        mock_resp.status = 404
        self.mock_service.subnetworks().get().execute.side_effect = HttpError(mock_resp, b"not found")
        results = check_subnetwork(self.mock_service, self.project_id, self.region, self.network_name, self.subnet_name)
        self.assertEqual(len(results), 1)
        self.assertFalse(results[0][0])
        self.assertIn(f"Subnetwork '{self.subnet_name}' does not exist", results[0][1])

    def test_check_subnetwork_pga_disabled(self):
        self.mock_service.subnetworks().get().execute.return_value = {
            "name": self.subnet_name,
            "network": f"https://www.googleapis.com/compute/v1/projects/{self.project_id}/global/networks/{self.network_name}",
            "privateIpGoogleAccess": False
        }
        results = check_subnetwork(self.mock_service, self.project_id, self.region, self.network_name, self.subnet_name)
        self.assertEqual(len(results), 2)
        self.assertTrue(results[0][0])
        self.assertFalse(results[1][0])
        self.assertIn("does not have Private Google Access enabled", results[1][1])

    def test_check_subnetwork_wrong_network(self):
        self.mock_service.subnetworks().get().execute.return_value = {
            "name": self.subnet_name,
            "network": f"https://www.googleapis.com/compute/v1/projects/{self.project_id}/global/networks/other-network",
            "privateIpGoogleAccess": True
        }
        results = check_subnetwork(self.mock_service, self.project_id, self.region, self.network_name, self.subnet_name)
        self.assertEqual(len(results), 2)
        self.assertTrue(results[0][0])
        self.assertFalse(results[1][0])
        self.assertIn(f"Subnetwork '{self.subnet_name}' does not belong to VPC '{self.network_name}'", results[1][1])

    def test_check_subnetwork_other_error(self):
        mock_resp = mock.MagicMock()
        mock_resp.status = 500
        self.mock_service.subnetworks().get().execute.side_effect = HttpError(mock_resp, b"internal error")
        results = check_subnetwork(self.mock_service, self.project_id, self.region, self.network_name, self.subnet_name)
        self.assertEqual(len(results), 1)
        self.assertFalse(results[0][0])
        self.assertIn("Error checking subnetwork", results[0][1])

    # --- run_checks tests ---
    def test_run_checks_success(self):
        self.mock_service.networks().get().execute.return_value = {
            "name": self.network_name, "autoCreateSubnetworks": False
        }
        self.mock_service.subnetworks().get().execute.return_value = {
            "name": self.subnet_name,
            "network": f"https://www.googleapis.com/compute/v1/projects/{self.project_id}/global/networks/{self.network_name}",
            "privateIpGoogleAccess": True
        }

        results = run_checks(self.mock_service, self.project_id, self.region)
        output = "
".join([msg for success, msg in results])
        self.assertIn(f"VPC '{self.network_name}' exists.", output)
        self.assertIn(f"VPC '{self.network_name}' is in custom subnet mode.", output)
        self.assertIn(f"Subnetwork '{self.subnet_name}' exists.", output)
        self.assertIn(f"Subnetwork '{self.subnet_name}' has Private Google Access enabled.", output)
        self.assertTrue(all(success for success, msg in results))

    def test_run_checks_missing_env(self):
        del os.environ["NETWORK"]
        results = run_checks(self.mock_service, self.project_id, self.region)
        output = "
".join([msg for success, msg in results])
        self.assertIn("NETWORK environment variable not set", output)
        self.assertFalse(any(success for success, msg in results))

if __name__ == '__main__':
    print("Running tests: python -m unittest modules.network.test_checks")
    unittest.main()
