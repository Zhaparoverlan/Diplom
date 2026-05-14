"""
Постобработка текста чека после OCR: сумма (контекстное окно) и поставщик.
"""
from __future__ import annotations

import re
from typing import List, Optional

# Ключевые слова итога: текущая строка ± 2 строки
_KEYWORD_RE = re.compile(
    r"(Итого|ИТОГО|Всего|ВСЕГО|Total|Сумма|Оплачено|ОПЛАЧЕНО|ИТОГ|"
    r"К\s*оплате|Всего\s*к\s*оплате|Amount)",
    re.IGNORECASE,
)

_SUPPLIER_RE = re.compile(r"(ООО|ОсОО|\bИП\b)")


def normalize_amount_string(raw: str) -> Optional[float]:
    """Убирает пробелы/апострофы внутри числа, нормализует запятую как десятичный разделитель."""
    if not raw:
        return None
    t = raw.strip()
    t = re.sub(r"\s+", "", t)
    t = t.replace("'", "").replace("’", "")
    if "," in t and "." in t:
        t = t.replace(".", "").replace(",", ".")
    else:
        t = t.replace(",", ".")
    t = re.sub(r"[^\d.]", "", t)
    if not t:
        return None
    if t.count(".") > 1:
        parts = t.split(".")
        t = "".join(parts[:-1]) + "." + parts[-1]
    try:
        v = float(t)
    except ValueError:
        return None
    if v != v or v <= 0:
        return None
    return v


def _candidates_in_segment(segment: str) -> List[float]:
    out: List[float] = []
    for m in re.finditer(r"\d[\d\s.,'’]*", segment):
        v = normalize_amount_string(m.group(0))
        if v is not None:
            out.append(v)
    return out


def extract_amount_from_receipt_text(text: str) -> float:
    """
    Контекстное окно ±2 строки вокруг строки с совпадением ключевых слов.
    Приоритет: число на той же строке, что и ключевое слово (после него, иначе до него),
    иначе максимум среди кандидатов в окне (только внутри окна, не по всему документу).
    """
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    if not lines:
        return 0.0
    n = len(lines)
    for i in range(n):
        lo = max(0, i - 2)
        hi = min(n, i + 3)
        window = lines[lo:hi]
        block = "\n".join(window)
        if not _KEYWORD_RE.search(block):
            continue
        for j in range(lo, hi):
            ln = lines[j]
            for kw in _KEYWORD_RE.finditer(ln):
                tail = ln[kw.end() :]
                cands = _candidates_in_segment(tail)
                if cands:
                    return cands[-1]
                head = ln[: kw.start()]
                cands = _candidates_in_segment(head)
                if cands:
                    return cands[-1]
        pool: List[float] = []
        for ln in window:
            pool.extend(_candidates_in_segment(ln))
        pool = [x for x in pool if 0 < x < 1e9]
        if pool:
            return max(pool)
    return 0.0


def extract_supplier_from_receipt_text(text: str) -> Optional[str]:
    """Первая строка, содержащая ООО / ИП / ОсОО."""
    for ln in text.splitlines():
        s = ln.strip()
        if not s:
            continue
        if _SUPPLIER_RE.search(s):
            return s[:255]
    return None


# DD.MM.YYYY or DD/MM/YYYY or DD-MM-YYYY
_DATE_RE = re.compile(r'\b(\d{1,2})[./\-](\d{1,2})[./\-](\d{2,4})\b')


def extract_date_from_receipt_text(text: str) -> Optional[str]:
    """Return ISO date YYYY-MM-DD from the first valid date found in text, or None."""
    import datetime
    for m in _DATE_RE.finditer(text):
        day_v, mon_v, yr_v = int(m.group(1)), int(m.group(2)), int(m.group(3))
        if yr_v < 100:
            yr_v += 2000
        try:
            d = datetime.date(yr_v, mon_v, day_v)
            if 2000 <= d.year <= 2100:
                return d.isoformat()
        except ValueError:
            continue
    return None
