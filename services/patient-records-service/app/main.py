import io
import logging
import os
import uuid

from fastapi import Depends, FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from prometheus_fastapi_instrumentator import Instrumentator
from sqlalchemy import Column, DateTime, Integer, LargeBinary, String, create_engine, func, select
from sqlalchemy.orm import Session, declarative_base

from .security import current_user, require_role

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./dev.db")
MAX_UPLOAD_BYTES = 5 * 1024 * 1024

engine = create_engine(DATABASE_URL, pool_pre_ping=True)
Base = declarative_base()
audit = logging.getLogger("audit")
logging.basicConfig(level=logging.INFO, format='{"ts":"%(asctime)s","type":"audit","msg":"%(message)s"}')


class Report(Base):
    __tablename__ = "reports"
    id = Column(Integer, primary_key=True)
    patient_id = Column(String, index=True, nullable=False)
    s3_key = Column(String, nullable=False, unique=True)
    title = Column(String, nullable=False)
    content = Column(LargeBinary, nullable=False)
    created_at = Column(DateTime, server_default=func.now())


Base.metadata.create_all(engine)
app = FastAPI(title="patient-records-service")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
Instrumentator().instrument(app).expose(app)


def db():
    with Session(engine) as s:
        yield s


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/records/upload-url", status_code=201)
def upload_report(
    file: UploadFile = File(...),
    session: Session = Depends(db),
    user=Depends(require_role("patient")),
):
    """Demo-only upload path: store small PDFs in Neon instead of AWS S3."""
    if file.content_type != "application/pdf":
        raise HTTPException(415, "Only PDF files are supported")
    content = file.file.read(MAX_UPLOAD_BYTES + 1)
    if not content.startswith(b"%PDF-"):
        raise HTTPException(400, "The uploaded file is not a valid PDF")
    if len(content) > MAX_UPLOAD_BYTES:
        raise HTTPException(413, "PDF must be 5 MB or smaller")

    key = f"{user['sub']}/{uuid.uuid4()}.pdf"
    report = Report(
        patient_id=user["sub"],
        s3_key=key,
        title=(file.filename or "report.pdf")[:255],
        content=content,
    )
    session.add(report)
    session.commit()
    session.refresh(report)
    audit.info("upload actor=%s report=%s", user["sub"], report.id)
    return {"id": report.id, "title": report.title, "key": report.s3_key}


@app.get("/records")
def list_reports(patient_id: str | None = None, session: Session = Depends(db), user=Depends(current_user)):
    target = user["sub"] if user["role"] == "patient" else (patient_id or user["sub"])
    rows = session.scalars(select(Report).where(Report.patient_id == target).order_by(Report.created_at.desc()))
    audit.info("list_records actor=%s target=%s", user["sub"], target)
    return [{"id": r.id, "title": r.title, "key": r.s3_key, "created_at": r.created_at} for r in rows]


@app.get("/records/{report_id}/download-url")
def download_url(report_id: int, session: Session = Depends(db), user=Depends(current_user)):
    report = session.get(Report, report_id)
    if report is None or (user["role"] == "patient" and report.patient_id != user["sub"]):
        raise HTTPException(404, "Not found")
    return {"url": f"/records/{report_id}/download"}


@app.get("/records/{report_id}/download")
def download_report(report_id: int, session: Session = Depends(db), user=Depends(current_user)):
    report = session.get(Report, report_id)
    if report is None or (user["role"] == "patient" and report.patient_id != user["sub"]):
        raise HTTPException(404, "Not found")
    audit.info("download actor=%s report=%s", user["sub"], report_id)
    return StreamingResponse(
        io.BytesIO(report.content),
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{report.title}"'},
    )
