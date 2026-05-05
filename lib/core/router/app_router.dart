import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/get_started.dart';
import '../../features/auth/presentation/pages/setup_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';

import '../../features/profile/presentation/pages/html_content_page.dart';
import 'package:easy_localization/easy_localization.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingPage(),
    ),
    GoRoute(
      path: '/first',
      builder: (context, state) => const GetStartedPage(),
    ),
    GoRoute(
      path: '/setup',
      builder: (context, state) => const SetupPage(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardPage(),
    ),
    GoRoute(
      path: '/privacy-policy',
      builder: (context, state) => HtmlContentPage(
        title: 'profile.privacy_policy'.tr(),
        assetPath: 'assets/privacy-policy.html',
      ),
    ),
    GoRoute(
      path: '/terms-of-use',
      builder: (context, state) => HtmlContentPage(
        title: 'profile.terms'.tr(),
        assetPath: 'assets/terms-use.html',
      ),
    ),
  ],
);
