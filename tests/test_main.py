import pytest
from fastapi.testclient import TestClient
from src.main import app, items, next_id
import src.main as main_module

client = TestClient(app)


@pytest.fixture(autouse=True)
def clear_state():
    items.clear()
    main_module.next_id = 1
    yield
    items.clear()
    main_module.next_id = 1


def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_create_item():
    response = client.post("/items", json={"name": "Item A", "description": "Desc A"})
    assert response.status_code == 201
    data = response.json()
    assert data["id"] == 1
    assert data["name"] == "Item A"
    assert data["description"] == "Desc A"


def test_list_items():
    client.post("/items", json={"name": "Item A"})
    client.post("/items", json={"name": "Item B"})
    response = client.get("/items")
    assert response.status_code == 200
    assert len(response.json()) == 2


def test_get_item():
    client.post("/items", json={"name": "Item A"})
    response = client.get("/items/1")
    assert response.status_code == 200
    assert response.json()["name"] == "Item A"


def test_get_item_not_found():
    response = client.get("/items/999")
    assert response.status_code == 404


def test_delete_item():
    client.post("/items", json={"name": "Item A"})
    response = client.delete("/items/1")
    assert response.status_code == 204
    assert client.get("/items/1").status_code == 404


def test_delete_item_not_found():
    response = client.delete("/items/999")
    assert response.status_code == 404
