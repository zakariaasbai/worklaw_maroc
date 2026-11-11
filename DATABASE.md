# Base de données — WorkLaw Maroc

## Prérequis

- Docker Desktop en cours d'exécution (Supabase local tourne dans des conteneurs).
- Node.js installé (on utilise `npx supabase`, pas besoin d'installer la CLI globalement).

## Démarrer Supabase en local

```bash
# Depuis la racine du projet.
# Si supabase/config.toml n'existe pas encore :
npx supabase init

# Démarre Postgres, Auth (GoTrue), Storage, etc. en local via Docker.
npx supabase start

# Applique toutes les migrations de supabase/migrations/ sur une base fraîche.
npx supabase db reset
```

`npx supabase status` affiche l'URL de l'API, la clé `anon`, et l'URL de connexion Postgres locale — nécessaires pour l'étape suivante et pour faire tourner l'app Flutter en local (voir `env.example.json`).

## Migrations

| Migration | Contenu |
|---|---|
| `supabase/migrations/20260917120000_create_organizations_schema.sql` | Milestone 2 : `profiles`, `organizations`, `organization_members`, trigger `handle_new_user`, RLS de base |
| `supabase/migrations/20260929120000_employees_schema.sql` | Milestone 3 : `contract_types`, `employees`, `employee_sensitive_data`, RLS (dont accès salaire/CNSS/CIN réservé owner/admin) |
| `supabase/migrations/20261105120000_legal_rules_schema.sql` | Milestone 5 Partie B : `legal_sources`, `legal_rules` (versionnée, garde-fous DB), vue `legal_rules_active`, fonction `get_applicable_rule()`, `calculation_runs` / `calculation_run_rules` (immuables). **Aucune règle ni source n'est seedée.** |
| `supabase/migrations/20261109120000_security_hardening.sql` | Audit sécurité : FK composites (`employee_id`/`organization_id` cross-checkées via `employees`/`calculation_runs`/`calculation_run_rules`), policies RLS restreintes explicitement `to authenticated`, immutabilité `legal_rules` renforcée (régression de statut bloquée, `verified_by`/`verified_at`/`legal_source_id`/`jurisdiction` protégés), `EXECUTE` resserré sur les fonctions `SECURITY DEFINER`, trigger `prevent_employee_organization_change()` (`employees.organization_id` immuable après création). Voir le rapport d'audit pour le détail. |

Toute nouvelle migration se crée avec :

```bash
npx supabase migration new <nom_descriptif>
```

## Projet distant (pas de Docker/WSL2 disponible en local sur cette machine)

Sur cette machine, Docker Desktop ne peut pas démarrer (WSL2 non installé) — le développement se fait donc contre un vrai projet Supabase cloud plutôt qu'une instance locale. Pour appliquer une migration dessus :

```bash
npx supabase login              # une fois, ouvre le navigateur
npx supabase link --project-ref <project-ref>   # demande le mot de passe DB au prompt
npx supabase db push            # applique les migrations en attente sur le projet distant
```

`SUPABASE_DB_URL` pour ce projet distant se trouve dans Project Settings → Database → Connection string → URI (remplacer `[YOUR-PASSWORD]` par le mot de passe DB du projet).

## Tester le trigger `handle_new_user()`

Le trigger crée `profiles` + `organizations` + `organization_members` de façon atomique à chaque signup (voir le commentaire en tête de la migration). Le test d'intégration appelle le **vrai endpoint GoTrue local** (le même que celui utilisé par l'app Flutter) plutôt que d'insérer directement dans `auth.users` — ça évite de dépendre du schéma interne exact de cette table, qui peut changer entre versions de Supabase.

```bash
# 1. Supabase local doit tourner (npx supabase start), avec les migrations appliquées.

# 2. Récupérer les valeurs de connexion.
npx supabase status

# 3. Les exporter (remplacer par les vraies valeurs affichées ci-dessus).
export SUPABASE_URL=http://127.0.0.1:54321
export SUPABASE_ANON_KEY=<anon key affichée par supabase status>
export SUPABASE_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres

# 4. Lancer le test.
bash supabase/tests/handle_new_user_test.sh
```

Le script vérifie :
1. **Chemin nominal** : un signup avec `full_name` et `organization_name` valides crée bien 1 ligne `profiles`, 1 ligne `organizations`, et 1 ligne `organization_members` avec `role = 'owner'`.
2. **Rejet + atomicité** : un signup avec `organization_name` vide échoue côté API, et ne laisse **aucune** ligne orpheline dans `auth.users` — preuve que la transaction complète (y compris l'insert Auth) a bien été annulée par l'exception levée dans le trigger.

## Tester le module employés (Milestone 3)

Trois scripts, mêmes variables d'environnement que ci-dessus (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_DB_URL`) :

```bash
bash supabase/tests/employees_crud_test.sh
bash supabase/tests/employees_isolation_test.sh
bash supabase/tests/employee_sensitive_data_role_test.sh
```

- **`employees_crud_test.sh`** : create/read/update/archive d'un employé, puis vérifie qu'une tentative de `DELETE` échoue silencieusement (aucune policy DELETE → la ligne reste présente) — la suppression définitive est bloquée au niveau base, pas juste par l'UI.
- **`employees_isolation_test.sh`** : deux organisations créées via deux signups distincts ; l'organisation B ne peut ni lire ni modifier un employé de l'organisation A, même en connaissant son `id`.
- **`employee_sensitive_data_role_test.sh`** : vérifie que `employee_sensitive_data` (salaire, CNSS, CIN) n'est visible que par `owner`/`admin`, jamais par un `member`. La préparation (ajout du membre avec `role = 'member'`) passe par `SUPABASE_DB_URL` — connexion directe qui bypasse RLS, seul moyen de simuler ce rôle tant qu'il n'y a pas de flux d'invitation — mais la **vérification** passe entièrement par la clé anon + un vrai JWT obtenu en se connectant en tant que ce membre, exactement comme le ferait l'app Flutter. Si la vérification utilisait aussi la connexion directe, le test ne prouverait rien sur le comportement RLS réel.

`supabase/tests/_helpers.sh` contient les fonctions communes (signup, signin, appels REST, parsing JSON minimal) réutilisées par ces trois scripts.

## Règles légales (Milestone 5 Partie B) — comment une règle entre en base

Il n'existe **aucune policy INSERT/UPDATE/DELETE côté client** sur `legal_sources` et `legal_rules` — volontairement. Il n'y a pas encore de rôle "staff interne" (`platform_staff` ou équivalent) distinct des rôles `owner/admin/member` qui sont des rôles *par organisation cliente*, pas des rôles internes à l'équipe WorkLaw.

**En attendant ce rôle (prévu avec le futur panneau d'administration) :** toute règle ou source légale s'ajoute soit par une migration (`npx supabase migration new ...`), soit directement via le **SQL Editor** du dashboard Supabase — jamais depuis l'app. Les garde-fous (statut `DRAFT→...→ACTIVE`, immutabilité une fois `VERIFIED`/`ACTIVE`, non-chevauchement des périodes) sont au niveau base, donc ils s'appliquent même à ces insertions manuelles — il n'y a pas de "mode admin" qui les contourne, et c'est volontaire.

## Tester les règles légales (Milestone 5 Partie B)

Trois scripts, mêmes variables d'environnement que ci-dessus :

```bash
bash supabase/tests/legal_rules_constraints_test.sh
bash supabase/tests/legal_rules_visibility_test.sh
bash supabase/tests/calculation_runs_test.sh
```

- **`legal_rules_constraints_test.sh`** : chaque scénario tourne dans un `BEGIN`/`ROLLBACK` (rien n'est jamais commité) et vérifie, via la connexion directe : `legal_source_id` obligatoire à partir de `SOURCE_FOUND`, `verified_by`/`verified_at` obligatoires à partir de `VERIFIED`, `rule_definition` immuable une fois `VERIFIED`, deux périodes qui se chevauchent pour le même `rule_key` sont rejetées, `get_applicable_rule()` retrouve bien la version qui était en vigueur à une date passée (pas la version actuelle), et (ajouté par l'audit sécurité) qu'une régression de statut `ACTIVE → DRAFT` est rejetée et que `verified_at` est lui aussi immuable une fois `VERIFIED`.
- **`legal_rules_visibility_test.sh`** : une ligne `DRAFT` et une ligne `ACTIVE` sont créées via `SUPABASE_DB_URL` (seul moyen, pas de policy d'écriture côté client) ; la vérification passe par la clé anon + un vrai JWT — seule la ligne `ACTIVE` est visible via l'API, `legal_sources` est lisible intégralement.
- **`calculation_runs_test.sh`** : isolation multi-tenant sur `calculation_runs`/`calculation_run_rules` (même pattern que Milestone 3), vérifie qu'une tentative de `UPDATE` ou `DELETE` ne change rien, qu'un `calculated_by` forgé (différent de l'utilisateur connecté) est rejeté, et (ajouté par l'audit sécurité) qu'un `calculation_runs` référençant un `employee_id` d'une autre organisation est rejeté.

## Audit sécurité (Milestone 5 hardening) — tests dédiés

```bash
bash supabase/tests/employee_sensitive_data_cross_org_test.sh
bash supabase/tests/anon_vs_authenticated_test.sh
bash supabase/tests/employees_organization_immutability_test.sh
```

- **`employee_sensitive_data_cross_org_test.sh`** : avant le correctif (`20261109120000_security_hardening.sql`), un owner/admin de l'organisation B pouvait insérer une ligne `employee_sensitive_data` avec `employee_id` pointant vers un employé de l'organisation A tout en déclarant `organization_id = B` — l'ancienne policy INSERT ne vérifiait que `organization_id`, jamais la cohérence avec l'employé réellement référencé. Ce test le vérifie via la clé anon + un vrai JWT (chemin réellement accessible depuis le client, pas seulement en théorie).
- **`anon_vs_authenticated_test.sh`** : appelle réellement l'API REST avec la clé anon **seule** (sans session utilisateur) sur `/rest/v1/employees` et `/rest/v1/organizations` — vérifie qu'aucune ligne n'est retournée, puis vérifie qu'un membre authentifié de l'organisation garde un accès normal à ses propres données. Ne se contente pas d'inspecter les policies en SQL.
- **`employees_organization_immutability_test.sh`** : crée un utilisateur privilégié dans **deux** organisations (seul cas réaliste où le trou aurait pu être exploité), tente de changer `organization_id` d'un employé de l'organisation A vers l'organisation B → rejeté par `prevent_employee_organization_change()` ; vérifie ensuite qu'une modification normale (`department`) sur le même employé fonctionne toujours.

Les autres nouveaux tests de l'audit (régression de statut, `verified_at` immuable, `calculation_runs` cross-org) sont intégrés directement dans `legal_rules_constraints_test.sh` et `calculation_runs_test.sh` ci-dessus plutôt que dans des fichiers séparés.

## Lancer tous les tests d'un coup

```bash
bash supabase/tests/run_all.sh
```

Demande interactivement, dans l'ordre : `SUPABASE_ANON_KEY` (saisie visible, pas un secret — mais son format est validé : doit commencer par `eyJ` ou `sb_publishable_` et dépasser 40 caractères, sinon le script s'arrête avec un message clair plutôt que de laisser échouer les 10 tests), l'hôte du **Session Pooler** (ex. `aws-0-eu-west-3.pooler.supabase.com` — visible dans Project Settings → Database → Connection pooling → Session pooler), et le mot de passe DB (saisie masquée, `read -s`, percent-encodé dans l'URI). Aucun des deux secrets n'est jamais écrit dans un fichier ni affiché. **Ne jamais lancer ce script avec `bash -x`** — ça afficherait `SUPABASE_DB_URL`, qui contient le mot de passe.

Avant de lancer les 10 tests, le script fait un unique `select 1;` via le pooler pour vérifier la connexion — s'il échoue, il affiche la cause exacte et s'arrête immédiatement, plutôt que de laisser 10 tests échouer un par un pour la même raison. Le résumé final liste, pour chaque test en échec, la première ligne d'erreur pertinente (plus besoin de faire défiler toute la sortie pour comprendre pourquoi un test a échoué).

### Pourquoi le Session Pooler et pas la connexion directe

L'hôte de connexion directe (`db.<ref>.supabase.co`) est IPv6 uniquement sur de nombreux projets Supabase — injoignable depuis WSL2 par défaut (pas de sortie IPv6 sans configuration réseau supplémentaire), avec une erreur typique `Network is unreachable`. Le Session Pooler (`aws-0-<région>.pooler.supabase.com`) est compatible IPv4 et conçu précisément pour ce cas. Avec le pooler, l'utilisateur de connexion devient `postgres.<project-ref>` (pas juste `postgres`) — `run_all.sh` construit déjà ça correctement.

### Limite d'envoi d'emails (HTTP 429 `over_email_send_rate_limit`)

Chaque `signup()` dans les tests déclenche un email de confirmation réel (puisque **Confirm email reste activé**, volontairement — ne pas le désactiver). Le service d'envoi d'emails par défaut de Supabase (sans SMTP personnalisé) a une limite horaire très basse, vite atteinte en lançant toute la suite de tests. Recommandation : configurer un SMTP personnalisé côté dashboard (Authentication → Email → SMTP Settings) — ça lève la limite par défaut et c'est de toute façon nécessaire avant un lancement commercial (les emails de confirmation/réinitialisation ne doivent pas partir d'une adresse Supabase partagée pour de vrais clients). Une amélioration complémentaire possible côté tests : des comptes de test stables, confirmés une fois, avec connexion (`signin()`) plutôt que ré-inscription quand le compte existe déjà — à faire si la limite reste un problème même avec un SMTP personnalisé.

## Arrêter Supabase local

```bash
npx supabase stop
```

## Configurer l'app Flutter pour pointer vers Supabase local

```bash
cp env.example.json env.json
# Éditer env.json : SUPABASE_URL = http://127.0.0.1:54321 (ou l'URL du projet distant),
# SUPABASE_ANON_KEY = valeur de `npx supabase status`.
# env.json est gitignoré — ne jamais le commiter.
```

### VS Code

Une configuration de lancement est déjà présente dans `.vscode/launch.json` (`worklaw_maroc (env.json)`), qui passe `--dart-define-from-file=env.json`. Sélectionnez-la dans l'onglet "Run and Debug".

### Android Studio / IntelliJ

1. Run → Edit Configurations…
2. Sélectionner (ou créer) la configuration Flutter pour `lib/main.dart`.
3. Dans le champ **Additional run args**, ajouter :
   ```
   --dart-define-from-file=env.json
   ```
4. Appliquer.

### Ligne de commande

```bash
flutter run --dart-define-from-file=env.json
```

## Auth — configuration requise côté dashboard Supabase (Milestone 4)

Les emails de confirmation de compte et de réinitialisation de mot de passe contiennent un lien de retour vers l'app. Ce lien doit être whitelisté dans **Authentication → URL Configuration** sur le projet distant, sinon Supabase refuse la redirection.

Pour le développement local en Flutter Web, fixez d'abord un port stable (le port change à chaque lancement sinon) :

```bash
flutter run -d chrome --web-port=5000 --dart-define-from-file=env.json
```

Puis configurez, dans **Authentication → URL Configuration** :

- **Site URL** : `http://localhost:5000`
- **Redirect URLs** (ajouter) :
  - `http://localhost:5000/**`

Le `**` couvre tous les chemins de l'app (`/login`, `/reset-password`, etc.) — Supabase supporte les wildcards dans cette liste. Si vous préférez être explicite plutôt que d'utiliser un wildcard, ajoutez individuellement `http://localhost:5000`, `http://localhost:5000/login` et `http://localhost:5000/reset-password`.

**Confirm email** reste activé sur ce projet (vérifié dans le dashboard : activé, longueur minimale de mot de passe = 8 — c'est la valeur utilisée par la validation Flutter, voir `lib/features/auth/domain/auth_validators.dart`). Si cette config change côté dashboard, `supabaseMinPasswordLength` dans ce fichier doit être mis à jour en conséquence.
