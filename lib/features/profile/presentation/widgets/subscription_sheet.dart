import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:animate_do/animate_do.dart';
import 'package:go_router/go_router.dart';
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

  List<Package>? _packages;
  Package? _selectedPackage;
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
      builder: (context, scrollController) => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        clipBehavior: Clip.antiAlias,
        child: Container(
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
                    subtitle: 'profile.premium.unlimited_transactions_desc'.tr(),
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
                    subtitle: 'profile.premium.advanced_analytics_desc'.tr(),
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
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
                      child: Center(child: Text('profile.premium.no_packages'.tr())),
                    )
                  else
                    Column(
                      children: _packages!.map((pkg) => _PackageCard(
                        package: pkg,
                        isSelected: _selectedPackage == pkg,
                        onTap: () => setState(() => _selectedPackage = pkg),
                      )).toList(),
                    ),
                  const SizedBox(height: 16),

                  FadeInUp(
                    delay: const Duration(milliseconds: 600),
                    child: ElevatedButton(
                      onPressed: (_isPurchasing || _isRestoring || _selectedPackage == null) ? null : () => _handlePurchase(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: _isPurchasing 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            'profile.premium.upgrade_now'.tr(),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeInUp(
                    delay: const Duration(milliseconds: 700),
                    child: TextButton(
                      onPressed: (_isPurchasing || _isRestoring) ? null : () => _handleRestore(context, ref),
                      child: _isRestoring
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            'get_started.restore_purchase'.tr(),
                            style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
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
    ),
    );
  }

  Future<void> _handlePurchase(BuildContext context, WidgetRef ref) async {
    if (_selectedPackage == null) return;
    
    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });
    
    final success = await ref.read(subscriptionServiceProvider).purchasePackage(_selectedPackage!);
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

    final success = await ref.read(subscriptionServiceProvider).restorePurchases();
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
        content: Text('common.success'.tr() + '! Welcome to Pro.'),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.5), fontSize: 10, ),
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

class _PackageCard extends StatelessWidget {
  final Package package;
  final bool isSelected;
  final VoidCallback onTap;

  const _PackageCard({
    required this.package,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLifetime = package.packageType == PackageType.lifetime;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.withValues(alpha: 0.1) : cs.surfaceContainerHighest.withValues(alpha: 0.3),
          border: Border.all(
            color: isSelected ? Colors.orange : cs.outlineVariant.withValues(alpha: 0.3),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              isLifetime ? Icons.all_inclusive_rounded : Icons.calendar_month_rounded,
              color: isSelected ? Colors.orange : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.storeProduct.title.replaceAll(RegExp(r'\(.*\)'), '').trim(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSelected ? Colors.orange : cs.onSurface,
                    ),
                  ),
                  if (package.storeProduct.description.isNotEmpty)
                    Text(
                      package.storeProduct.description,
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            Text(
              package.storeProduct.priceString,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isSelected ? Colors.orange : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
