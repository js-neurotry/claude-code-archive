# auto-archive.ps1 - Archivo automatico de conversaciones Claude Code
# Incluye: symlinks para Windows, generacion de Markdown, sanitizacion de secrets

$LogDir = "$env:USERPROFILE\claude-code-logs"
$LogFile = "$LogDir\archive.log"
$ProjectsDir = "$env:USERPROFILE\.claude\projects"

function Write-Log($msg) {
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $LogFile -Value "$timestamp - $msg"
}

Write-Log "Iniciando auto-archive..."

try {
    # =============================================
    # PASO 1: Crear symlinks para workaround Windows
    # claude-code-logs requiere que los directorios empiecen con "-"
    # En Windows los paths se codifican como "C--Users-..." en vez de "-Users-..."
    # =============================================
    $dirs = Get-ChildItem -Path $ProjectsDir -Directory | Where-Object {
        $_.Name -notlike "-*" -and $_.Name -notlike ".*"
    }
    $symlinksCreated = 0
    foreach ($dir in $dirs) {
        $linkName = "-$($dir.Name)"
        $linkPath = Join-Path $ProjectsDir $linkName
        if (-not (Test-Path $linkPath)) {
            New-Item -ItemType SymbolicLink -Path $linkPath -Target $dir.FullName -ErrorAction SilentlyContinue | Out-Null
            if ($?) { $symlinksCreated++ }
        }
    }
    if ($symlinksCreated -gt 0) {
        Write-Log "Symlinks creados: $symlinksCreated"
    }

    # =============================================
    # PASO 2: Generar Markdown con claude-code-logs
    # =============================================
    $process = Start-Process -FilePath "claude-code-logs" `
        -ArgumentList "serve", "--dir", $LogDir `
        -PassThru -NoNewWindow -RedirectStandardOutput "$LogDir\serve-stdout.tmp" `
        -RedirectStandardError "$LogDir\serve-stderr.tmp"

    # Esperar a que genere los archivos (max 30 seg)
    $timeout = 30
    $elapsed = 0
    while (-not $process.HasExited -and $elapsed -lt $timeout) {
        Start-Sleep -Seconds 2
        $elapsed += 2
        # Verificar si ya termino de generar (buscar "Completed" en stdout)
        if (Test-Path "$LogDir\serve-stdout.tmp") {
            $output = Get-Content "$LogDir\serve-stdout.tmp" -Raw -ErrorAction SilentlyContinue
            if ($output -match "Completed|Server starting") { break }
        }
    }

    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    Remove-Item "$LogDir\serve-stdout.tmp", "$LogDir\serve-stderr.tmp" -Force -ErrorAction SilentlyContinue

    Write-Log "Markdown generado"

    # =============================================
    # PASO 3: Sanitizar secrets
    # =============================================
    $sanitizeScript = Join-Path $LogDir "sanitize.sh"
    if (Test-Path $sanitizeScript) {
        $bashPath = (Get-Command bash -ErrorAction SilentlyContinue).Source
        if ($bashPath) {
            & bash $sanitizeScript $LogDir 2>&1 | Out-Null
            Write-Log "Sanitizacion completada"
        } else {
            Write-Log "ADVERTENCIA: bash no encontrado, sanitizacion omitida"
        }
    } else {
        Write-Log "ADVERTENCIA: sanitize.sh no encontrado"
    }

    # =============================================
    # PASO 4: Commit y push
    # =============================================
    Set-Location $LogDir

    $status = git status --porcelain
    if ($status) {
        git add -A
        $fecha = Get-Date -Format "yyyy-MM-dd HH:mm"
        git commit -m "Auto-archive: $fecha"

        $pushResult = git push origin main 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Nuevas conversaciones archivadas y pusheadas"
        } else {
            Write-Log "Commit local OK, push fallo: $pushResult"
        }
    } else {
        Write-Log "Sin cambios nuevos"
    }

} catch {
    Write-Log "ERROR: $_"
}
