import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/constants/category_icons.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/services/database_service.dart';
import '../../../../features/wallet/presentation/providers/wallet_provider.dart';
import '../../../../features/wallet/domain/entities/wallet_entity.dart';
import '../../../../features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../widgets/calculator_dialog.dart';
import '../widgets/image_source_sheet.dart';

// ---------------------------------------------------------------------------
// Add Income / Expense Page
// Replaces the old add_income_expense_screen.dart
// ---------------------------------------------------------------------------
class AddIncomeExpensePage extends ConsumerStatefulWidget {
  const AddIncomeExpensePage({super.key, required this.transactionType});

  /// 'income' or 'expense'
  final String transactionType;

  @override
  ConsumerState<AddIncomeExpensePage> createState() =>
      _AddIncomeExpensePageState();
}

class _AddIncomeExpensePageState extends ConsumerState<AddIncomeExpensePage> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  int? _selectedCategoryId;
  String? _selectedCategoryName;
  int? _selectedWalletId;
  DateTime _selectedDate = DateTime.now();
  String? _imageUrl;
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _isIncome => widget.transactionType == 'income';

  Color get _typeColor =>
      _isIncome ? const Color(0xFF00C48C) : const Color(0xFFFF4757);

  IconData get _typeIcon =>
      _isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;

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

    setState(() => _saving = true);

    try {
      final currency = ref.read(defaultCurrencyProvider).valueOrNull;
      final db = DatabaseService();
      final dbRaw = await db.database;

      await dbRaw.insert('transactions', {
        'wallet_id': _selectedWalletId,
        'category_id': _selectedCategoryId ?? (_isIncome ? 5 : 1),
        'currency_id': currency?.id ?? 1,
        'type': widget.transactionType,
        'direction': _isIncome ? 'plus' : 'min',
        'amount': amount,
        'date': _selectedDate.toIso8601String(),
        'is_paid': 1,
        'notes': _noteCtrl.text.trim(),
        'image_url': _imageUrl,
      });

      // Update wallet balance
      if (_isIncome) {
        await ref.read(walletProvider.notifier).addBalance(_selectedWalletId!, amount);
      } else {
        await ref.read(walletProvider.notifier).withdrawBalance(_selectedWalletId!, amount);
      }

      if (!mounted) return;
      ref.invalidate(dashboardMetricsProvider);
      ref.invalidate(recentTransactionsProvider);

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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
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

  Future<void> _openCalculator() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => CalculatorDialog(initialValue: _amountCtrl.text),
    );

    if (result != null) {
      setState(() {
        _amountCtrl.text = result;
      });
    }
  }

  Future<void> _pickCategory() async {
    final categories = await DatabaseService()
        .getCategoriesByType(widget.transactionType);
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
        backgroundColor: _typeColor,
        foregroundColor: Colors.white,
        title: Text(
          _isIncome
              ? 'transaction.type_income'.tr()
              : 'transaction.type_expense'.tr(),
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
                  colors: [_typeColor, _typeColor.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'transaction.amount'.tr(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: '0.00',
                              hintStyle:
                                  TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                              border: InputBorder.none,
                            ),
                            cursorColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _openCalculator,
                        icon: const Icon(Icons.calculate_rounded),
                        color: Colors.white.withOpacity(0.8),
                        iconSize: 28,
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
                  // Wallet
                  FadeInUp(
                    delay: const Duration(milliseconds: 60),
                    child: _FormCard(
                      icon: Icons.account_balance_wallet_rounded,
                      color: cs.primary,
                      label: 'transaction.wallet'.tr(),
                      child: wallets.isEmpty
                          ? Text(
                              'transaction.no_wallet'.tr(),
                              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
                            )
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedWalletId,
                                isExpanded: true,
                                hint: Text('transaction.select_wallet'.tr()),
                                items: wallets
                                    .map((w) => DropdownMenuItem<int>(
                                          value: w.id,
                                          child: Text(w.name),
                                        ))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedWalletId = v),
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
                        label: 'transaction.date'.tr(),
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
                  const SizedBox(height: 12),

                  // Image Picker
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
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
                                _imageUrl == null ? 'Attach Image (Optional)' : 'Image Attached',
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

                  const SizedBox(height: 32),

                  // Save button
                  FadeInUp(
                    delay: const Duration(milliseconds: 220),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: _typeColor,
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
                            : Icon(_typeIcon, color: Colors.white),
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
