from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.avatar import UserAvatar
from app.models.user import User


def get_avatar(db: Session, user_id: int) -> UserAvatar | None:
    return db.get(UserAvatar, user_id)


def save_avatar(db: Session, user: User, *, content_type: str, data: bytes) -> UserAvatar:
    avatar = db.get(UserAvatar, user.id)
    if avatar is None:
        avatar = UserAvatar(user_id=user.id, content_type=content_type, data=data)
        db.add(avatar)
    else:
        avatar.content_type = content_type
        avatar.data = data
        # onupdate срабатывает не во всех диалектах для повторной записи тех же байтов.
        avatar.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(user)
    return avatar


def delete_avatar(db: Session, user: User) -> None:
    avatar = db.get(UserAvatar, user.id)
    if avatar is not None:
        db.delete(avatar)
        db.commit()
    db.refresh(user)
