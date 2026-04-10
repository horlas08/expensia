import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:animate_do/animate_do.dart' ;
import '../../../../core/constants/category_icons.dart';
import '../../../../core/services/database_service.dart';

// ---------------------------------------------------------------------------
// Riverpod provider — loads categories by type from SQLite
// ---------------------------------------------------------------------------
final _categoriesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, type) async {
  final db = DatabaseService();
  return db.getCategoriesByType(type);
});

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
      builder: (_) => _AddCategorySheet(
        type: currentType,
        onSaved: () {
          // Invalidate providers to refresh all tabs
          for (final t in _tabs) {
            ref.invalidate(_categoriesProvider(t));
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single tab body
// ---------------------------------------------------------------------------
class _CategoryTabView extends ConsumerWidget {
  const _CategoryTabView({required this.type});
  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_categoriesProvider(type));
    final cs = Theme.of(context).colorScheme;

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (categories) {
        if (categories.isEmpty) {
          return _EmptyCategoryState(type: type);
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: categories.length,
          itemBuilder: (context, i) {
            return FadeInUp(
              delay: Duration(milliseconds: 40 * i),
              child: _CategoryCard(
                category: categories[i],
                onDelete: () async {
                  final id = categories[i]['id'] as int;
                  await DatabaseService().deleteCategory(id);
                  ref.invalidate(_categoriesProvider(type));
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Single category card
// ---------------------------------------------------------------------------
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onDelete});
  final Map<String, dynamic> category;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locale = context.locale.languageCode;
    final nameEn = category['name_en'] as String? ?? '';
    final nameAr = category['name_ar'] as String? ?? '';
    final displayName = locale == 'ar' ? nameAr : nameEn;
    final icon = CategoryIcons.getIcon(nameEn);
    final color = CategoryIcons.getColor(nameEn);

    return GestureDetector(
      onLongPress: () => _showDeleteDialog(context),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
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
// Add Category Sheet
// ---------------------------------------------------------------------------
class _AddCategorySheet extends StatefulWidget {
  const _AddCategorySheet({required this.type, required this.onSaved});
  final String type;
  final VoidCallback onSaved;

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  final _nameEnCtrl = TextEditingController();
  final _nameArCtrl = TextEditingController();
  String _selectedIconKey = 'other';
  bool _saving = false;

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
    await DatabaseService().addCategory(
      nameEn: nameEn,
      nameAr: _nameArCtrl.text.trim().isEmpty ? nameEn : _nameArCtrl.text.trim(),
      type: widget.type,
      iconKey: _selectedIconKey,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
                  'categories.add'.tr(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
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
