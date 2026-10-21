import os

os.environ["AUTH_MODE"] = "local"
os.environ["DATABASE_URL"] = "sqlite:///./test.db"

import jwt
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def hdr(role="patient", sub="p1"):
    token = jwt.encode({"sub": sub, "role": role}, "dev-only-secret", algorithm="HS256")
    return {"Authorization": f"Bearer {token}"}


def pdf_file(name="report.pdf"):
    return {"file": (name, b"%PDF-1.4\nDemo report\n%%EOF", "application/pdf")}


def test_upload_and_list():
    response = client.post("/records/upload-url", files=pdf_file(), headers=hdr())
    assert response.status_code == 201
    assert response.json()["key"].startswith("p1/")
    assert len(client.get("/records", headers=hdr()).json()) >= 1


def test_patient_only_sees_own():
    client.post("/records/upload-url", files=pdf_file("other.pdf"), headers=hdr(sub="p9"))
    mine = client.get("/records?patient_id=p9", headers=hdr(sub="p1")).json()
    assert not any(item["key"].startswith("p9/") for item in mine)


def test_rejects_non_pdf():
    response = client.post(
        "/records/upload-url",
        files={"file": ("notes.txt", b"not a pdf", "text/plain")},
        headers=hdr(),
    )
    assert response.status_code == 415
