# Starts the title with the settings this fork is played with (README.md, "How to run it").
#   scripts\play.ps1 -Exe <path of your own copy's executable>
# -Safe         without the newer, faster ways (the first thing to try when something is wrong)
# -RayTracing   the title's own ray-traced indirect light: lit interiors, about a third slower
# -Low (-Leve)  for a modest PC (16 GB of RAM, a 12 GB card such as the RTX 3060): worse picture,
#               less memory; what it sets and why: docs/pc-modesto.md
# -Console      series-x (default) or series-s: the console the title believes it runs on
#               (-Low picks series-s unless told)
# -Display WxH  the television the console reports (-Low: 1920x1080; 1280x720 is lighter still)
# -SkipShaders  names of the title's programs whose draws and dispatches are left out
#               (VICTORY_SKIP_NAMED, diag build only): -SkipShaders 'CS_Name1,PS_Name2'
# -Build        target\diag (the default, the build all measurements are of) or target\release
# -More         other settings: -More @{VICTORY_PANEL='1'}
# Run it from a normal window, not as administrator: the driver then keeps its shader cache elsewhere.
param(
    [Parameter(Mandatory)][string]$Exe,
    [switch]$Safe,
    [switch]$RayTracing,
    [Alias('Leve')][switch]$Low,
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
    # The title picks its resolution, detail and memory budgets by the console it is on.
    if (-not $Console) { $Console = 'series-s' }
    # A 1080p television: the title's output, its upscaler's target and its screen passes at 1080p, not 4K.
    $settings.VICTORY_DISPLAY_MODE = '1920x1080'
    # Every pair of GPU timestamps the title asks for says the card did nothing (all are written
    # when the frame lands), so its dynamic resolution never comes down. 45 ms, over its 33 ms
    # budget, makes it look busy: the title lowers what it renders at.
    $settings.VICTORY_GPU_LOAD_MS = '45'
    # Texture levels on the card only as the title holds them: 2 to 3 GB of a 12 GB card free.
    $settings.VICTORY_LEVELS_ON_DEMAND = '1'
    # At most 24 ms a frame waiting for pipelines still being made (500 by default): a draw whose
    # pipeline is not ready is left out for a frame or two instead of the frame standing still.
    $settings.VICTORY_PIPELINE_WAIT_MS = '24'
    # Fewer idle host lists, each with the memory of its largest recording (512 by default).
    $settings.VICTORY_LIST_IDLE = '256'
    if ($RayTracing) {
        Write-Host 'Aviso: -RayTracing custa cerca de 40 ms por frame na placa; com -Leve o melhor e deixa-lo desligado.'
    }
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

# (Other settings left over in this window go; where your files are stays.)
$paths = 'VICTORY_CONFIG', 'VICTORY_GAME_DIR', 'VICTORY_CACHE_DIR', 'VICTORY_DATA_DIR'
Get-ChildItem Env:VICTORY_* | Where-Object { $_.Name -notin $paths } | ForEach-Object { Remove-Item "Env:$($_.Name)" }
foreach ($k in $settings.Keys) { Set-Item "Env:$k" $settings[$k] }
$Exe = (Resolve-Path $Exe).Path
$arguments = @('run', $Exe, '--execute')
if ($Console) { $arguments += @('--console', $Console) }
if ($Low) {
    $shown = ($settings.Keys | Where-Object { $_ -in 'VICTORY_DISPLAY_MODE', 'VICTORY_GPU_LOAD_MS', 'VICTORY_LEVELS_ON_DEMAND', 'VICTORY_PIPELINE_WAIT_MS', 'VICTORY_LIST_IDLE', 'VICTORY_SKIP_NAMED' } | Sort-Object | ForEach-Object { "$_=$($settings[$_])" }) -join ' '
    Write-Host "Perfil leve: console $Console, $shown"
}
Push-Location (Join-Path $PSScriptRoot '..')   # victory.toml is looked for here
try { & $victory @arguments } finally { Pop-Location }
