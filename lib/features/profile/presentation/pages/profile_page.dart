import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:animate_do/animate_do.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import '../../../../core/config/premium_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/shared_preferences_service.dart';
import '../../../dashboard/presentation/widgets/debts_summary_sheet.dart';
import '../../../dashboard/presentation/widgets/installments_summary_sheet.dart';
import '../widgets/backup_restore_sheet.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../features/categories/presentation/pages/categories_page.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/language_sheet.dart';
import '../widgets/currency_picker_sheet.dart';
import '../widgets/app_lock_sheet.dart';
import 'notification_settings_page.dart';
import 'persons_page.dart';
import '../widgets/subscription_sheet.dart';
import '../../../../core/services/database_service.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/wallet/presentation/providers/wallet_provider.dart';
import '../../../../features/dashboard/presentation/providers/dashboard_provider.dart';

// import '../../../../features/transactions/presentation/providers/transactions_provider.dart';// Persists the chosen theme to SharedPreferences
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

  void _showDebtsSheet(BuildContext context, String sym) {
    Navigator.push(
      context,
      ModalSheetRoute(
        builder: (context) => DebtsSummarySheet(currencySymbol: sym),
      ),
    );
  }

  void _showInstallmentsSheet(BuildContext context, String sym) {
    Navigator.push(
      context,
      ModalSheetRoute(
        builder: (context) => InstallmentsSummarySheet(currencySymbol: sym),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final currencyCode = ref.watch(currencyCodeProvider);
    final isPro = ref.watch(isProProvider);

    // ThemeSwitchingArea is now global in main.dart — no wrapper needed here.
    return Scaffold(
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
                    child: _SettingsCard(
                      items: [
                        _SettingTile(
                          icon: Icons.person_outline_rounded,
                          label: 'profile.persons'.tr(),
                          onTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const PersonsPage(),
                                ),
                              ),
                        ),
                        _SettingTile(
                          icon: Icons.language_rounded,
                          label: 'profile.language'.tr(),
                          trailingText:
                              context.locale.languageCode.toUpperCase(),
                          onTap: () => showLanguageSheet(context),
                        ),
                        _SettingTile(
                          icon: Icons.category_outlined,
                          label: 'profile.categories'.tr(),
                          onTap:
                              () => Navigator.of(context).push(
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
                      ],
                    ),
                  ),

                  // ── Summary ──────────────────────────────────────────
                  _SectionLabel('profile.section_summary'.tr(), delay: 60),
                  FadeInUp(
                    delay: const Duration(milliseconds: 100),
                    child: _SettingsCard(
                      items: [
                        _SettingTile(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'profile.debt_summary'.tr(),
                          onTap: () => _showDebtsSheet(context, currencySymbol),
                        ),
                        _SettingTile(
                          icon: Icons.calendar_month_outlined,
                          label: 'profile.installment_summary'.tr(),
                          onTap: () => _showInstallmentsSheet(context,currencySymbol),
                        ),
                      ],
                    ),
                  ),

                  // ── App Preferences ──────────────────────────────────
                  _SectionLabel('profile.section_preferences'.tr(), delay: 80),
                  FadeInUp(
                    delay: const Duration(milliseconds: 130),
                    child: _SettingsCard(
                      items: [
                        // Theme tile — correct ThemeSwitcher.withTheme() API
                        ThemeSwitcher.withTheme(
                          builder: (context, switcher, theme) {
                            final isDark = theme.brightness == Brightness.dark;
                            return _SettingTile(
                              icon:
                                  isDark
                                      ? Icons.light_mode_rounded
                                      : Icons.dark_mode_rounded,
                              label: 'profile.theme'.tr(),
                              onTap: () async {
                                if (!isPro) {
                                  await SubscriptionSheet.show(context);
                                  return;
                                }
                                switcher.changeTheme(
                                  theme:
                                      isDark
                                          ? AppTheme.lightTheme
                                          : AppTheme.darkTheme,
                                  isReversed: isDark,
                                );
                                _persistTheme(!isDark);
                              },
                              trailing:
                                  isPro
                                      ? Transform.scale(
                                        scale: 0.85,
                                        child: Switch.adaptive(
                                          value: isDark,
                                          onChanged: (val) {
                                            switcher.changeTheme(
                                              theme:
                                                  isDark
                                                      ? AppTheme.lightTheme
                                                      : AppTheme.darkTheme,
                                              isReversed: isDark,
                                            );
                                            _persistTheme(!isDark);
                                          },
                                        ),
                                      )
                                      : _ProBadge(),
                            );
                          },
                        ),
                        _SettingTile(
                          icon: Icons.notifications_outlined,
                          label: 'profile.notifications'.tr(),
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => const NotificationSettingsPage(),
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),

                  // ── Data & Security ──────────────────────────────────
                  _SectionLabel('profile.section_data'.tr(), delay: 160),
                  FadeInUp(
                    delay: const Duration(milliseconds: 210),
                    child: _SettingsCard(
                      items: [
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
                          onTap: () => _openAppLock(context, isPro),
                          trailing: isPro ? null : _ProBadge(),
                        ),
                        _SettingTile(
                          icon: Icons.delete_forever_rounded,
                          label: 'profile.clear_data'.tr(),
                          onTap: () => _showClearDataConfirm(context),
                        ),
                      ],
                    ),
                  ),

                  if (!isPro) ...[
                    // ── Premium Banner ───────────────────────────────────
                    _SectionLabel('profile.section_premium'.tr(), delay: 240),
                    FadeInUp(
                      delay: const Duration(milliseconds: 290),
                      child: _PremiumBanner(),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // ── About ────────────────────────────────────────────
                  _SectionLabel('profile.section_about'.tr(), delay: 320),
                  FadeInUp(
                    delay: const Duration(milliseconds: 370),
                    child: _SettingsCard(
                      items: [
                        _SettingTile(
                          icon: Icons.info_outline_rounded,
                          label: 'profile.app_version'.tr(),
                          trailingText: '1.0.0',
                          onTap: () {},
                        ),
                        _SettingTile(
                          icon: Icons.privacy_tip_outlined,
                          label: 'profile.privacy_policy'.tr(),
                          onTap: () => context.push('/privacy-policy'),
                        ),
                        _SettingTile(
                          icon: Icons.description_outlined,
                          label: 'profile.terms'.tr(),
                          onTap: () => context.push('/terms-of-use'),
                        ),
                        _SettingTile(
                          icon: Icons.mail_outline_rounded,
                          label: 'profile.contact_us'.tr(),
                          onTap: () {},
                        ),
                      ],
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

  void _showBackupConfirm(BuildContext context) {
    BackupRestoreSheet.showLocal(context, isBackup: true);
  }

  void _showRestoreConfirm(BuildContext context) {
    BackupRestoreSheet.showLocal(context, isBackup: false);
  }

  Future<void> _openAppLock(BuildContext context, bool isPro) async {
    final isLocked = PremiumConfig.isLocked(
      feature: PremiumFeature.appLock,
      isPro: isPro,
    );
    if (isLocked) {
      await SubscriptionSheet.show(context);
      return;
    }

    await showAppLockSheet(context, ref);
  }

  void _showClearDataConfirm(BuildContext pageContext) {
    showDialog(
      context: pageContext,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('profile.clear_data'.tr()),
            content: Text('profile.clear_data_confirm'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('common.cancel'.tr()),
              ),
              TextButton(
                onPressed: () async {
                  // 1. Show loading state
                  Navigator.pop(dialogContext); // Close confirm dialog

                  if (!mounted) return;

                  showDialog(
                    context: pageContext,
                    barrierDismissible: false,
                    builder:
                        (loadingContext) =>
                            const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    // 2. Wipe Data
                    await DatabaseService().deleteAllData();

                    // 3. Clear SharedPreferences
                    final prefs = await SharedPreferencesService.getInstance();
                    await prefs.clearAppSetup();

                    // 4. Reset DB singleton
                    DatabaseService().resetInstance();

                    // 4.5. Invalidate global providers so no stale data is shown on restart
                    ref.invalidate(walletProvider);
                    ref.invalidate(recentTransactionsProvider);
                    ref.invalidate(dashboardMetricsProvider);
                    ref.invalidate(allTransactionsProvider);

                    if (!mounted) return;

                    // 5. Close loading dialog using the stable pageContext
                    Navigator.of(pageContext).pop();

                    ScaffoldMessenger.of(pageContext).showSnackBar(
                      SnackBar(
                        content: Text('profile.clear_data_success'.tr()),
                      ),
                    );

                    // 6. Give the snackbar a moment and restart app state
                    await Future.delayed(const Duration(milliseconds: 500));

                    if (mounted) {
                      // Using go() to completely replace the route stack
                      pageContext.go('/splash');
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.of(pageContext).pop(); // Close loading if error
                      ScaffoldMessenger.of(pageContext).showSnackBar(
                        SnackBar(content: Text('common.error'.tr() + ': $e')),
                      );
                    }
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text('common.delete'.tr()),
              ),
            ],
          ),
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
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                    GestureDetector(
                      onTap: onEditTap,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 14,
                          color: cs.primary,
                        ),
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
                      fontStyle:
                          userName.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FadeInUp(
                delay: const Duration(milliseconds: 130),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'profile.user_badge'.tr(),
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
      onTap: () => SubscriptionSheet.show(context),
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
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 26,
              ),
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
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
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

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'get_started.pro_badge'.tr(),
        style: const TextStyle(
          color: Colors.orange,
          fontSize: 11,
          fontWeight: FontWeight.bold,
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
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.15)),
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
