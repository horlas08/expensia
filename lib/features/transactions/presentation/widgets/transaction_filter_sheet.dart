import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/services/database_service.dart';
import '../providers/transaction_filter_provider.dart';

// ── Quick selection data ─────────────────────────────────────────────────────

const _types = [
  ('transaction', Icons.receipt_long_rounded, 'Transaction'),
  ('transfer', Icons.swap_horiz_rounded, 'Transfer'),
  ('debt', Icons.handshake_rounded, 'Debt'),
  ('installment', Icons.credit_card_rounded, 'Installment'),
];

const _typeColors = {
  'transaction': Colors.blue,
  'transfer': Colors.teal,
  'debt': Colors.orange,
  'installment': Colors.purple,
};

// ── Sheet Entry Point ────────────────────────────────────────────────────────

class TransactionFilterSheet extends ConsumerStatefulWidget {
  const TransactionFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TransactionFilterSheet(),
    );
  }

  @override
  ConsumerState<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends ConsumerState<TransactionFilterSheet> {
  // Local working copy of the filter — applied only on "Apply"
  late TransactionFilter _draft;

  List<Map<String, dynamic>> _wallets = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _persons = [];
  bool _loadingMeta = true;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(transactionFilterProvider);
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final db = DatabaseService();
    final wallets = await db.getWallets();
    final allCats = await db.getCategoriesByType('expense');
    final incomeCats = await db.getCategoriesByType('income');
    final persons = await db.getPersons();

    if (mounted) {
      setState(() {
        _wallets = wallets;
        _categories = [...allCats, ...incomeCats];
        _persons = persons;
        _loadingMeta = false;
      });
    }
  }

  void _apply() {
    ref.read(transactionFilterProvider.notifier)
      ..setType(_draft.type)
      ..setDirection(_draft.direction)
      ..setCategory(_draft.categoryId, _draft.categoryName)
      ..setWallet(_draft.walletId, _draft.walletName)
      ..setPerson(_draft.personId, _draft.personName)
      ..setFromDate(_draft.fromDate)
      ..setToDate(_draft.toDate)
      ..setIsPaid(_draft.isPaid);
    Navigator.pop(context);
  }

  void _reset() {
    setState(() => _draft = TransactionFilter.empty);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showDirection = _draft.type == null ||
        _draft.type == 'transaction' ||
        _draft.type == 'debt';
    final showPersonFilter = _draft.type == 'debt' || _draft.type == 'installment';
    final showCategoryFilter = _draft.type == null || _draft.type == 'transaction';

    return Material(
      color: Colors.transparent,
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Material(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // ── HANDLE BAR ────────────────────────────────────────────
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),

              // ── HEADER ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.tune_rounded, color: cs.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'history.filter_title'.tr(),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _draft.isEmpty
                                ? 'history.no_filters'.tr()
                                : '${_draft.activeCount} ${'history.filters_active'.tr()}',
                            style: TextStyle(
                              fontSize: 13,
                              color: _draft.isEmpty ? cs.onSurfaceVariant : cs.primary,
                              fontWeight: _draft.isEmpty ? FontWeight.normal : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_draft.isEmpty)
                      TextButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text('history.reset'.tr()),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // ── SCROLL CONTENT ────────────────────────────────────────
              Expanded(
                child: _loadingMeta
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        children: [

                          // ── TYPE SECTION ──────────────────────────────
                          _SectionHeader(
                            icon: Icons.category_rounded,
                            label: 'history.filter_type'.tr(),
                          ),
                          const SizedBox(height: 12),
                          FadeInLeft(
                            duration: const Duration(milliseconds: 300),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _types.map((t) {
                                final selected = _draft.type == t.$1;
                                final color = _typeColors[t.$1] ?? cs.primary;
                                return _FilterChip(
                                  label: t.$3,
                                  icon: t.$2,
                                  selected: selected,
                                  accentColor: color,
                                  onTap: () => setState(() {
                                    _draft = _draft.copyWith(
                                      type: selected ? null : t.$1,
                                      // reset direction when type changes
                                      direction: null,
                                      categoryId: null,
                                      categoryName: null,
                                    );
                                  }),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── DIRECTION SECTION ─────────────────────────
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: showDirection
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _SectionHeader(
                                        icon: Icons.swap_vert_rounded,
                                        label: 'history.filter_direction'.tr(),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _DirectionCard(
                                              label: 'categories.income'.tr(),
                                              icon: Icons.arrow_downward_rounded,
                                              color: Colors.green,
                                              selected: _draft.direction == 'plus',
                                              onTap: () => setState(() {
                                                _draft = _draft.copyWith(
                                                  direction: _draft.direction == 'plus' ? null : 'plus',
                                                );
                                              }),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _DirectionCard(
                                              label: 'categories.expense'.tr(),
                                              icon: Icons.arrow_upward_rounded,
                                              color: Colors.red,
                                              selected: _draft.direction == 'min',
                                              onTap: () => setState(() {
                                                _draft = _draft.copyWith(
                                                  direction: _draft.direction == 'min' ? null : 'min',
                                                );
                                              }),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),

                          // ── CATEGORY SECTION ──────────────────────────
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: showCategoryFilter
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _SectionHeader(
                                        icon: Icons.label_outline_rounded,
                                        label: 'profile.categories'.tr(),
                                      ),
                                      const SizedBox(height: 12),
                                      _DropdownSelector(
                                        hint: 'history.all_categories'.tr(),
                                        value: _draft.categoryName,
                                        icon: Icons.label_outline_rounded,
                                        onTap: () => _showListPicker(
                                          context,
                                          title: 'profile.categories'.tr(),
                                          items: _categories
                                              .map((c) => _PickerItem(
                                                    id: c['id'] as int,
                                                    name: c['name_en'] as String? ?? '',
                                                    icon: Icons.label_rounded,
                                                  ))
                                              .toList(),
                                          selected: _draft.categoryId,
                                          onSelect: (id, name) => setState(() {
                                            _draft = _draft.copyWith(categoryId: id, categoryName: name);
                                          }),
                                          onClear: () => setState(() {
                                            _draft = _draft.copyWith(categoryId: null, categoryName: null);
                                          }),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),

                          // ── WALLET SECTION ────────────────────────────
                          _SectionHeader(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'profile.wallets'.tr(),
                          ),
                          const SizedBox(height: 12),
                          _DropdownSelector(
                            hint: 'history.all_wallets'.tr(),
                            value: _draft.walletName,
                            icon: Icons.account_balance_wallet_outlined,
                            onTap: () => _showListPicker(
                              context,
                              title: 'profile.wallets'.tr(),
                              items: _wallets
                                  .map((w) => _PickerItem(
                                        id: w['id'] as int,
                                        name: w['name'] as String? ?? '',
                                        icon: Icons.account_balance_wallet_rounded,
                                      ))
                                  .toList(),
                              selected: _draft.walletId,
                              onSelect: (id, name) => setState(() {
                                _draft = _draft.copyWith(walletId: id, walletName: name);
                              }),
                              onClear: () => setState(() {
                                _draft = _draft.copyWith(walletId: null, walletName: null);
                              }),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── PERSON SECTION ────────────────────────────
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: showPersonFilter
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _SectionHeader(
                                        icon: Icons.person_outline_rounded,
                                        label: 'profile.persons'.tr(),
                                      ),
                                      const SizedBox(height: 12),
                                      _DropdownSelector(
                                        hint: 'history.all_persons'.tr(),
                                        value: _draft.personName,
                                        icon: Icons.person_outline_rounded,
                                        onTap: () => _showListPicker(
                                          context,
                                          title: 'profile.persons'.tr(),
                                          items: _persons
                                              .map((p) => _PickerItem(
                                                    id: p['id'] as int,
                                                    name: p['name'] as String? ?? '',
                                                    icon: Icons.person_rounded,
                                                  ))
                                              .toList(),
                                          selected: _draft.personId,
                                          onSelect: (id, name) => setState(() {
                                            _draft = _draft.copyWith(personId: id, personName: name);
                                          }),
                                          onClear: () => setState(() {
                                            _draft = _draft.copyWith(personId: null, personName: null);
                                          }),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),

                          // ── DATE RANGE ────────────────────────────────
                          _SectionHeader(
                            icon: Icons.date_range_rounded,
                            label: 'history.filter_date_range'.tr(),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _DatePickerCard(
                                  label: 'history.from'.tr(),
                                  date: _draft.fromDate,
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _draft.fromDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) {
                                      setState(() => _draft = _draft.copyWith(fromDate: picked));
                                    }
                                  },
                                  onClear: () => setState(() => _draft = _draft.copyWith(fromDate: null)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('—', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 18)),
                              ),
                              Expanded(
                                child: _DatePickerCard(
                                  label: 'history.to'.tr(),
                                  date: _draft.toDate,
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _draft.toDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setState(() => _draft = _draft.copyWith(toDate: picked));
                                    }
                                  },
                                  onClear: () => setState(() => _draft = _draft.copyWith(toDate: null)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 100), // bottom padding for FAB
                        ],
                      ),
              ),

              // ── APPLY BUTTON ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(
                    top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2)),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: Text(
                      'history.apply_filter'.tr(),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showListPicker(
    BuildContext context, {
    required String title,
    required List<_PickerItem> items,
    required int? selected,
    required void Function(int id, String name) onSelect,
    required VoidCallback onClear,
  }) async {
    final cs = Theme.of(context).colorScheme;

    await showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (selected != null)
              TextButton.icon(
                onPressed: () {
                  onClear();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close_rounded, size: 16),
                label: Text('history.clear_selection'.tr()),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: EdgeInsets.zero,
                ),
              ),
            const SizedBox(height: 8),
            ...items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: cs.primary, size: 18),
                ),
                title: Text(item.name),
                trailing: selected == item.id
                    ? Icon(Icons.check_circle_rounded, color: cs.primary)
                    : null,
                onTap: () {
                  onSelect(item.id, item.name);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

// ── Reusable Sub-widgets ─────────────────────────────────────────────────────

class _PickerItem {
  final int id;
  final String name;
  final IconData icon;
  const _PickerItem({required this.id, required this.name, required this.icon});
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: cs.onSurface,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accentColor : accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected ? accentColor : accentColor.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : accentColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : accentColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _DirectionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? Colors.white : color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownSelector extends StatelessWidget {
  final String hint;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;

  const _DropdownSelector({
    required this.hint,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = value != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary.withValues(alpha: 0.07) : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? cs.primary.withValues(alpha: 0.4) : cs.outlineVariant.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value ?? hint,
                style: TextStyle(
                  color: isSelected ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePickerCard extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DatePickerCard({
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasDate = date != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: hasDate ? cs.primary.withValues(alpha: 0.07) : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasDate ? cs.primary.withValues(alpha: 0.4) : cs.outlineVariant.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: hasDate ? cs.primary : cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: hasDate ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasDate ? DateFormat('MMM dd, yy').format(date!) : '—',
                    style: TextStyle(
                      color: hasDate ? cs.primary : cs.onSurfaceVariant,
                      fontWeight: hasDate ? FontWeight.w700 : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (hasDate)
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(Icons.close_rounded, size: 15, color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
