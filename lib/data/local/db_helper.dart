import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:developer';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'hisaabmate.db');

    return await openDatabase(
      path,
      version: 30,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // ... (previous migration logic)
    if (oldVersion < 20) {
      await _createPendingTransactionsTable(db);
      await _createLearnedRulesTable(db);
    }
    if (oldVersion < 21) {
      await _seedSenderRulesV21(db);
    }
    if (oldVersion < 22) {
      // Force creation of missing tables if they don't exist (safety for v21 fresh installs)
      await _createPendingTransactionsTable(db);
      await _createLearnedRulesTable(db);
      
      // Ensure sender_rules has package_name column
      try {
        await db.execute('ALTER TABLE sender_rules ADD COLUMN package_name TEXT');
      } catch (e) {
        // Already exists
      }
    }
    if (oldVersion < 23) {
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN currency_code TEXT DEFAULT "PKR"');
      } catch (e) {
        log('Migration to v23 failed: $e');
      }
    }
    if (oldVersion < 24) {
      await _createExchangeRatesTable(db);
    }
    if (oldVersion < 26) {
      try {
        await db.execute('ALTER TABLE learned_rules ADD COLUMN shortcode TEXT');
        log('Migration to v26 (learned_rules shortcode) successful');
      } catch (e) {
        log('Migration to v26 failed: $e');
      }
      await _seedSenderRulesV26(db);
    }
    if (oldVersion < 27) {
      // Fix potential missing shortcode column in learned_rules
      try {
        await db.execute('ALTER TABLE learned_rules ADD COLUMN shortcode TEXT');
      } catch (e) {
        log('Migration to v27 (learned_rules shortcode) already applied or failed: $e');
      }
    }
    if (oldVersion < 28) {
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN bill_payment_date INTEGER');
        await db.execute('ALTER TABLE accounts ADD COLUMN enable_reminder INTEGER DEFAULT 0');
        log('Migration to v28 (bill_payment_date) successful');
      } catch (e) {
        log('Migration to v28 failed: $e');
      }
    }
    if (oldVersion < 29) {
      try {
        await _createAppPreferencesTable(db);
        log('Migration to v29 (app_preferences) successful');
      } catch (e) {
        log('Migration to v29 failed: $e');
      }
    }
    if (oldVersion < 30) {
      try {
        await db.execute('ALTER TABLE pending_transactions ADD COLUMN to_account_id INTEGER');
        log('Migration to v30 (pending_transactions to_account_id) successful');
      } catch (e) {
        log('Migration to v30 failed: $e');
      }
    }
  }

  Future<void> _createAppPreferencesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_preferences (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        type TEXT NOT NULL
      )
    ''');
  }

  Future<void> _seedSenderRulesV26(Database db) async {
    await db.insert('sender_rules', {
      'sender_id': 'BOK',
      'bank_name': 'Bank Of Khyber',
      'package_name': 'com.temenos.bok'
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    
    // Also include common variants just in case
    await db.insert('sender_rules', {
      'sender_id': 'Transaction Alert: Raast Payment',
      'bank_name': 'HBL',
      'package_name': 'com.hbl.android.hblmobilebanking'
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _createExchangeRatesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exchange_rates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_currency TEXT NOT NULL,
        to_currency TEXT NOT NULL,
        rate REAL NOT NULL,
        last_updated INTEGER NOT NULL
      )
    ''');
    // Create index for faster lookups
    await db.execute('CREATE INDEX IF NOT EXISTS idx_exchange_rates_to ON exchange_rates(to_currency)');
  }

  Future<void> _createPendingTransactionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        date INTEGER NOT NULL,
        merchant_name TEXT,
        raw_title TEXT,
        raw_body TEXT,
        package_name TEXT,
        suggested_account_id INTEGER,
        to_account_id INTEGER,
        is_reconciled INTEGER DEFAULT 0,
        notification_key TEXT
      )
    ''');
  }

  Future<void> _createLearnedRulesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS learned_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT,
        shortcode TEXT,
        keyword TEXT,
        target_account_id INTEGER,
        target_merchant_name TEXT,
        occurrence_count INTEGER DEFAULT 1
      )
    ''');

    // Insert extracted global learned rules
    const List<Map<String, dynamic>> initialLearnedRules = [
      {'package_name': 'app.com.brd', 'shortcode': null, 'keyword': 'umair ali* habib bank ltd from your ubl a/c *8099', 'target_merchant_name': 'UMAIR ALI* HABIB BANK LTD from your UBL A/C *8099', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'sheraz awan ', 'target_merchant_name': 'SHERAZ AWAN ', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'unknown', 'target_merchant_name': 'Unknown', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': '********5427 to umair ali *******4747 digitt plus', 'target_merchant_name': '********5427 to UMAIR ALI *******4747 Digitt Plus', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'college', 'target_merchant_name': 'COLLEGE ROAD GUJRANWALA', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'atm', 'target_merchant_name': 'Atm Withdrawal ', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'transfer', 'target_merchant_name': 'Transfer to Mashreq', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'ib-hafizabad', 'target_merchant_name': 'IB-HAFIZABAD ROAD GUJRAWANWALLA', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'jazzcash', 'target_merchant_name': 'JAZZCASH Card Order', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'the', 'target_merchant_name': 'The TLT ', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'jazzcash.', 'target_merchant_name': 'JazzCash. cashback', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'zong', 'target_merchant_name': 'ZONG ISLAMABAD PK', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'chase', 'target_merchant_name': 'CHASE UP GUJRANWALA PK', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'total', 'target_merchant_name': 'TOTAL PARCO GUJRANWALA PK', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'mcdonalds', 'target_merchant_name': 'MCDONALDS RESTAURANT G Gujranwala PK. ', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'mcdonald\'s', 'target_merchant_name': 'McDonald\'s ', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'baba', 'target_merchant_name': 'BABA BAKERS GUJRANWALA PK', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'shalimar', 'target_merchant_name': 'SHALIMAR FILLING STATI GUJRANWALA PK', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'mir', 'target_merchant_name': 'MIR SONS PETROLEUM SER Azad Kashmir PK', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'cyber', 'target_merchant_name': 'CYBER INTERNET SERVI Karachi PK', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'ptcl', 'target_merchant_name': 'PTCL', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'bill', 'target_merchant_name': 'Bill Paid', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'apg*scentarious', 'target_merchant_name': 'APG*Scentarious F Karachi PK', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'foodpanda', 'target_merchant_name': 'Foodpanda Karachi Paki Karachi PK. ', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'suleman', 'target_merchant_name': 'SULEMAN SWEETS & BAKER GUJRANWALA PK. ', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'layers', 'target_merchant_name': 'LAYERS BAKESHOP GUJRANWALA PK. ', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'umair ali a c *4747 in umair ali akbl a c *0017', 'target_merchant_name': 'UMAIR ALI A C *4747 in Umair Ali AKBL A C *0017', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'umair ali a c *6001 in umair ali akbl a c *0017', 'target_merchant_name': 'UMAIR ALI A C *6001 in Umair Ali AKBL A C *0017', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'pk**habb**6001 in akbl pk**ascm**0017 umair ali', 'target_merchant_name': 'PK**HABB**6001 in AKBL PK**ASCM**0017 Umair Ali', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'pk**jcma**4747 in akbl pk**ascm**0017 umair ali', 'target_merchant_name': 'PK**JCMA**4747 in AKBL PK**ASCM**0017 Umair Ali', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'umair ali', 'target_merchant_name': 'UMAIR ALI', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'cyber internet servi', 'target_merchant_name': 'CYBER INTERNET SERVI', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'sngpl', 'target_merchant_name': 'SNGPL', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'netflix.com', 'target_merchant_name': 'NETFLIX.COM', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'gepco', 'target_merchant_name': 'GEPCO', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'chase up', 'target_merchant_name': 'CHASE UP', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'onic', 'target_merchant_name': 'ONIC', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'annual fee', 'target_merchant_name': 'Annual Fee', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'daraz', 'target_merchant_name': 'DARAZ', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'delicia foods', 'target_merchant_name': 'DELICIA FOODS', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'alfa payment gateway', 'target_merchant_name': 'ALFA PAYMENT GATEWAY', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'pakistan medical commi', 'target_merchant_name': 'PAKISTAN MEDICAL COMMI', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'imtiaz stores', 'target_merchant_name': 'IMTIAZ STORES', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'haroon yousaf petrol', 'target_merchant_name': 'HAROON YOUSAF PETROL', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'cyber internet service', 'target_merchant_name': 'CYBER INTERNET SERVICE', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'food panda', 'target_merchant_name': 'FOOD PANDA', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'total parco', 'target_merchant_name': 'TOTAL PARCO', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'carrefour', 'target_merchant_name': 'CARREFOUR', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'pakistan pharmacy', 'target_merchant_name': 'PAKISTAN PHARMACY', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'police welfare pso', 'target_merchant_name': 'POLICE WELFARE PSO', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'baba bakers', 'target_merchant_name': 'BABA BAKERS', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'baskin robbins', 'target_merchant_name': 'BASKIN ROBBINS', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'virtual university of pak', 'target_merchant_name': 'VIRTUAL UNIVERSITY OF PAK', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'jc**mukhtar dawakhana', 'target_merchant_name': 'JC**MUKHTAR DAWAKHANA', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'haram baby boutique', 'target_merchant_name': 'HARAM BABY BOUTIQUE', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'aramco', 'target_merchant_name': 'ARAMCO', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'google*chrome temp', 'target_merchant_name': 'GOOGLE*CHROME TEMP', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'whmpress* shopping car', 'target_merchant_name': 'WHMPRESS* SHOPPING CAR', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'umair ali a/c **0017', 'target_merchant_name': 'Umair Ali A/c **0017', 'target_account_id': null, 'occurrence_count': 1},
      {'package_name': 'com.android.mms', 'shortcode': null, 'keyword': 'umair ali a/c **6001', 'target_merchant_name': 'UMAIR ALI A/c **6001', 'target_account_id': null, 'occurrence_count': 1},
    ];

    for (var rule in initialLearnedRules) {
      await db.insert('learned_rules', rule, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _seedSenderRulesV21(Database db) async {
    final newRules = [
      {'sender_id': 'BOK', 'bank_name': 'Bank Of Khyber'},
      {'sender_id': 'HBL', 'bank_name': 'HBL'},
      {'sender_id': 'HBL Mobile', 'bank_name': 'HBL'},
      {'sender_id': 'HBLMobile', 'bank_name': 'HBL'},
    ];
    for (var rule in newRules) {
      await db.insert('sender_rules', rule, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    amount REAL NOT NULL,
    type TEXT NOT NULL,
    category TEXT NOT NULL,
    date INTEGER NOT NULL,
    merchant_name TEXT,
    account_id INTEGER,
    to_account_id INTEGER,
    debt_id INTEGER,
    is_auto_detected INTEGER DEFAULT 0,
    is_promotional INTEGER DEFAULT 0
);
    ''');

    await db.execute('''
CREATE TABLE sender_rules (
    sender_id TEXT PRIMARY KEY,
    bank_name TEXT NOT NULL,
    package_name TEXT,
    is_blocked INTEGER DEFAULT 0
);
    ''');

    await db.execute('''
CREATE TABLE accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    bank_name TEXT NOT NULL,
    balance REAL DEFAULT 0.0,
    theme_color TEXT DEFAULT '#FFFFFF',
    logo_asset_path TEXT,
    account_type TEXT DEFAULT 'BANK',
    credit_limit REAL DEFAULT 0.0,
    is_default INTEGER DEFAULT 0,
    currency_code TEXT DEFAULT 'PKR',
    bill_payment_date INTEGER,
    enable_reminder INTEGER DEFAULT 0
);
    ''');

    await db.execute('''
CREATE TABLE goals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    target_amount REAL NOT NULL,
    current_amount REAL DEFAULT 0.0,
    is_locked INTEGER DEFAULT 1,
    type TEXT DEFAULT 'SAVING',
    category TEXT,
    created_at INTEGER,
    image_path TEXT,
    target_account_id INTEGER
);
    ''');

    await _createBudgetsTable(db);
    await _createCategoriesTable(db);
    await _seedDefaultCategories(db);
    await _createPersonsTable(db);
    await _createDebtsTable(db);
    await _createPendingTransactionsTable(db);
    await _createLearnedRulesTable(db);
    await _createExchangeRatesTable(db);
    await _createAppPreferencesTable(db);
    await _seedDefaultAccount(db);
    await _seedSenderRules(db);
  }

  Future<void> _createBudgetsTable(Database db) async {
    await db.execute('''
CREATE TABLE budgets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category TEXT NOT NULL,
    monthly_limit REAL NOT NULL,
    period TEXT DEFAULT 'MONTHLY',
    is_overall INTEGER DEFAULT 0
);
    ''');
  }

  Future<void> _createCategoriesTable(Database db) async {
    await db.execute('''
CREATE TABLE categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    icon_code INTEGER NOT NULL,
    icon_family TEXT,
    icon_package TEXT,
    color_hex TEXT DEFAULT '#13EC13',
    type TEXT DEFAULT 'EXPENSE'
);
    ''');
  }

  Future<void> _seedDefaultCategories(Database db) async {
    final List<Map<String, dynamic>> defaultCategories = [
      {'name': 'Food', 'icon_code': 983304, 'icon_family': 'MaterialIcons', 'color_hex': '#FF5252', 'type': 'EXPENSE'},
      {'name': 'Fuel', 'icon_code': 63597, 'icon_family': 'MaterialIcons', 'color_hex': '#FFD740', 'type': 'EXPENSE'},
      {'name': 'Bills', 'icon_code': 983265, 'icon_family': 'MaterialIcons', 'color_hex': '#448AFF', 'type': 'EXPENSE'},
      {'name': 'Shopping', 'icon_code': 983407, 'icon_family': 'MaterialIcons', 'color_hex': '#E040FB', 'type': 'EXPENSE'},
      {'name': 'Other', 'icon_code': 63705, 'icon_family': 'MaterialIcons', 'color_hex': '#9E9E9E', 'type': 'EXPENSE'},
      {'name': 'Rent', 'icon_code': 63477, 'icon_family': 'MaterialIcons', 'color_hex': '#FF9100', 'type': 'EXPENSE'},
      {'name': 'Utilities', 'icon_code': 63573, 'icon_family': 'MaterialIcons', 'color_hex': '#00E5FF', 'type': 'EXPENSE'},
      {'name': 'Entertainment', 'icon_code': 63719, 'icon_family': 'MaterialIcons', 'color_hex': '#FF4081', 'type': 'EXPENSE'},
      {'name': 'Health', 'icon_code': 63664, 'icon_family': 'MaterialIcons', 'color_hex': '#B2FF59', 'type': 'EXPENSE'},
      {'name': 'Transport', 'icon_code': 63155, 'icon_family': 'MaterialIcons', 'color_hex': '#7C4DFF', 'type': 'EXPENSE'},
      {'name': 'Zakat', 'icon_code': 63567, 'icon_family': 'MaterialIcons', 'color_hex': '#4CAF50', 'type': 'EXPENSE'},
    ];

    for (var cat in defaultCategories) {
      await db.insert('categories', cat);
    }
    await _seedIncomeCategories(db);
  }

  Future<void> _seedIncomeCategories(Database db) async {
    final List<Map<String, dynamic>> incomeCategories = [
      {'name': 'Salary', 'icon_code': 983128, 'icon_family': 'MaterialIcons', 'color_hex': '#13EC13', 'type': 'INCOME'},
      {'name': 'Bonus', 'icon_code': 63065, 'icon_family': 'MaterialIcons', 'color_hex': '#FFD740', 'type': 'INCOME'},
      {'name': 'Other Income', 'icon_code': 63705, 'icon_family': 'MaterialIcons', 'color_hex': '#00E5FF', 'type': 'INCOME'},
    ];

    for (var cat in incomeCategories) {
      final List<Map<String, dynamic>> existing = await db.query(
        'categories',
        where: 'name = ? AND type = ?',
        whereArgs: [cat['name'], cat['type']],
      );
      if (existing.isEmpty) {
        await db.insert('categories', cat);
      }
    }
  }

  Future<void> _createPersonsTable(Database db) async {
    await db.execute('''
CREATE TABLE persons (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    phone_number TEXT,
    created_at INTEGER
);
    ''');
  }

  Future<void> _createDebtsTable(Database db) async {
    await db.execute('''
CREATE TABLE debts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    person_id INTEGER NOT NULL,
    amount REAL NOT NULL,
    type TEXT NOT NULL, -- 'LEND' or 'BORROW'
    description TEXT,
    date INTEGER NOT NULL,
    due_date INTEGER,
    remind_me INTEGER DEFAULT 0,
    is_settled INTEGER DEFAULT 0,
    account_id INTEGER
);
    ''');
  }

  Future<void> _seedDefaultAccount(Database db) async {
    final List<Map<String, dynamic>> existing = await db.query(
      'accounts',
      where: 'bank_name = ?',
      whereArgs: ['Wallet'],
    );
    if (existing.isEmpty) {
      await db.insert('accounts', {
        'bank_name': 'Wallet',
        'balance': 0.0,
        'theme_color': '#13EC13',
        'account_type': 'BANK',
      });
    }
  }

  Future<void> _seedSenderRules(Database db) async {
    final List<Map<String, dynamic>> rules = [
      {'sender_id': '14250', 'bank_name': 'HBL'},
      {'sender_id': '8425', 'bank_name': 'HBL'},
      {'sender_id': '8251', 'bank_name': 'UBL'},
      {'sender_id': '8862', 'bank_name': 'Meezan Bank'},
      {'sender_id': '8222', 'bank_name': 'Bank Alfalah'},
      {'sender_id': '6222', 'bank_name': 'MCB'},
      {'sender_id': '9080', 'bank_name': 'Allied Bank'},
      {'sender_id': '8810', 'bank_name': 'Bank Al Habib'},
      {'sender_id': '9130', 'bank_name': 'Faysal Bank'},
      {'sender_id': '8928', 'bank_name': 'Askari Bank'},
      {'sender_id': '8870', 'bank_name': 'Askari Bank'},
      {'sender_id': '8081', 'bank_name': 'Habib Metro'},
      {'sender_id': '8267', 'bank_name': 'Bank Of Punjab'},
      {'sender_id': '8392', 'bank_name': 'Standard Chartered'},
      {'sender_id': '8987', 'bank_name': 'Sindh Bank'},
      {'sender_id': '8558', 'bank_name': 'Jazz Cash'},
      {'sender_id': '3737', 'bank_name': 'Easy Paisa'},
      {'sender_id': '8255', 'bank_name': 'Sada Pay'},
      {'sender_id': '8245', 'bank_name': 'Naya Pay'},
      {'sender_id': 'BOK', 'bank_name': 'Bank Of Khyber'},
      {'sender_id': 'HBL', 'bank_name': 'HBL'},
      {'sender_id': 'HBL Mobile', 'bank_name': 'HBL'},
      {'sender_id': 'HBLMobile', 'bank_name': 'HBL'},
      {'sender_id': 'Transaction Alert: Bill Payment', 'bank_name': 'HBL'},
      {'sender_id': 'Transaction Alert', 'bank_name': 'HBL'},
      {'sender_id': 'WA Business', 'bank_name': 'WhatsApp (Test)'},
    ];

    for (var rule in rules) {
      await db.insert('sender_rules', rule, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
  Future<int> addTransaction(Map<String, dynamic> transactionMap) async {
    final db = await database;
    return await db.insert('transactions', transactionMap);
  }

  Future<int?> getDefaultAccountId() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'accounts',
      where: 'is_default = 1',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first['id'] as int;
    }
    // Fallback to first account if no default set
    final allAccounts = await db.query('accounts', limit: 1);
    if (allAccounts.isNotEmpty) {
      return allAccounts.first['id'] as int;
    }
    return null;
  }

  Future<bool> checkAndMergeTransfer(int newTxId, Map<String, dynamic> newTxMap) async {
    final db = await database;
    // Safely extract values regardless of Map vs Object typing coming from caller
    final double amount = (newTxMap['amount'] is num) ? (newTxMap['amount'] as num).toDouble() : double.tryParse(newTxMap['amount'].toString()) ?? 0.0;
    
    final String type = newTxMap['type'] as String;
    if (type != 'INCOME' && type != 'EXPENSE') return false; // Only merge income/expense pairs

    final int accountId = newTxMap['account_id'] as int;
    final int date = newTxMap['date'] as int;
    final int window = 5 * 60 * 1000; // 5 minute window
    
    final targetType = type == 'INCOME' ? 'EXPENSE' : 'INCOME';
    
    final List<Map<String, dynamic>> pairs = await db.query(
      'transactions',
      where: 'id != ? AND amount = ? AND type = ? AND account_id != ? AND date >= ? AND date <= ? AND (is_auto_detected = 1 OR is_auto_detected = 0)',
      whereArgs: [newTxId, amount, targetType, accountId, date - window, date + window],
      orderBy: 'date DESC',
      limit: 1,
    );
    
    if (pairs.isNotEmpty) {
      final pair = pairs.first;
      final pairId = pair['id'] as int;
      final pairAccountId = pair['account_id'] as int;
      
      final fromAccount = type == 'EXPENSE' ? accountId : pairAccountId;
      final toAccount = type == 'INCOME' ? accountId : pairAccountId;
      
      await db.transaction((txn) async {
         // Delete the two individual transactions
         await txn.delete('transactions', where: 'id IN (?, ?)', whereArgs: [newTxId, pairId]);
         
         // Insert the synthesized Transfer
         await txn.insert('transactions', {
            'amount': amount,
            'type': 'TRANSFER',
            'category': 'Transfer',
            'date': date,
            'merchant_name': 'Self Transfer',
            'account_id': fromAccount,
            'to_account_id': toAccount,
            'is_auto_detected': 1,
         });
      });
      return true;
    }
    return false;
  }

  Future<bool> isDuplicateTransaction(Map<String, dynamic> transactionMap) async {
    final db = await database;
    return await _isDuplicateTransactionInternal(db, transactionMap);
  }

  Future<bool> _isDuplicateTransactionInternal(DatabaseExecutor db, Map<String, dynamic> transactionMap) async {
    final double amount = transactionMap['amount'] is int ? (transactionMap['amount'] as int).toDouble() : transactionMap['amount'];
    final String type = transactionMap['type'];
    final int date = transactionMap['date'];
    final String? rawBody = transactionMap['raw_body'];
    final String? notificationKey = transactionMap['notification_key'];
    final int window = 5 * 60 * 1000; // 5 minute window

    // 1. Check final confirmed transactions
    // We can't use notification_key here as confirmed transactions don't store it,
    // so we stick to amount+type+date heuristic.
    final List<Map<String, dynamic>> confirmedResults = await db.query(
      'transactions',
      where: 'amount = ? AND type = ? AND date >= ? AND date <= ?',
      whereArgs: [
        amount,
        type,
        date - window,
        date + window
      ],
    );
    if (confirmedResults.isNotEmpty) return true;

    // 2. Check existing pending transactions (Review Captures queue)
    // Primary Deduplication: Use the unique Notification Key PLUS amount.
    // We explicitly include amount so that two different transactions from the same
    // shortcode/app (same notification key) with different amounts are NOT blocked.
    if (notificationKey != null) {
      final List<Map<String, dynamic>> keyMatch = await db.query(
        'pending_transactions',
        where: 'notification_key = ? AND amount = ? AND type = ? AND is_reconciled = 0',
        whereArgs: [notificationKey, amount, type],
      );
      if (keyMatch.isNotEmpty) return true;
    }

    // Secondary Deduplication: Raw Body Match (if same notification updates/re-fires)
    // This catches repeated identical messages from the same sender.
    if (rawBody != null) {
      final List<Map<String, dynamic>> pendingBodyMatch = await db.query(
        'pending_transactions',
        where: 'raw_body = ? AND is_reconciled = 0',
        whereArgs: [rawBody],
      );
      if (pendingBodyMatch.isNotEmpty) return true;
    }

    // Tertiary Deduplication: Heuristic match (amount + type + window)
    // This is only reached if above checks are insufficient.
    final List<Map<String, dynamic>> pendingResults = await db.query(
      'pending_transactions',
      where: 'amount = ? AND type = ? AND date >= ? AND date <= ? AND is_reconciled = 0',
      whereArgs: [
        amount,
        type,
        date - window,
        date + window
      ],
    );
    
    return pendingResults.isNotEmpty;
  }


  Future<String?> getBankNameBySender(String senderId) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'sender_rules',
      where: 'sender_id = ? AND is_blocked = 0',
      whereArgs: [senderId],
    );
    if (result.isNotEmpty) {
      return result.first['bank_name'] as String;
    }
    return null;
  }

  // --- Bank & Account Mapping ---

  static const Map<String, List<String>> _bankAliases = {
    'HBL': ['Habib Bank', 'HBL', 'Konnect', 'Habib Bank Limited'],
    'UBL': ['United Bank', 'UBL', 'United Bank Limited'],
    'ABL': ['Allied Bank', 'ABL', 'Allied'],
    'MCB': ['Muslim Commercial', 'MCB', 'MCB Bank'],
    'Bank Of Punjab': ['BOP', 'Bank of Punjab', 'Bank Of Punjab'],
    'Bank Al Habib': ['BAHL', 'Bank Al Habib', 'Habib Habib', 'Al Habib'],
    'Easy Paisa': ['Easypaisa', 'Easy Paisa', 'Telenor', 'EP'],
    'Jazz Cash': ['JazzCash', 'Jazz Cash', 'Mobilink', 'JC'],
    'Sada Pay': ['SadaPay', 'Sada Pay'],
    'Naya Pay': ['NayaPay', 'Naya Pay'],
    'Askari Bank': ['AKBL', 'Askari Bank', 'Askari'],
    'Bank Of Khyber': ['BOK', 'Bank of Khyber', 'Bank Of Khyber'],
    'Standard Chartered': ['SCB', 'Standard Chartered', 'SC'],
    'Faysal Bank': ['FBL', 'Faysal Bank', 'Faysal'],
    'Meezan Bank': ['Meezan', 'Meezan Bank'],
    'Bank Alfalah': ['Alfalah', 'Bank Alfalah'],
    'Samba Bank': ['Samba'],
    'JS Bank': ['JS', 'JS Bank'],
    'Habib Metro': ['HabibMetro', 'Habib Metro'],
    'Dubai Islamic Bank': ['DIB', 'Dubai Islamic'],
    'National Bank': ['NBP', 'National Bank'],
    'Allied Bank': ['ABL', 'Allied Bank'],
    'SadaPay': ['Sada Pay', 'SadaPay'],
    'NayaPay': ['Naya Pay', 'NayaPay'],
  };

  /// Finds a canonical bank name from any text containing bank-related keywords or aliases.
  Future<String?> getBankNameByKeywords(String text) async {
    final lowerText = text.toLowerCase();
    
    // Check all aliases in every bank group
    for (var entry in _bankAliases.entries) {
      final canonicalName = entry.key;
      final aliases = entry.value;
      
      for (final alias in aliases) {
        // Use word boundaries for abbreviations (to avoid matching 'UBL' in 'Bubble')
        final bool isAbbreviation = alias.length <= 4 && alias == alias.toUpperCase();
        if (isAbbreviation) {
          final regExp = RegExp('\\b${alias.toLowerCase()}\\b');
          if (regExp.hasMatch(lowerText)) return canonicalName;
        } else {
          if (lowerText.contains(alias.toLowerCase())) return canonicalName;
        }
      }
    }
    return null;
  }

  Future<int?> getAccountIdByBankName(String bankName, {String? rawText}) async {
    final db = await database;
    log("Searching for account matching bank: $bankName");
    
    // Determine if the message indicates a credit card transaction
    bool isCreditCard = false;
    if (rawText != null) {
      final lowerRaw = rawText.toLowerCase();
      isCreditCard = lowerRaw.contains('credit card') || 
                     lowerRaw.contains('creditcard') || 
                     lowerRaw.contains('card ending') ||
                     lowerRaw.contains('ccard');
    }

    // Helper to query accounts based on the bank name and priority type
    Future<int?> findAccount(String searchBankName) async {
      // Priority 1: If it's a credit card message, enforce CREDIT_CARD account type match
      if (isCreditCard) {
        final List<Map<String, dynamic>> ccResult = await db.query(
          'accounts',
          where: '(bank_name LIKE ? OR bank_name = ?) AND account_type = ?',
          whereArgs: ['%$searchBankName%', searchBankName, 'CREDIT_CARD'],
          limit: 1,
        );
        if (ccResult.isNotEmpty) {
          log("Found direct CREDIT_CARD match: ${ccResult.first['bank_name']}");
          return ccResult.first['id'] as int;
        }
      }

      // Priority 2: Fallback or standard match for BANK account type
      final List<Map<String, dynamic>> bankResult = await db.query(
        'accounts',
        where: '(bank_name LIKE ? OR bank_name = ?) AND account_type = ?',
        whereArgs: ['%$searchBankName%', searchBankName, 'BANK'],
        limit: 1,
      );
      if (bankResult.isNotEmpty) {
        log("Found direct BANK match: ${bankResult.first['bank_name']}");
        return bankResult.first['id'] as int;
      }

      // Priority 3: Ultimate fallback, any account matching the bank name regardless of type
      final List<Map<String, dynamic>> fallbackResult = await db.query(
        'accounts',
        where: 'bank_name LIKE ? OR bank_name = ?',
        whereArgs: ['%$searchBankName%', searchBankName],
        limit: 1,
      );
      if (fallbackResult.isNotEmpty) {
        log("Found fallback match (type independent): ${fallbackResult.first['bank_name']}");
        return fallbackResult.first['id'] as int;
      }
      return null;
    }

    // 1. Try exact or LIKE match first
    int? matchedId = await findAccount(bankName);
    if (matchedId != null) return matchedId;

    // Try stripping spaces (e.g. "Jazz Cash" -> "JazzCash")
    final noSpaceBankName = bankName.replaceAll(' ', '');
    if (noSpaceBankName != bankName) {
      matchedId = await findAccount(noSpaceBankName);
      if (matchedId != null) return matchedId;
    }

    // Try stripping suffixes like "(Personal)" or "(Savings)"
    final cleanBankName = bankName.split('(')[0].trim();
    if (cleanBankName != bankName) {
      // NOTE: findAccount uses LIKE and exact match. For partial suffix cleaning, we just try it directly.
      matchedId = await findAccount(cleanBankName);
      if (matchedId != null) return matchedId;
    }

    // 2. Try aliases if primary search fails
    String? lookupName;
    for (var entry in _bankAliases.entries) {
      if (entry.key.toLowerCase() == bankName.toLowerCase() || 
          entry.value.any((a) => a.toLowerCase() == bankName.toLowerCase())) {
        lookupName = entry.key;
        break;
      }
    }

    if (lookupName != null && _bankAliases.containsKey(lookupName)) {
      final variations = [lookupName, ..._bankAliases[lookupName]!];
      for (final variant in variations) {
        log("Trying bank variant: $variant");
        matchedId = await findAccount(variant);
        if (matchedId != null) return matchedId;
      }
    }

    return null;
  }

  Future<String?> getBankNameByPackage(String packageName) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'sender_rules',
      where: 'package_name = ? AND is_blocked = 0',
      whereArgs: [packageName],
    );
    if (result.isNotEmpty) {
      return result.first['bank_name'] as String;
    }
    return null;
  }

  // --- Pending Transactions & Learning ---

  Future<int> insertPendingTransaction(Map<String, dynamic> pt) async {
    final db = await database;
    return await db.insert('pending_transactions', pt);
  }

  Future<int> insertPendingUnique(Map<String, dynamic> pt) async {
    final db = await database;
    return await db.transaction((txn) async {
      final isDuplicate = await _isDuplicateTransactionInternal(txn, pt);
      if (isDuplicate) {
        log("Atomic Check: Ignored Duplicate Capture: ${pt['amount']} with key ${pt['notification_key']}");
        return -1; 
      }
      
      final String type = pt['type'];
      if (type == 'INCOME' || type == 'EXPENSE') {
        final double amount = (pt['amount'] is num) ? (pt['amount'] as num).toDouble() : double.tryParse(pt['amount'].toString()) ?? 0.0;
        final int date = pt['date'];
        final int accountId = pt['suggested_account_id'];
        final int window = 5 * 60 * 1000;
        final String targetType = type == 'INCOME' ? 'EXPENSE' : 'INCOME';

        // Search for an exact opposite pair in the un-reconciled pending queue
        final List<Map<String, dynamic>> pairs = await txn.query(
          'pending_transactions',
          where: 'amount = ? AND type = ? AND suggested_account_id != ? AND date >= ? AND date <= ? AND is_reconciled = 0',
          whereArgs: [amount, targetType, accountId, date - window, date + window],
          orderBy: 'date DESC',
          limit: 1,
        );

        if (pairs.isNotEmpty) {
          final pair = pairs.first;
          final pairId = pair['id'] as int;
          final pairAccountId = pair['suggested_account_id'] as int;

          // Delete the existing half of the pair
          await txn.delete('pending_transactions', where: 'id = ?', whereArgs: [pairId]);

          // Synthesize a Transfer pending transaction
          final fromAccount = type == 'EXPENSE' ? accountId : pairAccountId;
          final toAccount = type == 'INCOME' ? accountId : pairAccountId;

          final transferPt = Map<String, dynamic>.from(pt);
          transferPt['type'] = 'TRANSFER';
          transferPt['merchant_name'] = 'Self Transfer';
          transferPt['suggested_account_id'] = fromAccount;
          transferPt['to_account_id'] = toAccount;

          return await txn.insert('pending_transactions', transferPt);
        }
      }

      return await txn.insert('pending_transactions', pt);
    });
  }

  Future<List<Map<String, dynamic>>> getPendingTransactions() async {
    final db = await database;
    return await db.query('pending_transactions', where: 'is_reconciled = 0', orderBy: 'date DESC');
  }

  Future<void> deletePendingTransaction(int id) async {
    final db = await database;
    await db.delete('pending_transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markPendingAsReconciled(int id) async {
    final db = await database;
    await db.update('pending_transactions', {'is_reconciled': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getPendingCount() async {
    final db = await database;
    final List<Map<String, dynamic>> res = await db.rawQuery(
      'SELECT COUNT(*) as count FROM pending_transactions WHERE is_reconciled = 0'
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<void> saveLearnedRule(Map<String, dynamic> rule) async {
    final db = await database;
    // Check if rule already exists for this package and keyword
    final List<Map<String, dynamic>> existing = await db.query(
      'learned_rules',
      where: 'package_name = ? AND keyword = ?',
      whereArgs: [rule['package_name'], rule['keyword']],
    );

    if (existing.isNotEmpty) {
      await db.update(
        'learned_rules',
        {
          'target_account_id': rule['target_account_id'],
          'target_merchant_name': rule['target_merchant_name'],
          'occurrence_count': (existing.first['occurrence_count'] as int) + 1,
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert('learned_rules', rule);
    }
  }

  Future<Map<String, dynamic>?> findLearnedRule(String packageName, String body) async {
    final db = await database;
    final List<Map<String, dynamic>> rules = await db.query(
      'learned_rules',
      where: 'package_name = ?',
      whereArgs: [packageName],
    );

    for (var rule in rules) {
      final keyword = rule['keyword'] as String;
      if (body.toLowerCase().contains(keyword.toLowerCase())) {
        return rule;
      }
    }
    return null;
  }

  Future<bool> isSenderBlocked(String senderId) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'sender_rules',
      where: 'sender_id = ? AND is_blocked = 1',
      whereArgs: [senderId],
    );
    return result.isNotEmpty;
  }

  Future<void> blockSender(String senderId, {String? packageName}) async {
    final db = await database;
    final List<Map<String, dynamic>> existing = await db.query(
      'sender_rules',
      where: 'sender_id = ?',
      whereArgs: [senderId],
    );

    if (existing.isNotEmpty) {
      await db.update(
        'sender_rules',
        {'is_blocked': 1},
        where: 'sender_id = ?',
        whereArgs: [senderId],
      );
    } else {
      await db.insert('sender_rules', {
        'sender_id': senderId,
        'bank_name': 'Non-Financial', 
        'package_name': packageName,
        'is_blocked': 1,
      });
    }
  }
}
