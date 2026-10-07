import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:worklaw_maroc/l10n/generated/app_localizations.dart';
import 'core/config/env.dart';
import 'core/localization/locale_provider.dart';
import 'core/routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Path-based URLs (no '#') on web, so the '#' fragment stays free for
  // Supabase's email-link token detection (confirmation/password-reset
  // links) instead of colliding with go_router's own URL parsing.
  usePathUrlStrategy();
  Env.assertConfigured();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );
  runApp(const ProviderScope(child: WorkLawMarocApp()));
}

class WorkLawMarocApp extends ConsumerWidget {
  const WorkLawMarocApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'WorkLaw Maroc',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      locale: ref.watch(localeProvider),
      supportedLocales: supportedAppLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
