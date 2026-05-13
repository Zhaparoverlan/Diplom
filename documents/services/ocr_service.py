# documents/services/ocr_service.py
from paddleocr import PaddleOCR

# Инициализируется один раз на процесс
_OCR = PaddleOCR(
    use_angle_cls=True,
    lang="ru",      # для кириллицы; при необходимости можно сменить модель на multilingual
    use_gpu=False,  # переключить при наличии GPU
    show_log=False,
    enable_mkldnn=False,
)

def extract_text_from_image(image_path: str) -> tuple[str, float]:
    result = _OCR.ocr(image_path, cls=True)

    lines = []
    confs = []
    for page in result or []:
        for item in page or []:
            # item: [box, (text, confidence)]
            text, conf = item[1][0], float(item[1][1])
            if text:
                lines.append(text.strip())
                confs.append(conf)

    full_text = "\n".join(lines).strip()
    avg_conf = (sum(confs) / len(confs)) if confs else 0.0
    return full_text, avg_conf