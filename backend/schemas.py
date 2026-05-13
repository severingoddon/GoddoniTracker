from pydantic import BaseModel
from datetime import datetime


class UserResponse(BaseModel):
    email: str
    name: str | None
    avatar_letter: str
    picture: str | None

    model_config = {"from_attributes": True}


# --- Categories ---


class CategoryCreate(BaseModel):
    name: str


class CategoryResponse(BaseModel):
    id: int
    name: str
    sort_order: int

    model_config = {"from_attributes": True}


class CategoryReorder(BaseModel):
    order: list[int]


# --- Expenses ---


class ExpenseCreate(BaseModel):
    title: str
    date: datetime
    amount: float
    currency: str = "CHF"
    amount_in_chf: float
    category_id: int | None = None
    payment_method: str | None = None
    city: str | None = None
    country: str | None = None
    comment: str | None = None


class ExpenseResponse(BaseModel):
    id: int
    title: str
    date: datetime
    amount: float
    currency: str
    amount_in_chf: float
    category_id: int | None
    category_name: str | None = None
    payment_method: str | None
    city: str | None
    country: str | None
    comment: str | None

    model_config = {"from_attributes": True}


class DayGroup(BaseModel):
    date: str
    total: float
    expenses: list[ExpenseResponse]


class MonthExpenses(BaseModel):
    month: str
    all_time_total: float
    month_total: float
    days: list[DayGroup]


# --- Analytics ---


class CategoryBreakdown(BaseModel):
    category_id: int | None
    category_name: str
    total: float
    percentage: float


class AnalyticsSummary(BaseModel):
    total: float
    daily_average: float
    projected_monthly: float
    budget: float | None
    budget_used_percent: float | None
    categories: list[CategoryBreakdown]


# --- Settings ---


class UserSettingsResponse(BaseModel):
    monthly_budget: float | None

    model_config = {"from_attributes": True}


class UserSettingsUpdate(BaseModel):
    monthly_budget: float | None
