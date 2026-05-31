import unittest
from unittest import mock
import os
from googleapiclient.errors import HttpError

# Mock google.auth before importing checks
with mock.patch('google.auth.default', return_value=(mock.MagicMock(), None)):
    from modules.iam.checks import check_service_account_exists, check_vm_service_account_roles, check_dataproc_service_agent_roles, run_checks, get_project_number

class TestIamChecks(unittest.TestCase):

    def setUp(self):
        self.mock_iam_service = mock.MagicMock()
        self.mock_crm_service = mock.MagicMock()
        self.project_id = "test-project"
        self.project_number = "1234567890"
        self.sa_email = "test-sa@test-project.iam.gserviceaccount.com"
        self.dataproc_sa_email = f"service-{self.project_number}@dataproc-accounts.iam.gserviceaccount.com"
        os.environ["DATAPROC_SA_EMAIL"] = self.sa_email

        # Mock get_project_number to avoid real calls
        self.mock_get_project_number = mock.patch('modules.iam.checks.get_project_number').start()
        self.mock_get_project_number.return_value = self.project_number

    def tearDown(self):
        del os.environ["DATAPROC_SA_EMAIL"]
        mock.patch.stopall()

    def test_check_service_account_exists_true(self):
        self.mock_iam_service.projects().serviceAccounts().get().execute.return_value = {"email": self.sa_email}
        success, msg = check_service_account_exists(self.mock_iam_service, self.project_id, self.sa_email)
        self.assertTrue(success)
        self.assertIn("exists", msg)

    def test_check_service_account_exists_false(self):
        mock_resp = mock.MagicMock()
        mock_resp.status = 404
        self.mock_iam_service.projects().serviceAccounts().get().execute.side_effect = HttpError(mock_resp, b"not found")
        success, msg = check_service_account_exists(self.mock_iam_service, self.project_id, self.sa_email)
        self.assertFalse(success)
        self.assertIn("does not exist", msg)

    @mock.patch('modules.iam.checks.get_sa_roles')
    def test_check_vm_sa_roles_good(self, mock_get_roles):
        mock_get_roles.return_value = {"roles/dataproc.worker", "roles/bigquery.user"}
        results = check_vm_service_account_roles(self.mock_crm_service, self.project_id, self.sa_email)
        output = "
".join([msg for success, msg in results])
        self.assertIn("has required role 'roles/dataproc.worker'", output)
        self.assertIn("has optional role 'roles/bigquery.user'", output)
        self.assertIn("does not have 'roles/storage.admin'", output)
        self.assertTrue(all(r[0] is not False for r in results)) # No Fails, None is ok

    @mock.patch('modules.iam.checks.get_sa_roles')
    def test_check_vm_sa_roles_missing_required(self, mock_get_roles):
        mock_get_roles.return_value = {"roles/storage.objectUser"}
        results = check_vm_service_account_roles(self.mock_crm_service, self.project_id, self.sa_email)
        output = "
".join([msg for success, msg in results])
        self.assertIn("MISSING required role 'roles/dataproc.worker'", output)
        self.assertFalse(results[0][0])

    @mock.patch('modules.iam.checks.get_sa_roles')
    def test_check_vm_sa_roles_storage_admin(self, mock_get_roles):
        mock_get_roles.return_value = {"roles/dataproc.worker", "roles/storage.admin"}
        results = check_vm_service_account_roles(self.mock_crm_service, self.project_id, self.sa_email)
        self.assertFalse(results[1][0]) # storage.admin check is the second result
        self.assertIn("has 'roles/storage.admin', which is overly broad", results[1][1])

    @mock.patch('modules.iam.checks.get_sa_roles')
    def test_check_dataproc_sa_roles_good(self, mock_get_roles):
        mock_get_roles.return_value = {"roles/dataproc.serviceAgent"}
        results = check_dataproc_service_agent_roles(self.mock_crm_service, self.project_id, self.project_number)
        self.assertTrue(results[0][0])
        self.assertIn(f"Dataproc SA 'service-{self.project_number}@dataproc-accounts.iam.gserviceaccount.com' has required role", results[0][1])

    @mock.patch('modules.iam.checks.get_sa_roles')
    def test_check_dataproc_sa_roles_missing(self, mock_get_roles):
        mock_get_roles.return_value = {}
        results = check_dataproc_service_agent_roles(self.mock_crm_service, self.project_id, self.project_number)
        self.assertFalse(results[0][0])
        self.assertIn("MISSING required role 'roles/dataproc.serviceAgent'", results[0][1])

    @mock.patch('modules.iam.checks.check_service_account_exists')
    @mock.patch('modules.iam.checks.check_vm_service_account_roles')
    @mock.patch('modules.iam.checks.check_dataproc_service_agent_roles')
    def test_run_checks(self, mock_check_dp_sa, mock_check_vm_roles, mock_check_exists):
        mock_check_exists.return_value = (True, "SA Exists")
        mock_check_vm_roles.return_value = [(True, "VM Role Check Pass")]
        mock_check_dp_sa.return_value = [(True, "DP SA Role Check Pass")]

        results = run_checks(None, self.mock_crm_service, self.mock_iam_service, self.project_id, "us-central1")
        self.assertEqual(len(results), 4) # exists, vm roles, dp sa roles, cmek info
        self.assertTrue(all(r[0] is not False for r in results))

    def test_run_checks_missing_env(self):
        del os.environ["DATAPROC_SA_EMAIL"]
        self.mock_get_project_number.return_value = None
        results = run_checks(None, self.mock_crm_service, self.mock_iam_service, self.project_id, "us-central1")
        self.assertEqual(len(results), 1)
        self.assertFalse(results[0][0])
        self.assertIn("DATAPROC_SA_EMAIL not set and could not form default SA name", results[0][1])

if __name__ == '__main__':
    unittest.main()
