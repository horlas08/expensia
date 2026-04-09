import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animated_theme_switcher/animated_theme_switcher.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await EasyLocalization.ensureInitialized();

  runApp(
    ProviderScope(
      child: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        path: 'assets/lang',
        fallbackLocale: const Locale('en'),
        child: const ExpensiaApp(),
      ),
    ),
  );
}

class ExpensiaApp extends ConsumerWidget {
  const ExpensiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), // Standard iPhone dimension
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return ThemeProvider(
          initTheme: AppTheme.lightTheme,
          builder: (context, theme) {
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              title: 'Expensia'.tr(), // using easy_localization tr() early usage
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              theme: theme,
              // go_router
              routerConfig: appRouter,
              builder: (context, child) {
                // Ensure text sizes do not scale uncontrollably by OS settings, 
                // but still scale according to ScreenUtil.
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
