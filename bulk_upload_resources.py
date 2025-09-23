# bulk_upload_resources.py

import requests
import json
import getpass

# --- Configuration ---
# The base URL of your API. Update this if your server is hosted elsewhere.
API_BASE_URL = "https://api.luxashome.com/api"
# The name of the JSON file containing the resources to upload.
JSON_FILE_PATH = "resources.json"


def get_auth_token(session):
    """Prompts the user for credentials and gets an authentication token."""
    print("Please enter your credentials to authenticate with the API.")
    username = input("Username: ")
    password = getpass.getpass("Password: ")

    login_url = f"{API_BASE_URL}/login/"
    try:
        response = session.post(login_url, data={"username": username, "password": password})
        response.raise_for_status()  # Raise an exception for bad status codes (4xx or 5xx)
        return response.json().get("token")
    except requests.exceptions.RequestException as e:
        print(f"\nError: Login failed. {e}")
        if e.response is not None:
            print(f"Response from server: {e.response.text}")
        return None


def get_existing_resources(session, token):
    """Fetches all existing resources and maps them by name."""
    headers = {"Authorization": f"Token {token}"}
    resources_url = f"{API_BASE_URL}/resources/"
    try:
        response = session.get(resources_url, headers=headers)
        response.raise_for_status()
        # Create a dictionary mapping normalized names to resource objects
        return {r['name'].strip().lower(): r for r in response.json()}
    except requests.exceptions.RequestException as e:
        print(f"\nError: Failed to fetch existing resources. {e}")
        return {}


def upload_resources(session, token, resources_to_upload, existing_resources):
    """Uploads or updates resources from the JSON file."""
    headers = {"Authorization": f"Token {token}"}
    created_count = 0
    updated_count = 0
    failed_count = 0

    for resource in resources_to_upload:
        name = resource.get("name", "").strip()
        normalized_name = name.lower()
        
        # Prepare the payload, ensuring all required fields are present
        payload = {
            "name": name,
            "description": resource.get("description", ""),
            "type": resource.get("type", "General"),
            "url": resource.get("url", ""),
            "phone_number": resource.get("phone_number", ""),
            "tags": resource.get("tags", []),
            "provider": resource.get("provider", ""),
            "public": resource.get("public", True)
        }

        try:
            if normalized_name in existing_resources:
                # --- UPDATE EXISTING RESOURCE ---
                existing_resource = existing_resources[normalized_name]
                resource_id = existing_resource['id']
                
                # Add the user ID to the payload for validation
                payload['user'] = existing_resource.get('user')

                print(f"Updating existing resource: '{name}'...", end=" ")
                update_url = f"{API_BASE_URL}/resources/{resource_id}/"
                # Use PATCH for partial updates, which is more robust
                response = session.patch(update_url, headers=headers, json=payload)
                response.raise_for_status()
                updated_count += 1
                print("Success.")
            else:
                # --- CREATE NEW RESOURCE ---
                print(f"Creating new resource: '{name}'...", end=" ")
                create_url = f"{API_BASE_URL}/resources/"
                response = session.post(create_url, headers=headers, json=payload)
                response.raise_for_status()
                created_count += 1
                print("Success.")

        except requests.exceptions.RequestException as e:
            failed_count += 1
            print(f"Failed. Error: {e.response.text if e.response else e}")

    print("\n--- Upload Complete ---")
    print(f"Successfully created: {created_count}")
    print(f"Successfully updated: {updated_count}")
    print(f"Failed: {failed_count}")


def main():
    """Main function to drive the script."""
    # Load resources from the JSON file
    try:
        with open(JSON_FILE_PATH, 'r', encoding='utf-8') as f:
            resources_to_upload = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"Error reading {JSON_FILE_PATH}: {e}")
        return

    session = requests.Session()
    token = get_auth_token(session)

    if not token:
        return

    print("\nFetching existing resources to prevent duplicates...")
    existing_resources = get_existing_resources(session, token)

    print(f"Found {len(resources_to_upload)} resources in '{JSON_FILE_PATH}'.")
    upload_resources(session, token, resources_to_upload, existing_resources)


if __name__ == "__main__":
    main()
