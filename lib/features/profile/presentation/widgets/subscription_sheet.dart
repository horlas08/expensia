import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/services/subscription_service.dart';

class SubscriptionSheet extends ConsumerStatefulWidget {
  const SubscriptionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalSheet(
      context: context,
      builder: (context) => const SubscriptionSheet(),
    );
  }

  @override
  ConsumerState<SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends ConsumerState<SubscriptionSheet> {
  bool _isPurchasing = false;
  bool _isRestoring = false;
  String? _errorMessage;

  List<SubscriptionPackage>? _packages;
  SubscriptionPackage? _selectedPackage;
  bool _isLoadingPackages = true;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    final packages = await ref.read(subscriptionServiceProvider).getPackages();
    if (mounted) {
      setState(() {
        _packages = packages;
        _isLoadingPackages = false;
        if (packages.isNotEmpty) {
          _selectedPackage = packages.first;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,

      maxChildSize: 0.95,
      expand: false,
      builder:
          (context, scrollController) => Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // ── HANDLE ────────────────────────────────────────────────
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    children: [
                      // ── HEADER ──────────────────────────────────────────
                      Center(
                        child: FadeInDown(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              size: 64,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FadeInUp(
                        child: Text(
                          'profile.upgrade_premium'.tr(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FadeInUp(
                        delay: const Duration(milliseconds: 100),
                        child: Text(
                          'profile.premium_subtitle'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // ── FEATURES ────────────────────────────────────────
                      _FeatureItem(
                        icon: Icons.receipt_long_rounded,
                        title: 'profile.premium.unlimited_transactions'.tr(),
                        subtitle:
                            'profile.premium.unlimited_transactions_desc'.tr(),
                        delay: 200,
                      ),
                      _FeatureItem(
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'profile.premium.unlimited_wallets'.tr(),
                        subtitle: 'profile.premium.unlimited_wallets_desc'.tr(),
                        delay: 250,
                      ),
                      _FeatureItem(
                        icon: Icons.cloud_done_rounded,
                        title: 'profile.premium.google_drive_sync'.tr(),
                        subtitle: 'profile.premium.google_drive_sync_desc'.tr(),
                        delay: 300,
                      ),
                      _FeatureItem(
                        icon: Icons.bar_chart_rounded,
                        title: 'profile.premium.advanced_analytics'.tr(),
                        subtitle:
                            'profile.premium.advanced_analytics_desc'.tr(),
                        delay: 350,
                      ),
                      _FeatureItem(
                        icon: Icons.fingerprint_rounded,
                        title: 'profile.premium.biometric_lock'.tr(),
                        subtitle: 'profile.premium.biometric_lock_desc'.tr(),
                        delay: 400,
                      ),
                      _FeatureItem(
                        icon: Icons.dark_mode_rounded,
                        title: 'profile.premium.dark_mode'.tr(),
                        subtitle: 'profile.premium.dark_mode_desc'.tr(),
                        delay: 450,
                      ),
                      _FeatureItem(
                        icon: Icons.block_rounded,
                        title: 'profile.premium.ad_free'.tr(),
                        subtitle: 'profile.premium.ad_free_desc'.tr(),
                        delay: 500,
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),

                // ── BOTTOM ACTIONS ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── ERROR MESSAGE ──
                      if (_errorMessage != null)
                        FadeInUp(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                      // ── PACKAGES ──
                      if (_isLoadingPackages)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_packages == null || _packages!.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text('profile.premium.no_packages'.tr()),
                          ),
                        ),
                      const SizedBox(height: 16),

                      FadeInUp(
                        delay: const Duration(milliseconds: 600),
                        child: ElevatedButton(
                          onPressed:
                              (_isPurchasing ||
                                      _isRestoring ||
                                      _isLoadingPackages ||
                                      _packages == null ||
                                      _packages!.isEmpty)
                                  ? null
                                  : () async {
                                      final pkg = await Navigator.push<SubscriptionPackage>(
                                        context,
                                        ModalSheetRoute(
                                          builder: (_) => _PackagesSheet(
                                            packages: _packages!,
                                            selectedPackage: _selectedPackage,
                                          ),
                                        ),
                                      );
                                      if (pkg != null && context.mounted) {
                                        _handlePurchase(context, ref, pkg);
                                      }
                                    },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child:
                              _isPurchasing
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Text(
                                    'profile.premium.upgrade_now'.tr(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FadeInUp(
                        delay: const Duration(milliseconds: 700),
                        child: TextButton(
                          onPressed:
                              (_isPurchasing || _isRestoring)
                                  ? null
                                  : () => _handleRestore(context, ref),
                          child:
                              _isRestoring
                                  ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Text(
                                    'get_started.restore_purchase'.tr(),
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ── COMPLIANCE LINKS ──
                      // Row(
                      //   mainAxisAlignment: MainAxisAlignment.center,
                      //   children: [
                      //     TextButton(
                      //       onPressed: () => context.push('/privacy-policy'),
                      //       child: Text(
                      //         'profile.privacy_policy'.tr(),
                      //         style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      //       ),
                      //     ),
                      //     Text(
                      //       '•',
                      //       style: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                      //     ),
                      //     TextButton(
                      //       onPressed: () => context.push('/terms-of-use'),
                      //       child: Text(
                      //         'profile.terms'.tr(),
                      //         style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      //       ),
                      //     ),
                      //   ],
                      // ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _handlePurchase(BuildContext context, WidgetRef ref, SubscriptionPackage pkg) async {
    setState(() {
      _selectedPackage = pkg;
      _isPurchasing = true;
      _errorMessage = null;
    });

    final success = await ref
        .read(subscriptionServiceProvider)
        .purchasePackage(pkg);
    if (success) {
      ref.read(isProProvider.notifier).state = true;
      if (context.mounted) {
        Navigator.pop(context);
        _showSuccess(context);
      }
    } else {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  Future<void> _handleRestore(BuildContext context, WidgetRef ref) async {
    setState(() {
      _isRestoring = true;
      _errorMessage = null;
    });

    final success =
        await ref.read(subscriptionServiceProvider).restorePurchases();
    if (success) {
      ref.read(isProProvider.notifier).state = true;
      if (context.mounted) {
        Navigator.pop(context);
        _showSuccess(context);
      }
    } else {
      if (mounted) {
        setState(() {
          _isRestoring = false;
          _errorMessage = 'get_started.restore_purchase_failed'.tr();
        });
      }
    }
  }

  void _showSuccess(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text('${'common.success'.tr()}! Welcome to Pro.'),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int delay;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FadeInUp(
      delay: Duration(milliseconds: delay),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AutoSizeText(
                    title,
                    maxLines: 1,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackagesSheet extends StatefulWidget {
  final List<SubscriptionPackage> packages;
  final SubscriptionPackage? selectedPackage;

  const _PackagesSheet({required this.packages, this.selectedPackage});

  @override
  State<_PackagesSheet> createState() => _PackagesSheetState();
}

class _PackagesSheetState extends State<_PackagesSheet> {
  SubscriptionPackage? _currentSelected;

  @override
  void initState() {
    super.initState();
    _currentSelected = widget.selectedPackage ??
        (widget.packages.isNotEmpty ? widget.packages.first : null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Sheet(
      initialOffset: const SheetOffset(1),
      snapGrid: const SheetSnapGrid.stepless(
        minOffset: SheetOffset(0.4),
      ),
      child: SheetContentScaffold(
        body: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
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
              SafeArea(
                bottom: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeInDown(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.orange, Colors.deepOrange],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.workspace_premium_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'profile.premium.upgrade_now'.tr(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ...List.generate(widget.packages.length, (i) {
                        final pkg = widget.packages[i];
                        final isSelected = _currentSelected == pkg;
                        return FadeInUp(
                          delay: Duration(milliseconds: 80 * i),
                          child: _PackageTile(
                            package: pkg,
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                _currentSelected = pkg;
                              });
                            },
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      FadeInUp(
                        delay: Duration(
                          milliseconds: 80 * widget.packages.length,
                        ),
                        child: ElevatedButton(
                          onPressed:
                              _currentSelected == null
                                  ? null
                                  : () {
                                    Navigator.of(context).pop(_currentSelected);
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                            minimumSize: const Size.fromHeight(56),
                          ),
                          child: Text(
                            'profile.premium.upgrade_now'.tr(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
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

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.package,
    required this.isSelected,
    required this.onTap,
  });

  final SubscriptionPackage package;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLifetime = package.type == SubscriptionPackageType.lifetime;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.orange.withValues(alpha: 0.1)
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isLifetime ? Icons.all_inclusive_rounded : Icons.calendar_month_rounded,
              color: isSelected ? Colors.orange : cs.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AutoSizeText(
                          package.title.replaceAll(RegExp(r'\(.*\)'), '').trim(),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: cs.onSurface,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      Text(
                        package.priceString,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isSelected ? Colors.orange : cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  if (package.description.isNotEmpty)
                    AutoSizeText(
                      package.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                      maxLines: 3,
                    ),
                ],
              ),
            ),


          ],
        ),
      ),
    );
  }
}
