# Déploiement Yellow Frame
#   - Web     → Cloudflare Pages (https://theyellowframe.pages.dev)
#   - Android → APK release (build/app/outputs/flutter-apk/app-release.apk)
#
# Usage :
#   .\deploy.ps1                 # web (build + deploy) puis APK Android
#   .\deploy.ps1 -SkipAndroid    # web uniquement
#   .\deploy.ps1 -SkipWeb        # APK Android uniquement
#
# Prérequis : Flutter (C:\flutter), npx + wrangler authentifié (pour le web).

param(
    [switch]$SkipWeb,
    [switch]$SkipAndroid
)

$flutter = "C:\flutter\bin\flutter.bat"

# Clés injectées à la compilation — partagées par le web ET l'Android (sinon
# l'app afficherait « Configuration manquante »). Définies une seule fois.
$defines = @(
    "--dart-define=TMDB_TOKEN=3889808a354ed5f7476794b8b4abc105",
    "--dart-define=SUPABASE_URL=https://msawdukkcgjkxfktthdj.supabase.co",
    "--dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1zYXdkdWtrY2dqa3hma3R0aGRqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2MTU3MjAsImV4cCI6MjA5NzE5MTcyMH0.0UG-Fd0SxpZM2CbVmU2e301E6UqYI8jCexurqGUVxSY",
    "--dart-define=VISION_API_KEY=AIzaSyAqCzHQkKl0hYOguyaJhiWyDQkjwtKHSaE"
)

# --- Web ---------------------------------------------------------------------
if (-not $SkipWeb) {
    Write-Host "Building Flutter web..." -ForegroundColor Cyan
    & $flutter build web --release $defines
    if ($LASTEXITCODE -ne 0) { Write-Host "Web build failed." -ForegroundColor Red; exit 1 }

    Write-Host "Deploying to Cloudflare Pages..." -ForegroundColor Cyan
    npx wrangler pages deploy build/web --project-name=theyellowframe --branch=main --commit-dirty=true
    if ($LASTEXITCODE -ne 0) { Write-Host "Deploy failed." -ForegroundColor Red; exit 1 }
    Write-Host "Deployed! https://theyellowframe.pages.dev" -ForegroundColor Green
}

# --- Android -----------------------------------------------------------------
if (-not $SkipAndroid) {
    # Source unique de version : kDeployVersion (lib/core/config/app_version.dart).
    # On l'injecte comme versionCode (entier croissant) et versionName pour que
    # la version Android soit cohérente et traçable avec le reste de l'app.
    $verFile = "lib/core/config/app_version.dart"
    $deploy = [regex]::Match((Get-Content $verFile -Raw), 'kDeployVersion\s*=\s*(\d+)').Groups[1].Value
    if (-not $deploy) {
        Write-Host "Impossible de lire kDeployVersion dans $verFile." -ForegroundColor Red; exit 1
    }

    Write-Host "Building Android APK (version 1.0.$deploy, code $deploy)..." -ForegroundColor Cyan
    & $flutter build apk --release --build-name="1.0.$deploy" --build-number=$deploy $defines
    if ($LASTEXITCODE -ne 0) { Write-Host "Android build failed." -ForegroundColor Red; exit 1 }

    $apk = "build/app/outputs/flutter-apk/app-release.apk"
    Write-Host "APK release prêt : $apk (v1.0.$deploy)" -ForegroundColor Green
}
