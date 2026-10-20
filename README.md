# GoddoniTracker

A personal expense tracking application. Track daily expenses, analyze spending by category, set monthly budgets with visual projections, and export/import data via CSV.

## Features

- **Expense tracking** — log expenses with title, amount, currency, category, payment method, and comments
- **Monthly view** — expenses grouped by day with daily and monthly totals
- **Swipe to delete** — swipe left on any expense to delete, or use the trash icon when editing
- **Search** — find expenses by title or comment, dismiss keyboard with "Fertig" button
- **Categories** — customizable categories with emoji support, drag-to-reorder, per-user
- **Category drill-down** — tap a category in analytics to see all its expenses
- **Analytics** — donut chart breakdown by category, three time periods: Monat / 7 Tage / Gesamt
- **Budget tracking** — set a monthly budget, track usage percentage, see projected overspend
- **Budget chart** — expandable cumulative spending chart vs. budget path with daily projection
- **CSV export** — export expenses for any date range, generated client-side via iOS share sheet
- **CSV import** — import expenses from CSV with automatic category creation (supports DD.MM.YY, DD.MM.YYYY, YYYY-MM-DD formats)
- **Multi-currency** — track amounts in any currency with automatic CHF conversion via [frankfurter.app](https://api.frankfurter.app) (ECB rates, no API key required)
- **Multi-user** — each user has their own categories, expenses, and settings (Google OAuth)
- **Dark mode** — dark theme throughout
- **German UI** — all interface text in German, code in English

## Tech Stack

| Layer    | Technology                                        |
|----------|---------------------------------------------------|
| iOS      | SwiftUI, Swift Charts, Observation (`@Observable`), async/await, zero dependencies |
| Backend  | Python 3.12, FastAPI, SQLAlchemy, Pydantic, Authlib |
| Database | SQLite                                            |
| Server   | Nginx (SSL reverse proxy), Uvicorn                |
| FX Rates | [frankfurter.app](https://api.frankfurter.app) — ECB rates, free, no API key |
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

The API base URL is configured in `SwiftApp/GoddoniTracker/Network/APIEndpoints.swift`. For local development, change it to `http://localhost:8001`. For production it points to `https://goddonitracker.goddoni.org` (served via Cloudflare Tunnel, no port).

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

First-time setup on the Raspi:
```bash
ssh pi@<RASPI_IP>
mkdir -p ~/GoddoniTracker/Certs
cd ~/GoddoniTracker
git clone https://github.com/severingoddon/GoddoniTracker.git GoddoniTracker
```

Copy the `.env` file (not in git):
```bash
scp backend/.env pi@<RASPI_IP>:~/GoddoniTracker/GoddoniTracker/backend/.env
```

Deploy (from your Mac):
```bash
cd /Users/severingoddon/Desktop/docs/Coding/PycharmProjects/GoddoniTracker
ansible-playbook ansible/deploy.yml -i ansible/inventory.ini
```

This pulls the latest code on the Raspi, backs up the database to `~/GoddoniTracker/backups/`, rebuilds the GoddoniTracker backend image, and restarts the containers. The DB volume `goddonitracker_db-data` is kept, and nothing outside the GoddoniTracker project (e.g. WeekBite) is touched. If the volume does not exist yet (first deploy), run with `-e first_deploy=true`.

### Cloudflare Tunnel

`goddonitracker.goddoni.org` is published via the Cloudflare Tunnel `raspberrypi` (route to `https://127.0.0.1:3004`, Origin Server Name `goddonitracker.goddoni.org`, TLS verification disabled). No router port forwarding is needed. Nginx still serves SSL locally on port `3004`.

### SSL Certificates

Generated with Let's Encrypt:
```bash
sudo certbot certonly --standalone -d goddonitracker.goddoni.org
sudo cp /etc/letsencrypt/live/goddonitracker.goddoni.org/fullchain.pem ~/GoddoniTracker/Certs/
sudo cp /etc/letsencrypt/live/goddonitracker.goddoni.org/privkey.pem ~/GoddoniTracker/Certs/
sudo chown pi:pi ~/GoddoniTracker/Certs/*.pem
```

## API Endpoints

### Auth

| Method | Endpoint                     | Description                                      |
|--------|------------------------------|--------------------------------------------------|
| GET    | `/api/auth/google/login`     | Redirect to Google OAuth (`?platform=ios` for native app) |
| GET    | `/api/auth/google/callback`  | OAuth callback, creates session, redirects with token |
| GET    | `/api/auth/me`               | Get current user info                            |

All other endpoints require `Authorization: Bearer <token>` header.

### Expenses

| Method | Endpoint                                        | Description                                    |
|--------|-------------------------------------------------|------------------------------------------------|
| GET    | `/api/expenses?month=YYYY-MM&category_id=N`     | List expenses for a month, optionally filtered by category |
| GET    | `/api/expenses/{id}`                            | Get a single expense                           |
| POST   | `/api/expenses`                                 | Create an expense                              |
| PUT    | `/api/expenses/{id}`                            | Update an expense                              |
| DELETE | `/api/expenses/{id}`                            | Delete an expense                              |
| GET    | `/api/expenses/search?q=term`                   | Search expenses by title or comment            |

### Categories

| Method | Endpoint                     | Description                |
|--------|------------------------------|----------------------------|
| GET    | `/api/categories`            | List user's categories     |
| POST   | `/api/categories`            | Create a category          |
| PUT    | `/api/categories/{id}`       | Rename a category          |
| DELETE | `/api/categories/{id}`       | Delete a category          |
| PUT    | `/api/categories/reorder`    | Reorder categories         |

### Analytics

| Method | Endpoint                                          | Description                                    |
|--------|---------------------------------------------------|------------------------------------------------|
| GET    | `/api/analytics?month=YYYY-MM&period=month\|7days` | Analytics with category breakdown + daily cumulative data |

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
Title;Date;Amount;Currency;In CHF;Category;Payment Method;Comment
Migros Einkauf;2026-05-13 10:11:38;8.90;CHF;8.90;ToGo Food🍕;;
```

Import tolerates additional columns (City, Country) — they are silently ignored.

@Author Severin Goddon, 2026
