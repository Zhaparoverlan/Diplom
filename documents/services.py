from __future__ import annotations

import logging
import os
import tempfile
from typing import Any, List, Tuple

import cv2
import numpy as np

# Must be set before PaddlePaddle is imported to avoid ConvertPirAttribute2RuntimeAttribute
os.environ.setdefault("FLAGS_enable_pir_api", "0")
os.environ.setdefault("FLAGS_use_mkldnn", "0")

try:
    from paddleocr import PaddleOCR
except Exception:  # pragma: no cover
    PaddleOCR = None

logger = logging.getLogger(__name__)

# Загружаемые модели (для отчёта / диплома) — см. _get_ocr_engine()
OCR_DET_MODEL_NAME = "PP-OCRv5_mobile_det"
OCR_REC_MODEL_NAME = "cyrillic_PP-OCRv5_mobile_rec"

_OCR_ENGINE = None


def _get_ocr_engine():
    """Singleton PaddleOCR engine (PP-OCRv5 mobile, CPU). PIR and mkldnn disabled via env."""
    global _OCR_ENGINE

    if _OCR_ENGINE is not None:
        return _OCR_ENGINE

    if PaddleOCR is None:
        logger.error("Пакет paddleocr не установлен: pip install paddleocr paddlepaddle")
        return None

    _OCR_ENGINE = PaddleOCR(
        use_angle_cls=True,
        text_detection_model_name=OCR_DET_MODEL_NAME,
        text_recognition_model_name=OCR_REC_MODEL_NAME,
        enable_mkldnn=False,
        device="cpu",
    )
    logger.info("OCR engine: det=%s rec=%s", OCR_DET_MODEL_NAME, OCR_REC_MODEL_NAME)
    return _OCR_ENGINE


def _collect_from_paddlex_page(page: Any, lines: List[str], confs: List[float]) -> None:
    if page is None:
        return
    get = getattr(page, "get", None)
    if callable(get):
        rec_texts = page.get("rec_texts")
        rec_scores = page.get("rec_scores")
    else:
        rec_texts = getattr(page, "rec_texts", None)
        rec_scores = getattr(page, "rec_scores", None)

    if not rec_texts:
        return

    scores = list(rec_scores) if rec_scores is not None else []
    for i, raw in enumerate(rec_texts):
        text = raw
        if isinstance(text, tuple):
            text = text[0]
        text = (text or "").strip() if isinstance(text, str) else str(text).strip()
        if not text:
            continue
        conf = 1.0
        if i < len(scores):
            try:
                s = scores[i]
                conf = float(s) if not isinstance(s, (list, tuple)) else float(s[0])
            except (TypeError, ValueError, IndexError):
                conf = 0.0
        lines.append(text)
        confs.append(conf)


def _collect_from_legacy_page(page: Any, lines: List[str], confs: List[float]) -> None:
    if not isinstance(page, (list, tuple)):
        return
    for item in page:
        if not item or len(item) < 2:
            continue
        try:
            pair = item[1]
            if isinstance(pair, (list, tuple)) and len(pair) >= 2:
                text, conf = str(pair[0]).strip(), float(pair[1])
            elif isinstance(pair, str):
                text, conf = pair.strip(), 1.0
            else:
                continue
            if text:
                lines.append(text)
                confs.append(conf)
        except (TypeError, ValueError, IndexError):
            continue


def _parse_ocr_result(result: Any) -> Tuple[str, float]:
    lines: List[str] = []
    confs: List[float] = []

    if not result:
        return "", 0.0

    for page in result:
        before = len(lines)
        _collect_from_paddlex_page(page, lines, confs)
        if len(lines) == before:
            _collect_from_legacy_page(page, lines, confs)

    full_text = "\n".join(lines).strip()
    avg_conf = (sum(confs) / len(confs)) if confs else 0.0
    return full_text, avg_conf


def _run_ocr(ocr, image_input: Any) -> Any:
    predict = getattr(ocr, "predict", None)
    if callable(predict):
        return predict(image_input)
    try:
        return ocr.ocr(image_input, cls=True)
    except TypeError:
        return ocr.ocr(image_input)


def _preprocess_bgr(img: np.ndarray) -> np.ndarray:
    """Resize по ширине до 1500 px + адаптивный порог (контраст для OCR)."""
    h, w = img.shape[:2]
    if w > 1500:
        scale = 1500.0 / w
        img = cv2.resize(
            img,
            (1500, max(1, int(round(h * scale)))),
            interpolation=cv2.INTER_AREA,
        )
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    bin_img = cv2.adaptiveThreshold(
        gray,
        255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY,
        35,
        11,
    )
    return cv2.cvtColor(bin_img, cv2.COLOR_GRAY2BGR)


def extract_text_from_image(image_path: str) -> Tuple[str, float]:
    """
    Читает файл с диска, препроцессит (OpenCV), подаёт в Paddle predict, возвращает (text, avg_conf).
    """
    ocr = _get_ocr_engine()
    if ocr is None:
        return "", 0.0

    buf = np.fromfile(image_path, dtype=np.uint8)
    img = cv2.imdecode(buf, cv2.IMREAD_COLOR)
    tmp_path = None
    try:
        if img is not None:
            proc = _preprocess_bgr(img)
            fd, tmp_path = tempfile.mkstemp(suffix="_ocr_in.png", prefix="ledms_")
            os.close(fd)
            cv2.imencode(".png", proc)[1].tofile(tmp_path)
            inp = tmp_path
        else:
            inp = image_path

        raw = _run_ocr(ocr, inp)
        full_text, avg_conf = _parse_ocr_result(raw)

        logger.info(
            "OCR done confidence=%.4f text_len=%d input=%s",
            avg_conf,
            len(full_text),
            image_path,
        )
        return full_text, avg_conf
    finally:
        if tmp_path and os.path.isfile(tmp_path):
            try:
                os.remove(tmp_path)
            except OSError:
                pass
