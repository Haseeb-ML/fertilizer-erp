class DatabaseTables {
  // Table names
  static const String businessSettings = 'business_settings';
  static const String products = 'products';
  static const String stockCostLayers = 'stock_cost_layers';
  static const String customers = 'customers';
  static const String suppliers = 'suppliers';
  static const String purchases = 'purchases';
  static const String purchaseItems = 'purchase_items';
  static const String sales = 'sales';
  static const String saleItems = 'sale_items';
  static const String payments = 'payments';
  static const String expenses = 'expenses';
  static const String stockMovements = 'stock_movements';
  static const String customerLedger = 'customer_ledger';
  static const String supplierLedger = 'supplier_ledger';
  static const String returns = 'returns';
  static const String storages = 'storages';
  static const String storageStocks = 'storage_stocks';
  static const String stockTransfers = 'stock_transfers';

  // Schema creation queries
  static const List<String> createTableQueries = [
    '''
    CREATE TABLE IF NOT EXISTS $businessSettings (
      id INTEGER PRIMARY KEY,
      business_name TEXT NOT NULL,
      owner_name TEXT,
      phone TEXT,
      address TEXT,
      city TEXT,
      ntn_strn TEXT,
      invoice_prefix TEXT DEFAULT 'INV-',
      purchase_prefix TEXT DEFAULT 'PUR-',
      currency_symbol TEXT DEFAULT '₨',
      pin_code TEXT,
      is_pin_enabled INTEGER DEFAULT 0,
      initial_cash_balance REAL DEFAULT 0,
      updated_at TEXT NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      sku TEXT UNIQUE,
      category TEXT NOT NULL,
      brand TEXT NOT NULL,
      bag_size TEXT,
      unit TEXT NOT NULL,
      purchase_price REAL NOT NULL,
      selling_price REAL NOT NULL,
      opening_stock REAL NOT NULL DEFAULT 0,
      current_stock REAL NOT NULL DEFAULT 0,
      min_stock_alert REAL NOT NULL DEFAULT 10,
      notes TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $stockCostLayers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL REFERENCES $products(id) ON DELETE CASCADE,
      purchase_id INTEGER,
      purchase_date TEXT NOT NULL,
      unit_cost REAL NOT NULL,
      original_quantity REAL NOT NULL,
      remaining_quantity REAL NOT NULL,
      created_at TEXT NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $customers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT,
      village_or_address TEXT,
      opening_balance REAL NOT NULL DEFAULT 0,
      current_balance REAL NOT NULL DEFAULT 0,
      credit_limit REAL NOT NULL DEFAULT 0,
      notes TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $suppliers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT,
      company_or_address TEXT,
      opening_balance REAL NOT NULL DEFAULT 0,
      current_balance REAL NOT NULL DEFAULT 0,
      notes TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $purchases (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_number TEXT UNIQUE NOT NULL,
      supplier_id INTEGER NOT NULL REFERENCES $suppliers(id),
      supplier_name TEXT NOT NULL,
      purchase_date TEXT NOT NULL,
      subtotal REAL NOT NULL,
      discount REAL NOT NULL DEFAULT 0,
      freight_charges REAL NOT NULL DEFAULT 0,
      grand_total REAL NOT NULL,
      paid_amount REAL NOT NULL DEFAULT 0,
      balance_due REAL NOT NULL DEFAULT 0,
      payment_status TEXT NOT NULL,
      payment_method TEXT,
      notes TEXT,
      is_reversed INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $purchaseItems (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      purchase_id INTEGER NOT NULL REFERENCES $purchases(id) ON DELETE CASCADE,
      product_id INTEGER NOT NULL REFERENCES $products(id),
      product_name TEXT NOT NULL,
      unit TEXT NOT NULL,
      quantity REAL NOT NULL,
      unit_price REAL NOT NULL,
      total_price REAL NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $sales (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_number TEXT UNIQUE NOT NULL,
      customer_id INTEGER,
      customer_name TEXT NOT NULL,
      sale_date TEXT NOT NULL,
      subtotal REAL NOT NULL,
      discount REAL NOT NULL DEFAULT 0,
      grand_total REAL NOT NULL,
      paid_amount REAL NOT NULL DEFAULT 0,
      balance_due REAL NOT NULL DEFAULT 0,
      total_cost REAL NOT NULL DEFAULT 0,
      gross_profit REAL NOT NULL DEFAULT 0,
      payment_status TEXT NOT NULL,
      payment_method TEXT NOT NULL,
      notes TEXT,
      is_reversed INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $saleItems (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sale_id INTEGER NOT NULL REFERENCES $sales(id) ON DELETE CASCADE,
      product_id INTEGER NOT NULL REFERENCES $products(id),
      product_name TEXT NOT NULL,
      unit TEXT NOT NULL,
      quantity REAL NOT NULL,
      unit_price REAL NOT NULL,
      unit_cost REAL NOT NULL DEFAULT 0,
      total_price REAL NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      payment_type TEXT NOT NULL,
      party_type TEXT NOT NULL,
      party_id INTEGER NOT NULL,
      party_name TEXT NOT NULL,
      reference_invoice_id INTEGER,
      reference_invoice_number TEXT,
      amount REAL NOT NULL,
      payment_date TEXT NOT NULL,
      payment_method TEXT NOT NULL,
      reference_number TEXT,
      notes TEXT,
      created_at TEXT NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      category TEXT NOT NULL,
      amount REAL NOT NULL,
      expense_date TEXT NOT NULL,
      payment_method TEXT NOT NULL DEFAULT 'Cash',
      title TEXT NOT NULL,
      notes TEXT,
      created_at TEXT NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $stockMovements (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL REFERENCES $products(id),
      product_name TEXT NOT NULL,
      movement_type TEXT NOT NULL,
      quantity REAL NOT NULL,
      balance_after REAL NOT NULL,
      reference_id INTEGER,
      reference_type TEXT,
      notes TEXT,
      movement_date TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $customerLedger (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_id INTEGER NOT NULL REFERENCES $customers(id),
      transaction_date TEXT NOT NULL,
      transaction_type TEXT NOT NULL,
      reference_id INTEGER,
      reference_number TEXT,
      description TEXT NOT NULL,
      debit REAL NOT NULL DEFAULT 0,
      credit REAL NOT NULL DEFAULT 0,
      running_balance REAL NOT NULL,
      created_at TEXT NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $supplierLedger (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      supplier_id INTEGER NOT NULL REFERENCES $suppliers(id),
      transaction_date TEXT NOT NULL,
      transaction_type TEXT NOT NULL,
      reference_id INTEGER,
      reference_number TEXT,
      description TEXT NOT NULL,
      debit REAL NOT NULL DEFAULT 0,
      credit REAL NOT NULL DEFAULT 0,
      running_balance REAL NOT NULL,
      created_at TEXT NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $returns (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      return_type TEXT NOT NULL,
      original_invoice_id INTEGER NOT NULL,
      original_invoice_number TEXT NOT NULL,
      party_id INTEGER NOT NULL,
      party_name TEXT NOT NULL,
      return_date TEXT NOT NULL,
      product_id INTEGER NOT NULL,
      product_name TEXT NOT NULL,
      quantity REAL NOT NULL,
      unit_price REAL NOT NULL,
      total_amount REAL NOT NULL,
      refund_type TEXT NOT NULL,
      reason TEXT,
      created_at TEXT NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $storages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      code TEXT,
      location TEXT,
      incharge_name TEXT,
      contact_number TEXT,
      capacity_bags INTEGER DEFAULT 0,
      is_default INTEGER DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $storageStocks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      storage_id INTEGER NOT NULL REFERENCES $storages(id) ON DELETE CASCADE,
      product_id INTEGER NOT NULL REFERENCES $products(id) ON DELETE CASCADE,
      quantity REAL NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL,
      UNIQUE(storage_id, product_id)
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $stockTransfers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transfer_number TEXT UNIQUE NOT NULL,
      from_storage_id INTEGER NOT NULL REFERENCES $storages(id),
      to_storage_id INTEGER NOT NULL REFERENCES $storages(id),
      product_id INTEGER NOT NULL REFERENCES $products(id),
      quantity REAL NOT NULL,
      transfer_date TEXT NOT NULL,
      vehicle_number TEXT,
      driver_name TEXT,
      notes TEXT,
      created_at TEXT NOT NULL
    );
    ''',
  ];

  // Index queries for high-performance searches and filtering
  static const List<String> createIndexQueries = [
    'CREATE INDEX IF NOT EXISTS idx_products_sku ON $products(sku);',
    'CREATE INDEX IF NOT EXISTS idx_products_category ON $products(category);',
    'CREATE INDEX IF NOT EXISTS idx_sales_date ON $sales(sale_date);',
    'CREATE INDEX IF NOT EXISTS idx_sales_customer ON $sales(customer_id);',
    'CREATE INDEX IF NOT EXISTS idx_purchases_date ON $purchases(purchase_date);',
    'CREATE INDEX IF NOT EXISTS idx_purchases_supplier ON $purchases(supplier_id);',
    'CREATE INDEX IF NOT EXISTS idx_payments_date ON $payments(payment_date);',
    'CREATE INDEX IF NOT EXISTS idx_payments_party ON $payments(party_type, party_id);',
    'CREATE INDEX IF NOT EXISTS idx_expenses_date ON $expenses(expense_date);',
    'CREATE INDEX IF NOT EXISTS idx_stock_movements_prod ON $stockMovements(product_id);',
    'CREATE INDEX IF NOT EXISTS idx_cust_ledger_cust ON $customerLedger(customer_id);',
    'CREATE INDEX IF NOT EXISTS idx_supp_ledger_supp ON $supplierLedger(supplier_id);',
    'CREATE INDEX IF NOT EXISTS idx_stock_cost_prod ON $stockCostLayers(product_id);',
    'CREATE INDEX IF NOT EXISTS idx_storage_stocks_storage ON $storageStocks(storage_id);',
    'CREATE INDEX IF NOT EXISTS idx_storage_stocks_prod ON $storageStocks(product_id);',
    'CREATE INDEX IF NOT EXISTS idx_stock_transfers_date ON $stockTransfers(transfer_date);',
  ];
}
