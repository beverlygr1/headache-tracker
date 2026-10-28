from typing import Annotated

from fastapi import APIRouter, File, HTTPException, Response, UploadFile, status

from app.api.deps import CurrentUser, DbSession
from app.repositories import avatars as avatar_repo
from app.repositories.users import update_onboarding as save_onboarding
from app.repositories.users import update_user
from app.schemas.user import (
    OnboardingUpdateRequest,
    UserProfileResponse,
    UserProfileUpdateRequest,
)

router = APIRouter(prefix="/user", tags=["Профиль"])


@router.get("/profile", response_model=UserProfileResponse)
def get_profile(current_user: CurrentUser) -> UserProfileResponse:
    return UserProfileResponse.model_validate(current_user)


@router.put("/profile", response_model=UserProfileResponse)
def update_profile(
    data: UserProfileUpdateRequest, db: DbSession, current_user: CurrentUser
) -> UserProfileResponse:
    user = update_user(db, current_user, data.model_dump(exclude_unset=True))
    return UserProfileResponse.model_validate(user)


@router.put("/onboarding", response_model=UserProfileResponse)
def update_onboarding(
    data: OnboardingUpdateRequest, db: DbSession, current_user: CurrentUser
) -> UserProfileResponse:
    user = save_onboarding(db, current_user, step=data.step, completed=data.completed)
    return UserProfileResponse.model_validate(user)


MAX_AVATAR_BYTES = 2 * 1024 * 1024


def _image_type(data: bytes) -> str | None:
    """Тип по содержимому файла, а не по заявленному Content-Type."""
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    return None


@router.put("/avatar", response_model=UserProfileResponse)
async def upload_avatar(
    db: DbSession, current_user: CurrentUser, file: Annotated[UploadFile, File()]
) -> UserProfileResponse:
    data = await file.read(MAX_AVATAR_BYTES + 1)
    if len(data) > MAX_AVATAR_BYTES:
        raise HTTPException(
            status_code=413,
            detail="Фото больше 2 МБ",
        )
    content_type = _image_type(data)
    if content_type is None:
        raise HTTPException(
            status_code=422,
            detail="Нужно фото в формате JPEG, PNG или WebP",
        )
    avatar_repo.save_avatar(db, current_user, content_type=content_type, data=data)
    return UserProfileResponse.model_validate(current_user)


@router.get("/avatar", response_class=Response)
def get_avatar(db: DbSession, current_user: CurrentUser) -> Response:
    avatar = avatar_repo.get_avatar(db, current_user.id)
    if avatar is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Фото не загружено")
    return Response(
        content=avatar.data,
        media_type=avatar.content_type,
        headers={"Cache-Control": "private, no-cache"},
    )


@router.delete("/avatar", status_code=status.HTTP_204_NO_CONTENT)
def delete_avatar(db: DbSession, current_user: CurrentUser) -> Response:
    avatar_repo.delete_avatar(db, current_user)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
