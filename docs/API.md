# API reference

Base path: `/api`. Every endpoint except the OAuth flow requires the header:

```
Authorization: Bearer <session-token>
```

Responses are JSON with `snake_case` keys. Errors look like `{"detail": "..."}`.

## Auth

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/auth/google/login` | Redirects to Google OAuth. Add `?platform=ios` for the native app. |
| GET | `/api/auth/google/callback` | OAuth callback. Checks the allowlist, creates a session and redirects with `?token=…` (to `goddonitracker://auth` on iOS). |
| GET | `/api/auth/me` | The current user's profile |

Only verified Google accounts listed in `ALLOWED_EMAILS` can sign in. Everyone else gets `403`.

## Expenses

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/expenses?month=YYYY-MM&category_id=N` | A month's expenses grouped by day, with day, month and all-time totals. `category_id` is optional. |
| GET | `/api/expenses/search?q=term` | Search titles and comments |
| GET | `/api/expenses/{id}` | A single expense |
| POST | `/api/expenses` | Create an expense |
| PUT | `/api/expenses/{id}` | Update an expense |
| DELETE | `/api/expenses/{id}` | Delete an expense |

## Categories

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/categories` | The user's categories, in sort order |
| POST | `/api/categories` | Create a category |
| PUT | `/api/categories/{id}` | Rename a category |
| DELETE | `/api/categories/{id}` | Delete a category. Returns `400` if it still has expenses. |
| PUT | `/api/categories/reorder` | Set the order: `{"order": [id, id, …]}` |

## Analytics

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/analytics?month=YYYY-MM` | Summary for a month |
| GET | `/api/analytics?period=7days` | Summary for the last 7 days |
| GET | `/api/analytics` | Summary over all time |
| GET | `/api/analytics/category-comparison?month=YYYY-MM&months=N` | Per-category totals for `month` and the `N` months before it (1–24, default 3) |

A summary contains the total, daily average, projected monthly total, budget and its usage in percent, a breakdown by category and the daily cumulative spending.

## Settings

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/settings` | Get the user's settings |
| PUT | `/api/settings` | Update the monthly budget |

## Export / import

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/export?date_from=YYYY-MM-DD&date_to=YYYY-MM-DD` | Download expenses as CSV |
| POST | `/api/import` | Upload a CSV file (`multipart/form-data`) |

### CSV format

Semicolon-separated, UTF-8:

```
Title;Date;Amount;Currency;In CHF;Category;Payment Method;Comment;Split Applied;Split Factor
Groceries;2026-05-13 10:11:38;8.90;CHF;8.90;Groceries 🥦;;;0;
Dinner;2026-05-14 19:30:00;42.00;EUR;39.50;Restaurant 🍔;Card;;1;0.50
```

The import accepts the dates `YYYY-MM-DD HH:MM:SS`, `YYYY-MM-DD`, `DD.MM.YYYY` and `DD.MM.YY`. Unknown categories are created on the fly, and unknown columns are ignored.
