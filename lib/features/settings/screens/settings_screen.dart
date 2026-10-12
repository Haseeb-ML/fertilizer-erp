import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/localization/language_selection_dialog.dart';
import '../../../core/models/business_settings.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/validators.dart';
import 'backup_restore_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _businessNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _ntnController;
  late TextEditingController _invPrefixController;
  late TextEditingController _purPrefixController;
  late TextEditingController _initialCashController;
  late TextEditingController _pinController;

  bool _isPinEnabled = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await ref.read(settingsRepoProvider).getSettings();
    _businessNameController = TextEditingController(
      text: settings.businessName,
    );
    _ownerNameController = TextEditingController(text: settings.ownerName);
    _phoneController = TextEditingController(text: settings.phone);
    _addressController = TextEditingController(text: settings.address);
    _cityController = TextEditingController(text: settings.city);
    _ntnController = TextEditingController(text: settings.ntnStrn);
    _invPrefixController = TextEditingController(text: settings.invoicePrefix);
    _purPrefixController = TextEditingController(text: settings.purchasePrefix);
    _initialCashController = TextEditingController(
      text: settings.initialCashBalance.toStringAsFixed(0),
    );
    _pinController = TextEditingController(text: settings.pinCode);
    _isPinEnabled = settings.isPinEnabled;

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _ntnController.dispose();
    _invPrefixController.dispose();
    _purPrefixController.dispose();
    _initialCashController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final initialCash =
        double.tryParse(_initialCashController.text.trim()) ?? 0.0;
    final now = DateTime.now().toIso8601String();

    final settings = BusinessSettings(
      id: 1,
      businessName: _businessNameController.text.trim(),
      ownerName: _ownerNameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      ntnStrn: _ntnController.text.trim(),
      invoicePrefix: _invPrefixController.text.trim(),
      purchasePrefix: _purPrefixController.text.trim(),
      currencySymbol: '₨',
      pinCode: _pinController.text.trim(),
      isPinEnabled: _isPinEnabled,
      initialCashBalance: initialCash,
      updatedAt: now,
    );

    try {
      await ref.read(settingsRepoProvider).updateSettings(settings);
      ref.invalidate(businessSettingsProvider);

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Business Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Business Details Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  'assets/images/app_logo.png',
                                  width: 84,
                                  height: 84,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.business,
                                    size: 64,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Official Business Logo',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                        const Text(
                          'Agency & Shop Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _businessNameController,
                          decoration: const InputDecoration(
                            labelText: 'Business / Agency Name *',
                            prefixIcon: Icon(Icons.store),
                          ),
                          validator: (v) => Validators.requiredField(
                            v,
                            'Enter business name',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _ownerNameController,
                          decoration: const InputDecoration(
                            labelText: 'Owner / Proprietor Name',
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Phone Number',
                                  prefixIcon: Icon(Icons.phone),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _cityController,
                                decoration: const InputDecoration(
                                  labelText: 'City / Mandi',
                                  prefixIcon: Icon(Icons.location_city),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Shop / Warehouse Address',
                            prefixIcon: Icon(Icons.location_on),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _ntnController,
                          decoration: const InputDecoration(
                            labelText:
                                'NTN / STRN / Sales Tax Reg No (Optional)',
                            prefixIcon: Icon(Icons.badge),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Invoicing & Preferences Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Invoicing & Initial Cash',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _invPrefixController,
                                decoration: const InputDecoration(
                                  labelText: 'Sales Prefix',
                                  prefixIcon: Icon(Icons.receipt),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _purPrefixController,
                                decoration: const InputDecoration(
                                  labelText: 'Purchase Prefix',
                                  prefixIcon: Icon(Icons.shopping_bag),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _initialCashController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Initial Cash in Hand (PKR)',
                            hintText: 'Starting cash balance for cashbook',
                            prefixIcon: Icon(Icons.account_balance_wallet),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Security & PIN Lock Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Security & Lock',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Enable Security PIN Lock'),
                          subtitle: const Text(
                            'Requires 4-digit PIN on app resume/settings',
                          ),
                          value: _isPinEnabled,
                          activeColor: AppColors.primary,
                          onChanged: (val) =>
                              setState(() => _isPinEnabled = val),
                        ),
                        if (_isPinEnabled) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _pinController,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            maxLength: 6,
                            decoration: const InputDecoration(
                              labelText: 'Security PIN (4-6 Digits)',
                              prefixIcon: Icon(Icons.lock),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // App Language Selection Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.language, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  ref.tr('app_language'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: () => showLanguageSelectionDialog(context, ref),
                              icon: const Icon(Icons.swap_horiz, size: 18),
                              label: Text(ref.watch(languageProvider) == 'ur' ? 'اردو' : 'English'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => ref.read(languageProvider.notifier).setLanguage('en'),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: ref.watch(languageProvider) == 'en'
                                        ? AppColors.primary.withOpacity(0.1)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: ref.watch(languageProvider) == 'en'
                                          ? AppColors.primary
                                          : Colors.grey.shade300,
                                      width: ref.watch(languageProvider) == 'en' ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('🇬🇧 ', style: TextStyle(fontSize: 18)),
                                      Text(
                                        'English',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: ref.watch(languageProvider) == 'en'
                                              ? AppColors.primary
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => ref.read(languageProvider.notifier).setLanguage('ur'),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: ref.watch(languageProvider) == 'ur'
                                        ? AppColors.primary.withOpacity(0.1)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: ref.watch(languageProvider) == 'ur'
                                          ? AppColors.primary
                                          : Colors.grey.shade300,
                                      width: ref.watch(languageProvider) == 'ur' ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('🇵🇰 ', style: TextStyle(fontSize: 18)),
                                      Text(
                                        'اردو',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: ref.watch(languageProvider) == 'ur'
                                              ? AppColors.primary
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Backup & Restore Navigation Card
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.infoBg,
                      child: Icon(Icons.backup, color: AppColors.info),
                    ),
                    title: const Text(
                      'Database Backup & Restore',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Export JSON backups or restore previous data',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BackupRestoreScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isSaving ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Save Settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
