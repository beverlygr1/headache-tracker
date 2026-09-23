from fastapi import APIRouter

from app.api.routers import analytics, attacks, auth, diary, forecast, profile

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(profile.router)
api_router.include_router(attacks.router)
api_router.include_router(diary.router)
api_router.include_router(analytics.router)
api_router.include_router(forecast.router)
