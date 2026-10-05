"""JWT verification shared by all services.

Prod: validates Cognito-issued JWTs against the user pool JWKS.
Local: set AUTH_MODE=local to use an HS256 shared secret (docker-compose only).
"""
import os
import time
from functools import lru_cache

import httpx
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

bearer = HTTPBearer(auto_error=False)
AUTH_MODE = os.getenv("AUTH_MODE", "cognito")
LOCAL_SECRET = os.getenv("LOCAL_JWT_SECRET", "dev-only-secret")
REGION = os.getenv("AWS_REGION", "us-east-1")
POOL_ID = os.getenv("COGNITO_USER_POOL_ID", "")
CLIENT_ID = os.getenv("COGNITO_CLIENT_ID", "")


@lru_cache(maxsize=1)
def _jwks():
    url = f"https://cognito-idp.{REGION}.amazonaws.com/{POOL_ID}/.well-known/jwks.json"
    return httpx.get(url, timeout=5).json()["keys"]


def _decode(token: str) -> dict:
    if AUTH_MODE == "local":
        return jwt.decode(token, LOCAL_SECRET, algorithms=["HS256"])
    kid = jwt.get_unverified_header(token)["kid"]
    key = next(k for k in _jwks() if k["kid"] == kid)
    public_key = jwt.algorithms.RSAAlgorithm.from_jwk(key)
    claims = jwt.decode(token, public_key, algorithms=["RS256"], options={"verify_aud": False})
    if claims.get("client_id", claims.get("aud")) != CLIENT_ID:
        raise jwt.InvalidTokenError("bad client")
    return claims


def current_user(creds: HTTPAuthorizationCredentials = Depends(bearer)) -> dict:
    if creds is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing bearer token")
    try:
        claims = _decode(creds.credentials)
    except Exception:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid token")
    return {
        "sub": claims["sub"],
        "role": claims.get("custom:role", claims.get("role", "patient")),
        "email": claims.get("email"),
    }


def require_role(*roles: str):
    def checker(user: dict = Depends(current_user)) -> dict:
        if user["role"] not in roles:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Insufficient role")
        return user
    return checker
