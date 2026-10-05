"""Consumes appointment events from SQS and emails reminders via SES.
The FastAPI app only exposes health + metrics; the worker runs in a background thread."""
import json
import logging
import os
import threading

import boto3
from fastapi import FastAPI
from prometheus_client import Counter
from prometheus_fastapi_instrumentator import Instrumentator

QUEUE_URL = os.getenv("REMINDER_QUEUE_URL", "")
SENDER = os.getenv("SES_SENDER", "no-reply@example.com")
log = logging.getLogger("notification")
logging.basicConfig(level=logging.INFO)
SENT = Counter("reminders_sent_total", "Reminder emails sent")
FAILED = Counter("reminders_failed_total", "Reminder emails failed")


def render(msg: dict) -> tuple[str, str]:
    return ("Your appointment is confirmed",
            f"Your appointment is scheduled for {msg['starts_at']}. Reference #{msg['appointment_id']}.")


def process(msg: dict, ses) -> None:
    subject, body = render(msg)
    ses.send_email(Source=SENDER, Destination={"ToAddresses": [msg["email"]]},
                   Message={"Subject": {"Data": subject}, "Body": {"Text": {"Data": body}}})
    SENT.inc()


def worker():
    sqs, ses = boto3.client("sqs"), boto3.client("ses")
    while True:
        resp = sqs.receive_message(QueueUrl=QUEUE_URL, WaitTimeSeconds=20, MaxNumberOfMessages=5)
        for m in resp.get("Messages", []):
            try:
                process(json.loads(m["Body"]), ses)
                sqs.delete_message(QueueUrl=QUEUE_URL, ReceiptHandle=m["ReceiptHandle"])
            except Exception:  # left on queue -> retried -> DLQ after maxReceiveCount
                FAILED.inc()
                log.exception("failed to process message")


app = FastAPI(title="notification-service")
Instrumentator().instrument(app).expose(app)


@app.on_event("startup")
def start():
    if QUEUE_URL:
        threading.Thread(target=worker, daemon=True).start()


@app.get("/health")
def health():
    return {"status": "ok"}
