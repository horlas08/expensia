import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/shared_preferences_service.dart';
import '../widgets/backup_restore_sheet.dart';
import '../../../../core/services/backup_restore_service.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../features/categories/presentation/pages/categories_page.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/language_sheet.dart';
import '../widgets/currency_picker_sheet.dart';
import '../widgets/app_lock_sheet.dart';

// Persists the chosen theme to SharedPreferences
Future<void> _persistTheme(bool isDark) async {
  final prefs = await SharedPreferencesService.getInstance();
  await prefs.setDarkMode(isDark);
}


// ---------------------------------------------------------------------------
// Profile / Settings Tab
// ---------------------------------------------------------------------------
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferencesService.getInstance();
    final name = prefs.getUserName();
    if (mounted) setState(() => _userName = name ?? '');
  }

  // Called when edit-profile sheet returns a new name
  Future<void> _openEditProfile() async {
    final result = await showEditProfileSheet(context) as String?;
    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _userName = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final currencyCode = ref.watch(currencyCodeProvider);

    // ThemeSwitchingArea is REQUIRED for the ripple animation to cover the page
    return ThemeSwitchingArea(
      child: Scaffold(
        backgroundColor: cs.surface,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Gradient Header SliverAppBar ──────────────────────────────
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              collapsedHeight: 60,
              backgroundColor: cs.primary,
              foregroundColor: Colors.white,
              title: Text(
                'profile.title'.tr(),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: _ProfileHeader(
                  userName: _userName,
                  onEditTap: _openEditProfile,
                ),
              ),
            ),

            // ── Settings body ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── General ──────────────────────────────────────────
                    _SectionLabel('profile.section_general'.tr(), delay: 0),
                    FadeInUp(
                      delay: const Duration(milliseconds: 50),
                      child: _SettingsCard(items: [
                        _SettingTile(
                          icon: Icons.person_outline_rounded,
                          label: 'profile.persons'.tr(),
                          onTap: () {},
                        ),
                        _SettingTile(
                          icon: Icons.language_rounded,
                          label: 'profile.language'.tr(),
                          trailingText: context.locale.languageCode.toUpperCase(),
                          onTap: () => showLanguageSheet(context),
                        ),
                         _SettingTile(
                          icon: Icons.category_outlined,
                          label: 'profile.categories'.tr(),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CategoriesPage(),
                            ),
                          ),
                        ),
                        _SettingTile(
                          icon: Icons.currency_exchange_rounded,
                          label: 'profile.default_currency'.tr(),
                          // currencySymbol is static — not translated
                          trailingText: '$currencyCode  $currencySymbol',
                          onTap: () => showCurrencyPickerSheet(context, ref),
                        ),
                      ]),
                    ),

                    // ── App Preferences ──────────────────────────────────
                    _SectionLabel('profile.section_preferences'.tr(), delay: 80),
                    FadeInUp(
                      delay: const Duration(milliseconds: 130),
                      child: _SettingsCard(items: [
                        // Theme tile — correct ThemeSwitcher.withTheme() API
                        ThemeSwitcher.withTheme(
                          builder: (context, switcher, theme) {
                            final isDark = theme.brightness == Brightness.dark;
                            return _SettingTile(
                              icon: isDark
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                              label: 'profile.theme'.tr(),
                              onTap: () {
                                switcher.changeTheme(
                                  theme: isDark ? AppTheme.lightTheme : AppTheme.darkTheme,
                                  isReversed: isDark,
                                );
                                _persistTheme(!isDark);
                              },
                              trailing: Transform.scale(
                                scale: 0.85,
                                child: Switch.adaptive(
                                  value: isDark,
                                  onChanged: (_) {
                                    switcher.changeTheme(
                                      theme: isDark ? AppTheme.lightTheme : AppTheme.darkTheme,
                                      isReversed: isDark,
                                    );
                                    _persistTheme(!isDark);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                        _SettingTile(
                          icon: Icons.notifications_outlined,
                          label: 'profile.notifications'.tr(),
                          onTap: () => _showNotificationInfo(context),
                        ),
                      ]),
                    ),

                    // ── Data & Security ──────────────────────────────────
                    _SectionLabel('profile.section_data'.tr(), delay: 160),
                    FadeInUp(
                      delay: const Duration(milliseconds: 210),
                      child: _SettingsCard(items: [
                        _SettingTile(
                          icon: Icons.backup_outlined,
                          label: 'profile.backup'.tr(),
                          onTap: () => _showBackupConfirm(context),
                        ),
                        _SettingTile(
                          icon: Icons.restore_rounded,
                          label: 'profile.restore'.tr(),
                          onTap: () => _showRestoreConfirm(context),
                        ),
                        _SettingTile(
                          icon: Icons.fingerprint_rounded,
                          label: 'profile.app_lock'.tr(),
                          onTap: () => showAppLockSheet(context, ref),
                        ),
                      ]),
                    ),

                    // ── Premium Banner ───────────────────────────────────
                    _SectionLabel('profile.section_premium'.tr(), delay: 240),
                    FadeInUp(
                      delay: const Duration(milliseconds: 290),
                      child: GestureDetector(
                        onTap: () => _showPremiumSheet(context),
                        child: _PremiumBanner(),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── About ────────────────────────────────────────────
                    _SectionLabel('profile.section_about'.tr(), delay: 320),
                    FadeInUp(
                      delay: const Duration(milliseconds: 370),
                      child: _SettingsCard(items: [
                        _SettingTile(
                          icon: Icons.info_outline_rounded,
                          label: 'profile.app_version'.tr(),
                          trailingText: '1.0.0',
                          onTap: () {},
                        ),
                        _SettingTile(
                          icon: Icons.privacy_tip_outlined,
                          label: 'profile.privacy_policy'.tr(),
                          onTap: () {},
                        ),
                        _SettingTile(
                          icon: Icons.description_outlined,
                          label: 'profile.terms'.tr(),
                          onTap: () {},
                        ),
                        _SettingTile(
                          icon: Icons.mail_outline_rounded,
                          label: 'profile.contact_us'.tr(),
                          onTap: () {},
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NotificationInfoSheet(),
    );
  }

  void _showBackupConfirm(BuildContext context) {
    BackupRestoreSheet.showLocal(context, isBackup: true);
  }

  void _showRestoreConfirm(BuildContext context) {
    BackupRestoreSheet.showLocal(context, isBackup: false);
  }

  void _showPremiumSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PremiumSheet(ref: ref),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile Header Widget
// ---------------------------------------------------------------------------
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.userName, required this.onEditTap});
  final String userName;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, const Color(0xFF4A0080)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              // Avatar with edit overlay
              FadeInDown(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.3),
                            Colors.white.withValues(alpha: 0.1),
                          ],
                        ),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                      ),
                      child: const Icon(Icons.person_rounded, size: 44, color: Colors.white),
                    ),
                    GestureDetector(
                      onTap: onEditTap,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6)],
                        ),
                        child: Icon(Icons.edit_rounded, size: 14, color: cs.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FadeInUp(
                delay: const Duration(milliseconds: 80),
                child: GestureDetector(
                  onTap: onEditTap,
                  child: Text(
                    userName.isNotEmpty ? userName : 'profile.no_name'.tr(),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontStyle: userName.isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FadeInUp(
                delay: const Duration(milliseconds: 130),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Expensia User',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Premium Banner
// ---------------------------------------------------------------------------
class _PremiumBanner extends StatelessWidget {
  const _PremiumBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF8C00), Color(0xFFFFD700)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'profile.upgrade_premium'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'profile.premium_subtitle'.tr(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'PRO',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notification Info Sheet
// ---------------------------------------------------------------------------
class _NotificationInfoSheet extends StatelessWidget {
  const _NotificationInfoSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeInDown(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [cs.primary, Colors.deepPurple]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Text(
                  'profile.notif_title'.tr(),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FadeInUp(
            delay: const Duration(milliseconds: 100),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, color: cs.primary, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'profile.notif_coming_soon'.tr(),
                          style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'profile.notif_desc'.tr(),
                          style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('common.close'.tr()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section Label
// ---------------------------------------------------------------------------
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.delay = 0});
  final String label;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return FadeInLeft(
      delay: Duration(milliseconds: delay),
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings Card — groups items into a rounded container
// ---------------------------------------------------------------------------
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.items});
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          return Column(
            children: [
              items[i],
              if (i < items.length - 1)
                Divider(
                  height: 1,
                  indent: 58,
                  color: cs.outlineVariant.withValues(alpha: 0.25),
                ),
            ],
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Setting Tile
// ---------------------------------------------------------------------------
class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingText,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailingText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: cs.primary, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null)
              trailing!
            else if (trailingText != null)
              Text(
                trailingText!,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.45),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.3),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Premium Sheet — full RevenueCat purchase flow
// ---------------------------------------------------------------------------
class _PremiumSheet extends ConsumerStatefulWidget {
  const _PremiumSheet({required this.ref});
  final WidgetRef ref;

  @override
  ConsumerState<_PremiumSheet> createState() => _PremiumSheetState();
}

class _PremiumSheetState extends ConsumerState<_PremiumSheet> {
  bool _loading = false;
  bool _restoring = false;

  Future<void> _purchase() async {
    setState(() => _loading = true);
    final service = ref.read(subscriptionServiceProvider);
    final isPro = await service.purchasePro();
    if (!mounted) return;
    setState(() => _loading = false);
    ref.read(isProProvider.notifier).state = isPro;
    if (isPro) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('get_started.restore_purchase_success'.tr()),
          backgroundColor: const Color(0xFF00C48C),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    final service = ref.read(subscriptionServiceProvider);
    final isPro = await service.restorePurchases();
    if (!mounted) return;
    setState(() => _restoring = false);
    ref.read(isProProvider.notifier).state = isPro;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isPro
            ? 'get_started.restore_purchase_success'.tr()
            : 'get_started.restore_purchase_failed'.tr()),
        backgroundColor: isPro ? const Color(0xFF00C48C) : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (isPro && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final features = [
      (Icons.cloud_upload_rounded, 'Google Drive Backup', 'Auto backup your data to the cloud'),
      (Icons.bar_chart_rounded, 'Advanced Analytics', 'Deep insights & export to PDF/CSV'),
      (Icons.block_outlined, 'Ad-Free Experience', 'No ads, ever — full focus on you'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  'PRO',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'profile.upgrade_premium'.tr(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'profile.premium_subtitle'.tr(),
            style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.5)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          // Features
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(f.$1, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.$2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(f.$3, style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: Color(0xFF00C48C), size: 20),
              ],
            ),
          )),
          const SizedBox(height: 24),
          // Purchase button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _purchase,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _loading
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : Text(
                      'profile.upgrade_premium'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // Restore purchases
          TextButton(
            onPressed: _restoring ? null : _restore,
            child: _restoring
                ? const SizedBox(height: 16, width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    'get_started.restore_purchase'.tr(),
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
