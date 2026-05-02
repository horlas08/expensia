import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/shared_preferences_service.dart';
import '../../../../core/services/app_lock_service.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../../core/services/notification_service.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    _startApp();
  }

  Future<void> _startApp() async {
    SharedPreferencesService? prefs;
    try {
      // 1. Initialize core services
      prefs = await SharedPreferencesService.getInstance();
      await ref.read(subscriptionServiceProvider).init();
      final isPro =
          await ref.read(subscriptionServiceProvider).checkEntitlements();
      ref.read(isProProvider.notifier).state = isPro;
      final appLock = ref.read(appLockServiceProvider);
      await NotificationService().init();

      // 2. Wait for animation
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // 3. Check for setup status
      if (!prefs.isFirstPageCompleted()) {
        context.go('/onboarding');
        return;
      }

      // 4. Check for App Lock
      final isLockEnabled = await appLock.isLockEnabled();
      if (!mounted) return;

      if (isLockEnabled && isPro) {
        final authenticated = await appLock.authenticate();
        if (authenticated && mounted) {
          context.go('/dashboard');
        } else {
          // If auth fails or is cancelled, fallback to dashboard
          if (mounted) context.go('/dashboard');
        }
      } else {
        context.go('/dashboard');
      }
    } catch (e) {
      debugPrint('Critical error during app startup: $e');
      // Fallback: Try to respect onboarding status even on crash
      if (mounted) {
        if (prefs != null && !prefs.isFirstPageCompleted()) {
          context.go('/onboarding');
        } else {
          context.go('/dashboard');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Colors.deepPurple.shade900,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Pulse(
              infinite: true,
              duration: const Duration(seconds: 2),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.1),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),
            FadeInUp(
              delay: const Duration(milliseconds: 300),
              child: Text(
                'Expensia',
                style: GoogleFonts.outfit(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeInUp(
              delay: const Duration(milliseconds: 600),
              child: Text(
                'splash.tagline'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
