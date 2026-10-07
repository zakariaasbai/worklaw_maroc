import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';

class WorkLawHomeScreen extends ConsumerWidget {
  const WorkLawHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WorkLaw Maroc'),
        actions: [
          IconButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('WorkLaw Maroc — MVP en construction'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/employees'),
              child: const Text('Voir les employés'),
            ),
          ],
        ),
      ),
    );
  }
}
