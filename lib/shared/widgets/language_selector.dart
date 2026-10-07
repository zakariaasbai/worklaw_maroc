import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:worklaw_maroc/l10n/generated/app_localizations.dart';
import '../../core/localization/locale_provider.dart';

class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);

    return DropdownButton<Locale>(
      value: currentLocale,
      underline: const SizedBox.shrink(),
      onChanged: (locale) {
        if (locale != null) {
          ref.read(localeProvider.notifier).setLocale(locale);
        }
      },
      items: [
        DropdownMenuItem(
          value: const Locale('fr'),
          child: Text(l10n.languageFrench),
        ),
        DropdownMenuItem(
          value: const Locale('ar'),
          child: Text(l10n.languageArabic),
        ),
        DropdownMenuItem(
          value: const Locale('en'),
          child: Text(l10n.languageEnglish),
        ),
      ],
    );
  }
}
