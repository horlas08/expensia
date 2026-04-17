import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/models/person_model.dart';
import '../../../profile/presentation/providers/persons_provider.dart';
import '../../../profile/presentation/widgets/add_person_sheet.dart';

/// A reusable bottom sheet to pick a person from the app's own contact database.
/// Returns the selected [Person] or null if dismissed.
class PersonPickerSheet extends ConsumerStatefulWidget {
  const PersonPickerSheet({super.key});

  /// Shows this sheet and returns the selected Person, or null.
  static Future<Person?> show(BuildContext context) {
    return showModalBottomSheet<Person>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PersonPickerSheet(),
    );
  }

  @override
  ConsumerState<PersonPickerSheet> createState() => _PersonPickerSheetState();
}

class _PersonPickerSheetState extends ConsumerState<PersonPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final personsAsync = ref.watch(personsProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // ── Title ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'profile.persons'.tr(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await AddPersonSheet.show(context);
                    // Refresh after adding
                    ref.invalidate(personsProvider);
                  },
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: Text('profile.add_person'.tr()),
                ),
              ],
            ),
          ),
          // ── Search ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (val) => setState(() => _query = val),
              decoration: InputDecoration(
                hintText: 'profile.search_persons'.tr(),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: cs.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ── List ──
          Expanded(
            child: personsAsync.when(
              data: (persons) {
                final filtered = persons.where((p) {
                  if (_query.isEmpty) return true;
                  final q = _query.toLowerCase();
                  return p.name.toLowerCase().contains(q) ||
                      (p.phone?.toLowerCase().contains(q) ?? false);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline_rounded,
                              size: 48, color: cs.onSurface.withValues(alpha: 0.2)),
                          const SizedBox(height: 12),
                          Text(
                            'profile.no_persons'.tr(),
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final person = filtered[index];
                    final avatarColor = Colors
                        .primaries[person.name.length % Colors.primaries.length]
                        .withValues(alpha: 0.15);
                    final textColor = Colors
                        .primaries[person.name.length % Colors.primaries.length];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        onTap: () => Navigator.pop(context, person),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: avatarColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              person.initials,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          person.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        subtitle: person.phone != null && person.phone!.isNotEmpty
                            ? Text(
                                person.phone!,
                                style: TextStyle(
                                    color: cs.onSurfaceVariant, fontSize: 13),
                              )
                            : null,
                        trailing: Icon(Icons.chevron_right_rounded,
                            color: cs.onSurface.withValues(alpha: 0.3)),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
