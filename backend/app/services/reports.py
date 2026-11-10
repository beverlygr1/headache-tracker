"""Private, bounded PDF exports of the user's actual diary records."""
import io
from datetime import date
from pathlib import Path
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import LongTable, Paragraph, SimpleDocTemplate, Spacer, TableStyle
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.diary import DiaryEntry
from app.models.user import User
from app.schemas.analytics import PeriodEnum
from app.services.analytics import _attacks, _window

EFFECTS = {"helped": "Помог", "partly": "Частично помог", "not_helped": "Не помог"}


def export_pdf(db: Session, user: User, from_date: date | None, to_date: date | None, time_zone: str) -> bytes:
    window = _window(PeriodEnum.month, from_date, to_date, time_zone)
    attacks = _attacks(db, user.id, window)
    diaries = list(db.scalars(select(DiaryEntry).where(
        DiaryEntry.user_id == user.id,
        DiaryEntry.date >= window.from_date,
        DiaryEntry.date <= min(window.to_date, window.now.astimezone(window.zone).date()),
    ).order_by(DiaryEntry.date)))
    if "Onest" not in pdfmetrics.getRegisteredFontNames():
        pdfmetrics.registerFont(TTFont("Onest", str(Path(__file__).resolve().parents[1] / "assets/fonts/Onest.ttf")))
    body = ParagraphStyle("body", fontName="Onest", fontSize=9, leading=13, textColor=colors.HexColor("#101827"), alignment=TA_LEFT)
    title = ParagraphStyle("title", parent=body, fontSize=23, leading=28, spaceAfter=14)
    heading = ParagraphStyle("heading", parent=body, fontSize=15, leading=21, spaceBefore=18, spaceAfter=10)
    small = ParagraphStyle("small", parent=body, fontSize=8, leading=11)
    output = io.BytesIO()
    document = SimpleDocTemplate(output, pagesize=A4, leftMargin=36, rightMargin=36, topMargin=38, bottomMargin=40, title="Дневник головной боли", author="Дневник головной боли")

    def p(value, style=body):
        return Paragraph(escape(str(value)).replace("\n", "<br/>"), style)

    def table(rows, widths):
        result = LongTable([[p(cell, small) for cell in row] for row in rows], colWidths=widths, repeatRows=1, hAlign="LEFT", splitInRow=1)
        result.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#DCEBFF")),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F6F8FD")]),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("LEFTPADDING", (0, 0), (-1, -1), 8),
            ("RIGHTPADDING", (0, 0), (-1, -1), 8),
            ("TOPPADDING", (0, 0), (-1, -1), 8),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
            ("LINEBELOW", (0, 0), (-1, 0), .6, colors.HexColor("#B8CBE5")),
        ]))
        return result

    story = [p("Дневник головной боли", title), p(user.name),
             p(f"Период: {window.from_date:%d.%m.%Y} – {window.to_date:%d.%m.%Y}"),
             p(f"Часовой пояс: {window.zone.key}"),
             p(f"Сформирован: {window.now.astimezone(window.zone):%d.%m.%Y %H:%M}"), Spacer(1, 14)]
    completed = [a for a in attacks if a.end_time is not None and a.end_time <= window.now]
    average = round(sum(a.intensity for a in attacks) / len(attacks), 1) if attacks else None
    duration = round(sum((a.end_time - a.start_time).total_seconds() / 60 for a in completed) / len(completed)) if completed else None
    story.append(p(f"Приступов: {len(attacks)}    Завершённых: {len(completed)}"))
    story.append(p(f"Средняя интенсивность: {average if average is not None else '—'} / 10    Средняя длительность: {str(duration) + ' мин' if duration is not None else '—'}"))
    story.append(p("Приступы и препараты", heading))
    if not attacks:
        story.append(p("За выбранный период записей о приступах нет."))
    else:
        rows = [["Начало / окончание", "Боль", "Подробности", "Препараты и результат"]]
        for attack in attacks:
            start = attack.start_time.astimezone(window.zone)
            end = attack.end_time.astimezone(window.zone) if attack.end_time is not None else None
            times = f"{start:%d.%m.%Y %H:%M}\n" + (f"{end:%d.%m.%Y %H:%M}" if end else "Продолжается")
            if end is not None:
                times += f"\n{int((end - start).total_seconds() // 60)} мин"
            facts = [attack.localization or "Зона не указана", attack.pain_type or "Характер не указан"]
            if attack.symptoms:
                facts.append("Симптомы: " + ", ".join(attack.symptoms))
            if attack.relief_factors:
                facts.append("Облегчение: " + ", ".join(attack.relief_factors))
            medications = "\n".join(name + " — " + EFFECTS.get((attack.medication_effects or {}).get(name), "результат не указан") for name in (attack.medications or [])) or "Не указаны"
            rows.append([times, f"{attack.intensity} / 10", "\n".join(facts), medications])
        story.append(table(rows, [104, 48, 182, 189]))
    story.append(p("Самочувствие по дням", heading))
    if not diaries:
        story.append(p("За выбранный период записей самочувствия нет."))
    else:
        def value(v):
            return "—" if v is None else str(v).replace(".", ",")
        rows = [["Дата", "Боль", "Сон, ч / качество", "Стресс / 10", "Кофеин, мг", "Вода, мл"]]
        for entry in diaries:
            rows.append([f"{entry.date:%d.%m.%Y}", "—" if entry.headache_present is None else "Да" if entry.headache_present else "Нет", f"{value(entry.sleep_hours)} / {value(entry.sleep_quality)}", value(entry.stress_level), value(entry.caffeine_intake), value(entry.water_ml)])
        story.append(table(rows, [83, 44, 114, 85, 101, 96]))

    def footer(canvas, doc):
        canvas.setFont("Onest", 8)
        canvas.setFillColor(colors.HexColor("#7E8798"))
        canvas.drawString(36, 22, "Записи пользователя · Дневник головной боли")
        canvas.drawRightString(A4[0] - 36, 22, str(doc.page))

    document.build(story, onFirstPage=footer, onLaterPages=footer)
    return output.getvalue()
