import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/constants/category_icons.dart';

/// Shows a modernized, high-fidelity category picker sheet.
Future<Map<String, dynamic>?> showCategoryPickerSheet(
  BuildContext context, {
  required List<Map<String, dynamic>> categories,
  required String locale,
  int? initialParentId,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _CategoryPickerSheet(
      categories: categories,
      locale: locale,
      initialParentId: initialParentId,
    ),
  );
}

class _CategoryPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final String locale;
  final int? initialParentId;

  const _CategoryPickerSheet({
    required this.categories,
    required this.locale,
    this.initialParentId,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  int? _activeParentId;
  String? _activeParentName;

  @override
  void initState() {
    super.initState();
    _activeParentId = widget.initialParentId;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    final displayCats = widget.categories.where((c) {
      final pId = c['parent_id'] as int?;
      return (_activeParentId == null) 
          ? (pId == null || pId == 0) 
          : (pId == _activeParentId);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          // Header
          Row(
            children: [
              if (_activeParentId != null)
                IconButton(
                  onPressed: () => setState(() {
                    _activeParentId = null;
                    _activeParentName = null;
                  }),
                  style: IconButton.styleFrom(
                    backgroundColor: cs.primary.withValues(alpha: 0.1),
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: cs.primary),
                ),
              Expanded(
                child: Text(
                  _activeParentId == null
                      ? 'transaction.select_category'.tr()
                      : _activeParentName!,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: _activeParentId == null ? TextAlign.center : TextAlign.start,
                ),
              ),
              if (_activeParentId != null) const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 24),

          if (displayCats.isEmpty && _activeParentId == null)
            Expanded(
              child: Center(
                child: Opacity(
                  opacity: 0.5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.category_outlined, size: 64),
                      const SizedBox(height: 16),
                      Text('categories.empty'.tr()),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.only(bottom: 40),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: displayCats.length + (_activeParentId != null ? 1 : 0),
                itemBuilder: (_, i) {
                  // Option to select the parent itself if we are in a sub-category view
                  if (_activeParentId != null && i == 0) {
                    return _ModernCategoryCard(
                      name: 'transaction.select_parent'.tr(args: [_activeParentName!]),
                      imageName: 'misc',
                      color: cs.primary,
                      onTap: () {
                        final parent = widget.categories.firstWhere((c) => c['id'] == _activeParentId);
                        Navigator.pop(context, parent);
                      },
                      isParentOption: true,
                    );
                  }

                  final catIndex = _activeParentId != null ? i - 1 : i;
                  final cat = displayCats[catIndex];
                  final id = cat['id'] as int;
                  final nameEn = cat['name_en'] as String? ?? '';
                  final imageName = cat['image_name'] as String? ?? 'other';
                  final displayName = widget.locale == 'ar'
                      ? (cat['name_ar'] as String? ?? nameEn)
                      : nameEn;

                  final hasChildren = widget.categories.any((c) => c['parent_id'] == id);

                  return _ModernCategoryCard(
                    name: displayName,
                    imageName: imageName,
                    color: CategoryIcons.getColor(imageName),
                    hasChildren: hasChildren,
                    onTap: () {
                      if (hasChildren) {
                        setState(() {
                          _activeParentId = id;
                          _activeParentName = displayName;
                        });
                      } else {
                        Navigator.pop(context, cat);
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ModernCategoryCard extends StatelessWidget {
  final String name;
  final String imageName;
  final Color color;
  final VoidCallback onTap;
  final bool hasChildren;
  final bool isParentOption;

  const _ModernCategoryCard({
    required this.name,
    required this.imageName,
    required this.color,
    required this.onTap,
    this.hasChildren = false,
    this.isParentOption = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = CategoryIcons.getIcon(imageName);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isParentOption ? color : color.withValues(alpha: 0.2),
            width: isParentOption ? 2 : 1,
          ),
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
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isParentOption ? FontWeight.bold : FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (hasChildren)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
