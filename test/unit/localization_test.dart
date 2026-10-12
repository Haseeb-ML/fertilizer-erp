import 'package:flutter_test/flutter_test.dart';
import 'package:fertilizer/core/localization/app_translations.dart';
import 'package:fertilizer/core/localization/language_provider.dart';

void main() {
  group('Localization & Bilingual Translation Tests', () {
    test('English translations provide correct business strings', () {
      expect(AppTranslations.translate('app_title', 'en'), 'Fertilizer Business ERP');
      expect(AppTranslations.translate('nav_dashboard', 'en'), 'Dashboard');
      expect(AppTranslations.translate('nav_sales', 'en'), 'Sales');
      expect(AppTranslations.translate('nav_inventory', 'en'), 'Inventory');
      expect(AppTranslations.translate('nav_more', 'en'), 'More');
      expect(AppTranslations.translate('todays_sales', 'en'), "Today's Sales");
      expect(AppTranslations.translate('customer_receivables', 'en'), 'Customer Receivables');
      expect(AppTranslations.translate('supplier_payables', 'en'), 'Supplier Payables');
    });

    test('Urdu translations provide authentic agricultural & ERP Urdu strings', () {
      expect(AppTranslations.translate('app_title', 'ur'), 'کھاد بزنس ای آر پی');
      expect(AppTranslations.translate('nav_dashboard', 'ur'), 'ڈیش بورڈ');
      expect(AppTranslations.translate('nav_sales', 'ur'), 'فروخت');
      expect(AppTranslations.translate('nav_inventory', 'ur'), 'اسٹاک و کھاد');
      expect(AppTranslations.translate('nav_more', 'ur'), 'مزید مینیو');
      expect(AppTranslations.translate('todays_sales', 'ur'), 'آج کی کل فروخت');
      expect(AppTranslations.translate('customer_receivables', 'ur'), 'گاہکوں سے واجب الوصول');
      expect(AppTranslations.translate('supplier_payables', 'ur'), 'کمپنیوں کو واجب الادا');
      expect(AppTranslations.translate('cashbook_title', 'ur'), 'روزنامچہ روکڑ (کیش بک)');
      expect(AppTranslations.translate('unloading_hammali', 'ur'), 'پلے داری / حمّالی');
    });

    test('Translation fallback returns key when not found', () {
      expect(AppTranslations.translate('non_existent_key_xyz', 'en'), 'non_existent_key_xyz');
      expect(AppTranslations.translate('non_existent_key_xyz', 'ur'), 'non_existent_key_xyz');
    });

    test('LanguageNotifier switches between English and Urdu', () async {
      final notifier = LanguageNotifier();
      expect(notifier.state, 'en');

      await notifier.setLanguage('ur');
      expect(notifier.state, 'ur');

      await notifier.toggleLanguage();
      expect(notifier.state, 'en');

      await notifier.toggleLanguage();
      expect(notifier.state, 'ur');
    });
  });
}
