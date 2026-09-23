from fastapi import APIRouter

from app.api.deps import CurrentUser, DbSession
from app.repositories.users import update_user
from app.schemas.user import UserProfileResponse, UserProfileUpdateRequest

router = APIRouter(prefix="/user", tags=["Профиль"])


@router.get("/profile", response_model=UserProfileResponse)
def get_profile(current_user: CurrentUser) -> UserProfileResponse:
    return UserProfileResponse.model_validate(current_user)


@router.put("/profile", response_model=UserProfileResponse)
def update_profile(data: UserProfileUpdateRequest, db: DbSession, current_user: CurrentUser) -> UserProfileResponse:
    user = update_user(db, current_user, data.model_dump(exclude_unset=True))
    return UserProfileResponse.model_validate(user)
