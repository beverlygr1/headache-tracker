from fastapi import APIRouter, status

from app.api.deps import DbSession, CurrentUser
from app.schemas.auth import LoginRequest, PasswordChangeRequest, MessageResponse, RegisterRequest, TokenRefreshRequest, TokenResponse
from app.services import auth as auth_service

router = APIRouter(prefix="/auth", tags=["Авторизация"])


@router.post("/register", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
def register(data: RegisterRequest, db: DbSession) -> MessageResponse:
    auth_service.register(db, data)
    return MessageResponse(message="Пользователь успешно зарегистрирован")


@router.post("/login", response_model=TokenResponse)
def login(data: LoginRequest, db: DbSession) -> TokenResponse:
    return auth_service.login(db, data)


@router.post("/refresh", response_model=TokenResponse)
def refresh(data: TokenRefreshRequest, db: DbSession) -> TokenResponse:
    return auth_service.refresh(db, data.refresh_token)


@router.put("/password", response_model=TokenResponse)
def change_password(data: PasswordChangeRequest, db: DbSession, current_user: CurrentUser) -> TokenResponse:
    return auth_service.change_password(db, current_user, data.current_password, data.new_password)
