import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertConfigured();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );
  runApp(const ProviderScope(child: WorkLawMarocApp()));
}

class WorkLawMarocApp extends StatelessWidget {
  const WorkLawMarocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'WorkLaw Maroc',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      routerConfig: appRouter,
    );
  }
}
