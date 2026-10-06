import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WorkLawHomeScreen extends StatelessWidget {
  const WorkLawHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WorkLaw Maroc')),
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
