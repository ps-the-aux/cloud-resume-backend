import pytest
from playwright.sync_api import sync_playwright
import requests

API_ENDPOINT = "https://z6zppplf8i.execute-api.us-east-1.amazonaws.com"

@pytest.fixture
def browser():
    with sync_playwright() as p:
        yield p


def test_api_and_database_update(browser):
# Initial API call
    response = requests.get(API_ENDPOINT)
    assert response.status_code == 200
    initial_value = response.json()
                
# Action to update the value in the database
    updated_response = requests.post(API_ENDPOINT)
    assert updated_response.status_code == 200

 # Verify the value in the database
    updated_response = requests.get(API_ENDPOINT)
    updated_value = updated_response.json()

    assert updated_value != initial_value



