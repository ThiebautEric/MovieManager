#!/bin/sh
# Build Cloudflare Pages — la commande du dashboard est limitée à 512
# caractères, donc tout vit ici et le dashboard appelle : sh cloudflare_build.sh
# (Build output directory : build/web)
#
# Les clés ci-dessous sont volontairement en dur : la clé anon Supabase et le
# token TMDB sont publics par nature (présents dans le bundle JS servi au
# navigateur) ; la sécurité des données repose sur les politiques RLS.
set -e

git clone https://github.com/flutter/flutter.git --depth 1 -b stable
export PATH="$PATH:$PWD/flutter/bin"
flutter pub get
flutter build web --release \
  --dart-define=TMDB_TOKEN=3889808a354ed5f7476794b8b4abc105 \
  --dart-define=SUPABASE_URL=https://msawdukkcgjkxfktthdj.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1zYXdkdWtrY2dqa3hma3R0aGRqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2MTU3MjAsImV4cCI6MjA5NzE5MTcyMH0.0UG-Fd0SxpZM2CbVmU2e301E6UqYI8jCexurqGUVxSY
