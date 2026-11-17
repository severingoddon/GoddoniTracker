class TestMonthView:
    def test_groups_by_day_with_totals(self, client, alice, create_expense):
        create_expense(alice, title="Bread", date="2025-03-10T08:00:00", amount=3, amount_in_chf=3)
        create_expense(alice, title="Milk", date="2025-03-10T18:00:00", amount=2, amount_in_chf=2)
        create_expense(alice, title="Fuel", date="2025-03-12T12:00:00", amount=80, amount_in_chf=80)
        create_expense(alice, title="April", date="2025-04-01T12:00:00", amount=10, amount_in_chf=10)

        data = client.get("/api/expenses?month=2025-03", headers=alice).json()

        assert data["month"] == "2025-03"
        assert data["month_total"] == 85
        assert data["all_time_total"] == 95
        assert [d["date"] for d in data["days"]] == ["2025-03-12", "2025-03-10"]
        assert data["days"][1]["total"] == 5
        assert [e["title"] for e in data["days"][1]["expenses"]] == ["Milk", "Bread"]

    def test_month_boundaries_are_inclusive(self, client, alice, create_expense):
        create_expense(alice, title="First", date="2025-02-01T00:00:00")
        create_expense(alice, title="Last", date="2025-02-28T23:59:59")
        create_expense(alice, title="Next", date="2025-03-01T00:00:00")

        days = client.get("/api/expenses?month=2025-02", headers=alice).json()["days"]

        titles = {e["title"] for d in days for e in d["expenses"]}
        assert titles == {"First", "Last"}

    def test_filter_by_category_and_uncategorized(self, client, alice, create_expense, create_category):
        food = create_category(alice, "Food")
        create_expense(alice, title="Pizza", category_id=food["id"])
        create_expense(alice, title="Misc")

        by_food = client.get(f"/api/expenses?month=2025-03&category_id={food['id']}", headers=alice).json()
        uncategorized = client.get("/api/expenses?month=2025-03&category_id=0", headers=alice).json()

        assert [e["title"] for d in by_food["days"] for e in d["expenses"]] == ["Pizza"]
        assert [e["title"] for d in uncategorized["days"] for e in d["expenses"]] == ["Misc"]

    def test_invalid_month_is_rejected(self, client, alice):
        assert client.get("/api/expenses?month=march", headers=alice).status_code == 400


class TestCrud:
    def test_create_and_read_back(self, client, alice, create_expense, create_category):
        food = create_category(alice, "Food")
        created = create_expense(
            alice,
            title="Dinner",
            amount=42,
            currency="EUR",
            amount_in_chf=39.5,
            category_id=food["id"],
            payment_method="Card",
            comment="with friends",
            split_applied=True,
            split_factor=0.5,
        )

        fetched = client.get(f"/api/expenses/{created['id']}", headers=alice).json()

        assert fetched == created
        assert fetched["category_name"] == "Food"
        assert fetched["currency"] == "EUR"
        assert fetched["split_applied"] is True
        assert fetched["split_factor"] == 0.5

    def test_update(self, client, alice, create_expense):
        expense = create_expense(alice)
        payload = {**expense, "title": "Espresso", "amount": 3.8, "amount_in_chf": 3.8}

        response = client.put(f"/api/expenses/{expense['id']}", json=payload, headers=alice)

        assert response.status_code == 200
        assert response.json()["title"] == "Espresso"
        assert response.json()["amount_in_chf"] == 3.8

    def test_delete(self, client, alice, create_expense):
        expense = create_expense(alice)

        assert client.delete(f"/api/expenses/{expense['id']}", headers=alice).status_code == 200
        assert client.get(f"/api/expenses/{expense['id']}", headers=alice).status_code == 404

    def test_unknown_category_is_rejected(self, client, alice):
        payload = {"title": "X", "date": "2025-03-10T08:00:00", "amount": 1, "amount_in_chf": 1, "category_id": 999}
        assert client.post("/api/expenses", json=payload, headers=alice).status_code == 404


class TestSearch:
    def test_matches_title_and_comment_case_insensitive(self, client, alice, create_expense):
        create_expense(alice, title="Migros groceries")
        create_expense(alice, title="Lunch", comment="at migros restaurant")
        create_expense(alice, title="Fuel")

        results = client.get("/api/expenses/search?q=MIGROS", headers=alice).json()

        assert {e["title"] for e in results} == {"Migros groceries", "Lunch"}


class TestUserIsolation:
    def test_other_users_expenses_are_invisible(self, client, alice, bob, create_expense):
        expense = create_expense(alice, title="Secret")

        assert client.get(f"/api/expenses/{expense['id']}", headers=bob).status_code == 404
        assert client.get("/api/expenses?month=2025-03", headers=bob).json()["days"] == []
        assert client.get("/api/expenses/search?q=Secret", headers=bob).json() == []

    def test_other_users_expenses_cannot_be_changed(self, client, alice, bob, create_expense):
        expense = create_expense(alice, title="Secret")

        assert client.put(f"/api/expenses/{expense['id']}", json={**expense, "title": "Hacked"}, headers=bob).status_code == 404
        assert client.delete(f"/api/expenses/{expense['id']}", headers=bob).status_code == 404
        assert client.get(f"/api/expenses/{expense['id']}", headers=alice).json()["title"] == "Secret"

    def test_cannot_use_another_users_category(self, client, alice, bob, create_category):
        food = create_category(alice, "Food")
        payload = {"title": "X", "date": "2025-03-10T08:00:00", "amount": 1, "amount_in_chf": 1, "category_id": food["id"]}

        assert client.post("/api/expenses", json=payload, headers=bob).status_code == 404

    def test_all_time_total_only_counts_own_expenses(self, client, alice, bob, create_expense):
        create_expense(alice, amount=100, amount_in_chf=100)
        create_expense(bob, amount=1, amount_in_chf=1)

        assert client.get("/api/expenses?month=2025-03", headers=bob).json()["all_time_total"] == 1
