from datetime import datetime, timedelta, timezone
from typing import Any, Literal

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError
from jwt import InvalidTokenError

from app.core.config import settings

password_hasher = PasswordHasher()
TokenType = Literal["access", "refresh"]


class TokenDecodeError(ValueError):
    pass


def hash_password(password: str) -> str:
    return password_hasher.hash(password)


def verify_password(password: str, hashed_password: str) -> bool:
    try:
        return password_hasher.verify(hashed_password, password)
    except (VerifyMismatchError, VerificationError, InvalidHashError):
        return False


def _create_token(subject: int, token_type: TokenType, expires_delta: timedelta, token_version: int = 0) -> str:
    now = datetime.now(timezone.utc)
    payload: dict[str, Any] = {
        "sub": str(subject),
        "type": token_type,
        "ver": token_version,
        "iat": now,
        "exp": now + expires_delta,
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def create_access_token(user_id: int, token_version: int = 0) -> str:
    return _create_token(user_id, "access", timedelta(minutes=settings.access_token_expire_minutes), token_version)


def create_refresh_token(user_id: int, token_version: int = 0) -> str:
    return _create_token(user_id, "refresh", timedelta(days=settings.refresh_token_expire_days), token_version)


def decode_session_token(token: str, expected_type: TokenType) -> tuple[int, int]:
    try:
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
    except InvalidTokenError as exc:
        raise TokenDecodeError("Недействительный или просроченный токен") from exc
    if payload.get("type") != expected_type:
        raise TokenDecodeError("Неверный тип токена")
    subject = payload.get("sub")
    if subject is None:
        raise TokenDecodeError("В токене отсутствует subject")
    try:
        version = payload.get("ver", 0)
        if type(version) is not int or version < 0:
            raise TokenDecodeError("Некорректная версия сессии")
        return int(subject), version
    except (TypeError, ValueError) as exc:
        raise TokenDecodeError("Некорректный subject токена") from exc


def decode_token(token: str, expected_type: TokenType) -> int:
    return decode_session_token(token, expected_type)[0]
