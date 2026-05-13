# GoddoniTracker

A personal expense tracking application. Track daily expenses, analyze spending by category, set monthly budgets, and export/import data via CSV.

## Features

- **Expense tracking** — log expenses with title, amount, currency, category, payment method, location, and comments
- **Monthly view** — expenses grouped by day with daily and monthly totals
- **Search** — find expenses by title or comment
- **Categories** — customizable categories with emoji support, drag-to-reorder
- **Analytics** — donut chart breakdown by category, daily average, monthly projection
- **Budget tracking** — set a monthly budget, track usage percentage, see projected overspend
- **CSV export** — export expenses for any date range as semicolon-separated CSV
- **CSV import** — import expenses from CSV with automatic category creation
- **Multi-currency** — track amounts in any currency with CHF conversion
- **Google OAuth** — login via Google account
- **Dark mode** — dark theme throughout
- **German UI** — all interface text in German

## Tech Stack

| Layer    | Technology                                        |
|----------|---------------------------------------------------|
| iOS      | SwiftUI, Observation (`@Observable`), async/await, zero dependencies |
| Backend  | Python 3.12, FastAPI, SQLAlchemy, Pydantic, Authlib |
| Database | SQLite                                            |
| Server   | Nginx (SSL reverse proxy), Uvicorn                |
| Docker   | Docker Compose                                    |
| Deploy   | Ansible                                           |

## Getting Started

### Local Development

**Backend:**
```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8001
```

Create a `.env` file in `backend/` with your configuration:
```
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret
ADMIN_EMAIL=your-admin@example.com
ALLOWED_ORIGINS=http://localhost:8001
FRONTEND_URL=http://localhost:8001
SESSION_SECRET=some-random-secret
```

Backend API runs at `http://localhost:8001/api`.

**iOS App:**

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
cd SwiftApp
xcodegen generate
open GoddoniTracker.xcodeproj
```

In Xcode, select your development team under **Signing & Capabilities**, then build to a simulator or device.

The API base URL is configured in `SwiftApp/GoddoniTracker/Network/APIEndpoints.swift`. For local development, change it to `http://localhost:8001`. For production it points to `https://goddonitracker.goddoni.org:3004`.

The iOS OAuth flow uses `ASWebAuthenticationSession` with the `goddonitracker://` URL scheme. The backend detects `?platform=ios` on the login endpoint and redirects the OAuth callback to `goddonitracker://auth?token=...`.

### Docker (local)

```bash
docker-compose up --build
```

Backend available on port `8001`.

### Deployment (Ansible -> Raspberry Pi)

Prerequisites on your local machine:
- `ansible` installed (`pip install ansible`)
- `community.docker` collection: `ansible-galaxy collection install community.docker`
- SSH key on the Raspi: `ssh-copy-id pi@<RASPI_IP>`
- Key loaded in agent (if passphrase): `ssh-add ~/.ssh/id_ed25519`

Deploy:
```bash
ansible-playbook ansible/deploy.yml -i ansible/inventory.ini
```

This will pull the latest code on the Raspi, rebuild all Docker images from scratch, and restart the containers.

### Cloudflare DNS

Add an A record or CNAME for `goddonitracker.goddoni.org` pointing to the Raspberry Pi's public IP. The app is served on port `3004` via Nginx with SSL.

### SSL Certificates

Place your SSL certificates at `/home/pi/GoddoniTracker/Certs/` on the Raspberry Pi:
- `fullchain.pem`
- `privkey.pem`

## API Endpoints

### Auth

| Method | Endpoint                     | Description                                      |
|--------|------------------------------|--------------------------------------------------|
| GET    | `/api/auth/google/login`     | Redirect to Google OAuth (`?platform=ios` for native app) |
| GET    | `/api/auth/google/callback`  | OAuth callback, creates session, redirects with token |
| GET    | `/api/auth/me`               | Get current user info                            |

All other endpoints require `Authorization: Bearer <token>` header.

### Expenses

| Method | Endpoint                      | Description                                    |
|--------|-------------------------------|------------------------------------------------|
| GET    | `/api/expenses?month=YYYY-MM` | List expenses for a month, grouped by day      |
| GET    | `/api/expenses/{id}`          | Get a single expense                           |
| POST   | `/api/expenses`               | Create an expense                              |
| PUT    | `/api/expenses/{id}`          | Update an expense                              |
| DELETE | `/api/expenses/{id}`          | Delete an expense                              |
| GET    | `/api/expenses/search?q=term` | Search expenses by title or comment            |

### Categories

| Method | Endpoint                     | Description                |
|--------|------------------------------|----------------------------|
| GET    | `/api/categories`            | List user's categories     |
| POST   | `/api/categories`            | Create a category          |
| PUT    | `/api/categories/{id}`       | Rename a category          |
| DELETE | `/api/categories/{id}`       | Delete a category          |
| PUT    | `/api/categories/reorder`    | Reorder categories         |

### Analytics

| Method | Endpoint                      | Description                                    |
|--------|-------------------------------|------------------------------------------------|
| GET    | `/api/analytics?month=YYYY-MM`| Monthly analytics (or all-time if no month)    |

### Settings

| Method | Endpoint        | Description                |
|--------|-----------------|----------------------------|
| GET    | `/api/settings`  | Get user settings          |
| PUT    | `/api/settings`  | Update monthly budget      |

### Export / Import

| Method | Endpoint                                       | Description           |
|--------|------------------------------------------------|-----------------------|
| GET    | `/api/export?date_from=YYYY-MM-DD&date_to=...` | Download CSV          |
| POST   | `/api/import`                                  | Upload CSV (multipart)|

### CSV Format

Semicolon-separated, UTF-8:
```
Title;Date;Amount;Currency;In CHF;Category;Payment Method;City;Country;Comment
Migros Einkauf;2026-05-13 10:11:38;8.90;CHF;8.90;ToGo Food🍕;;;;
```

@Author Severin Goddon, 2026
