from __future__ import annotations

# До импорта paddle/paddleocr: обход NotImplementedError oneDNN+PIR на CPU (Windows).
# См. https://github.com/PaddlePaddle/Paddle/issues/77340
import os

os.environ.setdefault("FLAGS_use_mkldnn", "0")

import logging
from typing import Any, List, Tuple

try:
    from paddleocr import PaddleOCR
except Exception:  # pragma: no cover
    PaddleOCR = None

logger = logging.getLogger(__name__)

_OCR_ENGINE = None


def _get_ocr_engine():
    """Один экземпляр PaddleOCR на процесс (lazy init).

    enable_mkldnn=False — критично для Paddle 3.3+ на CPU (иначе падает predict).
    Не передавать use_gpu / show_log (ломает конструктор в paddleocr 3.x).
    """
    global _OCR_ENGINE

    if _OCR_ENGINE is not None:
        return _OCR_ENGINE

    if PaddleOCR is None:
        logger.error("Пакет paddleocr не установлен: pip install paddleocr paddlepaddle")
        return None

    try:
        import paddle

        paddle.set_flags({"FLAGS_use_mkldnn": False})
    except Exception:
        pass

    try:
        _OCR_ENGINE = PaddleOCR(
            lang="ru",
            use_angle_cls=True,
            enable_mkldnn=False,
        )
    except (ValueError, TypeError):
        # Старый paddleocr 2.x без enable_mkldnn в общих аргументах
        _OCR_ENGINE = PaddleOCR(lang="ru", use_angle_cls=True)
    return _OCR_ENGINE


def _collect_from_paddlex_page(page: Any, lines: List[str], confs: List[float]) -> None:
    """Формат PaddleX / paddleocr 3.x: dict или OCRResult с rec_texts / rec_scores."""
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
    """Старый формат PP-OCR 2.x: список элементов [box, (text, confidence)]."""
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
    """Разбор ответа predict()/ocr() для PaddleOCR 2.x и 3.x (PaddleX)."""
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


def _run_ocr(ocr, image_path: str) -> Any:
    """Вызов инференса без cls= (в PaddleX predict() его нет)."""
    predict = getattr(ocr, "predict", None)
    if callable(predict):
        return predict(image_path)
    try:
        return ocr.ocr(image_path, cls=True)
    except TypeError:
        return ocr.ocr(image_path)


def extract_text_from_image(image_path: str) -> Tuple[str, float]:
    """
    Путь к изображению → (full_text, средняя confidence по строкам).
    """
    ocr = _get_ocr_engine()
    if ocr is None:
        return "", 0.0

    raw = _run_ocr(ocr, image_path)
    full_text, avg_conf = _parse_ocr_result(raw)

    logger.info(
        "OCR Paddle confidence=%.4f image=%s text_len=%d",
        avg_conf,
        image_path,
        len(full_text),
    )
    return full_text, avg_conf
