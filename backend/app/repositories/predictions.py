from sqlalchemy.orm import Session

from app.ml.prediction_schemas import PredictionInput
from app.models.prediction import Prediction


def create_prediction(
    db: Session,
    user_id: int,
    features: PredictionInput,
    probability: float,
    latitude: float | None = None,
    longitude: float | None = None,
    weather_observation_id: int | None = None,
) -> Prediction:
    prediction = Prediction(
        user_id=user_id,
        probability=probability,
        latitude=latitude,
        longitude=longitude,
        weather_observation_id=weather_observation_id,
        **features.model_dump(),
    )
    db.add(prediction)
    db.flush()
    return prediction
