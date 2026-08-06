# Déploiement Yellow Frame → Cloudflare Pages
# Usage : .\deploy.ps1
# Prérequis : Flutter dans PATH, npx disponible, wrangler authentifié

$flutter = "C:\flutter\bin\flutter.bat"

Write-Host "Building Flutter web..." -ForegroundColor Cyan
& $flutter build web --release `
  --dart-define=TMDB_TOKEN=3889808a354ed5f7476794b8b4abc105 `
  --dart-define=SUPABASE_URL=https://msawdukkcgjkxfktthdj.supabase.co `
  "--dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1zYXdkdWtrY2dqa3hma3R0aGRqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2MTU3MjAsImV4cCI6MjA5NzE5MTcyMH0.0UG-Fd0SxpZM2CbVmU2e301E6UqYI8jCexurqGUVxSY"

if ($LASTEXITCODE -ne 0) { Write-Host "Build failed." -ForegroundColor Red; exit 1 }

Write-Host "Deploying to Cloudflare Pages..." -ForegroundColor Cyan
npx wrangler pages deploy build/web --project-name=theyellowframe --branch=main --commit-dirty=true

if ($LASTEXITCODE -eq 0) {
    Write-Host "Deployed! https://theyellowframe.pages.dev" -ForegroundColor Green
} else {
    Write-Host "Deploy failed." -ForegroundColor Red; exit 1
}
