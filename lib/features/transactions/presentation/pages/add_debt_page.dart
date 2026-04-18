import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../../core/constants/category_icons.dart';
import '../../../../core/models/person_model.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/services/database_service.dart';
import '../../../../features/wallet/presentation/providers/wallet_provider.dart';
import '../../../../features/wallet/domain/entities/wallet_entity.dart';
import '../../../../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../widgets/calculator_dialog.dart';
import '../widgets/image_source_sheet.dart';
import '../widgets/two_options_selector.dart';
import '../../../../features/profile/presentation/pages/persons_page.dart';
import '../widgets/wallet_picker_sheet.dart';

// ---------------------------------------------------------------------------
// Add Debt Page
// ---------------------------------------------------------------------------
class AddDebtPage extends ConsumerStatefulWidget {
  const AddDebtPage({super.key, this.initialTransaction});
  final Map<String, dynamic>? initialTransaction;

  @override
  ConsumerState<AddDebtPage> createState() => _AddDebtPageState();
}

class _AddDebtPageState extends ConsumerState<AddDebtPage> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _personCtrl = TextEditingController();

  int? _selectedCategoryId;
  String? _selectedCategoryName;
  int? _selectedWalletId;
  DateTime _selectedDate = DateTime.now();
  String? _imageUrl;
  bool _saving = false;

  // For you (they owe me = income technically) vs On you (I owe them = expense)
  bool _isOnYou = true; 

  @override
  void initState() {
    super.initState();
    if (widget.initialTransaction != null) {
      final tx = widget.initialTransaction!;
      _amountCtrl.text = tx['amount'].toString();
      _noteCtrl.text = tx['notes']?.toString() ?? '';
      _personCtrl.text = tx['person_name']?.toString() ?? '';
      _selectedCategoryId = tx['category_id'] as int?;
      _selectedCategoryName = tx['category_name'] as String?;
      _selectedWalletId = tx['wallet_id'] as int?;
      if (tx['date'] != null) _selectedDate = DateTime.parse(tx['date'].toString());
      _imageUrl = tx['image_url'] as String?;
      _isOnYou = (tx['direction'] as String? ?? 'min') == 'min';
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _personCtrl.dispose();
    super.dispose();
  }

  Color get _themeColor => const Color(0xFF0091EA); // Deep Blue for Debt

  Future<void> _submit() async {
    final amountText = _amountCtrl.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('transaction.invalid_amount'.tr())),
      );
      return;
    }
    if (_selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('transaction.select_wallet'.tr())),
      );
      return;
    }
    if (_personCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a person name')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final db = DatabaseService();
      final dbRaw = await db.database;

      if (widget.initialTransaction != null) {
        final id = widget.initialTransaction!['id'] as int;
        final oldAmount = (widget.initialTransaction!['amount'] as num).toDouble();
        final oldWalletId = widget.initialTransaction!['wallet_id'] as int;
        // Revert old balance
        if (_isOnYou) { await ref.read(walletProvider.notifier).addBalance(oldWalletId, oldAmount); }
        else { await ref.read(walletProvider.notifier).withdrawBalance(oldWalletId, oldAmount); }
        // Update transaction
        await db.updateTransaction(id, {
          'wallet_id': _selectedWalletId,
          'category_id': _selectedCategoryId ?? 6,
          'amount': amount,
          'direction': _isOnYou ? 'min' : 'plus',
          'date': _selectedDate.toIso8601String(),
          'notes': _noteCtrl.text.trim(),
          'image_url': _imageUrl,
        });

        // Update underlying debt if exists
        final debtId = widget.initialTransaction!['debt_id'];
        if (debtId != null) {
          int personId = await _getOrCreatePerson(dbRaw, _personCtrl.text.trim());
          await dbRaw.update('debts', {
            'person_id': personId,
            'wallet_id': _selectedWalletId,
            'category_id': _selectedCategoryId ?? 6,
            'income': _isOnYou ? 0 : amount,
            'expense': _isOnYou ? amount : 0,
            'due_date': _selectedDate.toIso8601String(),
            'notes': _noteCtrl.text.trim(),
            'image_path': _imageUrl,
          }, where: 'id = ?', whereArgs: [debtId]);
        }
        // Apply new balance
        if (_isOnYou) { await ref.read(walletProvider.notifier).withdrawBalance(_selectedWalletId!, amount); }
        else { await ref.read(walletProvider.notifier).addBalance(_selectedWalletId!, amount); }
      } else {
        int personId = await _getOrCreatePerson(dbRaw, _personCtrl.text.trim());
        double income = _isOnYou ? 0 : amount;
        double expense = _isOnYou ? amount : 0;
        final debtId = await dbRaw.insert('debts', {
          'person_id': personId,
          'wallet_id': _selectedWalletId,
          'category_id': _selectedCategoryId ?? 6,
          'income': income,
          'expense': expense,
          'status': 'active',
          'due_date': _selectedDate.toIso8601String(),
          'notes': _noteCtrl.text.trim(),
          'image_path': _imageUrl,
        });
        final curr = ref.read(defaultCurrencyProvider).valueOrNull;
        await dbRaw.insert('transactions', {
          'wallet_id': _selectedWalletId,
          'category_id': _selectedCategoryId ?? 6,
          'currency_id': curr?.id ?? 1,
          'type': 'debt',
          'direction': _isOnYou ? 'min' : 'plus',
          'amount': amount,
          'date': _selectedDate.toIso8601String(),
          'is_paid': 1,
          'notes': _noteCtrl.text.trim(),
          'image_url': _imageUrl,
          'debt_id': debtId,
          'person_id': personId,
          'person_name': _personCtrl.text.trim(),
        });
        if (_isOnYou) { await ref.read(walletProvider.notifier).withdrawBalance(_selectedWalletId!, amount); }
        else { await ref.read(walletProvider.notifier).addBalance(_selectedWalletId!, amount); }
      }

      if (!mounted) return;
      ref.invalidate(dashboardMetricsProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(allTransactionsProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('transaction.saved'.tr()),
          backgroundColor: const Color(0xFF00C48C),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<int> _getOrCreatePerson(dbRaw, String name) async {
    final list = await dbRaw.query('persons', where: 'name = ?', whereArgs: [name]);
    if (list.isNotEmpty) return list.first['id'] as int;
    return await dbRaw.insert('persons', {'name': name});
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickContact() async {
    final person = await Navigator.push<Person>(
      context,
      MaterialPageRoute(builder: (_) => const PersonsPage(isPicker: true)),
    );
    if (person != null) {
      setState(() {
        _personCtrl.text = person.name;
      });
    }
  }

  Future<void> _openCalculator() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => CalculatorDialog(initialValue: _amountCtrl.text),
    );
    if (result != null) {
      setState(() => _amountCtrl.text = result);
    }
  }

  Future<void> _pickImage() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const ImageSourceSheet(),
    );
    if (source == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);
      if (picked != null) setState(() => _imageUrl = picked.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _pickCategory() async {
    final categories = await DatabaseService().getCategoriesByType('debt');
    if (!mounted) return;
    final locale = context.locale.languageCode;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CategoryPickerSheet(
        categories: categories,
        locale: locale,
        onSelected: (id, name) {
          setState(() {
            _selectedCategoryId = id;
            _selectedCategoryName = name;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sym = ref.watch(currencySymbolProvider);
    final wallets = ref.watch(walletProvider);
    final dateStr = DateFormat('EEE, d MMM yyyy').format(_selectedDate);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: _themeColor,
        foregroundColor: Colors.white,
        title: Text(
          widget.initialTransaction != null ? 'Edit Debt' : 'dashboard.debt'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // ── Amount hero ──────────────────────────────────────────────────
          FadeInDown(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_themeColor, _themeColor.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  TwoOptionsSelector(
                    isLeftSelected: _isOnYou,
                    leftLabel: 'dashboard.on_you'.tr(),
                    rightLabel: 'dashboard.for_you'.tr(),
                    onChanged: (isLeft) => setState(() => _isOnYou = isLeft),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        sym,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: IntrinsicWidth(
                          child: TextField(
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: '0.00',
                              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                              border: InputBorder.none,
                            ),
                            cursorColor: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _openCalculator,
                        icon: const Icon(Icons.calculate_rounded, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Form fields ──────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Person Name
                  FadeInUp(
                    delay: const Duration(milliseconds: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4081).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Color(0xFFFF4081),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _personCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Person Name',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _pickContact,
                            icon: Icon(Icons.person_add_rounded, color: cs.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Wallet
                  FadeInUp(
                    delay: const Duration(milliseconds: 60),
                    child: GestureDetector(
                      onTap: () async {
                        final wallet = await showWalletPickerSheet(context, ref, selectedId: _selectedWalletId);
                        if (wallet != null) {
                          setState(() => _selectedWalletId = wallet.id);
                        }
                      },
                      child: _FormCard(
                        icon: Icons.account_balance_wallet_rounded,
                        color: cs.primary,
                        label: 'transaction.wallet'.tr(),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedWalletId == null
                                    ? 'transaction.select_wallet'.tr()
                                    : wallets.firstWhere((w) => w.id == _selectedWalletId).name,
                                style: TextStyle(
                                  color: _selectedWalletId == null ? cs.onSurface.withOpacity(0.5) : cs.onSurface,
                                  fontWeight: _selectedWalletId == null ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_down_rounded, color: cs.onSurface.withOpacity(0.3)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category
                  FadeInUp(
                    delay: const Duration(milliseconds: 100),
                    child: GestureDetector(
                      onTap: _pickCategory,
                      child: _FormCard(
                        icon: Icons.category_rounded,
                        color: const Color(0xFF9B5DE5),
                        label: 'transaction.category'.tr(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedCategoryName ??
                                  'transaction.select_category'.tr(),
                              style: TextStyle(
                                color: _selectedCategoryName != null
                                    ? cs.onSurface
                                    : cs.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: cs.onSurface.withValues(alpha: 0.3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Date
                  FadeInUp(
                    delay: const Duration(milliseconds: 140),
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: _FormCard(
                        icon: Icons.calendar_today_rounded,
                        color: const Color(0xFF4ECDC4),
                        label: 'Due Date',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(dateStr),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: cs.onSurface.withValues(alpha: 0.3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Image Picker
                  FadeInUp(
                    delay: const Duration(milliseconds: 160),
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _imageUrl == null ? cs.surfaceContainerLow : cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: _imageUrl == null ? Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.5),
                            style: BorderStyle.none,
                          ) : Border.all(color: cs.primary),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (_imageUrl == null ? cs.onSurface : cs.primary).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.image_rounded,
                                color: _imageUrl == null ? cs.onSurface.withValues(alpha: 0.5) : cs.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _imageUrl == null ? 'Attach Receipt (Optional)' : 'Image Attached',
                                style: TextStyle(
                                  color: _imageUrl == null ? cs.onSurface.withValues(alpha: 0.5) : cs.primary,
                                  fontWeight: _imageUrl == null ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                            ),
                            if (_imageUrl != null)
                              GestureDetector(
                                onTap: () => setState(() => _imageUrl = null),
                                child: Icon(Icons.close_rounded, color: cs.primary, size: 20),
                              )
                            else
                              Icon(Icons.add_a_photo_rounded, color: cs.onSurface.withValues(alpha: 0.3), size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Note
                  FadeInUp(
                    delay: const Duration(milliseconds: 180),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFBE0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.notes_rounded,
                              color: Color(0xFFFFBE0B),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _noteCtrl,
                              decoration: InputDecoration(
                                hintText: 'transaction.note_hint'.tr(),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Save button
                  FadeInUp(
                    delay: const Duration(milliseconds: 220),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: _themeColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_rounded, color: Colors.white),
                        label: Text(
                          'common.save'.tr(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({required String label, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? _themeColor : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable form card row
// ---------------------------------------------------------------------------
class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final Color color;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category picker bottom sheet
// ---------------------------------------------------------------------------
class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({
    required this.categories,
    required this.locale,
    required this.onSelected,
  });

  final List<Map<String, dynamic>> categories;
  final String locale;
  final void Function(int id, String name) onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'transaction.select_category'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (categories.isEmpty)
            Padding(
               padding: const EdgeInsets.all(24),
              child: Text(
                'categories.empty'.tr(),
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
              ),
            )
          else
            SizedBox(
              height: 300,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.8,
                ),
                itemCount: categories.length,
                itemBuilder: (_, i) {
                  final cat = categories[i];
                  final nameEn = cat['name_en'] as String? ?? '';
                  final displayName = locale == 'ar'
                      ? (cat['name_ar'] as String? ?? nameEn)
                      : nameEn;
                  final icon = CategoryIcons.getIcon(nameEn);
                  final color = CategoryIcons.getColor(nameEn);
                  return GestureDetector(
                    onTap: () {
                      onSelected(cat['id'] as int, displayName);
                      Navigator.of(context).pop();
                    },
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: color, size: 22),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          displayName,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: cs.onSurface),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
