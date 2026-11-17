def names(client, headers) -> list[str]:
    return [c["name"] for c in client.get("/api/categories", headers=headers).json()]


def test_create_appends_at_the_end(client, alice, create_category):
    create_category(alice, "Food")
    create_category(alice, "Travel")

    assert names(client, alice) == ["Food", "Travel"]


def test_rename(client, alice, create_category):
    food = create_category(alice, "Food")

    response = client.put(f"/api/categories/{food['id']}", json={"name": "Groceries"}, headers=alice)

    assert response.status_code == 200
    assert names(client, alice) == ["Groceries"]


def test_reorder(client, alice, create_category):
    a = create_category(alice, "A")
    b = create_category(alice, "B")
    c = create_category(alice, "C")

    client.put("/api/categories/reorder", json={"order": [c["id"], a["id"], b["id"]]}, headers=alice)

    assert names(client, alice) == ["C", "A", "B"]


def test_delete_empty_category(client, alice, create_category):
    food = create_category(alice, "Food")

    assert client.delete(f"/api/categories/{food['id']}", headers=alice).status_code == 200
    assert names(client, alice) == []


def test_category_with_expenses_cannot_be_deleted(client, alice, create_category, create_expense):
    food = create_category(alice, "Food")
    create_expense(alice, category_id=food["id"])

    response = client.delete(f"/api/categories/{food['id']}", headers=alice)

    assert response.status_code == 400
    assert names(client, alice) == ["Food"]


def test_categories_are_per_user(client, alice, bob, create_category):
    food = create_category(alice, "Food")

    assert names(client, bob) == []
    assert client.put(f"/api/categories/{food['id']}", json={"name": "Hacked"}, headers=bob).status_code == 404
    assert client.delete(f"/api/categories/{food['id']}", headers=bob).status_code == 404
    assert names(client, alice) == ["Food"]


def test_reorder_ignores_other_users_categories(client, alice, bob, create_category):
    a = create_category(alice, "A")
    b = create_category(alice, "B")
    foreign = create_category(bob, "Foreign")

    client.put("/api/categories/reorder", json={"order": [foreign["id"], b["id"], a["id"]]}, headers=alice)

    assert names(client, alice) == ["B", "A"]
    assert names(client, bob) == ["Foreign"]
