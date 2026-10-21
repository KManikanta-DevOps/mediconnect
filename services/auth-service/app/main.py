import os
import time

import jwt
from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from prometheus_fastapi_instrumentator import Instrumentator
from pydantic import BaseModel

from .security import AUTH_MODE, LOCAL_SECRET, current_user

app = FastAPI(title="auth-service")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
Instrumentator().instrument(app).expose(app)


class LoginIn(BaseModel):
    email: str
    role: str = "patient"


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/auth/dev-login")
def dev_login(body: LoginIn):
    """Public-demo login only. Never use this mode for real patient data."""
    if AUTH_MODE != "local":
        raise HTTPException(404, "Not found")
    if body.role != "patient":
        raise HTTPException(403, "Demo login only supports the patient role")
    email = body.email.strip().lower()
    if not email or "@" not in email:
        raise HTTPException(422, "Enter a valid email address")
    now = int(time.time())
    token = jwt.encode(
        {"sub": email, "email": email, "role": "patient", "iat": now, "exp": now + 3600},
        LOCAL_SECRET,
        algorithm="HS256",
    )
    return {"access_token": token, "token_type": "bearer"}


@app.get("/auth/me")
def me(user: dict = Depends(current_user)):
    return user
