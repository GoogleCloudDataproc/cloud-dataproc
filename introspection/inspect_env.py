import json
import os
import importlib
import inspect
import pkgutil
import sys
import google.auth
from googleapiclient.discovery import build

def load_config_from_env_json(config_path):
    """Loads configuration from a JSON file."""
    if os.path.exists(config_path):
        try:
            with open(config_path, 'r') as f:
                return json.load(f)
        except json.JSONDecodeError as e:
            print(f"[WARN] Error decoding JSON from {config_path}: {e}")
        except Exception as e:
            print(f"[WARN] Error reading config file {config_path}: {e}")
    else:
        print(f"[INFO] Config file not found: {config_path}")
    return {}

def run_inspections(compute_service, crm_service, iam_service, storage_service, sqladmin_service, project_id, region, config, selected_modules_str = os.environ.get("INSPECT_MODULES"):
    selected_modules = selected_modules_str.split(',') if selected_modules_str else None
    """Dynamically discovers and runs inspection modules."""
    all_results = {}
    package_path = os.path.dirname(__file__)

    for importer, modname, ispkg in pkgutil.iter_modules([os.path.join(package_path, 'modules')]):
        if selected_modules and modname not in selected_modules:
            continue

        if ispkg:
            print(f"
--- Running Inspections for Module: {modname} ---")
            try:
                module = importlib.import_module(f'modules.{modname}.checks')
                dataproc_sa_email = os.environ.get("DATAPROC_SA_EMAIL")
                if not dataproc_sa_email:
                    project_number = module.get_project_number(crm_service, project_id) if modname == 'iam' else None
                    if project_number:
                         dataproc_sa_email = f"{project_number}-compute@developer.gserviceaccount.com"

                if modname == 'network':
                    module_results = module.run_checks(compute_service, project_id, region)
                elif modname == 'iam':
                    module_results = module.run_checks(compute_service, crm_service, iam_service, project_id, region)
                elif modname == 'storage':
                    module_results = module.run_checks(storage_service, project_id, region, dataproc_sa_email)
                elif modname == 'cloudsql':
                    module_results = module.run_checks(sqladmin_service, project_id, region, config)
                else:
                    print(f"[WARN] No execution logic defined for module {modname}")
                    continue

                all_results[modname] = module_results
                for success, message in module_results:
                    print(f"[{'PASS' if success else 'FAIL'}] {message}")
            except ImportError as e:
                print(f"[ERROR] Could not import module {modname}: {e}")
            except AttributeError as e:
                print(f"[ERROR] Module {modname} does not have a run_checks function or a required service is missing: {e}")
            except Exception as e:
                print(f"[ERROR] Error running module {modname}: {e}")
    return all_results

def main():
    """Main function to run environment inspections."""
    config = {}
    config_path = os.environ.get("INSPECT_ENV_CONFIG")
    if config_path:
        print(f"[INFO] Loading configuration from {config_path}")
        config = load_config_from_env_json(config_path)

    project_id = os.environ.get("GOOGLE_CLOUD_PROJECT", config.get("PROJECT_ID"))
    region = os.environ.get("REGION", config.get("REGION"))
    dataproc_sa_email = os.environ.get("DATAPROC_SA_EMAIL", config.get("DATAPROC_SA_EMAIL"))
    bucket = os.environ.get("BUCKET", config.get("BUCKET"))
    temp_bucket = os.environ.get("TEMP_BUCKET", config.get("TEMP_BUCKET"))

    # Set env vars so modules can use them directly
    if project_id and not os.environ.get("GOOGLE_CLOUD_PROJECT"): os.environ["GOOGLE_CLOUD_PROJECT"] = project_id
    if region and not os.environ.get("REGION"): os.environ["REGION"] = region
    if dataproc_sa_email and not os.environ.get("DATAPROC_SA_EMAIL"): os.environ["DATAPROC_SA_EMAIL"] = dataproc_sa_email

    gcs_buckets = []
    if bucket: gcs_buckets.append(bucket)
    if temp_bucket: gcs_buckets.append(temp_bucket)
    if gcs_buckets and not os.environ.get("DATAPROC_GCS_BUCKETS"):
        os.environ["DATAPROC_GCS_BUCKETS"] = ",".join(gcs_buckets)
    elif gcs_buckets and os.environ.get("DATAPROC_GCS_BUCKETS"):
         # Append to existing env var
         existing_buckets = os.environ["DATAPROC_GCS_BUCKETS"].split(',')
         for b in gcs_buckets:
             if b not in existing_buckets:
                 existing_buckets.append(b)
         os.environ["DATAPROC_GCS_BUCKETS"] = ",".join(existing_buckets)

    if not project_id:
        print("[FAIL] Missing required configuration: GOOGLE_CLOUD_PROJECT (or PROJECT_ID in env.json)")
        return
    if not region:
        print("[FAIL] Missing required configuration: REGION (or REGION in env.json)")
        return

    print(f"--- Starting GCP Environment Inspection for Project: {project_id}, Region: {region} ---")

    try:
        credentials, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
        compute_service = build('compute', 'v1', credentials=credentials)
        crm_service = build('cloudresourcemanager', 'v1', credentials=credentials)
        iam_service = build('iam', 'v1', credentials=credentials)
        storage_service = build('storage', 'v1', credentials=credentials)
        sqladmin_service = build('sqladmin', 'v1beta4', credentials=credentials)

        # Pass services to the run_inspections function
        run_inspections(compute_service, crm_service, iam_service, storage_service, sqladmin_service, project_id, region, config)

    except google.auth.exceptions.DefaultCredentialsError:
        print("[FAIL] Could not obtain Application Default Credentials.")
    except Exception as e:
        print(f"[FAIL] An unexpected error occurred: {e}")

if __name__ == '__main__':
    # Add modules directory to path for dynamic import
    sys.path.append(os.path.join(os.path.dirname(__file__), 'modules'))
    main()
