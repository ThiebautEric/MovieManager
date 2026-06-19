# Movie Manager

Application multiplateforme (**Android + Windows + iOS**) de gestion d'une collection de films/séries,
basée sur le catalogue **TMDB**, avec authentification et synchronisation cloud via **Supabase**.

## Fonctionnalités
- Recherche TMDB + fiche détaillée (affiche, synopsis, genres, casting, bandes-annonces).
- Collection personnelle : possédé, **vu / non-vu**, **note** personnelle et **notes** texte.
- Filtres (genre, année, note, statut) et tableau de bord de **statistiques**.
- Synchronisation entre appareils (même compte) via Supabase.

## Stack
Flutter · Riverpod · go_router · dio · supabase_flutter · freezed · fl_chart

## Prérequis
- Flutter SDK (stable, testé 3.44.2).
- Android : SDK (platform-tools, platforms;android-36, build-tools;36.0.0) + **JDK 17**
  (le JDK 23 casse le compilateur Kotlin des plugins). Pointer Flutter dessus :
  `flutter config --jdk-dir "<chemin-jdk-17>"`.
- Windows : Visual Studio + charge « Développement Desktop en C++ ».
- iOS : un Mac avec Xcode (la compilation iOS est impossible depuis Windows).
- Un projet Supabase + une clé API TMDB (token v4).

> Note Windows : `android/gradle.properties` désactive la compilation incrémentale Kotlin
> (`kotlin.incremental=false`) pour contourner l'erreur « Could not close incremental caches ».

## Deux modes (détection automatique)
- **Mode local** : si les clés Supabase sont absentes (`SUPABASE_URL`/`SUPABASE_ANON_KEY` vides),
  l'app démarre sans connexion et stocke la collection **localement sur l'appareil**
  (via `shared_preferences`). Seule la clé TMDB est nécessaire. Pas de synchro entre appareils.
- **Mode cloud** : si les clés Supabase sont présentes, l'app exige une connexion et synchronise
  la collection via Supabase (multi-appareils).

Le client TMDB accepte aussi bien une **clé API v3** (32 caractères, passée en `api_key`) qu'un
**token v4** (« Bearer »).

## Configuration Supabase
1. Créer un projet sur https://supabase.com.
2. Exécuter `supabase/schema.sql` dans le SQL Editor.
3. Activer l'authentification e-mail/mot de passe (Authentication > Providers).
4. Récupérer `Project URL` et `anon public key` (Project Settings > API).

## Secrets (jamais en dur dans le code)
Les clés sont injectées au build via `--dart-define` :

```powershell
flutter run -d windows `
  --dart-define=TMDB_TOKEN=<token_tmdb_v4> `
  --dart-define=SUPABASE_URL=<project_url> `
  --dart-define=SUPABASE_ANON_KEY=<anon_key>
```

Pour éviter de retaper, créez un fichier `dart_define.json` (non versionné) :

```json
{
  "TMDB_TOKEN": "...",
  "SUPABASE_URL": "https://xxxx.supabase.co",
  "SUPABASE_ANON_KEY": "..."
}
```

puis : `flutter run -d windows --dart-define-from-file=dart_define.json`

## Lancer
```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # génère freezed/json
flutter run -d windows --dart-define-from-file=dart_define.json
flutter run -d <android-device> --dart-define-from-file=dart_define.json
```
