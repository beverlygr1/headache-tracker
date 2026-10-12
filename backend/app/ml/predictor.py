import json
import threading
from pathlib import Path

import joblib

from app.core.config import settings
from app.ml.prediction_schemas import FEATURE_COLS, PredictionInput


class Predictor:
    def __init__(self, model_path: Path, meta_path: Path) -> None:
        self._pipeline = joblib.load(model_path)
        self.meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if self.meta["feature_cols"] != FEATURE_COLS:
            raise RuntimeError(
                "Порядок признаков в model_meta.json и prediction_schemas.py не совпадает"
            )

    def predict(self, features: PredictionInput) -> float:
        proba = float(self._pipeline.predict_proba(features.to_dataframe())[0, 1])
        return round(proba, 2)


_predictor: Predictor | None = None
_lock = threading.Lock()


def load_model() -> Predictor:
    global _predictor
    if _predictor is None:
        with _lock:
            if _predictor is None:
                _predictor = Predictor(settings.ml_model_path, settings.ml_meta_path)
    return _predictor
