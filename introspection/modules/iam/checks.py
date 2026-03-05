import os
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

def get_project_number(crm_service, project_id):
    """Helper to get project number from project ID."""
    try:
        project = crm_service.projects().get(projectId=project_id).execute()
        return project.get('projectNumber')
    except Exception as e:
        print(f"Error fetching project number for {project_id}: {e}")
        return None

def check_service_account_exists(iam_service, project_id, sa_email):
    """Checks if the service account exists."""
    try:
        name = f"projects/{project_id}/serviceAccounts/{sa_email}"
        iam_service.projects().serviceAccounts().get(name=name).execute()
        return (True, f"Service Account '{sa_email}' exists.")
    except HttpError as e:
        if e.resp.status == 404:
            return (False, f"Service Account '{sa_email}' does not exist.")
        else:
            return (False, f"Error checking Service Account '{sa_email}': {e}")
    except Exception as e:
        return (False, f"Error checking Service Account '{sa_email}': {e}")

def get_sa_roles(crm_service, project_id, sa_email):
    """Helper to get roles granted to a service account on a project."""
    member = f"serviceAccount:{sa_email}"
    try:
        policy = crm_service.projects().getIamPolicy(resource=project_id, body={}).execute()
        bindings = policy.get('bindings', [])
        found_roles = set()
        for binding in bindings:
            role = binding.get('role')
            if member in binding.get('members', []):
                found_roles.add(role)
        return found_roles
    except Exception as e:
        raise Exception(f"Error checking IAM policy for '{sa_email}': {e}")

def check_vm_service_account_roles(crm_service, project_id, sa_email):
    """Checks roles for the Dataproc VM Service Account."""
    results = []
    if not sa_email:
        results.append((False, "DATAPROC_SA_EMAIL environment variable not set."))
        return results

    required_roles = ["roles/dataproc.worker"]
    optional_roles = {
        "roles/bigquery.dataEditor": "Required for full BigQuery read/write access.",
        "roles/bigquery.user": "Required for running BigQuery jobs.",
        "roles/cloudsql.client": "Required for connecting to Cloud SQL instances via proxy.",
        "roles/metastore.user": "Required for accessing Dataproc Metastore.",
        "roles/secretmanager.secretAccessor": "Required for accessing secrets in Secret Manager.",
        "roles/logging.logWriter": "Recommended for writing logs.",
        "roles/monitoring.metricWriter": "Recommended for writing metrics.",
    }
    gcs_admin_role = "roles/storage.admin"

    try:
        found_roles = get_sa_roles(crm_service, project_id, sa_email)

        for role in required_roles:
            if role in found_roles:
                results.append((True, f"VM SA '{sa_email}' has required role '{role}'."))
            else:
                results.append((False, f"VM SA '{sa_email}' is MISSING required role '{role}'."))

        for role, description in optional_roles.items():
            if role in found_roles:
                results.append((True, f"VM SA '{sa_email}' has optional role '{role}' ({description})."))

        if gcs_admin_role in found_roles:
            results.append((False, f"VM SA '{sa_email}' has '{gcs_admin_role}', which is overly broad. BEST PRACTICE: Use granular roles on specific GCS buckets. Bucket permissions are checked in the 'storage' module."))

        return results
    except Exception as e:
        return [(False, str(e))]

def check_dataproc_service_agent_roles(crm_service, project_id, project_number):
    """Checks roles for the Dataproc Service Agent."""
    results = []
    if not project_number:
        return [(False, f"Could not determine project number for project ID '{project_id}'.")]

    sa_email = f"service-{project_number}@dataproc-accounts.iam.gserviceaccount.com"
    required_role = "roles/dataproc.serviceAgent"

    try:
        found_roles = get_sa_roles(crm_service, project_id, sa_email)
        if required_role in found_roles:
            results.append((True, f"Dataproc SA '{sa_email}' has required role '{required_role}'."))
        else:
            results.append((False, f"Dataproc SA '{sa_email}' is MISSING required role '{required_role}'."))

        results.append((None, "INFO: If using Shared VPC, ensure Dataproc SA has 'roles/compute.networkUser' in the HOST project."))
        return results
    except Exception as e:
        return [(False, str(e))]

# Placeholder for CMEK checks
# def check_cmek_permissions(kms_service, project_id, vm_sa_email, dataproc_sa_email, compute_sa_email, key_name):
# results = []
# required_role = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
# members_to_check = [f"serviceAccount:{vm_sa_email}", f"serviceAccount:{dataproc_sa_email}", f"serviceAccount:{compute_sa_email}"]
# ... logic to check getIamPolicy on the KMS key ...
# return results

def run_checks(compute_service, crm_service, iam_service, project_id, region):
    """Runs all IAM checks."""
    all_results = []
    project_number = get_project_number(crm_service, project_id)

    dataproc_sa_email = os.environ.get("DATAPROC_SA_EMAIL")
    if not dataproc_sa_email:
        if project_number:
            dataproc_sa_email = f"{project_number}-compute@developer.gserviceaccount.com"
            all_results.append((None, f"INFO: DATAPROC_SA_EMAIL not set, assuming default Compute SA: {dataproc_sa_email}"))
        else:
             all_results.append((False, "ERROR: DATAPROC_SA_EMAIL not set and could not form default SA name."))
             return all_results
    else:
        all_results.append((None, f"INFO: Checking VM SA: {dataproc_sa_email}"))

    exists_result = check_service_account_exists(iam_service, project_id, dataproc_sa_email)
    all_results.append(exists_result)

    if exists_result[0]: # Only check roles if SA exists
        all_results.extend(check_vm_service_account_roles(crm_service, project_id, dataproc_sa_email))

    all_results.extend(check_dataproc_service_agent_roles(crm_service, project_id, project_number))

    all_results.append((None, "INFO: CMEK checks not yet implemented. If using CMEK, ensure service accounts have access to the KMS keys."))

    return all_results
