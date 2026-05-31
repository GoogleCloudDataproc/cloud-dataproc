import os
from googleapiclient.errors import HttpError

def check_bucket_iam_policy(storage_service, bucket_name, sa_email):
    """Checks if the service account has sufficient permissions on the GCS bucket."""
    results = []
    member = f"serviceAccount:{sa_email}"
    required_permissions = {
        "storage.objects.get",
        "storage.objects.create",
        "storage.objects.list",
        # storage.objects.delete is not strictly required for most jobs
    }

    try:
        policy = storage_service.buckets().getIamPolicy(bucket=bucket_name).execute()
        bindings = policy.get('bindings', [])

        found_roles = set()
        for binding in bindings:
            role = binding.get('role')
            if member in binding.get('members', []):
                found_roles.add(role)

        # This is a simplification. Ideally, we'd expand roles into permissions.
        # For now, we check for common roles granting the required permissions.
        sufficient_roles = {
            "roles/storage.objectAdmin",
            "roles/storage.objectUser",
            "roles/storage.admin",
            "roles/owner",
            "roles/editor",
        }

        has_sufficient_role = any(role in found_roles for role in sufficient_roles)

        if has_sufficient_role:
            results.append((True, f"VM SA '{sa_email}' appears to have sufficient roles ({found_roles}) on bucket '{bucket_name}'."))
        else:
            # Check for custom roles - This requires permission service
            results.append((False, f"VM SA '{sa_email}' may lack required object permissions (get, create, list) on bucket '{bucket_name}'. Found roles: {found_roles}. Consider granting 'roles/storage.objectUser'."))

    except HttpError as e:
        if e.resp.status == 403:
            results.append((False, f"Permission denied to check IAM policy on bucket '{bucket_name}'. You need 'storage.buckets.getIamPolicy' permission."))
        elif e.resp.status == 404:
            results.append((False, f"Bucket '{bucket_name}' not found."))
        else:
            results.append((False, f"Error checking IAM policy for bucket '{bucket_name}': {e}"))
    except Exception as e:
        results.append((False, f"Error checking IAM policy for bucket '{bucket_name}': {e}"))

    return results

def run_checks(storage_service, project_id, region, sa_email):
    """Runs all storage checks."""
    all_results = []
    bucket_names_str = os.environ.get("DATAPROC_GCS_BUCKETS")

    if not sa_email:
        all_results.append((False, "VM Service Account email not provided to storage module."))
        return all_results

    if not bucket_names_str:
        all_results.append((None, "INFO: DATAPROC_GCS_BUCKETS environment variable not set. Skipping bucket IAM checks."))
        return all_results

    bucket_names = [b.strip() for b in bucket_names_str.split(',') if b.strip()]
    if not bucket_names:
        all_results.append((None, "INFO: DATAPROC_GCS_BUCKETS is set but contains no bucket names."))
        return all_results

    all_results.append((None, f"INFO: Checking bucket permissions for SA '{sa_email}' on: {', '.join(bucket_names)}"))

    for bucket_name in bucket_names:
        all_results.extend(check_bucket_iam_policy(storage_service, bucket_name, sa_email))

    return all_results
