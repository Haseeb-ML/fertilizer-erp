import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/models/storage.dart';
import '../../../core/providers/app_providers.dart';

class StorageFormScreen extends ConsumerStatefulWidget {
  final Storage? storage;

  const StorageFormScreen({super.key, this.storage});

  @override
  ConsumerState<StorageFormScreen> createState() => _StorageFormScreenState();
}

class _StorageFormScreenState extends ConsumerState<StorageFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _locationController;
  late TextEditingController _inchargeController;
  late TextEditingController _contactController;
  late TextEditingController _capacityController;
  bool _isDefault = false;
  bool _isActive = true;
  bool _isSaving = false;

  bool get isEdit => widget.storage != null;

  @override
  void initState() {
    super.initState();
    final s = widget.storage;
    _nameController = TextEditingController(text: s?.name ?? '');
    _codeController = TextEditingController(text: s?.code ?? '');
    _locationController = TextEditingController(text: s?.location ?? '');
    _inchargeController = TextEditingController(text: s?.inchargeName ?? '');
    _contactController = TextEditingController(text: s?.contactNumber ?? '');
    _capacityController = TextEditingController(
      text: s != null && s.capacityBags > 0 ? s.capacityBags.toString() : '',
    );
    _isDefault = s?.isDefault ?? false;
    _isActive = s?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _locationController.dispose();
    _inchargeController.dispose();
    _contactController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final repo = ref.read(storageRepoProvider);
    final now = DateTime.now().toIso8601String();

    try {
      final capacity = int.tryParse(_capacityController.text.trim()) ?? 0;
      final storageToSave = Storage(
        id: widget.storage?.id,
        name: _nameController.text.trim(),
        code: _codeController.text.trim(),
        location: _locationController.text.trim(),
        inchargeName: _inchargeController.text.trim(),
        contactNumber: _contactController.text.trim(),
        capacityBags: capacity,
        isDefault: _isDefault,
        isActive: _isActive,
        createdAt: widget.storage?.createdAt ?? now,
        updatedAt: now,
      );

      if (isEdit) {
        await repo.updateStorage(storageToSave);
      } else {
        await repo.insertStorage(storageToSave);
      }

      ref.read(storagesUpdateTriggerProvider.notifier).state++;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? 'Storage updated successfully / گودام محفوظ ہو گیا'
                  : 'New Storage added / نیا گودام شامل ہو گیا',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteStorage() async {
    final s = widget.storage;
    if (s == null || s.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Delete Storage (گودام ختم کریں)'),
          ],
        ),
        content: Text('Are you sure you want to delete "${s.name}"?\n(کیا آپ واقعی اس گودام کو ڈیلیٹ کرنا چاہتے ہیں؟)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel / منسوخ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete / ڈیلیٹ کریں'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(storageRepoProvider);
      await repo.deleteStorage(s.id!);
      ref.read(storagesUpdateTriggerProvider.notifier).state++;
      ref.read(productsUpdateTriggerProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Storage "${s.name}" deleted / گودام حذف ہو گیا'),
            backgroundColor: AppColors.danger,
          ),
        );
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = isEdit ? 'Edit Storage (گودام میں ترمیم)' : 'Add Godown / Storage (نیا گودام)';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete Storage (گودام ختم کریں)',
              onPressed: _deleteStorage,
            ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: ref.tr('save'),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Storage / Godown Name * (گودام کا نام)',
                          hintText: 'e.g. Main Godown, Ada Godown, Shop',
                          prefixIcon: Icon(Icons.warehouse),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter storage name / نام درج کریں';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'Storage Code (کوڈ نمبر)',
                          hintText: 'e.g. GDN-01, SHP-01',
                          prefixIcon: Icon(Icons.qr_code),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location / Address (پتہ یا مقام)',
                          hintText: 'e.g. Bypass Road, Grain Market',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _inchargeController,
                        decoration: const InputDecoration(
                          labelText: 'In-Charge Person (انچارج بندہ)',
                          hintText: 'Name of supervisor or munshi',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _contactController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Contact Number (موبائل نمبر)',
                          hintText: 'e.g. 0300-1234567',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _capacityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Storage Capacity (گنجائش - بوریاں)',
                          hintText: 'e.g. 5000 Bags',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                          suffixText: 'Bags',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text(
                          'Primary / Default Storage (مرکزی گودام)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: const Text(
                          'Standard storage for incoming stock & sales',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        value: _isDefault,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => _isDefault = val),
                      ),
                      if (isEdit) ...[
                        const Divider(),
                        SwitchListTile(
                          title: const Text(
                            'Active Status (فعال گودام)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: const Text(
                            'Deactivate if this godown is closed',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          value: _isActive,
                          activeColor: AppColors.success,
                          onChanged: (val) => setState(() => _isActive = val),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  isEdit ? 'Update Storage (محفوظ کریں)' : 'Save Storage (محفوظ کریں)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isSaving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
