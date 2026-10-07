# Roadmap & dette technique — WorkLaw Maroc

## Dette technique connue

- **Écrans employés du Milestone 3 à traduire** : `lib/features/employees/presentation/*` et `lib/shared/widgets/work_law_home_screen.dart` contiennent du texte en dur en français. Le Milestone 4 a mis en place toute l'infrastructure FR/AR/EN (`l10n.yaml`, `lib/l10n/*.arb`, génération `AppLocalizations`) mais ne l'a appliquée qu'aux écrans d'authentification. Migrer les écrans employés vers `AppLocalizations` reste à faire.
- **Déploiement web** : configurer la redirection de toutes les routes vers `index.html` (path URL strategy) — nécessaire côté serveur d'hébergement en production, en complément de `usePathUrlStrategy()` déjà activé côté Flutter (Milestone 4).
