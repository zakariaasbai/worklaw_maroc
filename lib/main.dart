import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: WorkLawMarocApp()));
}

class WorkLawMarocApp extends StatelessWidget {
  const WorkLawMarocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WorkLaw Maroc',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const _PlaceholderHomePage(),
    );
  }
}

class _PlaceholderHomePage extends StatelessWidget {
  const _PlaceholderHomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WorkLaw Maroc')),
      body: const Center(child: Text('WorkLaw Maroc — MVP en construction')),
    );
  }
}
