# 🌱 Fertilizer Business ERP (کھاد بزنس ای آر پی)

A complete, modern, and offline-first mobile ERP application designed specifically for fertilizer dealers, pesticide distributors, and agri-shops in Pakistan.

---

## 🌟 Key Features

### 1. 🧾 Sales & Invoicing (POS)
- Quick billing for cash and credit (*udhaar*) sales.
- Professional A4 PDF Sales Invoices with company logo, tax details (NTN/STRN), and authorized signatures.
- Clean and accurate currency formatting (`Rs. 57,000`) without missing character glitches.
- Instant invoice sharing via WhatsApp, email, or direct printing.

### 2. 📦 Inventory & Stock Control
- Track fertilizer products by company, brand, bag size (e.g. 50 kg Urea, DAP, NP, Potash).
- Automatic stock reduction on sales and addition on purchases.
- Low-stock warning badges and alerts.
- Stock adjustments for damaged or expired bags.

### 3. 👥 Customer & Farmer Ledgers (*Khata*)
- Farmer profile management with contact details and village address.
- Debit/Credit ledgers with running balance calculation.
- Credit limit enforcement to prevent bad debts.
- Printable PDF account statements for farmers.

### 4. 🏢 Suppliers & Purchases
- Record supplier bills with freight (*kiraya*) and loading/unloading (*hammali*) expenses.
- Track total payables and supplier payment history.
- Printable supplier ledger statements.

### 5. 💰 Daily Cashbook (*Rokarr*) & Expenses
- Live cash-in-hand calculation without double-counting.
- Record daily business expenses (rent, labor, electricity, diesel, tea).
- Track cash inflows and outflows in real time.

### 6. 📊 Reports & Financial Analytics
- Gross profit and Net profit reports.
- Total stock valuation calculation.
- Sales, purchase, and expense summaries for Today, This Week, and This Month.

### 7. 🌐 Bilingual Support (English & Urdu)
- Seamless 1-tap switch between English and Urdu.
- Authentic agricultural and accounting terms (*روکڑ، کھاتہ، بنام، جمع، ادھار*).

### 8. 🔒 Security & Data Safety
- Optional 4-digit PIN security to protect sensitive financial records.
- **100% Offline-First:** Runs completely without internet using local SQLite database.
- **Full Database Backup:** Export verified JSON backups and share them to Google Drive or WhatsApp.
- **Restore & Factory Reset:** Restore previous data or clear the database safely with double-confirmation protection.

---

## 🛠️ Technology Stack

- **Framework:** Flutter (Android & iOS ready)
- **Language:** Dart
- **State Management:** Flutter Riverpod
- **Local Database:** SQLite (`sqflite`)
- **Reporting & Printing:** `pdf`, `printing`
- **File Sharing:** `share_plus`

---

## 🚀 How to Run Locally

### Prerequisites
- Flutter SDK (v3.24+ recommended)
- Android Studio / VS Code
- Android Device or Emulator

### Steps
1. Clone the repository:
   ```bash
   git clone https://github.com/Haseeb-ML/fertilizer-erp.git
   cd fertilizer-erp
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run automated tests:
   ```bash
   flutter test
   ```

4. Launch the application:
   ```bash
   flutter run
   ```

5. Build production Release APK:
   ```bash
   flutter build apk --release
   ```
   The generated APK will be at:
   `build/app/outputs/flutter-apk/app-release.apk`

---

## 📄 License
This project is proprietary and built for fertilizer dealers and agricultural businesses.
