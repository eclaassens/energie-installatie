# Installeert de energie-app op deze Windows-pc, of werkt hem bij. Plak in PowerShell (geen beheerder nodig):
#
#   irm https://raw.githubusercontent.com/eclaassens/energie-installatie/main/installeer.ps1 | iex
#
# Wat het doet: controleert Docker Desktop, zet docker-compose.yml en .env in %USERPROFILE%\energie-app,
# laat je de .env invullen in Kladblok, test de verbinding met Home Assistant, en start de app op
# http://localhost:8000. Nog een keer uitvoeren = bijwerken naar de nieuwste versie; je gegevens blijven.

function Install-EnergieApp {
    # Niet 'Stop': in Windows PowerShell 5.1 wordt elke regel die docker op stderr schrijft dan een fout.
    $ErrorActionPreference = 'Continue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $bron = 'https://raw.githubusercontent.com/eclaassens/energie-installatie/main'
    $map = Join-Path $env:USERPROFILE 'energie-app'
    $env_pad = Join-Path $map '.env'

    function Stap($tekst) { Write-Host ""; Write-Host "== $tekst" -ForegroundColor Cyan }
    function Fout($tekst) { Write-Host $tekst -ForegroundColor Red }

    # 1. Docker Desktop
    Stap 'Docker Desktop controleren'
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Fout 'Docker Desktop is nog niet geinstalleerd.'
        $ja = Read-Host 'Nu installeren via winget? Windows vraagt daarna om toestemming (j/n)'
        if ($ja -eq 'j') {
            winget install -e --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
            Write-Host ''
            Write-Host 'Docker Desktop is geinstalleerd. Herstart de pc, start Docker Desktop (accepteer de voorwaarden;'
            Write-Host 'inloggen is niet nodig) en voer daarna deze installatie opnieuw uit.' -ForegroundColor Yellow
        } else {
            Write-Host 'Installeer Docker Desktop via https://www.docker.com/products/docker-desktop/ en voer dit daarna opnieuw uit.'
        }
        return
    }
    docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        $exe = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
        if (Test-Path $exe) {
            Write-Host 'Docker Desktop starten...'
            Start-Process $exe
        }
        Write-Host 'Wachten tot Docker draait (dat kan een minuut duren)...'
        for ($i = 0; $i -lt 60; $i++) {
            Start-Sleep -Seconds 3
            docker info *> $null
            if ($LASTEXITCODE -eq 0) { break }
        }
        if ($LASTEXITCODE -ne 0) {
            Fout 'Docker draait niet. Start Docker Desktop zelf, wacht tot het "Engine running" zegt, en voer dit opnieuw uit.'
            return
        }
    }
    Write-Host 'Docker draait.'

    # 2. Bestanden
    Stap "Bestanden in $map"
    try {
        New-Item -ItemType Directory -Force -Path $map -ErrorAction Stop | Out-Null
        Invoke-WebRequest -UseBasicParsing "$bron/docker-compose.yml" -OutFile (Join-Path $map 'docker-compose.yml') -ErrorAction Stop
    } catch {
        Fout "Downloaden mislukt: $($_.Exception.Message)"
        return
    }
    $invullen = $true
    if (Test-Path $env_pad) {
        $invullen = (Read-Host 'Er zijn al instellingen. Wil je ze aanpassen? (j/N)') -eq 'j'
    } else {
        Invoke-WebRequest -UseBasicParsing "$bron/env-voorbeeld.txt" -OutFile $env_pad -ErrorAction Stop
    }
    if ($invullen) {
        Write-Host ''
        Write-Host 'Kladblok gaat open met de instellingen:' -ForegroundColor Yellow
        Write-Host ' - vervang alles door de regels die Claude je gaf (of vul ze in);'
        Write-Host ' - plak je Home Assistant-token achter HA_TOKEN= (en nergens anders);'
        Write-Host ' - tarieven naar HA (MQTT)? typ dan het wachtwoord van de HA-gebruiker achter MQTT_PASSWORD=;'
        Write-Host ' - sla op (Ctrl+S) en sluit Kladblok. Daarna gaat de installatie verder.'
        Start-Process notepad.exe -ArgumentList "`"$env_pad`"" -Wait
    }
    # Docker leest de .env het best zonder BOM en met gewone regeleinden.
    $tekst = [IO.File]::ReadAllText($env_pad) -replace "`r`n", "`n"
    [IO.File]::WriteAllText($env_pad, $tekst, (New-Object Text.UTF8Encoding $false))

    # 3. Instellingen controleren (het token wordt nooit getoond)
    Stap 'Verbinding met Home Assistant testen'
    $waarden = @{}
    foreach ($regel in $tekst -split "`n") {
        if ($regel -match '^\s*([A-Z_0-9]+)\s*=\s*(.*?)\s*$') { $waarden[$Matches[1]] = $Matches[2] }
    }
    $url = ($waarden['HA_URL'] + '').TrimEnd('/')
    $token = $waarden['HA_TOKEN'] + ''
    if (-not $url -or -not $token) {
        Fout 'HA_URL of HA_TOKEN is leeg. Voer dit opnieuw uit en vul ze in.'
        return
    }
    $ontbreekt = @('SENSOR_ENERGY_CONSUMED_T1','SENSOR_ENERGY_CONSUMED_T2','SENSOR_GAS','SENSOR_PV_POWER','SENSOR_OUTDOOR_TEMP','SENSOR_INDOOR_TEMP') |
        Where-Object { -not $waarden.ContainsKey($_) }
    if ($ontbreekt) {
        # Een regel die helemaal ontbreekt valt terug op de sensornamen van een ander huishouden.
        Fout ("Deze regels ontbreken in de instellingen: " + ($ontbreekt -join ', ') + ". Zet ze erin (leeg achter de = als je de sensor niet hebt).")
        return
    }
    if ($waarden['MQTT_HOST'] -and -not $waarden['MQTT_USER']) {
        # Mosquitto in HA laat niemand toe zonder login; zonder gebruiker mislukt elk bericht.
        Write-Host 'Let op: MQTT_HOST staat aan, maar MQTT_USER is leeg. Mosquitto in Home Assistant wil een login;' -ForegroundColor Yellow
        Write-Host '        vul MQTT_USER en MQTT_PASSWORD in (een HA-gebruiker), of maak MQTT_HOST leeg.' -ForegroundColor Yellow
    }
    try {
        $antwoord = Invoke-RestMethod -Uri "$url/api/" -Headers @{ Authorization = "Bearer $token" } -TimeoutSec 15 -ErrorAction Stop
        Write-Host "Home Assistant antwoordt: $($antwoord.message)"
    } catch {
        $code = $null
        if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
        if ($code -eq 401) {
            Fout 'Home Assistant weigert het token (401). Maak een nieuw token en voer dit opnieuw uit.'
            return
        }
        Fout "Home Assistant op $url is niet bereikbaar vanaf deze pc: $($_.Exception.Message)"
        $door = Read-Host 'Toch doorgaan? (j/N)'
        if ($door -ne 'j') { return }
    }

    # 4. Starten of bijwerken
    Stap 'De app ophalen en starten'
    Push-Location $map
    try {
        docker compose pull
        if ($LASTEXITCODE -ne 0) { Fout 'Ophalen van de app mislukt (internet?).'; return }
        docker compose up -d
        if ($LASTEXITCODE -ne 0) { Fout 'Starten mislukt; zie de melding hierboven.'; return }
    } finally {
        Pop-Location
    }
    Write-Host 'Wachten tot de app klaar is...'
    $status = ''
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Seconds 3
        $status = (docker inspect --format '{{.State.Health.Status}}' energie-app 2>$null)
        if ($status -eq 'healthy') { break }
    }
    if ($status -ne 'healthy') {
        Fout "De app start niet goed (status: $status). Laatste regels van het logboek:"
        docker logs --tail 30 energie-app
        return
    }

    Stap 'Klaar'
    Write-Host 'De app draait op http://localhost:8000 (ook na een herstart, zolang Docker Desktop meestart).' -ForegroundColor Green
    Write-Host 'De eerste keer haalt hij jaren aan meterstanden uit Home Assistant; dat duurt een paar minuten.'
    Write-Host 'Vul daarna bij Beheer de tarieven van je contract in. Bijwerken: voer dezelfde regel opnieuw uit.'
    Start-Process 'http://localhost:8000'
}

Install-EnergieApp
