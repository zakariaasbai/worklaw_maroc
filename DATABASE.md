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

Le schéma du Milestone 2 (`profiles`, `organizations`, `organization_members`, trigger `handle_new_user`, RLS) est dans :

```
supabase/migrations/20260917120000_create_organizations_schema.sql
```

Toute nouvelle migration se crée avec :

```bash
npx supabase migration new <nom_descriptif>
```

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
