import datetime as dt
import json
import os

import boto3
import redis
from fastapi import Depends, FastAPI, HTTPException
from prometheus_fastapi_instrumentator import Instrumentator
from pydantic import BaseModel
from sqlalchemy import Column, DateTime, Integer, String, UniqueConstraint, create_engine, select
from sqlalchemy.orm import Session, declarative_base

from .security import current_user, require_role

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./dev.db")
REDIS_URL = os.getenv("REDIS_URL", "")
QUEUE_URL = os.getenv("REMINDER_QUEUE_URL", "")
SLOT_TTL = 60

engine = create_engine(DATABASE_URL, pool_pre_ping=True)
Base = declarative_base()
cache = redis.from_url(REDIS_URL, decode_responses=True) if REDIS_URL else None
sqs = boto3.client("sqs") if QUEUE_URL else None


class Appointment(Base):
    __tablename__ = "appointments"
    __table_args__ = (UniqueConstraint("doctor_id", "starts_at", name="uq_doctor_slot"),)
    id = Column(Integer, primary_key=True)
    patient_id = Column(String, index=True, nullable=False)
    patient_email = Column(String)
    doctor_id = Column(String, index=True, nullable=False)
    starts_at = Column(DateTime, nullable=False)
    status = Column(String, default="booked")


Base.metadata.create_all(engine)
app = FastAPI(title="appointment-service")
Instrumentator().instrument(app).expose(app)


def db():
    with Session(engine) as s:
        yield s


class BookIn(BaseModel):
    doctor_id: str
    starts_at: dt.datetime


@app.get("/health")
def health():
    return {"status": "ok"}


def _free_slots(session: Session, doctor_id: str, day: dt.date) -> list[str]:
    taken = {
        a.starts_at.hour
        for a in session.scalars(select(Appointment).where(Appointment.doctor_id == doctor_id))
        if a.starts_at.date() == day and a.status == "booked"
    }
    return [f"{day}T{h:02d}:00:00" for h in range(9, 17) if h not in taken]


@app.get("/appointments/slots")
def slots(doctor_id: str, day: dt.date, session: Session = Depends(db), _=Depends(current_user)):
    key = f"slots:{doctor_id}:{day}"
    if cache and (hit := cache.get(key)):
        return {"slots": json.loads(hit), "cached": True}
    result = _free_slots(session, doctor_id, day)
    if cache:
        cache.setex(key, SLOT_TTL, json.dumps(result))
    return {"slots": result, "cached": False}


@app.post("/appointments", status_code=201)
def book(body: BookIn, session: Session = Depends(db), user=Depends(require_role("patient"))):
    appt = Appointment(patient_id=user["sub"], patient_email=user["email"],
                       doctor_id=body.doctor_id, starts_at=body.starts_at)
    session.add(appt)
    try:
        session.commit()
    except Exception:
        session.rollback()
        raise HTTPException(409, "Slot already booked")
    if cache:
        cache.delete(f"slots:{body.doctor_id}:{body.starts_at.date()}")
    if sqs:
        sqs.send_message(QueueUrl=QUEUE_URL, MessageBody=json.dumps({
            "appointment_id": appt.id, "email": appt.patient_email,
            "starts_at": body.starts_at.isoformat()}))
    return {"id": appt.id, "status": appt.status}


@app.get("/appointments")
def list_mine(session: Session = Depends(db), user=Depends(current_user)):
    col = Appointment.doctor_id if user["role"] == "doctor" else Appointment.patient_id
    rows = session.scalars(select(Appointment).where(col == user["sub"]).order_by(Appointment.starts_at))
    return [{"id": a.id, "doctor_id": a.doctor_id, "starts_at": a.starts_at, "status": a.status} for a in rows]
