from datetime import datetime

from sqlalchemy import ForeignKey, LargeBinary, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base
from app.models.types import UTCDateTime


class UserAvatar(Base):
    """Фото профиля. Хранится в БД: отдельного файлового хранилища у проекта нет."""

    __tablename__ = "user_avatars"

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    content_type: Mapped[str] = mapped_column(String(32), nullable=False)
    # deferred: профиль читает только дату обновления, а не сами байты.
    data: Mapped[bytes] = mapped_column(LargeBinary, nullable=False, deferred=True)
    updated_at: Mapped[datetime] = mapped_column(
        UTCDateTime(), server_default=func.now(), onupdate=func.now(), nullable=False
    )
