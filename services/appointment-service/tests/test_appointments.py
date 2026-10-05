import os
os.environ["AUTH_MODE"] = "local"
os.environ["DATABASE_URL"] = "sqlite:///./test.db"
import jwt
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def hdr(role="patient", sub="p1"):
    t = jwt.encode({"sub": sub, "email": f"{sub}@x.com", "role": role}, "dev-only-secret", algorithm="HS256")
    return {"Authorization": f"Bearer {t}"}


def test_book_and_conflict():
    body = {"doctor_id": "d1", "starts_at": "2030-01-01T10:00:00"}
    client.post("/appointments", json=body, headers=hdr())
    assert client.post("/appointments", json=body, headers=hdr(sub="p2")).status_code == 409


def test_doctor_cannot_book():
    body = {"doctor_id": "d1", "starts_at": "2030-01-01T11:00:00"}
    assert client.post("/appointments", json=body, headers=hdr("doctor")).status_code == 403
