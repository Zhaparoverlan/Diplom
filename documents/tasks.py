from __future__ import annotations

import logging
from decimal import Decimal

from celery import shared_task

logger = logging.getLogger(__name__)


@shared_task(max_retries=3, default_retry_delay=60)
def process_document(document_id: int) -> None:
    """
    Background OCR pipeline for a saved document:
      1. Near-duplicate detection via pHash (distance 5-15 → NEEDS_APPROVAL).
      2. OCR extraction of amount / supplier / date.
      3. Conflict resolution: user input is source of truth; OCR fills empty fields
         or flags discrepancies → NEEDS_VERIFICATION.
      4. Final status: READY if clean, otherwise NEEDS_VERIFICATION / NEEDS_APPROVAL.
    """
    from .models import Document
    from .services import extract_text_from_image, phash_distance
    from .receipt_parser import (
        extract_amount_from_receipt_text,
        extract_date_from_receipt_text,
        extract_supplier_from_receipt_text,
    )

    logger.info("process_document START doc=%s", document_id)

    try:
        doc = Document.objects.select_related('company').get(pk=document_id)
    except Document.DoesNotExist:
        logger.warning("process_document: doc %s not found", document_id)
        return

    logger.info("process_document doc=%s initial_status=%s", document_id, doc.status)

    # Skip if already resolved synchronously (e.g. flagged DUPLICATE)
    if doc.status == 'duplicate':
        logger.info("process_document doc=%s skipped (already duplicate)", document_id)
        return

    # ── Step 1: near-duplicate detection ──────────────────────────────────────
    is_near_duplicate = False
    if doc.phash:
        existing_hashes = (
            Document.objects
            .filter(company=doc.company)
            .exclude(pk=doc.pk)
            .exclude(phash__isnull=True)
            .exclude(phash='')
            .values_list('phash', flat=True)
        )
        for other_hash in existing_hashes:
            dist = phash_distance(doc.phash, other_hash)
            if 5 <= dist <= 15:
                is_near_duplicate = True
                logger.info(
                    "STEP1 near-duplicate doc=%s dist=%d → will set needs_approval",
                    document_id, dist,
                )
                break
        if not is_near_duplicate:
            logger.info("STEP1 doc=%s no near-duplicate found", document_id)
    else:
        logger.info("STEP1 doc=%s no phash, skipping near-dup check", document_id)

    # ── Step 2: OCR ───────────────────────────────────────────────────────────
    ocr_amount: float | None   = None
    ocr_supplier: str | None   = None
    ocr_date: str | None       = None
    ocr_conf: float            = 0.0
    extracted_text: str        = ""

    is_image = bool(
        doc.file and doc.file.name.lower().endswith(('.png', '.jpg', '.jpeg'))
    )

    if is_image:
        logger.info("STEP2 doc=%s running OCR on %s", document_id, doc.file.name)
        try:
            extracted_text, ocr_conf = extract_text_from_image(doc.file.path)
            extracted_text = (extracted_text or "").strip()
            logger.info(
                "STEP2 doc=%s OCR done conf=%.4f text_len=%d",
                document_id, ocr_conf, len(extracted_text),
            )
            if extracted_text:
                doc.raw_text = extracted_text
                raw_amount   = extract_amount_from_receipt_text(extracted_text)
                ocr_amount   = raw_amount if raw_amount > 0 else None
                ocr_supplier = extract_supplier_from_receipt_text(extracted_text)
                ocr_date     = extract_date_from_receipt_text(extracted_text)
                logger.info(
                    "STEP2 doc=%s parsed amount=%s supplier=%r date=%s",
                    document_id, ocr_amount, ocr_supplier, ocr_date,
                )
        except Exception:
            logger.exception("STEP2 OCR failed for document %s", document_id)
    else:
        logger.info("STEP2 doc=%s not an image, skipping OCR", document_id)

    doc.confidence_score = ocr_conf

    # ── Step 3: conflict resolution (user input = source of truth) ────────────
    has_conflict = False

    # Amount: flag if user provided a value and OCR disagrees by > 10 %
    if doc.amount is not None and ocr_amount is not None:
        user_amount = float(doc.amount)
        divisor     = max(abs(user_amount), abs(ocr_amount), 1e-9)
        rel_diff    = abs(user_amount - ocr_amount) / divisor
        if rel_diff > 0.10:
            has_conflict = True
            logger.info(
                "STEP3 amount conflict doc=%s user=%.2f ocr=%.2f diff=%.0f%% → needs_verification",
                document_id, user_amount, ocr_amount, rel_diff * 100,
            )
        else:
            logger.info(
                "STEP3 amount ok doc=%s user=%.2f ocr=%.2f diff=%.0f%%",
                document_id, user_amount, ocr_amount, rel_diff * 100,
            )
    elif ocr_amount is not None and doc.amount is None:
        doc.amount = Decimal(str(round(ocr_amount, 2)))
        logger.info("STEP3 doc=%s amount filled from OCR: %s", document_id, doc.amount)

    # Supplier: flag only if neither string is contained in the other
    if doc.supplier and ocr_supplier:
        a, b = doc.supplier.lower(), ocr_supplier.lower()
        if a not in b and b not in a:
            has_conflict = True
            logger.info(
                "STEP3 supplier conflict doc=%s user=%r ocr=%r → needs_verification",
                document_id, doc.supplier, ocr_supplier,
            )
    elif ocr_supplier and not doc.supplier:
        doc.supplier = ocr_supplier[:255]
        logger.info("STEP3 doc=%s supplier filled from OCR: %r", document_id, doc.supplier)

    # Date: fill if empty, no conflict check
    if ocr_date and not doc.doc_date:
        import datetime
        try:
            doc.doc_date = datetime.date.fromisoformat(ocr_date)
            logger.info("STEP3 doc=%s date filled from OCR: %s", document_id, doc.doc_date)
        except (ValueError, AttributeError):
            logger.warning("STEP3 doc=%s invalid OCR date: %r", document_id, ocr_date)

    # ── Step 4: final status ─────────────────────────────────────────────────
    # "Man in the Loop" rule: the task NEVER sets ready.
    # ready is exclusively set by a human via POST /approve/.
    # needs_verification = OCR found a conflict the approver must resolve.
    # needs_approval     = everything else (clean doc still needs sign-off).
    old_status = doc.status
    if has_conflict or (is_image and ocr_conf < 0.30 and not extracted_text):
        doc.status = 'needs_verification'
    else:
        # near_duplicate or clean — both require human approval
        doc.status = 'needs_approval'

    logger.info(
        "STEP4 status transition doc=%s %s → %s "
        "(has_conflict=%s near_dup=%s low_conf=%s)",
        document_id, old_status, doc.status,
        has_conflict, is_near_duplicate,
        (is_image and ocr_conf < 0.30 and not extracted_text),
    )

    doc.save()
    logger.info(
        "process_document DONE doc=%s final_status=%s confidence=%.4f",
        document_id, doc.status, ocr_conf,
    )
