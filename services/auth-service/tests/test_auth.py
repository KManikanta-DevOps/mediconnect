import os
os.environ["AUTH_MODE"] = "local"
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_health():
    assert client.get("/health").json() == {"status": "ok"}


def test_login_and_me():
    token = client.post("/auth/dev-login", json={"email": "a@b.com", "role": "patient"}).json()["access_token"]
    r = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200 and r.json()["role"] == "patient"


def test_me_requires_token():
    assert client.get("/auth/me").status_code == 401
