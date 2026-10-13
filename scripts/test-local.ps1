param(
    [string]$FlutterExecutable = "flutter",
    [switch]$BackendOnly,
    [switch]$FrontendOnly
)

$ErrorActionPreference = "Stop"
if ($BackendOnly -and $FrontendOnly) {
    throw "Elige BackendOnly o FrontendOnly, no ambos."
}
$repoRoot = Split-Path -Parent $PSScriptRoot
$originalLocation = Get-Location
try {
    Set-Location -LiteralPath $repoRoot
    if (-not $FrontendOnly) {
        docker build -f backend/Dockerfile.test -t dnd-backend-tests:local backend
        if ($LASTEXITCODE -ne 0) { throw "Falló la construcción del entorno de tests." }
        $reportPath = Join-Path $repoRoot "backend/coverage"
        New-Item -ItemType Directory -Path $reportPath -Force | Out-Null
        $reportMount = "type=bind,source=$reportPath,target=/reports"
        docker run --rm --network none --mount $reportMount dnd-backend-tests:local python -m pytest --cov=app --cov-branch --cov-report=term-missing --cov-report=html:/reports/html --cov-report=json:/reports/coverage.json
        if ($LASTEXITCODE -ne 0) { throw "Fallaron las pruebas del backend." }
    }
    if (-not $BackendOnly) {
        Set-Location -LiteralPath (Join-Path $repoRoot "dnd_frontend")
        & $FlutterExecutable test --coverage
        if ($LASTEXITCODE -ne 0) { throw "Fallaron las pruebas del frontend." }
        & $FlutterExecutable analyze
        if ($LASTEXITCODE -ne 0) { throw "Flutter Analyze encontró problemas." }
    }
} finally {
    Set-Location -LiteralPath $originalLocation.Path
}

