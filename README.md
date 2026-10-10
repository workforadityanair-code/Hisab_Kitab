# HisabKitab

A clean, modern Flutter expense-splitting app with Material You design. Split bills with friends, scan receipts, track recurring expenses, and settle debts instantly via UPI.

## Features

- **Expense Splitting:** Add expenses and split equally or by exact amounts
- **Bill Scanning:** Scan receipts with on-device ML Kit OCR; items, tax, totals extracted automatically
- **Groups:** Create groups for trips, flats, or any shared expense pool
- **Recurring:** Set weekly or monthly expenses (rent, subscriptions, etc.)
- **Settlements:** See who owes whom, send reminders via SMS or WhatsApp with payment QR codes
- **Backups:** Export everything to a `.hisab` file; restore on any phone
- **Sharing:** Share a group with friends; they sync expenses and balances
- **Categories:** Automatic categorization; monthly insights by spending type
- **Photos:** Add a photo to groups and friends
- **App Lock:** Fingerprint or face unlock with a configurable lock timer
- **Material You:** Dynamic theming from device wallpaper; 8 accent colors

## Getting Started

```bash
flutter pub get
flutter run
```

### First Run
Create a profile with your name, phone number, and UPI ID. Everything else follows from there.

### Building

Debug:
```bash
flutter build apk --debug
```

Release (arm64 only, smaller):
```bash
flutter build apk --release --split-per-abi
```
Install `app-arm64-v8a-release.apk` to your phone.

## Architecture

- **Models:** Person, ExpenseGroup, GroupExpense, RecurringExpense, Settlement
- **Store:** Single source of truth; SharedPreferences persistence; ID-based person references
- **UI:** 10+ screens (Dashboard, Add Expense, Bill Review, Friends, Settings, Insights, etc.)
- **Messaging:** SMS, WhatsApp (with optional QR image); direct UPI deeplinks
- **Import/Export:** `.hisab` JSON format; cross-phone group sharing and full backups

## Key Packages

- `dynamic_color` — Material You theming
- `google_mlkit_text_recognition`, `google_mlkit_document_scanner` — OCR and bill scanning
- `qr_flutter` — QRP code generation
- `local_auth` — Fingerprint and face unlock
- `file_picker`, `image_picker` — File and photo selection
- `pdf`, `printing` — Bill PDF export

## Testing

28 tests cover data models, settlement logic, bill parsing, file sharing, and backups.

```bash
flutter test
```

## Credits

Built by Aditya Nair. Made in India 🇮🇳

---

**No login required.** All data lives on your phone. Share groups with friends using `.hisab` files.
