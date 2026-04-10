import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animated_theme_switcher/animated_theme_switcher.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/shared_preferences_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EasyLocalization.ensureInitialized();

  // Load persisted theme before first frame
  final prefs = await SharedPreferencesService.getInstance();
  final savedDark = prefs.isDarkMode();

  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        path: 'assets/lang',
        fallbackLocale: const Locale('en'),
        child: ExpensiaApp(initDark: savedDark),
      ),
    ),
  );
}

class ExpensiaApp extends ConsumerWidget {
  const ExpensiaApp({super.key, required this.initDark});
  final bool initDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return ThemeProvider(
          initTheme: initDark ? AppTheme.darkTheme : AppTheme.lightTheme,
          builder: (context, theme) {
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              title: 'Expensia',
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              theme: theme,
              routerConfig: appRouter,
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.0),
                  ),
                  child: child!,
                );
              },
            );
          },
        );
      },
    );
  }
}
