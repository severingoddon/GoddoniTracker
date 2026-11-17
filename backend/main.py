import csv
import io
import os
import secrets
from calendar import monthrange
from datetime import datetime, date, timedelta

from authlib.integrations.starlette_client import OAuth
from dotenv import load_dotenv
from fastapi import FastAPI, Depends, HTTPException, Request, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from starlette.middleware.sessions import SessionMiddleware
from sqlalchemy import func, extract
from sqlalchemy.orm import Session as DBSession

from database import Base, engine, get_db
from models import User, Session as SessionModel, Category, Expense, UserSettings
from schemas import (
    UserResponse,
    CategoryCreate,
    CategoryResponse,
    CategoryReorder,
    ExpenseCreate,
    ExpenseResponse,
    DayGroup,
    MonthExpenses,
    AnalyticsSummary,
    CategoryBreakdown,
    DailyCumulative,
    CategoryMonthly,
    CategoryComparison,
    UserSettingsResponse,
    UserSettingsUpdate,
)

load_dotenv()

ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "http://localhost:8001").split(",")
FRONTEND_URL = os.getenv("FRONTEND_URL", "http://localhost:8001")
SESSION_SECRET = os.getenv("SESSION_SECRET", "dev-secret-not-for-production")
# Comma-separated list of Google account emails that may use the backend.
# Empty or unset = nobody can log in (fail closed).
ALLOWED_EMAILS = {e.strip().lower() for e in os.getenv("ALLOWED_EMAILS", "").split(",") if e.strip()}


def is_email_allowed(email: str | None) -> bool:
    return bool(email) and email.lower() in ALLOWED_EMAILS

app = FastAPI(title="GoddoniTracker API")

app.add_middleware(SessionMiddleware, secret_key=SESSION_SECRET)
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_methods=["*"],
    allow_headers=["*"],
)

oauth = OAuth()
oauth.register(
    name="google",
    client_id=os.getenv("GOOGLE_CLIENT_ID"),
    client_secret=os.getenv("GOOGLE_CLIENT_SECRET"),
    server_metadata_url="https://accounts.google.com/.well-known/openid-configuration",
    client_kwargs={"scope": "openid email profile"},
)

DEFAULT_CATEGORIES = [
    "ToGo Food\U0001f355",
    "Lebensmittel + Haushalt\U0001f966\U0001f3e1",
    "Sprit⛽️",
    "Restaurant\U0001f354",
    "Elektronik⚡️",
    "Kleider\U0001f455",
    "Gym Supplements\U0001f4aa",
    "Katzen\U0001f408‍⬛",
    "Kosmetik\U0001f9f4",
    "Auto\U0001f3ce️",
    "E-Scooter\U0001f6f4",
    "SBB\U0001f683",
]


# --- Auth ---


def get_current_session(request: Request, db: DBSession = Depends(get_db)):
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated")
    token = auth[7:]
    session = db.query(SessionModel).filter(SessionModel.token == token).first()
    if not session:
        raise HTTPException(status_code=401, detail="Invalid session")
    if not is_email_allowed(session.user.email):
        raise HTTPException(status_code=403, detail="Access denied")
    return session


def seed_categories(db: DBSession, user_id: int):
    existing = db.query(Category).filter(Category.user_id == user_id).count()
    if existing > 0:
        return
    for i, name in enumerate(DEFAULT_CATEGORIES):
        db.add(Category(name=name, sort_order=i, user_id=user_id))
    db.commit()


def init_db():
    Base.metadata.create_all(bind=engine)


init_db()


@app.get("/api/auth/google/login")
async def google_login(request: Request, platform: str = ""):
    redirect_uri = os.getenv("GOOGLE_REDIRECT_URI", "http://localhost:8001/api/auth/google/callback")
    if platform:
        request.session["platform"] = platform
    return await oauth.google.authorize_redirect(request, redirect_uri)


@app.get("/api/auth/google/callback")
async def google_callback(request: Request, db: DBSession = Depends(get_db)):
    token_data = await oauth.google.authorize_access_token(request)
    userinfo = token_data.get("userinfo")
    if not userinfo:
        raise HTTPException(status_code=400, detail="Failed to get user info from Google")

    google_id = userinfo["sub"]
    email = userinfo["email"]
    if not userinfo.get("email_verified") or not is_email_allowed(email):
        raise HTTPException(status_code=403, detail="Access denied")
    name = userinfo.get("name", "")
    picture = userinfo.get("picture", "")

    user = db.query(User).filter(User.google_id == google_id).first()
    if user:
        user.email = email
        user.name = name
        user.picture = picture
    else:
        user = User(google_id=google_id, email=email, name=name, picture=picture)
        db.add(user)
    db.flush()

    seed_categories(db, user.id)

    session_token = secrets.token_urlsafe(32)
    db.add(SessionModel(token=session_token, user_id=user.id))
    db.commit()

    platform = request.session.pop("platform", "")
    if platform == "ios":
        from fastapi.responses import RedirectResponse
        return RedirectResponse(url=f"goddonitracker://auth?token={session_token}")

    from fastapi.responses import RedirectResponse
    return RedirectResponse(url=f"{FRONTEND_URL}/login?token={session_token}")


@app.get("/api/auth/me", response_model=UserResponse)
def get_me(session: SessionModel = Depends(get_current_session)):
    user = session.user
    letter = user.email[0].upper() if user.email else "?"
    return UserResponse(
        email=user.email,
        name=user.name,
        avatar_letter=letter,
        picture=user.picture,
    )


# --- Categories ---


@app.get("/api/categories", response_model=list[CategoryResponse])
def get_categories(session: SessionModel = Depends(get_current_session), db: DBSession = Depends(get_db)):
    return (
        db.query(Category)
        .filter(Category.user_id == session.user.id)
        .order_by(Category.sort_order)
        .all()
    )


@app.post("/api/categories", response_model=CategoryResponse)
def create_category(data: CategoryCreate, session: SessionModel = Depends(get_current_session), db: DBSession = Depends(get_db)):
    max_order = (
        db.query(func.max(Category.sort_order))
        .filter(Category.user_id == session.user.id)
        .scalar()
    )
    cat = Category(name=data.name, sort_order=(max_order or 0) + 1, user_id=session.user.id)
    db.add(cat)
    db.commit()
    db.refresh(cat)
    return cat


# Must be registered before "/api/categories/{category_id}", otherwise "reorder" is parsed as an id.
@app.put("/api/categories/reorder")
def reorder_categories(data: CategoryReorder, session: SessionModel = Depends(get_current_session), db: DBSession = Depends(get_db)):
    cats = db.query(Category).filter(Category.user_id == session.user.id).all()
    cat_map = {c.id: c for c in cats}
    for i, cat_id in enumerate(data.order):
        if cat_id in cat_map:
            cat_map[cat_id].sort_order = i
    db.commit()
    return {"detail": "Reordered"}


@app.put("/api/categories/{category_id}", response_model=CategoryResponse)
def update_category(category_id: int, data: CategoryCreate, session: SessionModel = Depends(get_current_session), db: DBSession = Depends(get_db)):
    cat = db.query(Category).filter(Category.id == category_id, Category.user_id == session.user.id).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    cat.name = data.name
    db.commit()
    db.refresh(cat)
    return cat


@app.delete("/api/categories/{category_id}")
def delete_category(category_id: int, session: SessionModel = Depends(get_current_session), db: DBSession = Depends(get_db)):
    cat = db.query(Category).filter(Category.id == category_id, Category.user_id == session.user.id).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    expense_count = db.query(Expense).filter(Expense.category_id == category_id).count()
    if expense_count > 0:
        raise HTTPException(status_code=400, detail=f"Kategorie hat noch {expense_count} Ausgaben")
    db.delete(cat)
    db.commit()
    return {"detail": "Category deleted"}


# --- Expenses ---


def expense_to_response(expense: Expense) -> ExpenseResponse:
    return ExpenseResponse(
        id=expense.id,
        title=expense.title,
        date=expense.date,
        amount=expense.amount,
        currency=expense.currency,
        amount_in_chf=expense.amount_in_chf,
        category_id=expense.category_id,
        category_name=expense.category.name if expense.category else None,
        payment_method=expense.payment_method,
        comment=expense.comment,
        split_applied=expense.split_applied or False,
        split_factor=expense.split_factor,
    )


@app.get("/api/expenses", response_model=MonthExpenses)
def get_expenses(month: str | None = None, category_id: int | None = None, session: SessionModel = Depends(get_current_session), db: DBSession = Depends(get_db)):
    user_id = session.user.id

    if month:
        try:
            year, m = map(int, month.split("-"))
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid month format. Use YYYY-MM.")
    else:
        today = date.today()
        year, m = today.year, today.month

    start = datetime(year, m, 1)
    _, last_day = monthrange(year, m)
    end = datetime(year, m, last_day, 23, 59, 59)

    query = db.query(Expense).filter(Expense.user_id == user_id, Expense.date >= start, Expense.date <= end)
    if category_id is not None:
        if category_id == 0:
            query = query.filter(Expense.category_id.is_(None))
        else:
            query = query.filter(Expense.category_id == category_id)

    expenses = query.order_by(Expense.date.desc()).all()

    all_time_total = (
        db.query(func.sum(Expense.amount_in_chf))
        .filter(Expense.user_id == user_id)
        .scalar()
    ) or 0.0

    month_total = sum(e.amount_in_chf for e in expenses)

    day_groups: dict[str, list[Expense]] = {}
    for exp in expenses:
        day_key = exp.date.strftime("%Y-%m-%d")
        day_groups.setdefault(day_key, []).append(exp)

    days = []
    for day_key in sorted(day_groups.keys(), reverse=True):
        group = day_groups[day_key]
        days.append(DayGroup(
            date=day_key,
            total=sum(e.amount_in_chf for e in group),
            expenses=[expense_to_response(e) for e in group],
        ))

    return MonthExpenses(
        month=f"{year}-{m:02d}",
        all_time_total=all_time_total,
        month_total=month_total,
        days=days,
    )


@app.get("/api/expenses/search", response_model=list[ExpenseResponse])
def search_expenses(q: str, session: SessionModel = Depends(get_current_session), db: DBSession = Depends(get_db)):
    pattern = f"%{q}%"
    expenses = (
        db.query(Expense)
        .filter(
            Expense.user_id == session.user.id,
            (Expense.title.ilike(pattern)) | (Expense.comment.ilike(pattern)),
        )
        .order_by(Expense.date.desc())
        .limit(50)
        .all()
    )
    return [expense_to_response(e) for e in expenses]


@app.get("/api/expenses/{expense_id}", response_model=ExpenseResponse)
def get_expense(expense_id: int, session: SessionModel = Depends(get_current_session), db: DBSession = Depends(get_db)):
    expense = db.query(Expense).filter(Expense.id == expense_id, Expense.user_id == session.user.id).first()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")
    return expense_to_response(expense)


@app.post("/api/expenses", response_model=ExpenseResponse)
def create_expense(data: ExpenseCreate, session: SessionModel = Depends(get_current_session), db: DBSession = Depends(get_db)):
    if data.category_id:
        cat = db.query(Category).filter(Category.id == data.category_id, Category.user_id == session.user.id).first()
        if not cat:
            raise HTTPException(status_code=404, detail="Category not found")

    expense = Expense(
        title=data.title,
        date=data.date,
        amount=data.amount,
        currency=data.currency,
        amount_in_chf=data.amount_in_chf,
        category_id=data.category_id,
        payment_method=data.payment_method,
        comment=data.comment,
        split_applied=data.split_applied,
        split_factor=data.split_factor,
        user_id=session.user.id,
    )
    db.add(expense)
    db.commit()
    db.refresh(expense)
    return expense_to_response(expense)


@app.put("/api/expenses/{expense_id}", response_model=ExpenseResponse)
def update_expense(expense_id: int, data: ExpenseCreate, session: SessionModel = Depends(get_current_session), db: DBSession = Depends(get_db)):
    expense = db.query(Expense).filter(Expense.id == expense_id, Expense.user_id == session.user.id).first()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")

    if data.category_id:
        cat = db.query(Category).filter(Category.id == data.category_id, Category.user_id == session.user.id).first()
        if not cat:
            raise HTTPException(status_code=404, detail="Category not found")

    expense.title = data.title
    expense.date = data.date
    expense.amount = data.amount
    expense.currency = data.currency
    expense.amount_in_chf = data.amount_in_chf
    expense.category_id = data.category_id
    expense.payment_method = data.payment_method
    expense.comment = data.comment
    expense.split_applied = data.split_applied
    expense.split_factor = data.split_factor
    db.commit()
    db.refresh(expense)
    return expense_to_response(expense)


@app.delete("/api/expenses/{expense_id}")
def delete_expense(expense_id: int, session: SessionModel = Depends(get_current_session), db: DBSession = Depends(get_db)):
    expense = db.query(Expense).filter(Expense.id == expense_id, Expense.user_id == session.user.id).first()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")
    db.delete(expense)
    db.commit()
    return {"detail": "Expense deleted"}


# --- Analytics ---


@app.get("/api/analytics", response_model=AnalyticsSummary)
def get_analytics(month: str | None = None, period: str = "month", session: SessionModel = Depends(get_current_session), db: DBSession = Depends(get_db)):
    user_id = session.user.id
    today = date.today()

    if period == "7days":
        start = datetime.combine(today - timedelta(days=6), datetime.min.time())
        end = datetime.combine(today, datetime.max.time())
        expenses = (
            db.query(Expense)
            .filter(Expense.user_id == user_id, Expense.date >= start, Expense.date <= end)
            .all()
        )
        total = sum(e.amount_in_chf for e in expenses)
        days_elapsed = 7
        daily_average = total / days_elapsed
        _, last_day = monthrange(today.year, today.month)
        projected_monthly = daily_average * last_day
    elif month:
        try:
            year, m = map(int, month.split("-"))
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid month format. Use YYYY-MM.")
        start = datetime(year, m, 1)
        _, last_day = monthrange(year, m)
        end = datetime(year, m, last_day, 23, 59, 59)
        expenses = (
            db.query(Expense)
            .filter(Expense.user_id == user_id, Expense.date >= start, Expense.date <= end)
            .all()
        )
        if year == today.year and m == today.month:
            days_elapsed = today.day
        else:
            days_elapsed = last_day
        total = sum(e.amount_in_chf for e in expenses)
        daily_average = total / max(days_elapsed, 1)
        projected_monthly = daily_average * last_day
    else:
        expenses = db.query(Expense).filter(Expense.user_id == user_id).all()
        if expenses:
            earliest = min(e.date for e in expenses).date()
            days_elapsed = (today - earliest).days + 1
        else:
            days_elapsed = 1
        total = sum(e.amount_in_chf for e in expenses)
        daily_average = total / max(days_elapsed, 1)
        projected_monthly = daily_average * 30

    settings = db.query(UserSettings).filter(UserSettings.user_id == user_id).first()
    budget = settings.monthly_budget if settings else None
    budget_used_percent = (total / budget * 100) if budget and budget > 0 else None

    cat_totals: dict[int | None, float] = {}
    cat_names: dict[int | None, str] = {}
    for e in expenses:
        cat_totals[e.category_id] = cat_totals.get(e.category_id, 0) + e.amount_in_chf
        if e.category_id not in cat_names:
            cat_names[e.category_id] = e.category.name if e.category else "Ohne Kategorie"

    categories = []
    for cat_id, cat_total in sorted(cat_totals.items(), key=lambda x: x[1], reverse=True):
        categories.append(CategoryBreakdown(
            category_id=cat_id,
            category_name=cat_names[cat_id],
            total=cat_total,
            percentage=(cat_total / total * 100) if total > 0 else 0,
        ))

    daily_totals: dict[str, float] = {}
    for e in expenses:
        day_key = e.date.strftime("%Y-%m-%d")
        daily_totals[day_key] = daily_totals.get(day_key, 0) + e.amount_in_chf

    daily_cumulative = []
    cumulative = 0.0
    for day_key in sorted(daily_totals.keys()):
        cumulative += daily_totals[day_key]
        daily_cumulative.append(DailyCumulative(date=day_key, cumulative=cumulative))

    return AnalyticsSummary(
        total=total,
        daily_average=daily_average,
        projected_monthly=projected_monthly,
        budget=budget,
        budget_used_percent=budget_used_percent,
        categories=categories,
        daily_cumulative=daily_cumulative,
    )


@app.get("/api/analytics/category-comparison", response_model=CategoryComparison)
def get_category_comparison(month: str | None = None, months: int = 3, session: SessionModel = Depends(get_current_session), db: DBSession = Depends(get_db)):
    """Per-category totals for the given month plus the `months` months before it."""
    user_id = session.user.id
    if months < 1 or months > 24:
        raise HTTPException(status_code=400, detail="months must be between 1 and 24.")

    if month:
        try:
            year, m = map(int, month.split("-"))
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid month format. Use YYYY-MM.")
    else:
        today = date.today()
        year, m = today.year, today.month

    month_keys = []
    for offset in range(months, -1, -1):
        idx = year * 12 + (m - 1) - offset
        month_keys.append(f"{idx // 12:04d}-{idx % 12 + 1:02d}")

    first_year, first_month = map(int, month_keys[0].split("-"))
    start = datetime(first_year, first_month, 1)
    _, last_day = monthrange(year, m)
    end = datetime(year, m, last_day, 23, 59, 59)
    expenses = (
        db.query(Expense)
        .filter(Expense.user_id == user_id, Expense.date >= start, Expense.date <= end)
        .all()
    )

    position = {key: i for i, key in enumerate(month_keys)}
    cat_amounts: dict[int | None, list[float]] = {}
    cat_names: dict[int | None, str] = {}
    for e in expenses:
        if e.category_id not in cat_amounts:
            cat_amounts[e.category_id] = [0.0] * len(month_keys)
            cat_names[e.category_id] = e.category.name if e.category else "Ohne Kategorie"
        cat_amounts[e.category_id][position[e.date.strftime("%Y-%m")]] += e.amount_in_chf

    categories = [
        CategoryMonthly(category_id=cat_id, category_name=cat_names[cat_id], amounts=amounts)
        for cat_id, amounts in sorted(cat_amounts.items(), key=lambda x: sum(x[1]), reverse=True)
    ]

    return CategoryComparison(months=month_keys, categories=categories)


# --- Settings ---


@app.get("/api/settings", response_model=UserSettingsResponse)
def get_settings(session: SessionModel = Depends(get_current_session), db: DBSession = Depends(get_db)):
    settings = db.query(UserSettings).filter(UserSettings.user_id == session.user.id).first()
    if not settings:
        return UserSettingsResponse(monthly_budget=None)
    return settings


@app.put("/api/settings", response_model=UserSettingsResponse)
def update_settings(data: UserSettingsUpdate, session: SessionModel = Depends(get_current_session), db: DBSession = Depends(get_db)):
    settings = db.query(UserSettings).filter(UserSettings.user_id == session.user.id).first()
    if not settings:
        settings = UserSettings(user_id=session.user.id)
        db.add(settings)
    settings.monthly_budget = data.monthly_budget
    db.commit()
    db.refresh(settings)
    return settings


# --- Export / Import ---


@app.get("/api/export")
def export_csv(date_from: str | None = None, date_to: str | None = None, session: SessionModel = Depends(get_current_session), db: DBSession = Depends(get_db)):
    query = db.query(Expense).filter(Expense.user_id == session.user.id)

    if date_from:
        query = query.filter(Expense.date >= datetime.fromisoformat(date_from))
    if date_to:
        query = query.filter(Expense.date <= datetime.fromisoformat(date_to + "T23:59:59"))

    expenses = query.order_by(Expense.date.desc()).all()

    output = io.StringIO()
    writer = csv.writer(output, delimiter=";")
    writer.writerow(["Title", "Date", "Amount", "Currency", "In CHF", "Category", "Payment Method", "Comment", "Split Applied", "Split Factor"])

    for e in expenses:
        writer.writerow([
            e.title,
            e.date.strftime("%Y-%m-%d %H:%M:%S"),
            f"{e.amount:.2f}",
            e.currency,
            f"{e.amount_in_chf:.2f}",
            e.category.name if e.category else "",
            e.payment_method or "",
            e.comment or "",
            "1" if e.split_applied else "0",
            f"{e.split_factor:.2f}" if e.split_factor else "",
        ])

    output.seek(0)
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=expenses.csv"},
    )


@app.post("/api/import")
async def import_csv(file: UploadFile = File(...), session: SessionModel = Depends(get_current_session), db: DBSession = Depends(get_db)):
    content = await file.read()
    text = content.decode("utf-8-sig")
    reader = csv.DictReader(io.StringIO(text), delimiter=";")

    user_id = session.user.id
    categories = db.query(Category).filter(Category.user_id == user_id).all()
    cat_map = {c.name: c.id for c in categories}

    imported = 0
    for row in reader:
        title = row.get("Title", "").strip()
        if not title:
            continue

        date_str = row.get("Date", "").strip()
        expense_date = None
        for fmt in ("%Y-%m-%d %H:%M:%S", "%d.%m.%y", "%d.%m.%Y", "%Y-%m-%d"):
            try:
                expense_date = datetime.strptime(date_str, fmt)
                break
            except ValueError:
                continue
        if not expense_date:
            try:
                expense_date = datetime.fromisoformat(date_str)
            except ValueError:
                continue

        amount_str = row.get("Amount", "0").strip().replace(",", ".")
        amount = float(amount_str) if amount_str else 0.0

        currency = row.get("Currency", "CHF").strip() or "CHF"

        chf_str = row.get("In CHF", "").strip().replace(",", ".")
        amount_in_chf = float(chf_str) if chf_str else amount

        cat_name = row.get("Category", "").strip()
        category_id = cat_map.get(cat_name)
        if cat_name and not category_id:
            max_order = db.query(func.max(Category.sort_order)).filter(Category.user_id == user_id).scalar() or 0
            new_cat = Category(name=cat_name, sort_order=max_order + 1, user_id=user_id)
            db.add(new_cat)
            db.flush()
            cat_map[cat_name] = new_cat.id
            category_id = new_cat.id

        expense = Expense(
            title=title,
            date=expense_date,
            amount=amount,
            currency=currency,
            amount_in_chf=amount_in_chf,
            category_id=category_id,
            payment_method=row.get("Payment Method", "").strip() or None,
            comment=row.get("Comment", "").strip() or None,
            user_id=user_id,
        )
        db.add(expense)
        imported += 1

    db.commit()
    return {"detail": f"{imported} Ausgaben importiert"}
