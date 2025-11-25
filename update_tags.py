# update_tags.py

import request
import json
import getpass
import sys

# --- Configuration ---
API_BASE_URL = "https://api.luxashome.com/api"
JSON_FILE_PATH = "resources.json"

def check_dependencies():
    """Checks for the requests library."""
    try:
        import requests
        print(" 'requests' library is installed.")
        return requests
    except ImportError:
        print(" Error: The 'requests' library is not installed.")
        print("Please run 'pip3 install requests' in your terminal and try again.")
        sys.exit(1)

def get_auth_token(session, requests):
    """Prompts for credentials and gets an auth token."""
    print("\nStep 1: Authenticating...")
    username = input("Username: ")
    password = getpass.getpass("Password: ")

    login_url = f"{API_BASE_URL}/login/"
    print(f"   - POST to {login_url}")
    try:
        response = session.post(login_url, data={"username": username, "password": password})
        print(f"   - Server responded with status: {response.status_code}")
        response.raise_for_status()
        token = response.json().get("token")
        if token:
            print("   - Authentication successful.")
            return token
        else:
            print("   - Authentication failed. No token in response.")
            return None
    except requests.exceptions.RequestException as e:
        print(f"   - Error: Login request failed. {e}")
        if e.response is not None:
            print(f"   - Server response content: {e.response.text}")
        return None

def get_existing_resources(session, token, requests):
    """Fetches all existing resources and maps them by name."""
    print("\nStep 2: Fetching all resources from the database...")
    headers = {"Authorization": f"Token {token}"}
    resources_url = f"{API_BASE_URL}/resources/"
    print(f"   - GET from {resources_url}")
    try:
        response = session.get(resources_url, headers=headers)
        print(f"   - Server responded with status: {response.status_code}")
        response.raise_for_status()
        resources = response.json()
        print(f"   - Found {len(resources)} resources in the database.")
        return {r['name'].strip().lower(): r for r in resources}
    except requests.exceptions.RequestException as e:
        print(f"   - Error: Failed to fetch existing resources. {e}")
        return {}

def update_resource_tags(session, token, resource_id, tags, requests):
    """Updates only the tags for a specific resource using PATCH."""
    headers = {"Authorization": f"Token {token}"}
    update_url = f"{API_BASE_URL}/resources/{resource_id}/"
    payload = {"tags": tags}
    
    print(f"   - PATCH to {update_url}")
    print(f"   - Sending payload: {json.dumps(payload)}")
    
    try:
        response = session.patch(update_url, headers=headers, json=payload)
        print(f"   - Server responded with status: {response.status_code}")
        print(f"   - Response content: {response.text}")
        response.raise_for_status()
        return True
    except requests.exceptions.RequestException as e:
        print(f"   - PATCH failed. Error: {e}")
        return False

def main():
    """Main function to drive the script."""
    requests = check_dependencies()
    
    try:
        with open(JSON_FILE_PATH, 'r', encoding='utf-8') as f:
            resources_from_json = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"Error reading {JSON_FILE_PATH}: {e}")
        return

    session = requests.Session()
    token = get_auth_token(session, requests)
    if not token:
        return

    existing_resources_map = get_existing_resources(session, token, requests)
    if not existing_resources_map:
        print("\nCould not fetch resources from DB. Aborting.")
        return

    updated_count = 0
    failed_count = 0
    skipped_count = 0

    print("\nStep 3: Comparing JSON file to database and updating tags...")
    for resource_data in resources_from_json:
        name = resource_data.get("name", "").strip()
        normalized_name = name.lower()
        tags = resource_data.get("tags", [])

        if normalized_name in existing_resources_map:
            resource_id = existing_resources_map[normalized_name]['id']
            print(f"\nProcessing: '{name}' (ID: {resource_id}) with tags: {tags}")
            if update_resource_tags(session, token, resource_id, tags, requests):
                updated_count += 1
            else:
                failed_count += 1
        else:
            print(f"\nSkipping '{name}' as it was not found in the database.")
            skipped_count += 1

    print("\n--- Diagnosis Complete ---")
    print(f"Attempted to update: {updated_count + failed_count}")
    print(f"Succeeded: {updated_count}")
    print(f"Failed:    {failed_count}")
    print(f"Skipped:   {skipped_count}")

if __name__ == "__main__":
    main()
