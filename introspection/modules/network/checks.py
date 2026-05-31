import os
import google.auth
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

def check_vpc(service, project_id, network_name):
    """Checks VPC existence and subnet mode."""
    results = []
    try:
        network = service.networks().get(project=project_id, network=network_name).execute()
        results.append((True, f"VPC '{network_name}' exists."))

        if network.get('autoCreateSubnetworks', True):
            results.append((False, f"VPC '{network_name}' is NOT in custom subnet mode (autoCreateSubnetworks is True)."))
        else:
            results.append((True, f"VPC '{network_name}' is in custom subnet mode."))
    except HttpError as e:
        if e.resp.status == 404:
            results.append((False, f"VPC '{network_name}' does not exist."))
        else:
            results.append((False, f"Error checking VPC '{network_name}': {e}"))
    return results

def check_subnetwork(service, project_id, region, network_name, subnet_name):
    """Checks Subnetwork existence and Private Google Access."""
    results = []
    try:
        subnetwork = service.subnetworks().get(project=project_id, region=region, subnetwork=subnet_name).execute()
        results.append((True, f"Subnetwork '{subnet_name}' exists."))

        if subnetwork.get('network') != f"https://www.googleapis.com/compute/v1/projects/{project_id}/global/networks/{network_name}":
             results.append((False, f"Subnetwork '{subnet_name}' does not belong to VPC '{network_name}'."))
             return results

        if subnetwork.get('privateIpGoogleAccess', False):
            results.append((True, f"Subnetwork '{subnet_name}' has Private Google Access enabled."))
        else:
            results.append((False, f"Subnetwork '{subnet_name}' does not have Private Google Access enabled."))
    except HttpError as e:
        if e.resp.status == 404:
            results.append((False, f"Subnetwork '{subnet_name}' does not exist in region '{region}'."))
        else:
            results.append((False, f"Error checking subnetwork '{subnet_name}': {e}"))
    return results

def run_checks(service, project_id, region):
    """Main function to check network configuration."""
    project_id = os.environ.get("PROJECT_ID")
    region = os.environ.get("REGION")
    network_name = os.environ.get("NETWORK")
    subnet_name = os.environ.get("SUBNET")

    if not all([project_id, region, network_name, subnet_name]):
        print("[FAIL] Missing required environment variables: PROJECT_ID, REGION, NETWORK, SUBNET")
        return

    try:
        credentials, _ = google.auth.default()
        service = build('compute', 'v1', credentials=credentials)


    all_results = []
    network_name = os.environ.get("NETWORK")
    subnet_name = os.environ.get("SUBNET")

    if not network_name:
        all_results.append((False, "NETWORK environment variable not set."))
        return all_results
    if not subnet_name:
        all_results.append((False, "SUBNET environment variable not set."))
        return all_results

    all_results.extend(check_vpc(service, project_id, network_name))
    all_results.extend(check_subnetwork(service, project_id, region, network_name, subnet_name))

    except google.auth.exceptions.DefaultCredentialsError:
        print("[FAIL] Could not obtain Application Default Credentials.")
    except Exception as e:
        print(f"[FAIL] An unexpected error occurred: {e}")

    return all_results
