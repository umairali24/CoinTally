# CoinTally — SYSTEM MAP
> **AI AGENT CONTEXT BRIDGE** — This is the primary source of truth for any AI agent working on this codebase.  
> **Protocol**: Every feature addition, DB change, new package, or architectural shift MUST be reflected in this file before the task is considered complete.

---

## 1. Tech Stack & Architecture

| Concern | Technology / Pattern |
|---|---|
| **Framework** | Flutter (Dart SDK `^3.10.4`, app version `1.0.0+1`) |
| **App ID** | `cointally` (package name in pubspec) |
| **DB filename** | `hisaabmate.db` (current schema version: **30**) |
| **State Management** | `flutter_riverpod ^2.5.1` — `StateNotifier` + `Provider` pattern |
| **Database** | `sqflite ^2.4.1` via singleton `DatabaseHelper` (`lib/data/local/db_helper.dart`) |
| **Routing** | `MaterialApp` routes map + `onGenerateRoute` for parametric routes (no named-route library) |
| **Typography** | Manrope via `google_fonts ^6.2.1` |
| **UI Theme** | Material 3, dual-primary: `#109D10` (light) / `#13EC13` (dark), fully adaptive |
| **Localization** | `flutter_localizations` SDK + `Locale(langCode)` from `localeProvider`; supports `en` & `ur` |
| **Analytics** | Firebase Analytics via `firebase_analytics ^11.4.1` + custom `TelemetryService` |
| **Cloud** | Google Sign-In / Drive for backup (`google_sign_in`, `googleapis`, `drive_service.dart`) |
| **Background** | `workmanager ^0.9.0` — daily Google Drive backup (`BackupWorkerManager`) |
| **Security** | `local_auth ^3.0.0` — biometric lock with auto-lock after 1 min via `SecurityNotifier` |
| **Notifications** | `flutter_local_notifications ^17.2.3` + `flutter_notification_listener` (local package) |
| **Data Export** | `csv ^7.1.0`, `pdf ^3.11.3`, `printing ^5.14.2`, `share_plus ^12.0.1` |
| **Currency** | Live rates fetched by `currency_api_service.dart`; stored in `exchange_rates` table |
| **Gold/Silver** | Scraped/fetched by `GoldService` (`lib/data/services/gold_service.dart`) |

---

## 2. Directory Structure (`lib/`)

```
lib/
├── main.dart                     # App bootstrap, Firebase init, theme config, AuthWrapper
│
├── core/
│   ├── constants/                # App-wide constants
│   ├── database/
│   │   └── database_config.dart  # Platform-specific DB init (sqflite_common_ffi for desktop/web)
│   ├── services/
│   │   ├── notification_service.dart   # ★ Notification pipeline (listener, parser, dedup)
│   │   ├── backup_worker.dart          # WorkManager daily Google Drive backup
│   │   ├── biometric_service.dart      # local_auth wrapper
│   │   ├── cloud_auth_service.dart     # Google Sign-In persistence
│   │   ├── currency_api_service.dart   # Live exchange rate fetch
│   │   ├── currency_sync_service.dart  # Sync rates into exchange_rates table
│   │   ├── drive_service.dart          # Google Drive upload/download
│   │   ├── export_service.dart         # CSV/PDF export
│   │   ├── import_service.dart         # CSV import
│   │   └── telemetry_service.dart      # Firebase Analytics + DebugView
│   └── utils/
│       ├── transaction_parser.dart     # ★ Regex engine: amount/type/merchant from SMS text
│       ├── spam_filter.dart            # ★ Blacklist-based spam rejection
│       ├── bank_utils.dart             # Bank name normalization helpers
│       ├── format_utils.dart           # Currency & percentage formatting
│       └── localization_service.dart   # Urdu/English string service
│
├── data/
│   ├── local/
│   │   └── db_helper.dart         # ★ SQLite singleton, all table creation & migrations
│   ├── repository/                # Concrete implementations of domain interfaces
│   │   ├── transaction_repository_impl.dart
│   │   ├── account_repository_impl.dart
│   │   ├── budget_repository_impl.dart
│   │   ├── category_repository_impl.dart
│   │   ├── debt_repository_impl.dart
│   │   ├── goal_repository_impl.dart
│   │   ├── preference_repository_impl.dart
│   │   └── person_repository_impl.dart
│   └── services/
│       └── gold_service.dart      # Gold/Silver price scraper
│
├── domain/
│   ├── entities/                  # Pure Dart data models (no Flutter deps)
│   │   ├── transaction_entity.dart
│   │   ├── account_entity.dart
│   │   ├── category_entity.dart
│   │   ├── budget_entity.dart
│   │   ├── goal_entity.dart
│   │   ├── debt_entity.dart
│   │   ├── person_entity.dart
│   │   ├── zakat_models.dart      # ZakatAsset, ZakatLiability, enums
│   │   └── ...
│   └── repository/                # Abstract interfaces (contracts)
│       ├── transaction_repository.dart
│       ├── account_repository.dart
│       └── ...
│
└── presentation/
    ├── notifiers/                 # Riverpod StateNotifiers (one per domain area)
    │   ├── transaction_notifier.dart
    │   ├── account_notifier.dart
    │   ├── budget_notifier.dart
    │   ├── category_notifier.dart
    │   ├── currency_notifier.dart
    │   ├── debt_notifier.dart
    │   ├── goal_notifier.dart
    │   ├── person_notifier.dart
    │   ├── security_notifier.dart
    │   ├── theme_notifier.dart
    │   ├── locale_notifier.dart
    │   ├── format_preferences_notifier.dart   # FormatPreferencesState
    │   └── zakat_preference_notifier.dart
    │
    ├── screens/                   # Full-page UI
    │   ├── main_navigation_screen.dart  # Bottom nav shell (Home, Budgets, Assets, Settings)
    │   ├── welcome_screen.dart          # Onboarding
    │   ├── lock_screen.dart             # Biometric gate
    │   ├── dashboard_screen.dart        # Home tab
    │   ├── transaction_history_screen.dart
    │   ├── add_transaction_screen.dart
    │   ├── budget_list_screen.dart
    │   ├── budget_creation_screen.dart
    │   ├── goals_screen.dart
    │   ├── zakat_screen.dart            # ★ Zakat calculator
    │   ├── debt_screen.dart
    │   ├── person_detail_screen.dart
    │   ├── add_person_screen.dart
    │   ├── settings_screen.dart
    │   ├── notification_settings_screen.dart
    │   └── ...
    │
    └── widgets/                   # Reusable components
        ├── sleek_components.dart        # PremiumCard, NeonButton, SleekTextField, etc.
        ├── cashflow_overview_card.dart  # ★ Donut chart + drill-down bottom sheet
        ├── currency_selector.dart       # CurrencySelector.currencies list
        └── ...
```

---

## 3. Database Schema (SQLite) — `hisaabmate.db` v30

### 3.1 `transactions`
| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | |
| `amount` | REAL NOT NULL | Always positive |
| `type` | TEXT NOT NULL | `'INCOME'`, `'EXPENSE'`, `'TRANSFER'` |
| `category` | TEXT NOT NULL | Matches `categories.name`; special: `'Transfer'`, `'Debt:LEND'`, `'Debt:BORROW'` |
| `date` | INTEGER NOT NULL | Unix ms since epoch |
| `merchant_name` | TEXT | Display name of payee/payer |
| `account_id` | INTEGER | FK → `accounts.id` (source account) |
| `to_account_id` | INTEGER | FK → `accounts.id` (TRANSFER destination) |
| `debt_id` | INTEGER | FK → `debts.id` if linked to a debt |
| `is_auto_detected` | INTEGER DEFAULT 0 | 1 = created via notification pipeline |
| `is_promotional` | INTEGER DEFAULT 0 | Reserved for future use |

### 3.2 `accounts`
| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | |
| `bank_name` | TEXT NOT NULL | Display name (e.g., `'HBL'`, `'Wallet'`) |
| `balance` | REAL DEFAULT 0.0 | Seed balance (actual balance computed from transactions) |
| `theme_color` | TEXT DEFAULT `'#FFFFFF'` | Hex color for the card UI |
| `logo_asset_path` | TEXT | Path to bank logo asset |
| `account_type` | TEXT DEFAULT `'BANK'` | `'BANK'`, `'CREDIT_CARD'`, `'WALLET'`, `'SAVINGS'` |
| `credit_limit` | REAL DEFAULT 0.0 | Only relevant for CREDIT_CARD type |
| `is_default` | INTEGER DEFAULT 0 | 1 = fallback account for auto-capture |
| `currency_code` | TEXT DEFAULT `'PKR'` | ISO 4217 code (added v23) |
| `bill_payment_date` | INTEGER | Day of month for CC reminder (added v28) |
| `enable_reminder` | INTEGER DEFAULT 0 | 1 = send monthly bill reminder (added v28) |

### 3.3 `categories`
| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | |
| `name` | TEXT NOT NULL | e.g., `'Food'`, `'Salary'` |
| `icon_code` | INTEGER NOT NULL | `IconData.codePoint` value |
| `icon_family` | TEXT | e.g., `'MaterialIcons'` |
| `icon_package` | TEXT | Usually null |
| `color_hex` | TEXT DEFAULT `'#13EC13'` | Hex color |
| `type` | TEXT DEFAULT `'EXPENSE'` | `'EXPENSE'` or `'INCOME'` |

**Default EXPENSE seeds**: Food, Fuel, Bills, Shopping, Other, Rent, Utilities, Entertainment, Health, Transport, Zakat  
**Default INCOME seeds**: Salary, Bonus, Other Income

### 3.4 `budgets`
| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | |
| `category` | TEXT NOT NULL | Matches `categories.name`; `'Overall'` if `is_overall = 1` |
| `monthly_limit` | REAL NOT NULL | |
| `period` | TEXT DEFAULT `'MONTHLY'` | Reserved for future periods |
| `is_overall` | INTEGER DEFAULT 0 | 1 = total monthly cap (not category-specific) |

### 3.5 `goals`
| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | |
| `title` | TEXT NOT NULL | |
| `target_amount` | REAL NOT NULL | |
| `current_amount` | REAL DEFAULT 0.0 | |
| `is_locked` | INTEGER DEFAULT 1 | 1 = funds locked until goal met |
| `type` | TEXT DEFAULT `'SAVING'` | |
| `category` | TEXT | Optional tag |
| `created_at` | INTEGER | Unix ms |
| `image_path` | TEXT | Local image for the goal card |
| `target_account_id` | INTEGER | FK → `accounts.id` |

### 3.6 `debts`
| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | |
| `person_id` | INTEGER NOT NULL | FK → `persons.id` |
| `amount` | REAL NOT NULL | |
| `type` | TEXT NOT NULL | `'LEND'` (you gave money) or `'BORROW'` (you owe money) |
| `description` | TEXT | |
| `date` | INTEGER NOT NULL | Unix ms |
| `due_date` | INTEGER | Unix ms, optional |
| `remind_me` | INTEGER DEFAULT 0 | 1 = schedule a local notification |
| `is_settled` | INTEGER DEFAULT 0 | 1 = fully settled |
| `account_id` | INTEGER | FK → `accounts.id` (which account was used) |

### 3.7 `persons`
| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | |
| `name` | TEXT NOT NULL | |
| `phone_number` | TEXT | |
| `created_at` | INTEGER | Unix ms |

### 3.8 `pending_transactions` *(Auto-Capture queue)*
| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | |
| `amount` | REAL NOT NULL | |
| `type` | TEXT NOT NULL | |
| `date` | INTEGER NOT NULL | Unix ms |
| `merchant_name` | TEXT | Parsed by `TransactionParser` |
| `raw_title` | TEXT | Original notification title |
| `raw_body` | TEXT | Original notification body (used for dedup) |
| `package_name` | TEXT | Android package of originating app |
| `suggested_account_id` | INTEGER | FK → `accounts.id` (auto-resolved) |
| `to_account_id` | INTEGER | FK → `accounts.id` (for auto-detected transfers, added v30) |
| `is_reconciled` | INTEGER DEFAULT 0 | 1 = user confirmed it (moved to `transactions`) |
| `notification_key` | TEXT | Android `Notification.key` for dedup |

### 3.9 `sender_rules`
| Column | Type | Notes |
|---|---|---|
| `sender_id` | TEXT PK | SMS shortcode or notification title (e.g., `'14250'`, `'HBL'`) |
| `bank_name` | TEXT NOT NULL | Canonical bank name |
| `package_name` | TEXT | Android package name alternative key |
| `is_blocked` | INTEGER DEFAULT 0 | 1 = block all notifications from this sender |

### 3.10 `learned_rules` *(ML Keyword Routing Brain)*
| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | |
| `package_name` | TEXT | Source app package |
| `shortcode` | TEXT | SMS shortcode (added v26) |
| `keyword` | TEXT | Lowercase keyword extracted from notification body |
| `target_account_id` | INTEGER | FK → `accounts.id` |
| `target_merchant_name` | TEXT | Canonical merchant display name |
| `occurrence_count` | INTEGER DEFAULT 1 | How many times this rule triggered |

### 3.11 `exchange_rates`
| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | |
| `from_currency` | TEXT NOT NULL | ISO 4217 (e.g., `'USD'`) |
| `to_currency` | TEXT NOT NULL | ISO 4217 |
| `rate` | REAL NOT NULL | Conversion factor |
| `last_updated` | INTEGER NOT NULL | Unix ms |

Index: `idx_exchange_rates_to` on `to_currency`.

### 3.12 `app_preferences` *(added v29)*
| Column | Type | Notes |
|---|---|---|
| `key` | TEXT PK | Preference key (e.g., `'zakat_assets_json'`) |
| `value` | TEXT NOT NULL | Serialized value |
| `type` | TEXT NOT NULL | Data type hint (e.g., `'string'`, `'bool'`) |

---

## 4. Core Engines & Logic

### 4.1 Auto-Capture Notification Pipeline
**Files**: `lib/core/services/notification_service.dart`, `lib/core/utils/transaction_parser.dart`, `lib/core/utils/spam_filter.dart`, `lib/data/local/db_helper.dart`

**Flow** (runs in a background Dart isolate):
1. **Permission gate** — only whitelisted app packages (set in `NotificationSettingsScreen`) or the default SMS app (if enabled) are processed. Blocked `sender_id` entries in `sender_rules` are rejected silently.
2. **SpamFilter** — blacklist of 35+ promotional keywords plus a "has currency symbol but no transactional context" heuristic. Promotions (%, "offer", "bundle", etc.) are dropped.
3. **TransactionParser** (regex engine):
   - **Amount**: Strategy A = explicit `Rs./PKR` prefix regex. Strategy B = keyword-context implicit number with date/time/year filter heuristics.
   - **Type**: `INCOME` if text contains `received/credited/added/deposit`; else `EXPENSE`.
   - **Merchant**: Priority regex on prepositions (`from`, `to`, `paid to`, `sent to`); fallback `at` regex; Raast-specific pattern; fallback to notification title or `'Unknown'`.
4. **Learned Rules lookup** — `findLearnedRule()` queries `learned_rules` by `package_name` + keyword match for account routing and merchant name overrides.
5. **Bank Resolution** — Package name → `sender_rules` → title → body keyword alias table → `_bankAliases` map (25 banks) → `getAccountIdByBankName()` with CREDIT_CARD priority logic.
6. **Deduplication** (3-layer):
   - Confirmed transactions within 5-min window (amount+type+date).
   - Pending queue by `notification_key` + amount.
   - Pending queue heuristic (amount+type+5-min window).
7. **Atomic insert** via `insertPendingUnique()` DB transaction.
8. **Badge/System notification update** + UI isolate signal via `IsolateNameServer`.

### 4.2 Smart Transfer Detector
**File**: `lib/data/local/db_helper.dart` → `checkAndMergeTransfer()`

When a new transaction is committed to `transactions`, a query looks for an opposing INCOME/EXPENSE of the **same amount** from a **different account** within a **5-minute window**. If found, both are deleted in a single DB transaction and replaced with a synthetic `TRANSFER` record with `account_id` (from) and `to_account_id` (to).

### 4.3 Zakat Math Engine
**File**: `lib/presentation/screens/zakat_screen.dart` → `_calculateZakat()`

- Fetches live gold (`GoldService.fetchLiveGoldRate()`) and silver rates.
- Supports user-defined `ZakatAsset` list (cash, gold in tolas, silver in tolas, other) and `ZakatLiability` list, all stored as JSON in `app_preferences`.
- Gold/Silver assets use live rate × weight for PKR equivalent.
- **Nisab** determined by user's `NisabStandard` preference: Gold = `7.5 × goldRate`, Silver = `52.5 × silverRate`.
- **Fiqh school** (`FiqhSchool.hanafi` vs others) determines if personal-use jewelry is exempt.
- Zakat = `(Total Assets − Total Liabilities) × 2.5%` if net wealth ≥ Nisab; else 0.
- Assets/Liabilities can be **dynamically linked** to live account balances or unsettled debt entries (`linkedAccountId`, `linkedDebtId`), auto-synced by `_syncLiveBalances()`.
- Already-paid Zakat for the current calendar year is tracked by querying `transactions` for category `'Zakat'`.

### 4.4 Cashflow Donut Chart + Drill-Down
**File**: `lib/presentation/widgets/cashflow_overview_card.dart`

- `CashflowOverviewCard` receives a flat `List<TransactionEntity>` from `transactionProvider`.
- `_aggregateByCategory()` groups by `CategoryEntity` and sums amounts (with currency conversion via `CurrencyNotifier`).
- `DonutChartPainter` (custom `CustomPainter`) draws arc segments with icon overlays.
- **Drill-Down** (added): tapping the Active Selection Card opens `_CategoryDrillDownSheet` (modal bottom sheet), fetching matching transactions via `TransactionRepository.getTransactionsByCategoryAndDateRange()`. The Debt bucket uses `LIKE 'Debt%'` matching. Individual tiles are `_DrillDownTransactionTile`, tapping opens `AddTransactionScreen` for edit.

### 4.5 Multi-Currency System
**Files**: `lib/presentation/notifiers/currency_notifier.dart`, `lib/data/local/db_helper.dart` (`exchange_rates` table), `lib/core/services/currency_sync_service.dart`

- Each account has a `currency_code`.
- `CurrencyNotifier` holds the primary display currency preference.
- Amounts displayed in the primary currency are converted via `exchange_rates` table.

---

## 5. Current State & Known Issues *(as of 2026-03-13)*

### Recently Completed
- **Cashflow Donut Chart Drill-Down**: Tapping the Active Selection Card now opens a modal bottom sheet showing individual transactions for that category, reusing `TransactionListTile` UI. New repo method `getTransactionsByCategoryAndDateRange()` added.

### Design Decisions & Gotchas
- **`FormatPreferencesState`** is the correct Riverpod state class for formatting preferences (NOT `FormatPreferences`). Provider is `formatPreferencesProvider`.
- **Debt category** in the Donut Chart is a virtual aggregate — the chart groups all `category LIKE 'Debt%'` transactions under a single "Debt" slice. The drill-down sheet queries using `LIKE 'Debt%'` to match this.
- **Account balance** is always computed at runtime by summing transactions. The `balance` column in `accounts` is only a seed/initial balance.
- **`is_auto_detected`** flag on a transaction does NOT mean it's unconfirmed. Confirmed auto-detected transactions have this set to 1. Unconfirmed ones live in `pending_transactions`.
- **Localization**: The `localization_service.dart` provides static Urdu/English strings but the full Urdu locale is toggled via `localeProvider`.

### Known Pending Work / Possible Bugs
- `print()` statements remain in `notification_service.dart` and `main.dart` (dev artifacts, should be replaced with `log()` before production).
- `SpamFilter` is aggressive — legitimate messages containing "services" or "scheduled" can be incorrectly filtered.
- The `_bankAliases` map in `db_helper.dart` has a duplicate entry for `'Allied Bank'` / `'ABL'`.

---

## 6. Changelog

| Date | Change | DB Version |
|---|---|---|
| Pre-v20 | Initial schema with transactions, accounts, budgets, categories, goals, debts, persons | — |
| v20 | Added `pending_transactions` + `learned_rules` tables | 20 |
| v21 | Seeded additional `sender_rules` (BOK, HBL variants) | 21 |
| v22 | Safety re-creation of pending/learned tables; `package_name` added to `sender_rules` | 22 |
| v23 | `currency_code` added to `accounts` | 23 |
| v24 | `exchange_rates` table added | 24 |
| v26 | `shortcode` column added to `learned_rules`; BOK/HBL Raast sender rules seeded | 26 |
| v28 | `bill_payment_date` + `enable_reminder` added to `accounts` | 28 |
| v29 | `app_preferences` table added (Zakat data, format prefs) | 29 |
| v30 | `to_account_id` added to `pending_transactions` (transfer support in capture queue) | 30 |
| 2026-03-13 | **Cashflow Drill-Down**: `getTransactionsByCategoryAndDateRange()` added to `TransactionRepository`/`Impl`; `cashflow_overview_card.dart` upgraded with `_CategoryDrillDownSheet`, `_DrillDownTransactionTile`, `_showDrillDownSheet`, `_getDateRangeForCurrentFilter`. | 30 (no DB change) |
