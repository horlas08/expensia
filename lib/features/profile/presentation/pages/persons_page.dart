import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:animate_do/animate_do.dart';
import 'package:toastification/toastification.dart';
import 'package:flutter/scheduler.dart';
import '../../../../core/models/person_model.dart';
import '../../../../core/services/device_contact_picker_service.dart';
import '../../../../core/utils/url_launcher_utils.dart';
import '../providers/persons_provider.dart';
import '../widgets/add_person_sheet.dart';

class PersonsPage extends ConsumerStatefulWidget {
  const PersonsPage({super.key, this.isPicker = false});
  final bool isPicker;

  @override
  ConsumerState<PersonsPage> createState() => _PersonsPageState();
}

class _PersonsPageState extends ConsumerState<PersonsPage> {
  bool _didAutoSync = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _autoSyncContacts();
    });
  }

  Future<void> _autoSyncContacts() async {
    if (_didAutoSync || !mounted || widget.isPicker) return;
    _didAutoSync = true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filteredPersonsAsync = ref.watch(filteredPersonsProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── SLIVER APP BAR ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: cs.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.isPicker
                    ? 'profile.select_person'.tr()
                    : 'profile.persons'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, const Color(0xFF4A0080)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: FadeInDown(
                    child: Icon(
                      Icons.people_alt_rounded,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => _handleImport(context, ref),
                icon: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: Colors.white,
                ),
                tooltip: 'profile.import_contacts'.tr(),
              ),
            ],
          ),

          // ── SEARCH BAR ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: FadeInUp(
                child: TextField(
                  onChanged:
                      (val) =>
                          ref.read(personsSearchQueryProvider.notifier).state =
                              val,
                  decoration: InputDecoration(
                    hintText: 'profile.search_persons'.tr(),
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ),

          // ── CONTENT ─────────────────────────────────────────────────
          filteredPersonsAsync.when(
            data: (persons) {
              if (persons.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyPersonsView(),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final person = persons[index];
                    return FadeInUp(
                      delay: Duration(milliseconds: 50 * index),
                      child: _PersonCard(
                        person: person,
                        isPicker: widget.isPicker,
                      ),
                    );
                  }, childCount: persons.length),
                ),
              );
            },
            loading:
                () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
            error:
                (e, _) => SliverFillRemaining(
                  child: Center(
                    child: Text('common.error_prefix'.tr(args: ['$e'])),
                  ),
                ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddPersonSheet.show(context),
        icon: const Icon(Icons.person_add_rounded),
        label: Text('profile.add_person'.tr()),
      ),
    );
  }

  Future<void> _handleImport(BuildContext context, WidgetRef ref) async {
    try {
      final pickedPerson = await DeviceContactPickerService.pickPerson();
      if (pickedPerson == null || !context.mounted) return;

      final saved = await ref
          .read(personsProvider.notifier)
          .importPickedContact(pickedPerson);

      if (!context.mounted || saved == null) return;
      if (widget.isPicker) {
        Navigator.pop(context, saved);
        return;
      }

      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.flatColored,
        title: Text('common.success'.tr()),
        description: Text('profile.contact_imported'.tr(args: [saved.name])),
        autoCloseDuration: const Duration(seconds: 4),
      );
    } catch (e) {
      if (context.mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: Text('common.error'.tr()),
          description: Text(e.toString()),
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    }
  }
}

class _PersonCard extends ConsumerWidget {
  const _PersonCard({required this.person, this.isPicker = false});
  final Person person;
  final bool isPicker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    // Soft color based on name
    final avatarColor = Colors
        .primaries[person.name.length % Colors.primaries.length]
        .withValues(alpha: 0.15);
    final textIconColor =
        Colors.primaries[person.name.length % Colors.primaries.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        onTap: () {
          if (isPicker) {
            Navigator.pop(context, person);
          } else {
            AddPersonSheet.show(context, person: person);
          }
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: avatarColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              person.initials,
              style: TextStyle(
                color: textIconColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        title: Text(
          person.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle:
            person.phone != null && person.phone!.isNotEmpty
                ? Text(
                  person.phone!,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                )
                : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (person.phone != null && person.phone!.isNotEmpty) ...[
              IconButton(
                onPressed:
                    () =>
                        UrlLauncherUtils.launchWhatsApp(context, person.phone!),
                icon: const Icon(
                  Icons.message_rounded,
                  size: 20,
                  color: Colors.green,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green.withValues(alpha: 0.1),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed:
                    () => UrlLauncherUtils.launchCall(context, person.phone!),
                icon: const Icon(
                  Icons.phone_rounded,
                  size: 20,
                  color: Colors.blue,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                ),
              ),
            ],
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => _confirmDelete(context, ref),
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: Colors.red,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(personsProvider.notifier);
    final hasDeps = await notifier.hasDependencies(person.id!);

    if (context.mounted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text('profile.delete_person_title'.tr()),
              content: Text(
                hasDeps
                    ? 'profile.delete_person_confirm'.tr()
                    : "${'common.delete'.tr()} ${person.name}?",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('common.cancel'.tr()),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    'common.delete'.tr(),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
      );

      if (confirm == true) {
        await notifier.deletePerson(person.id!);
      }
    }
  }
}

class _EmptyPersonsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeInDown(
            child: Image.asset(
              'assets/images/empty_contacts_illustration.png',
              height: 240,
            ),
          ),
          const SizedBox(height: 24),
          FadeInUp(
            child: Text(
              'profile.no_persons'.tr(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          FadeInUp(
            delay: const Duration(milliseconds: 100),
            child: Text(
              'profile.no_persons_sub'.tr(),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
