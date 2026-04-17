import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/category_icons.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/services/database_service.dart';
import '../../../../features/wallet/presentation/providers/wallet_provider.dart';
import '../../../../features/wallet/domain/entities/wallet_entity.dart';
import '../../../../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../../../../core/providers/categories_provider.dart';
import '../widgets/calculator_dialog.dart';
import '../widgets/category_picker_sheet.dart';
import '../widgets/image_source_sheet.dart';
import '../widgets/modern_priority_selector.dart';
import '../widgets/wallet_picker_sheet.dart';

// ---------------------------------------------------------------------------
// Add Income / Expense Page
// Replaces the old add_income_expense_screen.dart
// ---------------------------------------------------------------------------
class AddIncomeExpensePage extends ConsumerStatefulWidget {
  const AddIncomeExpensePage({super.key, required this.transactionType, this.initialTransaction});

  /// 'income' or 'expense'
  final String transactionType;
  final Map<String, dynamic>? initialTransaction;

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

  // New fields
  int _selectedPriority = 1; // 1: Basic, 2: Normal, 3: Ent
  bool _isRepeat = false;
  String _repeatType = 'monthly'; // daily, weekly, monthly, yearly
  bool _autoAdd = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTransaction != null) {
      final tx = widget.initialTransaction!;
      _amountCtrl.text = tx['amount'].toString();
      _noteCtrl.text = tx['notes']?.toString() ?? '';
      _selectedCategoryId = tx['category_id'] as int?;
      _selectedCategoryName = tx['category_name'] as String?;
      _selectedWalletId = tx['wallet_id'] as int?;
      if (tx['date'] != null) {
        _selectedDate = DateTime.parse(tx['date'].toString());
      }
      _imageUrl = tx['image_url'] as String?;
      _selectedPriority = tx['priority'] as int? ?? 1;
      _isRepeat = (tx['is_repeat'] as int? ?? 0) == 1;
    }
  }

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

      final wallet = ref.read(walletProvider).firstWhere((w) => w.id == _selectedWalletId);

      final transactionData = {
        'wallet_id': _selectedWalletId,
        'category_id': _selectedCategoryId ?? (_isIncome ? 5 : 11), // Default to Salary(5) or Housing(11)
        'currency_id': currency?.id ?? wallet.currencyId,
        'type': widget.transactionType,
        'direction': _isIncome ? 'plus' : 'min',
        'amount': amount,
        'date': _selectedDate.toIso8601String(),
        'is_paid': 1,
        'notes': _noteCtrl.text.trim(),
        'image_url': _imageUrl,
        'priority': _selectedPriority,
        'is_repeat': _isRepeat ? 1 : 0,
      };

      if (widget.initialTransaction != null) {
        final id = widget.initialTransaction!['id'] as int;
        final oldAmount = (widget.initialTransaction!['amount'] as num).toDouble();
        final oldWalletId = widget.initialTransaction!['wallet_id'] as int;
        
        // Revert old wallet balance
        if (_isIncome) {
          await ref.read(walletProvider.notifier).withdrawBalance(oldWalletId, oldAmount);
        } else {
          await ref.read(walletProvider.notifier).addBalance(oldWalletId, oldAmount);
        }

        await db.updateTransaction(id, transactionData);

        // Apply new wallet balance
        if (_isIncome) {
          await ref.read(walletProvider.notifier).addBalance(_selectedWalletId!, amount);
        } else {
          await ref.read(walletProvider.notifier).withdrawBalance(_selectedWalletId!, amount);
        }
      } else {
        final transactionId = await dbRaw.insert('transactions', transactionData);

        // Handle recurring transaction
        if (_isRepeat) {
          DateTime nextDate;
          switch (_repeatType) {
            case 'daily': nextDate = _selectedDate.add(const Duration(days: 1)); break;
            case 'weekly': nextDate = _selectedDate.add(const Duration(days: 7)); break;
            case 'monthly': nextDate = DateTime(_selectedDate.year, _selectedDate.month + 1, _selectedDate.day); break;
            case 'yearly': nextDate = DateTime(_selectedDate.year + 1, _selectedDate.month, _selectedDate.day); break;
            default: nextDate = _selectedDate.add(const Duration(days: 30));
          }

          await dbRaw.insert('recurring_transactions', {
            'transaction_id': transactionId,
            'start_date': _selectedDate.toIso8601String(),
            'next_execution_date': nextDate.toIso8601String(),
            'repeat_type': _repeatType,
            'is_active': 1,
            'auto_add': _autoAdd ? 1 : 0,
          });
        }

        // Update wallet balance
        if (_isIncome) {
          await ref.read(walletProvider.notifier).addBalance(_selectedWalletId!, amount);
        } else {
          await ref.read(walletProvider.notifier).withdrawBalance(_selectedWalletId!, amount);
        }
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
    final categories = await ref.read(categoriesProvider(widget.transactionType).future) as List<Map<String, dynamic>>;
    if (!mounted) return;

    final selected = await showCategoryPickerSheet(
      context,
      categories: categories,
      locale: context.locale.languageCode,
      initialParentId: _selectedCategoryId == null ? null : _getInitialParentId(categories),
    );

    if (selected != null) {
      setState(() {
        _selectedCategoryId = selected['id'];
        _selectedCategoryName = context.locale.languageCode == 'ar'
            ? (selected['name_ar'] ?? selected['name_en'])
            : selected['name_en'];
      });
    }
  }

  int? _getInitialParentId(List<Map<String, dynamic>> categories) {
    if (_selectedCategoryId == null) return null;
    try {
      final current = categories.firstWhere((c) => c['id'] == _selectedCategoryId);
      final pId = current['parent_id'] as int?;
      return (pId == 0) ? null : pId;
    } catch (_) {
      return null;
    }
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              wallets.isEmpty
                                  ? 'transaction.no_wallet'.tr()
                                  : (wallets.any((w) => w.id == _selectedWalletId)
                                      ? wallets.firstWhere((w) => w.id == _selectedWalletId).name
                                      : 'transaction.select_wallet'.tr()),
                              style: TextStyle(
                                color: _selectedWalletId != null
                                    ? cs.onSurface
                                    : cs.onSurface.withValues(alpha: 0.4),
                                fontWeight: _selectedWalletId != null ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: cs.onSurface.withValues(alpha: 0.3),
                            ),
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

                  const SizedBox(height: 12),

                  // Priority
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: ModernPrioritySelector(
                      selectedPriority: _selectedPriority,
                      onChanged: (v) => setState(() => _selectedPriority = v),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Repeat
                  FadeInUp(
                    delay: const Duration(milliseconds: 220),
                    child: _ModernRepeatSection(
                      isRepeat: _isRepeat,
                      repeatType: _repeatType,
                      autoAdd: _autoAdd,
                      onRepeatChanged: (v) => setState(() => _isRepeat = v),
                      onTypeChanged: (v) => setState(() => _repeatType = v),
                      onAutoAddChanged: (v) => setState(() => _autoAdd = v),
                    ),
                  ),
                  const SizedBox(height: 24),

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

class _ModernRepeatSection extends StatelessWidget {
  final bool isRepeat;
  final String repeatType;
  final bool autoAdd;
  final ValueChanged<bool> onRepeatChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<bool> onAutoAddChanged;

  const _ModernRepeatSection({
    required this.isRepeat,
    required this.repeatType,
    required this.autoAdd,
    required this.onRepeatChanged,
    required this.onTypeChanged,
    required this.onAutoAddChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        GestureDetector(
          onTap: () => onRepeatChanged(!isRepeat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isRepeat ? cs.primary.withOpacity(0.08) : cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (isRepeat ? cs.primary : Colors.black).withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isRepeat ? cs.primary : cs.onSurface).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.replay_rounded,
                    color: isRepeat ? cs.primary : cs.onSurface.withOpacity(0.5),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'transaction.repeat_title'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        isRepeat ? 'transaction.repeat_enabled'.tr() : 'transaction.repeat_disabled'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: isRepeat,
                  onChanged: onRepeatChanged,
                  activeColor: cs.primary,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: !isRepeat
              ? const SizedBox.shrink()
              : Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'transaction.frequency'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface.withOpacity(0.5),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FrequencyChip(
                              label: 'transaction.daily'.tr(),
                              isSelected: repeatType == 'daily',
                              onTap: () => onTypeChanged('daily'),
                            ),
                            const SizedBox(width: 8),
                            _FrequencyChip(
                              label: 'transaction.weekly'.tr(),
                              isSelected: repeatType == 'weekly',
                              onTap: () => onTypeChanged('weekly'),
                            ),
                            const SizedBox(width: 8),
                            _FrequencyChip(
                              label: 'transaction.monthly'.tr(),
                              isSelected: repeatType == 'monthly',
                              onTap: () => onTypeChanged('monthly'),
                            ),
                            const SizedBox(width: 8),
                            _FrequencyChip(
                              label: 'transaction.yearly'.tr(),
                              isSelected: repeatType == 'yearly',
                              onTap: () => onTypeChanged('yearly'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Divider(color: cs.outlineVariant.withOpacity(0.3)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'transaction.auto_add'.tr(),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'transaction.auto_add_hint'.tr(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Checkbox(
                            value: autoAdd,
                            onChanged: (v) => onAutoAddChanged(v ?? false),
                            activeColor: cs.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _FrequencyChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FrequencyChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : cs.surfaceContainerHighest.withOpacity(0.35),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: cs.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : cs.onSurface.withOpacity(0.8),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
