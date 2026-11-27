# Starts the title with the settings this fork is played with (README.md, "How to run it").
#   scripts\play.ps1 -Exe <path of your own copy's executable>
# -Safe         without the newer, faster ways (the first thing to try when something is wrong)
# -RayTracing   the title's own ray-traced indirect light: lit interiors, about a third slower
# -Low (-Leve)  for a modest PC (16 GB of RAM, a 12 GB card such as the RTX 3060), in steps
#               (-Level/-Nivel 1 to 4, 1 unless told): each adds to the one before, the later
#               ones change the picture the title makes and are untried; docs/pc-modesto.md
# -Console      series-x (default) or series-s: the console the title believes it runs on
# -Display WxH  the television the console reports (3840x2160 unless told)
# -SkipShaders  names of the title's programs whose draws and dispatches are left out
#               (VICTORY_SKIP_NAMED, diag build only): -SkipShaders 'CS_Name1,PS_Name2'
# -Build        target\diag (the default, the build all measurements are of) or target\release
# -More         other settings: -More @{VICTORY_PANEL='1'}
# Every run's log goes to %LOCALAPPDATA%\victory\logs as well; what went wrong is said at the end.
# Run it from a normal window, not as administrator: the driver then keeps its shader cache elsewhere.
param(
    [Parameter(Mandatory)][string]$Exe,
    [switch]$Safe,
    [switch]$RayTracing,
    [Alias('Leve')][switch]$Low,
    [Alias('Nivel')][ValidateRange(1, 4)][int]$Level = 1,
    [ValidateSet('series-x', 'series-s')][string]$Console,
    [ValidatePattern('^\d{3,4}[xX]\d{3,4}$')][string]$Display,
    [Alias('TirarShaders')][string]$SkipShaders,
    [ValidateSet('diag', 'release')][string]$Build = 'diag',
    [hashtable]$More = @{}
)
$settings = @{
    VICTORY_TEXTURE_NO_WAIT = '1'; VICTORY_RELAY = '2'; VICTORY_WIDE_BACK = '1'; VICTORY_CARD_REHASH_RUNS = '1'
    VICTORY_JOIN_COPIES = '1'; VICTORY_INDIRECT_WINDOW = '1'; VICTORY_RELAY_COPY = '1'; VICTORY_CARD_STEPS = '2'
    VICTORY_INDIRECT_BATCH = '2'; VICTORY_MAP_THREADS = '1'; VICTORY_TITLE_PRIORITIES = '0'; VICTORY_CARD_AWAKE = '1'
    VICTORY_SHOW_AFTER = '1'; VICTORY_AMBIENT = '0.8'; VICTORY_D3D12_DRED = 'light'; VICTORY_SKIP_PIPELINES = 'none'
}
if ($Safe) {
    $settings.VICTORY_UNDER_WIDE = '0'; $settings.VICTORY_LAND_ECHO = '0'
} else {
    $settings.VICTORY_THIN = '1'; $settings.VICTORY_JOIN_PARTS = '8'; $settings.VICTORY_UPLOAD_AHEAD = '1'
}
if ($RayTracing) { $settings.VICTORY_BVH_BUILDER = '1' }
if ($Low) {
    # 1: what the title draws stays as it is. Every pair of GPU timestamps the title asks for said
    # the card did nothing (all are written when the frame lands), so its dynamic resolution never
    # came down; 45 ms, over its 33 ms budget, makes it lower what it renders at. Fewer idle host
    # lists, each with the memory of its largest recording (512 by default).
    $settings.VICTORY_GPU_LOAD_MS = '45'
    $settings.VICTORY_LIST_IDLE = '256'
    # 2: texture levels on the card only as the title holds them, 2 to 3 GB of a 12 GB card
    # (tried on an AMD card only).
    if ($Level -ge 2) { $settings.VICTORY_LEVELS_ON_DEMAND = '1' }
    # 3: a 1080p television: the title's output and screen passes at 1080p, not 4K (untried).
    if ($Level -ge 3 -and -not $Display) { $Display = '1920x1080' }
    # 4: the Series S profile (untried in the world): less memory, lower resolution and detail.
    # The first -Low, which was all four with a 24 ms pipeline wait, showed a black picture.
    if ($Level -ge 4 -and -not $Console) { $Console = 'series-s' }
    if ($RayTracing) {
        Write-Host 'Aviso: -RayTracing custa cerca de 40 ms por frame na placa; com -Leve o melhor e deixa-lo desligado.'
    }
} elseif ($PSBoundParameters.ContainsKey('Level')) {
    Write-Host 'Aviso: -Nivel so vale junto com -Leve.'
}
if ($Display) { $settings.VICTORY_DISPLAY_MODE = $Display.ToLower() }
if ($SkipShaders) {
    $settings.VICTORY_SKIP_NAMED = $SkipShaders
    if ($Build -ne 'diag') { Write-Host 'Aviso: -SkipShaders so funciona na build diag (-Build diag).' }
}
foreach ($k in $More.Keys) { $settings[$k] = $More[$k] }

$victory = Join-Path $PSScriptRoot "..\target\$Build\victory.exe"
if (-not (Test-Path $victory)) { Write-Host "No $victory. Build it first (README.md)."; return }
if (-not (Test-Path $Exe)) { Write-Host "No $Exe."; return }

# The process commits 25 to 46 GB (README.md); what physical memory does not hold must fit in the
# page file, or the title stops with Windows error 1455 or crawls while Windows pages.
try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $ramGB = [math]::Round($os.TotalVisibleMemorySize / 1MB)      # (KB)
    $commitGB = [math]::Round($os.TotalVirtualMemorySize / 1MB)   # memory and page file
    if ($ramGB -lt 32) {
        Write-Host "Memoria: $ramGB GB de RAM, $commitGB GB com o arquivo de paginacao."
        Write-Host '  Feche navegador, Discord e overlays antes de jogar.'
        if ($commitGB -lt 64) {
            Write-Host '  Aumente a memoria virtual para 48 a 64 GB, num SSD NVMe (docs/pc-modesto.md).'
        }
    }
} catch {}

# The log of this run, outside the repository (it names the title's code); the ten newest are kept.
$log = $null
if ($env:LOCALAPPDATA -and -not $settings.ContainsKey('VICTORY_LOG_FILE')) {
    $logs = Join-Path $env:LOCALAPPDATA 'victory\logs'
    try {
        New-Item -ItemType Directory -Force -Path $logs -ErrorAction Stop | Out-Null
        Get-ChildItem $logs -Filter 'play-*.log' | Sort-Object LastWriteTime -Descending |
            Select-Object -Skip 9 | Remove-Item -ErrorAction SilentlyContinue
        $log = Join-Path $logs ("play-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
        $settings.VICTORY_LOG_FILE = $log
    } catch { $log = $null }
}

# (Other settings left over in this window go; where your files are stays.)
$paths = 'VICTORY_CONFIG', 'VICTORY_GAME_DIR', 'VICTORY_CACHE_DIR', 'VICTORY_DATA_DIR'
Get-ChildItem Env:VICTORY_* | Where-Object { $_.Name -notin $paths } | ForEach-Object { Remove-Item "Env:$($_.Name)" }
foreach ($k in $settings.Keys) { Set-Item "Env:$k" $settings[$k] }
$Exe = (Resolve-Path $Exe).Path
$arguments = @('run', $Exe, '--execute')
if ($Console) { $arguments += @('--console', $Console) }
$shown = ($settings.Keys | Where-Object { $_ -ne 'VICTORY_LOG_FILE' } | Sort-Object | ForEach-Object { "$_=$($settings[$_])" }) -join ' '
$what = if ($Low) { "Perfil leve, nivel $Level" } else { 'Perfil normal' }
$consoleName = if ($Console) { $Console } else { 'series-x' }
Write-Host "$what, console $consoleName"
if ($log) {
    Set-Content -Path $log -Value "play.ps1: $what, console $consoleName, build $Build`r`n$shown`r`n" -ErrorAction SilentlyContinue
    Write-Host "Registro: $log"
}

# What the log says went wrong, once the title has ended (or the window was closed with Ctrl+C).
function Show-Outcome {
    if (-not $log -or -not (Test-Path $log)) { return }
    $found = { param($text) [bool](Select-String -Path $log -Pattern $text -SimpleMatch -Quiet) }
    $frames = @(Select-String -Path $log -Pattern 'frame presented' -SimpleMatch).Count
    Write-Host ''
    Write-Host "Fim da partida. Registro: $log"
    if (& $found 'device removed') {
        Write-Host '  A placa de video caiu (device removed): rode de novo com um nivel menor, ou com -Safe.'
    }
    if ((& $found 'cannot present this format') -or (& $found 'no swap chain') -or (& $found 'swap chain not resized')) {
        Write-Host '  O emulador nao conseguiu mostrar a imagem que o jogo entregou: use -Nivel 2 ou menos'
        Write-Host '  (os niveis 3 e 4 mudam a saida do jogo).'
    }
    if (& $found 'more than one plane') {
        Write-Host '  O jogo entregou a imagem em mais de um plano, e o emulador mostra so o primeiro:'
        Write-Host '  e o que deixa a tela preta. Use -Nivel 2 ou menos.'
    }
    if ($frames -eq 0) {
        Write-Host '  O jogo nao apresentou nenhum frame.'
    }
    if ($Low -and $Level -gt 1) {
        Write-Host "  Se a tela ficou preta: rode com -Leve -Nivel $($Level - 1) e mande este registro."
    } elseif ($Low) {
        Write-Host '  Se a tela ficou preta: rode sem -Leve, para ver se a imagem volta, e mande este registro.'
    }
}

Push-Location (Join-Path $PSScriptRoot '..')   # victory.toml is looked for here
try { & $victory @arguments } finally { Pop-Location; Show-Outcome }
