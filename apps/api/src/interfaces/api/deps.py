"""LicitaI Piloto - Auth via Supabase (JWT do Supabase Auth)."""

from dataclasses import dataclass
from typing import Any

import httpx
from fastapi import Depends, Header, HTTPException, status
from jose import JWTError, jwt

from apps.api.src.settings import get_settings


@dataclass
class AuthUser:
    id: str
    email: str
    tenant_id: str
    role: str
    nome: str | None = None
    orgao_lotacao: str | None = None


_settings = get_settings()


def _decode_supabase_jwt(token: str) -> dict[str, Any]:
    """Decodifica e valida o JWT do Supabase (HS256)."""
    try:
        payload = jwt.decode(
            token,
            _settings.supabase_jwt_secret,
            algorithms=["HS256"],
            audience=_settings.jwt_audience,
            options={"verify_aud": bool(_settings.jwt_audience)},
        )
        return payload
    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token inválido: {e}",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def get_current_user(
    authorization: str | None = Header(None),
) -> AuthUser:
    """
    Extrai o usuário autenticado do header Authorization.
    Espera: "Bearer <jwt_token>"
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token de autenticação ausente",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = authorization.split(" ")[1]
    claims = _decode_supabase_jwt(token)

    user_id = claims.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token sem identificação de usuário",
        )

    return AuthUser(
        id=user_id,
        email=claims.get("email", ""),
        tenant_id=claims.get("tenant_id", ""),
        role=claims.get("role", "DEMANDANTE"),
        nome=claims.get("user_metadata", {}).get("nome"),
        orgao_lotacao=claims.get("user_metadata", {}).get("orgao_lotacao"),
    )


async def require_role(*allowed_roles: str):
    """Dependency factory que valida role do usuário."""

    async def _check(user: AuthUser = Depends(get_current_user)) -> AuthUser:
        if user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Role {user.role} não autorizada. Necessário: {allowed_roles}",
            )
        return user

    return _check
