import os

def run_checks(sqladmin_service, project_id, region, config):
    """Runs Cloud SQL checks if configuration is provided."""
    all_results = []
    instance_name = config.get("CLOUD_SQL_INSTANCE_NAME")

    if not instance_name:
        all_results.append((None, "INFO: CLOUD_SQL_INSTANCE_NAME not set in config. Skipping Cloud SQL checks."))
        return all_results

    all_results.append((None, f"INFO: Checking Cloud SQL instance '{instance_name}'."))

    try:
        # Check Instance Existence and State
        request = sqladmin_service.instances().get(project=project_id, instance=instance_name)
        instance = request.execute()
        all_results.append((True, f"Cloud SQL instance '{instance_name}' exists."))

        state = instance.get('state')
        if state == 'RUNNABLE':
            all_results.append((True, f"Cloud SQL instance '{instance_name}' is in state: {state}."))
        else:
            all_results.append((False, f"Cloud SQL instance '{instance_name}' is in state: {state}. Expected: RUNNABLE."))

        # TODO: Add network connectivity checks

    except Exception as e:
        all_results.append((False, f"Error checking Cloud SQL instance '{instance_name}': {e}"))

    return all_results
