class AppConstants {
  static const String appName = 'Fertilizer Business ERP';
  static const String appVersion = '1.0.0';
  static const String currencySymbol = '₨';
  static const String currencyCode = 'PKR';

  // Fertilizer & Feed Product Categories
  static const List<String> fertilizerCategories = [
    'Cattle Feed / Vanda (وانڈا)',
    'Urea',
    'DAP (Di-Ammonium Phosphate)',
    'NP (NitroPhos)',
    'SOP / Potash',
    'CAN (Calcium Ammonium Nitrate)',
    'SSP (Single Super Phosphate)',
    'Zinc & Micronutrients',
    'Bio / Organic Fertilizer',
    'Pesticides & Spray',
    'Hybrid Seeds',
    'Other Agritech',
  ];

  // Common Brands in Pakistan
  static const List<String> popularBrands = [
    'Kissan Feeds',
    'Engro Fertilizers',
    'FFC (Fauji Fertilizer Company)',
    'Fatima Fertilizer',
    'Agritech (Tara)',
    'Pak-Arab Fertilizers',
    'National Fertilizer Marketing (NFML)',
    'Syngenta',
    'Bayer',
    'Ali Akbar Group',
    'Imported / Other',
  ];

  // Common Units of Measurement
  static const List<String> unitsOfMeasurement = [
    'Bag (40 Kg)',
    'Bag (50 Kg)',
    'Bag (25 Kg)',
    'Bag (10 Kg)',
    'Kg',
    'Liter (L)',
    'Milliliter (ml)',
    'Bottle',
    'Carton / Box',
    'Packet',
  ];

  // Payment Methods
  static const List<String> paymentMethods = [
    'Cash',
    'Bank Transfer',
    'Cheque',
    'JazzCash / EasyPaisa',
  ];

  // Expense Categories
  static const List<String> expenseCategories = [
    'Transport / Freight (Kiraya)',
    'Loading & Unloading (Muzdoori/Hammali)',
    'Shop Rent',
    'Electricity / Utilities',
    'Shop & Warehouse Maintenance',
    'Staff Refreshment / Tea',
    'Labor / Daily Wages',
    'Taxes / Levies',
    'Stationery & Office Supplies',
    'Miscellaneous',
  ];

  // Stock Adjustment Reasons
  static const List<String> stockAdjustmentReasons = [
    'Damaged / Burst Bags',
    'Stock Audit Correction',
    'Moisture / Spoilage Loss',
    'Theft / Shortage',
    'Customer Return Without Invoice',
    'Sample / Promotion Given',
    'Found Excess Stock',
  ];
}
