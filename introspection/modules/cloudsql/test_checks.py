import unittest
from unittest import mock

# Mock google.auth before importing checks
with mock.patch('google.auth.default', return_value=(mock.MagicMock(), None)):
    from modules.cloudsql.checks import run_checks

class TestCloudSqlChecks(unittest.TestCase):

    def setUp(self):
        self.mock_sqladmin_service = mock.MagicMock()
        self.project_id = "test-project"
        self.region = "us-central1"

    def test_run_checks_no_config(self):
        config = {}
        results = run_checks(self.mock_sqladmin_service, self.project_id, self.region, config)
        self.assertEqual(len(results), 1)
        self.assertIsNone(results[0][0])
        self.assertIn("CLOUD_SQL_INSTANCE_NAME not set", results[0][1])
        self.mock_sqladmin_service.instances().get.assert_not_called()

    def test_run_checks_instance_exists_runnable(self):
        config = {"CLOUD_SQL_INSTANCE_NAME": "test-instance"}
        self.mock_sqladmin_service.instances().get().execute.return_value = {
            "name": "test-instance",
            "state": "RUNNABLE",
        }
        results = run_checks(self.mock_sqladmin_service, self.project_id, self.region, config)
        self.assertEqual(len(results), 3)
        self.assertTrue(results[1][0]) # Exists
        self.assertTrue(results[2][0]) # Runnable
        self.assertIn("exists", results[1][1])
        self.assertIn("is in state: RUNNABLE", results[2][1])

    def test_run_checks_instance_exists_not_runnable(self):
        config = {"CLOUD_SQL_INSTANCE_NAME": "test-instance"}
        self.mock_sqladmin_service.instances().get().execute.return_value = {
            "name": "test-instance",
            "state": "SUSPENDED",
        }
        results = run_checks(self.mock_sqladmin_service, self.project_id, self.region, config)
        self.assertEqual(len(results), 3)
        self.assertTrue(results[1][0])  # Exists
        self.assertFalse(results[2][0]) # Not Runnable
        self.assertIn("is in state: SUSPENDED", results[2][1])

    def test_run_checks_instance_error(self):
        config = {"CLOUD_SQL_INSTANCE_NAME": "test-instance"}
        self.mock_sqladmin_service.instances().get().execute.side_effect = Exception("API Error")
        results = run_checks(self.mock_sqladmin_service, self.project_id, self.region, config)
        self.assertEqual(len(results), 2)
        self.assertFalse(results[1][0])
        self.assertIn("Error checking Cloud SQL instance", results[1][1])

if __name__ == '__main__':
    unittest.main()
