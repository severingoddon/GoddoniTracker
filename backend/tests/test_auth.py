from urllib.parse import parse_qs, urlparse

import pytest
from fastapi.responses import RedirectResponse

import main
from models import User


@pytest.fixture
def fake_google(monkeypatch):
    """Replace the Google OAuth round trip with a configurable userinfo payload."""
    userinfo = {
        "sub": "google-123",
        "email": "alice@example.com",
        "email_verified": True,
        "name": "Alice",
        "picture": "https://example.com/alice.png",
    }

    async def fake_authorize_redirect(request, redirect_uri):
        return RedirectResponse(url="https://accounts.google.com/fake")

    async def fake_authorize_access_token(request):
        return {"userinfo": userinfo}

    monkeypatch.setattr(main.oauth.google, "authorize_redirect", fake_authorize_redirect)
    monkeypatch.setattr(main.oauth.google, "authorize_access_token", fake_authorize_access_token)
    return userinfo


def token_from_redirect(response) -> str:
    return parse_qs(urlparse(response.headers["location"]).query)["token"][0]


class TestBearerAuth:
    def test_missing_token_is_rejected(self, client):
        assert client.get("/api/categories").status_code == 401

    def test_unknown_token_is_rejected(self, client):
        response = client.get("/api/categories", headers={"Authorization": "Bearer nope"})
        assert response.status_code == 401

    def test_me_returns_current_user(self, client, alice):
        response = client.get("/api/auth/me", headers=alice)
        assert response.status_code == 200
        assert response.json()["email"] == "alice@example.com"
        assert response.json()["avatar_letter"] == "A"

    def test_session_of_user_removed_from_allowlist_is_rejected(self, client, make_user):
        headers = make_user("mallory@example.com")
        assert client.get("/api/auth/me", headers=headers).status_code == 403
        assert client.get("/api/expenses", headers=headers).status_code == 403


class TestGoogleCallback:
    def test_allowed_user_is_created_with_default_categories(self, client, fake_google, db_factory):
        response = client.get("/api/auth/google/callback", follow_redirects=False)

        assert response.status_code == 307
        token = token_from_redirect(response)
        categories = client.get("/api/categories", headers={"Authorization": f"Bearer {token}"}).json()
        assert [c["name"] for c in categories] == main.DEFAULT_CATEGORIES

    def test_ios_login_redirects_to_app_url_scheme(self, client, fake_google):
        client.get("/api/auth/google/login?platform=ios", follow_redirects=False)
        response = client.get("/api/auth/google/callback", follow_redirects=False)

        assert response.headers["location"].startswith("goddonitracker://auth?token=")

    def test_repeat_login_updates_profile_and_keeps_user(self, client, fake_google, db_factory):
        client.get("/api/auth/google/callback", follow_redirects=False)
        fake_google["name"] = "Alice Renamed"
        client.get("/api/auth/google/callback", follow_redirects=False)

        db = db_factory()
        users = db.query(User).all()
        assert len(users) == 1
        assert users[0].name == "Alice Renamed"

    def test_allowlist_is_case_insensitive(self, client, fake_google):
        fake_google["email"] = "BOB@example.COM"
        response = client.get("/api/auth/google/callback", follow_redirects=False)
        assert response.status_code == 307

    def test_email_not_on_allowlist_is_rejected(self, client, fake_google, db_factory):
        fake_google["email"] = "mallory@example.com"
        response = client.get("/api/auth/google/callback", follow_redirects=False)

        assert response.status_code == 403
        assert db_factory().query(User).count() == 0

    def test_unverified_email_is_rejected(self, client, fake_google, db_factory):
        fake_google["email_verified"] = False
        response = client.get("/api/auth/google/callback", follow_redirects=False)

        assert response.status_code == 403
        assert db_factory().query(User).count() == 0


def test_empty_allowlist_allows_nobody(monkeypatch):
    monkeypatch.setattr(main, "ALLOWED_EMAILS", set())
    assert not main.is_email_allowed("alice@example.com")
    assert not main.is_email_allowed("")
    assert not main.is_email_allowed(None)
