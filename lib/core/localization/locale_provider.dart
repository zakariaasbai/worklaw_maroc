import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const supportedAppLocales = [Locale('fr'), Locale('ar'), Locale('en')];

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => const Locale('fr');

  void setLocale(Locale locale) => state = locale;
}

/// In-memory only (no persistence) — a per-session language choice is
/// enough for this milestone; wiring it to a stored preference can follow
/// later without touching this provider's shape.
final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);
