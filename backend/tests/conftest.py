import os
import tempfile

# Configure the app before it is imported: main.py reads these at import time.
# Values set here take precedence over a local backend/.env (load_dotenv doesn't override).
os.environ["DATA_DIR"] = tempfile.mkdtemp(prefix="goddonitracker-tests-")
os.environ["ALLOWED_EMAILS"] = "alice@example.com, Bob@Example.com"
os.environ["SESSION_SECRET"] = "test-secret"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import create_engine  # noqa: E402
from sqlalchemy.orm import sessionmaker  # noqa: E402
from sqlalchemy.pool import StaticPool  # noqa: E402

import main  # noqa: E402
from database import Base, get_db  # noqa: E402
from models import Session as SessionModel, User  # noqa: E402


@pytest.fixture
def db_factory():
    """A fresh in-memory database per test."""
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    yield sessionmaker(bind=engine, autoflush=False, autocommit=False)
    engine.dispose()


@pytest.fixture
def client(db_factory):
    def override_get_db():
        db = db_factory()
        try:
            yield db
        finally:
            db.close()

    main.app.dependency_overrides[get_db] = override_get_db
    with TestClient(main.app) as c:
        yield c
    main.app.dependency_overrides.clear()


@pytest.fixture
def make_user(db_factory):
    """Create a user with a session directly in the DB and return auth headers."""

    def _make(email: str) -> dict[str, str]:
        db = db_factory()
        user = User(google_id=f"google-{email}", email=email, name=email.split("@")[0])
        db.add(user)
        db.flush()
        token = f"token-{email}"
        db.add(SessionModel(token=token, user_id=user.id))
        db.commit()
        db.close()
        return {"Authorization": f"Bearer {token}"}

    return _make


@pytest.fixture
def alice(make_user):
    return make_user("alice@example.com")


@pytest.fixture
def bob(make_user):
    return make_user("bob@example.com")


@pytest.fixture
def create_expense(client):
    def _create(headers: dict[str, str], **fields) -> dict:
        payload = {
            "title": "Coffee",
            "date": "2025-03-10T08:30:00",
            "amount": 4.5,
            "currency": "CHF",
            "amount_in_chf": 4.5,
        }
        payload.update(fields)
        response = client.post("/api/expenses", json=payload, headers=headers)
        assert response.status_code == 200, response.text
        return response.json()

    return _create


@pytest.fixture
def create_category(client):
    def _create(headers: dict[str, str], name: str) -> dict:
        response = client.post("/api/categories", json={"name": name}, headers=headers)
        assert response.status_code == 200, response.text
        return response.json()

    return _create
