import os
os.environ["AUTH_MODE"] = "local"
os.environ["DATABASE_URL"] = "sqlite:///./test.db"
os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1")
os.environ.setdefault("AWS_ACCESS_KEY_ID", "x")
os.environ.setdefault("AWS_SECRET_ACCESS_KEY", "x")
import jwt
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def hdr(role="patient", sub="p1"):
    t = jwt.encode({"sub": sub, "role": role}, "dev-only-secret", algorithm="HS256")
    return {"Authorization": f"Bearer {t}"}


def test_upload_url_and_list():
    r = client.post("/records/upload-url", json={"title": "Blood test"}, headers=hdr())
    assert r.status_code == 201 and r.json()["key"].startswith("p1/")
    assert len(client.get("/records", headers=hdr()).json()) >= 1


def test_patient_only_sees_own():
    client.post("/records/upload-url", json={"title": "x"}, headers=hdr(sub="p9"))
    mine = client.get("/records?patient_id=p9", headers=hdr(sub="p1")).json()
    assert not any(t["key"].startswith("p9/") for t in mine)
