# Property Manager

A native macOS property management app built with **SwiftUI** and **SwiftData**.

---

## Requirements

| Tool | Minimum Version |
|------|----------------|
| Xcode Command Line Tools | 15.0+ |
| macOS (development) | 14 Sonoma+ |
| macOS (runtime) | 14 Sonoma+ |

---

## Quick Start (Recommended)

The fastest way to build and run — no Xcode project setup needed.

### 1 – Build the app

```bash
chmod +x build.sh
./build.sh
```

This compiles the project using Swift Package Manager and creates a **Property Manager.app** bundle.

### 2 – Run the app

```bash
open "Property Manager.app"
```

### 3 – Install to Applications (optional)

```bash
chmod +x install.sh
./install.sh
```

This copies the app to `/Applications` so it appears in Spotlight and Launchpad.

---

## Alternative: Setup in Xcode

If you prefer to develop in Xcode:

1. Open the folder in Xcode: **File → Open → select the project folder** (Xcode will detect `Package.swift`)
2. Select the **PropertyManager** scheme
3. Press **⌘R** to build and run

---

## Default Login

| Username | Password | Role |
|----------|----------|------|
| `admin` | `admin123` | Administrator |

The admin account is created automatically on first launch. You can add more users from **Settings → Add User**.

---

## User Roles

| Role | Apartments | Contracts | Tenants | Payments | Users |
|------|-----------|-----------|---------|----------|-------|
| **Admin** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Property Manager** | ✅ | ✅ | ✅ | 👁️ | ❌ |
| **Accountant** | 👁️ | 👁️ | 👁️ | ✅ | ❌ |

---

## Features

- **Dashboard** — live stats, revenue charts, expiry alerts, overdue payment alerts
- **Apartments** — register units with address, area, rooms, rent price, and status
- **Contracts** — landlord & tenant contracts linked to apartments and tenants
- **Tenants** — full personal profiles with employment and emergency contacts
- **Rent Tracking** — record and track monthly payments with status (Paid / Pending / Overdue / Partial), bar charts, and follow-up view
- **Settings** — add/edit/delete users, assign roles, change passwords

---

## Data Storage

All data is stored **locally on your Mac** using SwiftData (SQLite under the hood).  
The database is located at:
```
~/Library/Application Support/PropertyManager/
```

To back up your data, copy that folder.

---

## Security Note

This app stores passwords as plain text for simplicity (local-only tool).  
For production use, integrate with `CryptoKit` to hash passwords with SHA-256 or bcrypt.
