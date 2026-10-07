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
