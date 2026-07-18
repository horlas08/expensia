import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/shared_preferences_service.dart';
import 'core/services/recurring_transaction_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EasyLocalization.ensureInitialized();

  // Initialize AdMob before runApp so the SDK is ready
  // before any ad requests can be triggered by the user.
  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint('AdMob initialization failed: $e');
  }

  // Load persisted theme before first frame
  final prefs = await SharedPreferencesService.getInstance();
  final savedDark = prefs.isDarkMode();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        path: 'assets/lang',
        fallbackLocale: const Locale('en'),
        useOnlyLangCode: true,
        child: ExpensiaApp(initDark: savedDark),
      ),
    ),
  );

  unawaited(_warmUpRecurringTransactions());
}

Future<void> _warmUpRecurringTransactions() async {
  try {
    await RecurringTransactionService().processDueTransactions();
  } catch (e) {
    debugPrint('Recurring transactions warm-up failed: $e');
  }
}

class ExpensiaApp extends ConsumerWidget {
  const ExpensiaApp({super.key, required this.initDark});
  final bool initDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read locale here — when EasyLocalization rebuilds (locale switch),
    // this whole Widget rebuilds and passes the fresh locale down.
    final locale = context.locale;

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return ThemeProvider(
          initTheme: initDark ? AppTheme.darkTheme : AppTheme.lightTheme,
          builder: (context, theme) {
            // applyLocaleFont is called every time theme OR locale changes
            final themedForLocale = AppTheme.applyLocaleFont(theme, locale);

            // ThemeSwitchingArea is placed HERE (above MaterialApp) so:
            // 1. The ripple animation covers the entire app (global effect).
            // 2. MaterialApp's `theme: themedForLocale` (with Cairo) is BELOW
            //    ThemeSwitchingArea's AnimatedTheme in the widget tree, so
            //    Theme.of(context) inside every route returns the Cairo theme.
            //    We no longer need per-page ThemeSwitchingArea wrappers.
            return ThemeSwitchingArea(
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                title: 'Expensia pro',
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: locale,
                theme: themedForLocale,
                routerConfig: appRouter,
                builder: (context, child) {
                  return GestureDetector(
                    onTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                    child: MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: const TextScaler.linear(1.3)),
                      child: child!,
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
