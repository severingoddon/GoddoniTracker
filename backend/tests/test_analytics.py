from datetime import datetime, timedelta

import pytest


@pytest.fixture
def february(alice, create_expense, create_category):
    """A past month (28 days): 300 for Food, 100 for Travel, 50 uncategorized."""
    food = create_category(alice, "Food")
    travel = create_category(alice, "Travel")
    create_expense(alice, date="2025-02-03T12:00:00", amount=100, amount_in_chf=100, category_id=food["id"])
    create_expense(alice, date="2025-02-03T19:00:00", amount=200, amount_in_chf=200, category_id=food["id"])
    create_expense(alice, date="2025-02-10T12:00:00", amount=100, amount_in_chf=100, category_id=travel["id"])
    create_expense(alice, date="2025-02-20T12:00:00", amount=50, amount_in_chf=50)
    create_expense(alice, date="2025-03-01T12:00:00", amount=999, amount_in_chf=999)  # other month


class TestMonthSummary:
    def test_totals_and_projection(self, client, alice, february):
        data = client.get("/api/analytics?month=2025-02", headers=alice).json()

        assert data["total"] == 450
        assert data["daily_average"] == pytest.approx(450 / 28)
        # A finished month projects to exactly its total
        assert data["projected_monthly"] == pytest.approx(450)

    def test_category_breakdown_sorted_by_total(self, client, alice, february):
        categories = client.get("/api/analytics?month=2025-02", headers=alice).json()["categories"]

        assert [(c["category_name"], c["total"]) for c in categories] == [
            ("Food", 300),
            ("Travel", 100),
            ("Ohne Kategorie", 50),
        ]
        assert sum(c["percentage"] for c in categories) == pytest.approx(100)
        assert categories[0]["percentage"] == pytest.approx(300 / 450 * 100)

    def test_daily_cumulative(self, client, alice, february):
        cumulative = client.get("/api/analytics?month=2025-02", headers=alice).json()["daily_cumulative"]

        assert cumulative == [
            {"date": "2025-02-03", "cumulative": 300},
            {"date": "2025-02-10", "cumulative": 400},
            {"date": "2025-02-20", "cumulative": 450},
        ]

    def test_budget_usage(self, client, alice, february):
        client.put("/api/settings", json={"monthly_budget": 900}, headers=alice)

        data = client.get("/api/analytics?month=2025-02", headers=alice).json()

        assert data["budget"] == 900
        assert data["budget_used_percent"] == pytest.approx(50)

    def test_without_budget(self, client, alice, february):
        data = client.get("/api/analytics?month=2025-02", headers=alice).json()

        assert data["budget"] is None
        assert data["budget_used_percent"] is None

    def test_empty_month(self, client, alice):
        data = client.get("/api/analytics?month=2024-06", headers=alice).json()

        assert data["total"] == 0
        assert data["categories"] == []

    def test_invalid_month_is_rejected(self, client, alice):
        assert client.get("/api/analytics?month=2025", headers=alice).status_code == 400


def test_last_7_days_only_counts_recent_expenses(client, alice, create_expense):
    now = datetime.now().replace(microsecond=0)
    create_expense(alice, date=now.isoformat(), amount=70, amount_in_chf=70)
    create_expense(alice, date=(now - timedelta(days=10)).isoformat(), amount=500, amount_in_chf=500)

    data = client.get("/api/analytics?period=7days", headers=alice).json()

    assert data["total"] == 70
    assert data["daily_average"] == pytest.approx(10)


def test_all_time(client, alice, february):
    data = client.get("/api/analytics", headers=alice).json()

    assert data["total"] == 1449


class TestCategoryComparison:
    def test_amounts_per_month_across_year_boundary(self, client, alice, create_expense, create_category):
        food = create_category(alice, "Food")
        create_expense(alice, date="2024-11-15T12:00:00", amount=10, amount_in_chf=10, category_id=food["id"])
        create_expense(alice, date="2025-01-05T12:00:00", amount=30, amount_in_chf=30, category_id=food["id"])
        create_expense(alice, date="2024-10-31T12:00:00", amount=999, amount_in_chf=999, category_id=food["id"])

        data = client.get("/api/analytics/category-comparison?month=2025-01&months=2", headers=alice).json()

        assert data["months"] == ["2024-11", "2024-12", "2025-01"]
        assert data["categories"] == [{"category_id": food["id"], "category_name": "Food", "amounts": [10, 0, 30]}]

    @pytest.mark.parametrize("months", [0, 25])
    def test_months_out_of_range_is_rejected(self, client, alice, months):
        response = client.get(f"/api/analytics/category-comparison?month=2025-01&months={months}", headers=alice)
        assert response.status_code == 400


def test_settings_round_trip(client, alice):
    assert client.get("/api/settings", headers=alice).json() == {"monthly_budget": None}

    client.put("/api/settings", json={"monthly_budget": 1500}, headers=alice)

    assert client.get("/api/settings", headers=alice).json() == {"monthly_budget": 1500}
