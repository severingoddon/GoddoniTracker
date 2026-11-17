import csv
import io

HEADER = "Title;Date;Amount;Currency;In CHF;Category;Payment Method;Comment"


def upload(client, headers, content: str):
    return client.post(
        "/api/import",
        files={"file": ("expenses.csv", content.encode("utf-8"), "text/csv")},
        headers=headers,
    )


def all_expenses(client, headers, month: str) -> list[dict]:
    days = client.get(f"/api/expenses?month={month}", headers=headers).json()["days"]
    return [e for d in days for e in d["expenses"]]


class TestExport:
    def test_exports_requested_date_range(self, client, alice, create_expense, create_category):
        food = create_category(alice, "Food")
        create_expense(alice, title="Dinner", date="2025-03-10T19:00:00", amount=42, currency="EUR",
                       amount_in_chf=39.5, category_id=food["id"], payment_method="Card",
                       split_applied=True, split_factor=0.5)
        create_expense(alice, title="Too early", date="2025-02-28T12:00:00")

        response = client.get("/api/export?date_from=2025-03-01&date_to=2025-03-31", headers=alice)

        assert response.status_code == 200
        assert response.headers["content-type"].startswith("text/csv")
        rows = list(csv.DictReader(io.StringIO(response.text), delimiter=";"))
        assert rows == [{
            "Title": "Dinner",
            "Date": "2025-03-10 19:00:00",
            "Amount": "42.00",
            "Currency": "EUR",
            "In CHF": "39.50",
            "Category": "Food",
            "Payment Method": "Card",
            "Comment": "",
            "Split Applied": "1",
            "Split Factor": "0.50",
        }]

    def test_date_to_includes_the_whole_day(self, client, alice, create_expense):
        create_expense(alice, title="Late", date="2025-03-31T23:30:00")

        response = client.get("/api/export?date_from=2025-03-31&date_to=2025-03-31", headers=alice)

        assert "Late" in response.text

    def test_only_exports_own_expenses(self, client, alice, bob, create_expense):
        create_expense(alice, title="Secret")

        assert "Secret" not in client.get("/api/export", headers=bob).text


class TestImport:
    def test_accepts_multiple_date_formats(self, client, alice):
        content = "\n".join([
            HEADER,
            "ISO with time;2025-05-13 10:11:38;8.90;CHF;8.90;;;",
            "ISO date;2025-05-13;1;CHF;1;;;",
            "Swiss long;13.05.2025;1;CHF;1;;;",
            "Swiss short;13.05.25;1;CHF;1;;;",
        ])

        response = upload(client, alice, content)

        assert response.json() == {"detail": "4 Ausgaben importiert"}
        assert len(all_expenses(client, alice, "2025-05")) == 4

    def test_skips_rows_without_title_or_valid_date(self, client, alice):
        content = "\n".join([
            HEADER,
            ";2025-05-13;1;CHF;1;;;",
            "Bad date;yesterday;1;CHF;1;;;",
            "Valid;2025-05-13;1;CHF;1;;;",
        ])

        assert upload(client, alice, content).json() == {"detail": "1 Ausgaben importiert"}

    def test_creates_missing_categories_and_reuses_existing(self, client, alice, create_category):
        create_category(alice, "Food")
        content = "\n".join([
            HEADER,
            "Pizza;2025-05-13;20;CHF;20;Food;;",
            "Train;2025-05-13;10;CHF;10;Travel;;",
            "Bus;2025-05-14;3;CHF;3;Travel;;",
        ])

        upload(client, alice, content)

        categories = [c["name"] for c in client.get("/api/categories", headers=alice).json()]
        assert categories == ["Food", "Travel"]

    def test_parses_decimal_comma_and_defaults_chf_amount(self, client, alice):
        content = "\n".join([
            HEADER,
            "Comma;2025-05-13;8,90;CHF;;;;",
        ])

        upload(client, alice, content)

        [expense] = all_expenses(client, alice, "2025-05")
        assert expense["amount"] == 8.9
        assert expense["amount_in_chf"] == 8.9

    def test_handles_utf8_bom_and_extra_columns(self, client, alice):
        content = "﻿" + HEADER + ";City;Country\nZüri Gschnätzlets 🍽;2025-05-13;30;CHF;30;Restaurant 🍔;;;Zürich;CH"

        upload(client, alice, content)

        [expense] = all_expenses(client, alice, "2025-05")
        assert expense["title"] == "Züri Gschnätzlets 🍽"
        assert expense["category_name"] == "Restaurant 🍔"


def test_export_import_round_trip(client, alice, bob, create_expense, create_category):
    food = create_category(alice, "Food")
    create_expense(alice, title="Dinner", date="2025-03-10T19:00:00", amount=42, currency="EUR",
                   amount_in_chf=39.5, category_id=food["id"], payment_method="Card", comment="nice")
    create_expense(alice, title="Coffee", date="2025-03-11T08:00:00", amount=4.5, amount_in_chf=4.5)

    exported = client.get("/api/export", headers=alice).text
    upload(client, bob, exported)

    fields = ("title", "date", "amount", "currency", "amount_in_chf", "category_name", "payment_method", "comment")
    original = [{k: e[k] for k in fields} for e in all_expenses(client, alice, "2025-03")]
    imported = [{k: e[k] for k in fields} for e in all_expenses(client, bob, "2025-03")]
    assert imported == original
