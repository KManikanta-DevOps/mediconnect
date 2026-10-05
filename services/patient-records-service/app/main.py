import logging
import os
import uuid

import boto3
from botocore.config import Config
from fastapi import Depends, FastAPI
from prometheus_fastapi_instrumentator import Instrumentator
from pydantic import BaseModel
from sqlalchemy import Column, DateTime, Integer, String, create_engine, func, select
from sqlalchemy.orm import Session, declarative_base

from .security import current_user, require_role

BUCKET = os.getenv("REPORTS_BUCKET", "local-reports")
KMS_KEY = os.getenv("KMS_KEY_ID", "")
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./dev.db")
S3_ENDPOINT = os.getenv("S3_ENDPOINT_URL") or None  # MinIO/localstack in compose

engine = create_engine(DATABASE_URL, pool_pre_ping=True)
Base = declarative_base()
s3 = boto3.client("s3", endpoint_url=S3_ENDPOINT, config=Config(signature_version="s3v4"))
audit = logging.getLogger("audit")
logging.basicConfig(level=logging.INFO, format='{"ts":"%(asctime)s","type":"audit","msg":"%(message)s"}')


class Report(Base):
    __tablename__ = "reports"
    id = Column(Integer, primary_key=True)
    patient_id = Column(String, index=True, nullable=False)
    s3_key = Column(String, nullable=False)
    title = Column(String, nullable=False)
    created_at = Column(DateTime, server_default=func.now())


Base.metadata.create_all(engine)
app = FastAPI(title="patient-records-service")
Instrumentator().instrument(app).expose(app)


def db():
    with Session(engine) as s:
        yield s


class UploadIn(BaseModel):
    title: str
    content_type: str = "application/pdf"


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/records/upload-url", status_code=201)
def upload_url(body: UploadIn, session: Session = Depends(db), user=Depends(require_role("patient"))):
    key = f"{user['sub']}/{uuid.uuid4()}.pdf"
    params = {"Bucket": BUCKET, "Key": key, "ContentType": body.content_type}
    if KMS_KEY:
        params.update(ServerSideEncryption="aws:kms", SSEKMSKeyId=KMS_KEY)
    url = s3.generate_presigned_url("put_object", Params=params, ExpiresIn=300)
    session.add(Report(patient_id=user["sub"], s3_key=key, title=body.title))
    session.commit()
    audit.info("upload_url actor=%s key=%s", user["sub"], key)
    return {"url": url, "key": key, "kms": bool(KMS_KEY)}


@app.get("/records")
def list_reports(patient_id: str | None = None, session: Session = Depends(db), user=Depends(current_user)):
    target = user["sub"] if user["role"] == "patient" else (patient_id or user["sub"])
    rows = session.scalars(select(Report).where(Report.patient_id == target))
    audit.info("list_records actor=%s target=%s", user["sub"], target)
    return [{"id": r.id, "title": r.title, "key": r.s3_key} for r in rows]


@app.get("/records/{report_id}/download-url")
def download_url(report_id: int, session: Session = Depends(db), user=Depends(current_user)):
    r = session.get(Report, report_id)
    if r is None or (user["role"] == "patient" and r.patient_id != user["sub"]):
        from fastapi import HTTPException
        raise HTTPException(404, "Not found")
    audit.info("download_url actor=%s report=%s", user["sub"], report_id)
    return {"url": s3.generate_presigned_url("get_object", Params={"Bucket": BUCKET, "Key": r.s3_key}, ExpiresIn=300)}
