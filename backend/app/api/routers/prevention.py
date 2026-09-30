from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.session import get_db
from app.api.deps import get_current_user
from app.models.new_features import UserSetting, UserSupplement
from app.schemas.new_features import (
    UserSettingsUpdate, UserSettingsResponse,
    SupplementCreate, SupplementResponse, ArticleResponse
)

router = APIRouter(prefix="/prevention", tags=["Профилактика и настройки"])


@router.get("/settings", response_model=UserSettingsResponse)
async def get_settings(
        current_user=Depends(get_current_user),
        db: AsyncSession = Depends(get_db)
):
    """Получение настроек уведомлений и темы интерфейса."""
    stmt = select(UserSetting).where(UserSetting.user_id == current_user.id)
    result = await db.execute(stmt)
    settings = result.scalar_one_or_none()

    if not settings:
        settings = UserSetting(user_id=current_user.id)
        db.add(settings)
        await db.commit()
        await db.refresh(settings)

    return settings


@router.put("/settings", response_model=UserSettingsResponse)
async def update_settings(
        data: UserSettingsUpdate,
        current_user=Depends(get_current_user),
        db: AsyncSession = Depends(get_db)
):
    """Обновление настроек уведомлений и темы."""
    stmt = select(UserSetting).where(UserSetting.user_id == current_user.id)
    result = await db.execute(stmt)
    settings = result.scalar_one_or_none()

    if not settings:
        settings = UserSetting(user_id=current_user.id)
        db.add(settings)

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(settings, field, value)

    await db.commit()
    await db.refresh(settings)
    return settings


@router.get("/supplements", response_model=List[SupplementResponse])
async def get_supplements(
        current_user=Depends(get_current_user),
        db: AsyncSession = Depends(get_db)
):
    """Список витаминов и БАДов в расписании пользователя."""
    stmt = select(UserSupplement).where(UserSupplement.user_id == current_user.id)
    result = await db.execute(stmt)
    return result.scalars().all()


@router.post("/supplements", response_model=SupplementResponse, status_code=status.HTTP_201_CREATED)
async def add_supplement(
        data: SupplementCreate,
        current_user=Depends(get_current_user),
        db: AsyncSession = Depends(get_db)
):
    """Добавление витамина / БАДа в расписание."""
    item = UserSupplement(user_id=current_user.id, name=data.name, intake_time=data.intake_time)
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item


@router.get("/articles", response_model=List[ArticleResponse])
async def get_knowledge_base():
    """Справочник по типам боли и опасным симптомам (Красные флаги)."""
    return [
        ArticleResponse(
            id="migraine_info",
            title="Мигрень: основные особенности",
            category="migraine",
            summary="Пульсирующая боль, односторонняя локализация, светобоязнь.",
            content="Мигрень часто сопровождается тошнотой и аурой. Важно фиксировать триггеры..."
        ),
        ArticleResponse(
            id="red_flags",
            title="Когда нужно срочно обратиться к врачу (Красные флаги)",
            category="red_flags",
            summary="Внезапная громоподобная боль, высокая температура, нарушение речи.",
            content="Срочно вызывайте скорую помощь при появлении онемения конечностей или травме..."
        )
    ]