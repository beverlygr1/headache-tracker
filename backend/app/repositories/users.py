from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.models.user import User


def get_user_by_email(db: Session, email: str) -> User | None:
    return db.execute(
        select(User).where(User.email == email.lower())
    ).scalar_one_or_none()


def get_user_by_id(db: Session, user_id: int) -> User | None:
    return db.get(User, user_id)


def create_user(db: Session, *, email: str, password_hash: str, name: str) -> User:
    user = User(email=email.lower(), password_hash=password_hash, name=name)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def update_user(db: Session, user: User, values: dict) -> User:
    for field, value in values.items():
        setattr(user, field, value)
    db.commit()
    db.refresh(user)
    return user


def update_onboarding(db: Session, user: User, *, step: int, completed: bool) -> User:
    # The condition is checked atomically, including concurrent device requests.
    db.execute(
        update(User)
        .where(User.id == user.id, User.onboarding_completed.is_(False))
        .values(
            onboarding_step=1 if completed else step,
            onboarding_completed=completed,
        )
    )
    db.commit()
    db.refresh(user)
    return user
