# Roadmap & dette technique — WorkLaw Maroc

## Dette technique connue

- **Écran d'accueil à traduire** : `lib/shared/widgets/work_law_home_screen.dart` contient encore du texte en dur en français (bouton déconnexion, titre). Les écrans d'authentification (Milestone 4) et employés (Milestone 5) sont traduits via `AppLocalizations` ; cet écran reste à migrer.
- **Libellés des types de contrat non localisés** : `contract_types` a des colonnes `label_fr`/`label_ar`/`label_en` en base, mais le modèle Flutter `ContractType` (`lib/features/employees/domain/contract_type.dart`) n'expose que `labelFr`, donc "CDI"/"CDD" s'affichent toujours en français dans le formulaire et la fiche employé, quelle que soit la langue choisie. Ce n'est pas une chaîne en dur dans le code (c'est une donnée issue de la base), donc le grep de vérification ne le détecte pas — à corriger en exposant le bon label selon la locale active.
- **Déploiement web** : configurer la redirection de toutes les routes vers `index.html` (path URL strategy) — nécessaire côté serveur d'hébergement en production, en complément de `usePathUrlStrategy()` déjà activé côté Flutter (Milestone 4).
