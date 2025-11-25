# deduplicate_resources.py

import requests
import json
import getpass
from collections import defaultdict

# --- Configuration ---
API_BASE_URL = "https://api.luxashome.com/api"

def get_auth_token(session):
    """Prompts the user for credentials and gets an authentication token."""
    print("Please enter your credentials to authenticate with the API.")
    username = input("Username: ")
    password = getpass.getpass("Password: ")

    login_url = f"{API_BASE_URL}/login/"
    try:
        response = session.post(login_url, data={"username": username, "password": password})
        response.raise_for_status()
        return response.json().get("token")
    except requests.exceptions.RequestException as e:
        print(f"\nError: Login failed. {e}")
        if e.response is not None:
            print(f"Response from server: {e.response.text}")
        return None

def fetch_all_resources(session, token):
    """Fetches all resources from the API."""
    headers = {"Authorization": f"Token {token}"}
    resources_url = f"{API_BASE_URL}/resources/"
    try:
        response = session.get(resources_url, headers=headers)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"\nError: Failed to fetch resources. {e}")
        return []

def delete_resource(session, token, resource_id):
    """Deletes a single resource by its ID."""
    headers = {"Authorization": f"Token {token}"}
    delete_url = f"{API_BASE_URL}/resources/{resource_id}/"
    try:
        response = session.delete(delete_url, headers=headers)
        response.raise_for_status()
        return True
    except requests.exceptions.RequestException as e:
        print(f"\nError deleting resource {resource_id}: {e.response.text if e.response else e}")
        return False

def main():
    """Main function to find and delete duplicate resources."""
    session = requests.Session()
    token = get_auth_token(session)

    if not token:
        return

    print("\nFetching all resources to find duplicates...")
    all_resources = fetch_all_resources(session, token)

    if not all_resources:
        print("No resources found or failed to fetch.")
        return

    # Group resources by name
    resources_by_name = defaultdict(list)
    for resource in all_resources:
        # Use a case-insensitive and whitespace-trimmed name for grouping
        normalized_name = resource.get('name', '').strip().lower()
        if normalized_name:
            resources_by_name[normalized_name].append(resource)

    # Find duplicates and prepare a list of IDs to delete
    ids_to_delete = []
    for name, group in resources_by_name.items():
        if len(group) > 1:
            # Keep the first one, mark the rest for deletion
            group.sort(key=lambda r: r['id']) # Sort by ID to be consistent
            duplicates = group[1:]
            print(f"Found {len(duplicates)} duplicate(s) for resource: '{group[0]['name']}'")
            for dup in duplicates:
                ids_to_delete.append(dup['id'])
    
    if not ids_to_delete:
        print("\nNo duplicates found. All good!")
        return

    print(f"\nFound a total of {len(ids_to_delete)} duplicate resources to delete.")
    confirm = input("Proceed with deletion? (yes/no): ").lower()

    if confirm != 'yes':
        print("Deletion cancelled.")
        return

    # Delete the identified duplicates
    deleted_count = 0
    for resource_id in ids_to_delete:
        if delete_resource(session, token, resource_id):
            deleted_count += 1
            print(f"Deleted resource with ID: {resource_id}")

    print("\n--- Deduplication Complete ---")
    print(f"Successfully deleted: {deleted_count} duplicates.")

if __name__ == "__main__":
    main()
