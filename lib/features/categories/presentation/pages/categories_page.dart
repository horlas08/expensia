import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:animate_do/animate_do.dart' ;
import '../../../../core/providers/categories_provider.dart';
import '../../../../core/constants/category_icons.dart';
import '../../../../core/services/database_service.dart';

// ---------------------------------------------------------------------------
// Categories Page — 3 tabs: Expense / Income / Debt
// ---------------------------------------------------------------------------
class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = ['expense', 'income', 'debt'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        title: Text(
          'profile.categories'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(text: 'categories.expense'.tr()),
            Tab(text: 'categories.income'.tr()),
            Tab(text: 'categories.debt'.tr()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategorySheet(context),
        backgroundColor: cs.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'categories.add'.tr(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs
            .map((type) => _CategoryTabView(type: type))
            .toList(),
      ),
    );
  }

  void _showAddCategorySheet(BuildContext context) {
    final currentType = _tabs[_tabController.index];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryFormSheet(
        type: currentType,
        onSaved: () {
          // Invalidate providers to refresh all tabs
          for (final t in _tabs) {
            ref.invalidate(categoriesProvider(t));
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single tab body
// ---------------------------------------------------------------------------
class _CategoryTabView extends ConsumerStatefulWidget {
  const _CategoryTabView({required this.type});
  final String type;

  @override
  ConsumerState<_CategoryTabView> createState() => _CategoryTabViewState();
}

class _CategoryTabViewState extends ConsumerState<_CategoryTabView> {
  int? _activeParentId;
  String? _activeParentName;

  @override
  Widget build(BuildContext context) {
    // We'll load ALL categories for this type and filter in memory for better UX responsiveness
    final async = ref.watch(categoriesProvider(widget.type));
    final cs = Theme.of(context).colorScheme;

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (allCategories) {
        final filtered = allCategories.where((c) {
          final pId = c['parent_id'] as int?;
          return (_activeParentId == null) 
              ? (pId == null || pId == 0) 
              : (pId == _activeParentId);
        }).toList();

        if (allCategories.isEmpty) {
          return _EmptyCategoryState(type: widget.type);
        }

        return Column(
          children: [
            if (_activeParentId != null)
              FadeInDown(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: cs.primary.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => setState(() {
                          _activeParentId = null;
                          _activeParentName = null;
                        }),
                        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: cs.primary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _activeParentName ?? 'profile.categories'.tr(),
                        style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final category = filtered[i];
                  final catId = category['id'] as int;
                  final hasChildren = allCategories.any((c) => c['parent_id'] == catId);
                  final locale = context.locale.languageCode;
                  final displayName = locale == 'ar' ? category['name_ar'] : category['name_en'];

                  return FadeInUp(
                    delay: Duration(milliseconds: 30 * i),
                    child: _CategoryCard(
                      category: category,
                      hasChildren: hasChildren,
                      onTap: () {
                        if (hasChildren) {
                          setState(() {
                            _activeParentId = catId;
                            _activeParentName = displayName;
                          });
                        } else {
                          _openEdit(category);
                        }
                      },
                      onEdit: () => _openEdit(category),
                      onDelete: () async {
                        await DatabaseService().deleteCategory(catId);
                        ref.invalidate(categoriesProvider(widget.type));
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _openEdit(Map<String, dynamic> category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryFormSheet(
        type: widget.type,
        category: category,
        onSaved: () {
          ref.invalidate(categoriesProvider(widget.type));
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single category card
// ---------------------------------------------------------------------------
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.onDelete,
    required this.onEdit,
    required this.onTap,
    this.hasChildren = false,
  });
  final Map<String, dynamic> category;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onTap;
  final bool hasChildren;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locale = context.locale.languageCode;
    final nameEn = category['name_en'] as String? ?? '';
    final nameAr = category['name_ar'] as String? ?? '';
    final displayName = locale == 'ar' ? nameAr : nameEn;
    final icon = CategoryIcons.getIcon(category['image_name'] ?? '');
    final color = CategoryIcons.getColor(category['image_name'] ?? '');

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showDeleteDialog(context),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      displayName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (hasChildren)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 8),
                ),
              ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                icon: Icon(Icons.edit_rounded, size: 14, color: cs.onSurface.withValues(alpha: 0.3)),
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('categories.delete_title'.tr()),
        content: Text('categories.delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------
class _EmptyCategoryState extends StatelessWidget {
  const _EmptyCategoryState({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            size: 72,
            color: cs.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'categories.empty'.tr(),
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category Form Sheet (Add/Edit)
// ---------------------------------------------------------------------------
class _CategoryFormSheet extends ConsumerStatefulWidget {
  const _CategoryFormSheet({
    super.key,
    required this.type,
    required this.onSaved,
    this.category,
  });
  final String type;
  final VoidCallback onSaved;
  final Map<String, dynamic>? category;

  @override
  ConsumerState<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<_CategoryFormSheet> {
  final _nameEnCtrl = TextEditingController();
  final _nameArCtrl = TextEditingController();
  String _selectedIconKey = 'other';
  int? _selectedParentId;
  bool _saving = false;

  bool get _isEdit => widget.category != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameEnCtrl.text = widget.category!['name_en'] as String? ?? '';
      _nameArCtrl.text = widget.category!['name_ar'] as String? ?? '';
      _selectedIconKey = widget.category!['image_name'] as String? ?? 'other';
      _selectedParentId = widget.category!['parent_id'] as int?;
      if (_selectedParentId == 0) _selectedParentId = null;
    }
  }

  // Available icon slots the user can pick from
  static const _iconOptions = [
    'food', 'groceries', 'transport', 'fuel', 'shopping',
    'health', 'pharmacy', 'entertainment', 'bills', 'utilities',
    'education', 'travel', 'sports', 'savings', 'gift',
    'salary', 'freelance', 'investment', 'bonus', 'rental',
    'subscriptions', 'rent', 'insurance', 'taxes', 'debt',
    'installment', 'other',
  ];

  @override
  void dispose() {
    _nameEnCtrl.dispose();
    _nameArCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nameEn = _nameEnCtrl.text.trim();
    if (nameEn.isEmpty) return;
    setState(() => _saving = true);
    
    if (_isEdit) {
      await DatabaseService().updateCategory(
        widget.category!['id'] as int,
        nameEn,
        _nameArCtrl.text.trim().isEmpty ? nameEn : _nameArCtrl.text.trim(),
        widget.type,
        _selectedIconKey,
        parentId: _selectedParentId,
      );
    } else {
      await DatabaseService().addCategory(
        nameEn: nameEn,
        nameAr: _nameArCtrl.text.trim().isEmpty ? nameEn : _nameArCtrl.text.trim(),
        type: widget.type,
        iconKey: _selectedIconKey,
        parentId: _selectedParentId,
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locale = context.locale.languageCode;
    
    // Load parent categories to choose from (only those of same type that are roots)
    final categoriesAsync = ref.watch(categoriesProvider(widget.type));

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [cs.primary, Colors.deepPurple]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  _isEdit ? 'categories.edit_title'.tr() : 'categories.add'.tr(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Parent category selection
            categoriesAsync.when(
              data: (all) {
                final roots = all.where((c) => (c['parent_id'] == null || c['parent_id'] == 0)).toList();
                // If editing, exclude itself from being its own parent
                if (_isEdit) {
                  roots.removeWhere((c) => c['id'] == widget.category!['id']);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'transaction.sub_category'.tr(),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: cs.primary),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _selectedParentId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: cs.surfaceContainerLow,
                        hintText: 'transaction.select_category'.tr(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      items: [
                        DropdownMenuItem<int>(
                          value: null,
                          child: Text('wallet.root_category_none'.tr()),
                        ),
                        ...roots.map((c) => DropdownMenuItem<int>(
                          value: c['id'] as int,
                          child: Text(locale == 'ar' ? c['name_ar'] : c['name_en']),
                        )),
                      ],
                      onChanged: (v) => setState(() => _selectedParentId = v),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Name EN
            TextField(
              controller: _nameEnCtrl,
              decoration: InputDecoration(
                labelText: 'categories.name_en'.tr(),
                filled: true,
                fillColor: cs.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: cs.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Name AR
            Directionality(
              textDirection: TextDirection.rtl,
              child: TextField(
                controller: _nameArCtrl,

                decoration: InputDecoration(
                  labelText: 'categories.name_ar'.tr(),
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cs.primary, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'categories.pick_icon'.tr(),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _iconOptions.length,
                itemBuilder: (_, i) {
                  final key = _iconOptions[i];
                  final icon = CategoryIcons.getIcon(key);
                  final color = CategoryIcons.getColor(key);
                  final isSelected = _selectedIconKey == key;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIconKey = key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.15)
                            : cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? color : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Icon(icon, color: isSelected ? color : cs.onSurface.withValues(alpha: 0.5), size: 22),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('common.save'.tr(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
