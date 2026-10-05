import os
import time

import jwt
from fastapi import Depends, FastAPI, HTTPException
from prometheus_fastapi_instrumentator import Instrumentator
from pydantic import BaseModel

from .security import AUTH_MODE, LOCAL_SECRET, current_user

app = FastAPI(title="auth-service")
Instrumentator().instrument(app).expose(app)


class LoginIn(BaseModel):
    email: str
    role: str = "patient"


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/auth/dev-login")
def dev_login(body: LoginIn):
    """Local development only. In AWS the frontend signs in against Cognito directly."""
    if AUTH_MODE != "local":
        raise HTTPException(404, "Not found")
    now = int(time.time())
    token = jwt.encode(
        {"sub": body.email, "email": body.email, "role": body.role, "iat": now, "exp": now + 3600},
        LOCAL_SECRET, algorithm="HS256",
    )
    return {"access_token": token, "token_type": "bearer"}


@app.get("/auth/me")
def me(user: dict = Depends(current_user)):
    return user
