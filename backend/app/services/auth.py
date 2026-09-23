from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.security import TokenDecodeError, create_access_token, create_refresh_token, decode_token, hash_password, verify_password
from app.repositories import users as user_repo
from app.schemas.auth import LoginRequest, RegisterRequest, TokenResponse


def register(db: Session, data: RegisterRequest) -> None:
    if user_repo.get_user_by_email(db, str(data.email)) is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email уже зарегистрирован")
    try:
        user_repo.create_user(db, email=str(data.email), password_hash=hash_password(data.password), name=data.name.strip())
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email уже зарегистрирован") from exc


def login(db: Session, data: LoginRequest) -> TokenResponse:
    user = user_repo.get_user_by_email(db, str(data.email))
    if user is None or not verify_password(data.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Неверный email или пароль")
    return TokenResponse(access_token=create_access_token(user.id), refresh_token=create_refresh_token(user.id))


def refresh(db: Session, refresh_token: str) -> TokenResponse:
    try:
        user_id = decode_token(refresh_token, "refresh")
    except TokenDecodeError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    user = user_repo.get_user_by_id(db, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Пользователь не найден")
    return TokenResponse(access_token=create_access_token(user.id), refresh_token=create_refresh_token(user.id))
