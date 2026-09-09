<#
.SYNOPSIS
    Monitor en tiempo real de criptomonedas usando la API de CoinGecko.
.DESCRIPTION
    Obtiene la ficha tecnica completa al inicio (Algoritmo, Genesis, Supply, ATH/ATL con fechas,
    cambios multitemporales 1h a 1y, FDV, metricas de GitHub) en una sola llamada optimizada.
    Posteriormente ejecuta un ticker en vivo con actualizacion continua mediante /simple/price.
.EXAMPLE
    .\live-crypto-asset-monitor-pro-v1.ps1          # Tabla inicial + loop continuo
    .\live-crypto-asset-monitor-pro-v1.ps1 -Once    # Tabla inicial + 1 sola iteracion (modo test)

    Con Mucho Amor Para Mis Hijos Karol Natalia y Fabián Andrés Zuñiga Álvarez.
    Pueden ejecutarlo directamente en cualquier momento con: powershell -ExecutionPolicy Bypass -File .\live-crypto-asset-monitor-pro-v1.ps1
#>

param(
    [switch]$Once
)

# Forzar soporte TLS 1.2 para compatibilidad total con Windows PowerShell 5.1 y PowerShell 7+
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ==============================================================================
# 1. CONFIGURACION Y PARAMETROS
# ==============================================================================
# Regla de sintaxis:
#   - Valor simple:         "usd"               (Usa color por defecto)
#   - Valor con color:      @($true, "Cyan")    (Formato: @(Valor, "Color"))
#   - Moneda configurable:  Soporta IDs ("bitcoin", "ethereum") y tickers ("btc", "eth", "sol", etc.)
$cfg = @{
    # --- Parametros Generales ---
    coin                     = "btc"             # ID ("bitcoin") o Ticker ("btc", "eth", "sol", "ada", etc.)
    vs_currency              = @("usd", "Blue") # Moneda de cotizacion: "usd", "eur", "gbp", "ars", "mxn", etc.
    refresh_interval         = 60                # Intervalo de actualizacion en segundos (Recomendado: 30 a 60s)
    precision                = "2"            # "full" o numero de decimales (ej. "2", "4", "0")
    
    # --- Parametros del Ticker en Vivo (/simple/price) ---
    show_date                = @($true, "Cyan")      # Muestra la fecha y hora local
    show_24hr_change         = $true                 # Color dinamico: Verde (>= 0) o Rojo (< 0)
    show_24hr_vol            = @($true, "Yellow")    # Volumen de trading en 24h
    show_market_cap          = @($true, "Magenta")   # Capitalizacion de mercado
    show_last_updated_at     = @($true, "DarkGray")  # Hora de la ultima actualizacion en el servidor

    # --- API Key Demo (Opcional) ---
    # Elimina los limites del pool anonimo compartido (https://www.coingecko.com/en/api/pricing)
    api_key                  = "CG-fkZxBZcDjhfFE998tpLwPF79"
}

# ==============================================================================
# 2. DICCIONARIO DE ALIAS (TICKER -> COINGECKO ID)
# ==============================================================================
$global:SymbolMap = @{
    "btc"   = "bitcoin"
    "eth"   = "ethereum"
    "sol"   = "solana"
    "bnb"   = "binancecoin"
    "xrp"   = "ripple"
    "ada"   = "cardano"
    "doge"  = "dogecoin"
    "avax"  = "avalanche-2"
    "dot"   = "polkadot"
    "matic" = "matic-network"
    "pol"   = "polygon-ecosystem-token"
    "link"  = "chainlink"
    "shib"  = "shiba-inu"
    "ltc"   = "litecoin"
    "near"  = "near"
    "sui"   = "sui"
    "trx"   = "tron"
    "bch"   = "bitcoin-cash"
    "uni"   = "uniswap"
    "pepe"  = "pepe"
    "ton"   = "the-open-network"
    "apt"   = "aptos"
    "xlm"   = "stellar"
    "atom"  = "cosmos"
    "xmr"   = "monero"
}

# ==============================================================================
# 3. FUNCIONES AUXILIARES Y FORMATEADORES
# ==============================================================================

# Extrae el valor configurado
function Get-CfgValue($param) {
    if ($param -is [array]) { return $param[0] }
    return $param
}

# Extrae el color asignado o valor por defecto
function Get-CfgColor($param, [string]$defaultColor = "White") {
    if ($param -is [array] -and $param.Count -gt 1) { return [string]$param[1] }
    return $defaultColor
}

# Obtiene una propiedad de forma segura tanto de PSCustomObject como de Hashtables / Dictionaries
function Get-Prop($obj, [string]$propName) {
    if ($null -eq $obj) { return $null }
    if ($obj -is [System.Collections.IDictionary]) {
        if ($obj.ContainsKey($propName)) { return $obj[$propName] }
        return $null
    }
    if ($obj -is [System.Management.Automation.PSCustomObject]) {
        $p = $obj.PSObject.Properties[$propName]
        if ($null -ne $p) { return $p.Value }
        return $null
    }
    try { return $obj.$propName } catch { return $null }
}

# Deserializador JSON universal (compatible con PS 5.1 y PS 7+)
function ConvertFrom-JsonSafe([string]$jsonString) {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return ($jsonString | ConvertFrom-Json -AsHashtable)
    }
    try {
        return ($jsonString | ConvertFrom-Json)
    }
    catch {
        Add-Type -AssemblyName System.Web.Extensions -ErrorAction SilentlyContinue
        $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $ser.MaxJsonLength = [int32]::MaxValue
        return $ser.DeserializeObject($jsonString)
    }
}

# Formateador numerico seguro
function Format-Number($num, [int]$decimals = 2) {
    if ($null -eq $num) { return "N/D" }
    try {
        $fmt = "{0:N" + $decimals + "}"
        return ($fmt -f [double]$num)
    } catch {
        return [string]$num
    }
}

# Formateador de porcentajes con signo (+0.00% / -0.00%)
function Format-Pct($num) {
    if ($null -eq $num) { return "N/D" }
    try {
        return ("{0:+0.00;-0.00}%" -f [double]$num)
    } catch {
        return [string]$num
    }
}

# Formateador de magnitudes grandes (B = Miles de Millones, T = Billones en espanol / Trillions en escala US)
function Format-Magnitude($num, [string]$currUpper = "USD") {
    if ($null -eq $num) { return "N/D" }
    try {
        $n = [double]$num
        if ($n -ge 1e12) {
            return ("$" + (Format-Number ($n / 1e12) 2) + "T " + $currUpper)
        } elseif ($n -ge 1e9) {
            return ("$" + (Format-Number ($n / 1e9) 2) + "B " + $currUpper)
        } elseif ($n -ge 1e6) {
            return ("$" + (Format-Number ($n / 1e6) 2) + "M " + $currUpper)
        } else {
            return ("$" + (Format-Number $n 2) + " " + $currUpper)
        }
    } catch {
        return [string]$num
    }
}

# ==============================================================================
# 4. CAPA DE RED ROBUSTA (Invoke-CgApi con Backoff y deteccion Cloudflare) - Evita bloqueos por tasa de peticiones (Rate Limiting)
# ==============================================================================
function Invoke-CgApi {
    param(
        [string]$Url,
        [int]$MaxRetries = 3
    )
    
    $headers = @{ 
        "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        "Accept"     = "application/json"
    }
    
    $apiKey = Get-CfgValue $cfg.api_key
    if ($apiKey) {
        $headers["x-cg-demo-api-key"] = $apiKey
    }

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            $resp = Invoke-WebRequest -Uri $Url -Headers $headers -TimeoutSec 25 -UseBasicParsing -ErrorAction Stop
            $raw = $resp.Content

            # Deteccion de desafios Cloudflare (HTML en lugar de JSON)
            if ($raw -match '<\s*html' -or $raw -match 'Just a moment') {
                throw "Desafio Cloudflare detectado (HTML recibido en lugar de JSON)"
            }

            # Parseo seguro
            $data = ConvertFrom-JsonSafe $raw

            # Desempaquetar array si viene envuelto
            if ($data -is [array] -and $data.Count -gt 0) {
                $data = $data[0]
            }

            # Validar mensajes de error dentro del JSON
            $statusObj = Get-Prop $data "status"
            if ($statusObj) {
                $errCode = Get-Prop $statusObj "error_code"
                $errMsg  = Get-Prop $statusObj "error_message"
                if ($errCode) {
                    throw "CoinGecko Error $errCode : $errMsg"
                }
            }

            return $data
        }
        catch {
            $errMessage = $_.Exception.Message
            $statusCode = 0
            if ($_.Exception.Response) {
                try { $statusCode = $_.Exception.Response.StatusCode.value__ } catch {}
            }

            if ($attempt -lt $MaxRetries) {
                # Backoff inteligente: Espera mas tiempo ante 429
                $waitTime = if ($statusCode -eq 429 -or $errMessage -match "429") { 20 * $attempt } else { 5 * $attempt }
                $ts = Get-Date -Format "HH:mm:ss"
                Write-Host "[$ts] [AVISO] $errMessage - Reintentando ($attempt/$MaxRetries) en ${waitTime}s..." -ForegroundColor DarkYellow
                Start-Sleep -Seconds $waitTime
            }
            else {
                throw
            }
        }
    }
}

# ==============================================================================
# 5. MOTOR DE LA TABLA INICIAL (Renderizado completo y estructurado)
# ==============================================================================
function Show-InitialTable {
    param(
        [string]$CoinId,
        [string]$VsCurrency
    )

    $currLower = $VsCurrency.ToLower()
    $currUpper = $VsCurrency.ToUpper()

    # Optimizacion clave: Una sola llamada filtrando campos pesados innecesarios (<30 KB)
    $fichaUrl = "https://api.coingecko.com/api/v3/coins/" + $CoinId + "?localization=false&tickers=false&market_data=true&community_data=true&developer_data=true&sparkline=false"
    
    $coinData = $null
    try {
        $coinData = Invoke-CgApi -Url $fichaUrl -MaxRetries 2
    }
    catch {
        # Fallback a /coins/markets si /coins/{id} se bloquea o satura
        $marketFallbackUrl = "https://api.coingecko.com/api/v3/coins/markets?vs_currency=" + $currLower + "&ids=" + $CoinId + "&price_change_percentage=24h,7d"
        try {
            $coinData = Invoke-CgApi -Url $marketFallbackUrl -MaxRetries 1
        } catch {
            Write-Warning ("No se pudo cargar la tabla inicial: " + $_.Exception.Message)
            return
        }
    }

    if ($null -eq $coinData) { return }

    # Extraccion de metadatos generales
    $sym = (Get-Prop $coinData "symbol")
    $coinSymbol = if ($sym) { $sym.ToUpper() } else { $CoinId.ToUpper() }
    $coinName   = Get-Prop $coinData "name"
    if (-not $coinName) { $coinName = $CoinId }
    $rank       = Get-Prop $coinData "market_cap_rank"
    $algo       = Get-Prop $coinData "hashing_algorithm"
    $genesis    = Get-Prop $coinData "genesis_date"
    $blockTime  = Get-Prop $coinData "block_time_in_minutes"

    # Datos de mercado
    $m = Get-Prop $coinData "market_data"
    if ($null -eq $m) { $m = $coinData }

    # 1. Ficha General
    $fichaItems = @("$coinSymbol")
    if ($rank)      { $fichaItems += "Rank #$rank" }
    if ($algo)      { $fichaItems += "$algo" }
    if ($genesis)   { $fichaItems += "Genesis: $genesis" }
    if ($blockTime) { $fichaItems += "Bloque: $blockTime min" }
    $fichaStr = $fichaItems -join " | "

    # 2. Supply
    $circSupplyRaw = Get-Prop $m "circulating_supply"
    $maxSupplyRaw  = Get-Prop $m "max_supply"
    $totalSupplyRaw= Get-Prop $m "total_supply"
    if ($null -eq $maxSupplyRaw -and $totalSupplyRaw) { $maxSupplyRaw = $totalSupplyRaw }

    $circStr = Format-Number $circSupplyRaw 0
    $supplyStr = "$circStr $coinSymbol"
    if ($maxSupplyRaw -and [double]$maxSupplyRaw -gt 0) {
        $maxStr = Format-Number $maxSupplyRaw 0
        $pctMined = [math]::Round(([double]$circSupplyRaw / [double]$maxSupplyRaw) * 100, 2)
        $supplyStr = "$circStr / $maxStr ($pctMined% emitido) $coinSymbol"
    }

    # 3. Precio
    $priceObj = Get-Prop $m "current_price"
    $curPrice = if ($priceObj -is [System.Collections.IDictionary] -or $priceObj -is [System.Management.Automation.PSCustomObject]) {
        Get-Prop $priceObj $currLower
    } else {
        $priceObj
    }
    $priceDecimals = if ($curPrice -and [double]$curPrice -lt 1) { 6 } else { 2 }
    $priceStr = "$" + (Format-Number $curPrice $priceDecimals) + " " + $currUpper

    # 4. ATH (Maximo Historico)
    $athObj = Get-Prop $m "ath"
    $athVal = if ($athObj -is [System.Collections.IDictionary] -or $athObj -is [System.Management.Automation.PSCustomObject]) { Get-Prop $athObj $currLower } else { $athObj }
    $athDateObj = Get-Prop $m "ath_date"
    $athDateVal = if ($athDateObj -is [System.Collections.IDictionary] -or $athDateObj -is [System.Management.Automation.PSCustomObject]) { Get-Prop $athDateObj $currLower } else { $athDateObj }
    $athPctObj = Get-Prop $m "ath_change_percentage"
    $athPctVal = if ($athPctObj -is [System.Collections.IDictionary] -or $athPctObj -is [System.Management.Automation.PSCustomObject]) { Get-Prop $athPctObj $currLower } else { $athPctObj }
    
    $athDateStr = if ($athDateVal) {
        try { ([datetime]$athDateVal).ToString("yyyy-MM-dd") } catch { [string]$athDateVal }
    } else { "N/D" }
    $athStr = "$" + (Format-Number $athVal $priceDecimals) + " " + $currUpper + " | " + $athDateStr + " | " + (Format-Pct $athPctVal) + " vs ATH"

    # 5. ATL (Minimo Historico)
    $atlObj = Get-Prop $m "atl"
    $atlVal = if ($atlObj -is [System.Collections.IDictionary] -or $atlObj -is [System.Management.Automation.PSCustomObject]) { Get-Prop $atlObj $currLower } else { $atlObj }
    $atlDateObj = Get-Prop $m "atl_date"
    $atlDateVal = if ($atlDateObj -is [System.Collections.IDictionary] -or $atlDateObj -is [System.Management.Automation.PSCustomObject]) { Get-Prop $atlDateObj $currLower } else { $atlDateObj }
    $atlPctObj = Get-Prop $m "atl_change_percentage"
    $atlPctVal = if ($atlPctObj -is [System.Collections.IDictionary] -or $atlPctObj -is [System.Management.Automation.PSCustomObject]) { Get-Prop $atlPctObj $currLower } else { $atlPctObj }
    
    $atlDateStr = if ($atlDateVal) {
        try { ([datetime]$atlDateVal).ToString("yyyy-MM-dd") } catch { [string]$atlDateVal }
    } else { "N/D" }
    $atlStr = "$" + (Format-Number $atlVal $priceDecimals) + " " + $currUpper + " | " + $atlDateStr + " | " + (Format-Pct $atlPctVal) + " vs ATL"

    # 6. Cambios Multitemporales (1h, 24h, 7d, 30d, 60d, 200d, 1y)
    $ch1h  = Get-Prop (Get-Prop $m "price_change_percentage_1h_in_currency") $currLower
    $ch24h = Get-Prop $m "price_change_percentage_24h"
    if ($null -eq $ch24h) { $ch24h = Get-Prop (Get-Prop $m "price_change_percentage_24h_in_currency") $currLower }
    $ch7d  = Get-Prop (Get-Prop $m "price_change_percentage_7d_in_currency") $currLower
    $ch30d = Get-Prop (Get-Prop $m "price_change_percentage_30d_in_currency") $currLower
    $ch60d = Get-Prop (Get-Prop $m "price_change_percentage_60d_in_currency") $currLower
    $ch200d= Get-Prop (Get-Prop $m "price_change_percentage_200d_in_currency") $currLower
    $ch1y  = Get-Prop (Get-Prop $m "price_change_percentage_1y_in_currency") $currLower

    $cambiosList = @()
    if ($null -ne $ch1h)  { $cambiosList += "1h " + (Format-Pct $ch1h) }
    if ($null -ne $ch24h) { $cambiosList += "24h " + (Format-Pct $ch24h) }
    if ($null -ne $ch7d)  { $cambiosList += "7d " + (Format-Pct $ch7d) }
    if ($null -ne $ch30d) { $cambiosList += "30d " + (Format-Pct $ch30d) }
    if ($null -ne $ch60d) { $cambiosList += "60d " + (Format-Pct $ch60d) }
    if ($null -ne $ch200d){ $cambiosList += "200d " + (Format-Pct $ch200d) }
    if ($null -ne $ch1y)  { $cambiosList += "1y " + (Format-Pct $ch1y) }
    $cambiosStr = if ($cambiosList.Count -gt 0) { $cambiosList -join " | " } else { "N/D" }

    # 7. Mercado (Market Cap, FDV, Volumen 24h)
    $mcObj = Get-Prop $m "market_cap"
    $mcVal = if ($mcObj -is [System.Collections.IDictionary] -or $mcObj -is [System.Management.Automation.PSCustomObject]) { Get-Prop $mcObj $currLower } else { $mcObj }
    
    $fdvObj = Get-Prop $m "fully_diluted_valuation"
    $fdvVal = if ($fdvObj -is [System.Collections.IDictionary] -or $fdvObj -is [System.Management.Automation.PSCustomObject]) { Get-Prop $fdvObj $currLower } else { $fdvObj }
    
    $volObj = Get-Prop $m "total_volume"
    $volVal = if ($volObj -is [System.Collections.IDictionary] -or $volObj -is [System.Management.Automation.PSCustomObject]) { Get-Prop $volObj $currLower } else { $volObj }

    $mercadoStr = "MC " + (Format-Magnitude $mcVal $currUpper) + " | FDV " + (Format-Magnitude $fdvVal $currUpper) + " | Vol24h " + (Format-Magnitude $volVal $currUpper)

    # 8. Metricas GitHub / Desarrollador
    $dev = Get-Prop $coinData "developer_data"
    $gitStr = "No disponible"
    if ($dev) {
        $starsRaw   = Get-Prop $dev "stars"
        $forksRaw   = Get-Prop $dev "forks"
        $commitsRaw = Get-Prop $dev "commit_count_4_weeks"
        if ($null -ne $starsRaw -and [double]$starsRaw -gt 0) {
            $stars   = Format-Number $starsRaw 0
            $forks   = Format-Number $forksRaw 0
            $commits = Format-Number $commitsRaw 0
            $gitStr  = "$stars stars | $forks forks | $commits commits (4 sem)"
        }
    }

    # ==========================================
    # RENDERIZADO VISUAL DE LA TABLA EN TERMINAL
    # ==========================================
    $title = "INFORMACION DE LA CRIPTO: " + $coinName.ToUpper() + " (" + $coinSymbol + ") - Con Mucho Amor Para Mis Hijos Karol Natalia y Fabián Andrés Zuñiga Álvarez."
    $lineBorder = "+" + ("-" * 15) + "+" + ("-" * 105) + "+"

    Write-Host ""
    Write-Host $lineBorder -ForegroundColor DarkCyan
    Write-Host ("| {0,-121} |" -f $title) -ForegroundColor Cyan
    Write-Host $lineBorder -ForegroundColor DarkCyan

    $summaryData = [ordered]@{
        "Ficha"     = $fichaStr
        "Supply"    = $supplyStr
        "Precio"    = $priceStr
        "ATH"       = $athStr
        "ATL"       = $atlStr
        "Cambios"   = $cambiosStr
        "Mercado"   = $mercadoStr
        "GitHub"    = $gitStr
    }

    foreach ($entry in $summaryData.GetEnumerator()) {
        $k = [string]$entry.Key
        $v = [string]$entry.Value
        Write-Host ("| {0,-13} | " -f $k) -ForegroundColor Yellow -NoNewline
        Write-Host ("{0,-103} |" -f $v) -ForegroundColor White
    }
    Write-Host $lineBorder -ForegroundColor DarkCyan
    Write-Host ""
}

# ==============================================================================
# 6. MOTOR DEL TICKER EN VIVO
# ==============================================================================
function Start-LiveTicker {
    param(
        [string]$CoinInput,
        [string]$VsCurrency,
        [switch]$RunOnce
    )

    $rawCoin = ([string]$CoinInput).Trim().ToLower()
    $resolvedId = $(if ($global:SymbolMap.ContainsKey($rawCoin)) { $global:SymbolMap[$rawCoin] } else { $rawCoin })

    $currName  = (Get-CfgValue $cfg.vs_currency).ToLower()
    $currColor = Get-CfgColor $cfg.vs_currency "Green"
    $currUpper = $currName.ToUpper()

    # 1. Ejecutar tabla inicial completa
    Show-InitialTable -CoinId $resolvedId -VsCurrency $currName
    
    # Pausa breve de cortesia para no colisionar 2 peticiones instantaneas
    Start-Sleep -Seconds 2

    # 2. Preparar URL de /simple/price
    $chBool  = (Get-CfgValue $cfg.show_24hr_change).ToString().ToLower()
    $volBool = (Get-CfgValue $cfg.show_24hr_vol).ToString().ToLower()
    $mcBool  = (Get-CfgValue $cfg.show_market_cap).ToString().ToLower()
    $updBool = (Get-CfgValue $cfg.show_last_updated_at).ToString().ToLower()
    $prec    = Get-CfgValue $cfg.precision

    $queryUrl = "https://api.coingecko.com/api/v3/simple/price?ids=" + $resolvedId + "&vs_currencies=" + $currName + "&include_24hr_change=" + $chBool + "&include_24hr_vol=" + $volBool + "&include_market_cap=" + $mcBool + "&include_last_updated_at=" + $updBool + "&precision=" + $prec

    $interval = [int](Get-CfgValue $cfg.refresh_interval)
    if ($interval -lt 10) { $interval = 10 }

    # 3. Bucle continuo de monitoreo
    do {
        try {
            $r = Invoke-CgApi -Url $queryUrl -MaxRetries 2
            $coinData = Get-Prop $r $resolvedId

            if ($null -eq $coinData) {
                throw "La moneda '$resolvedId' no devolvio datos de precio."
            }

            $t = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $p = Get-Prop $coinData $currName
            $c = Get-Prop $coinData ($currName + "_24h_change")
            $vRaw = Get-Prop $coinData ($currName + "_24h_vol")
            $v = if ($null -ne $vRaw) { Format-Number ([double]$vRaw / 1e9) 2 } else { "0" }
            $mRaw = Get-Prop $coinData ($currName + "_market_cap")
            $m = if ($null -ne $mRaw) { Format-Number ([double]$mRaw / 1e12) 2 } else { "0" }
            $uRaw = Get-Prop $coinData "last_updated_at"
            $u = if ($null -ne $uRaw) {
                Get-Date -Date ([DateTimeOffset]::FromUnixTimeSeconds($uRaw).DateTime) -Format "HH:mm:ss"
            } else { "N/D" }

            $symDisp = $resolvedId.ToUpper()
            if ($rawCoin.Length -le 5) { $symDisp = $rawCoin.ToUpper() }

            # Renderizado de linea
            if (Get-CfgValue $cfg.show_date) {
                Write-Host ("[" + $t + "] ") -ForegroundColor (Get-CfgColor $cfg.show_date "Cyan") -NoNewline
            }

            Write-Host ("Coin: " + $symDisp) -ForegroundColor White -NoNewline
            Write-Host " | " -ForegroundColor Gray -NoNewline
            Write-Host ("Price: " + $p + " " + $currUpper) -ForegroundColor $currColor -NoNewline

            if ((Get-CfgValue $cfg.show_24hr_change) -and ($null -ne $c)) {
                Write-Host " | " -ForegroundColor Gray -NoNewline
                $chgColor = if ([double]$c -ge 0) { "Green" } else { "Red" }
                Write-Host ("Change 24h: " + (Format-Pct $c)) -ForegroundColor $chgColor -NoNewline
            }

            if (Get-CfgValue $cfg.show_24hr_vol) {
                Write-Host " | " -ForegroundColor Gray -NoNewline
                Write-Host ("Vol: " + $v + "B " + $currUpper) -ForegroundColor (Get-CfgColor $cfg.show_24hr_vol "Yellow") -NoNewline
            }

            if (Get-CfgValue $cfg.show_market_cap) {
                Write-Host " | " -ForegroundColor Gray -NoNewline
                Write-Host ("MC: " + $m + "T " + $currUpper) -ForegroundColor (Get-CfgColor $cfg.show_market_cap "Magenta") -NoNewline
            }

            if (Get-CfgValue $cfg.show_last_updated_at) {
                Write-Host " | " -ForegroundColor Gray -NoNewline
                Write-Host ("Updated: " + $u) -ForegroundColor (Get-CfgColor $cfg.show_last_updated_at "DarkGray")
            } else {
                Write-Host ""
            }
        }
        catch {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $errMsg = $_.Exception.Message
            if ($errMsg -match "429") {
                Write-Host ("[" + $timestamp + "] [AVISO] Limite de peticiones alcanzado (CoinGecko Rate Limit). Pausando " + $interval + "s...") -ForegroundColor Yellow
            } else {
                Write-Host ("[" + $timestamp + "] [ERROR] No se pudo obtener el precio: " + $errMsg) -ForegroundColor Red
            }
        }

        if (-not $RunOnce) {
            Start-Sleep -Seconds $interval
        }
    } while (-not $RunOnce)
}

# ==============================================================================
# 7. PUNTO DE ENTRADA PRINCIPAL
# ==============================================================================
$activeCoin = Get-CfgValue $cfg.coin
$activeCurrency = Get-CfgValue $cfg.vs_currency

Start-LiveTicker -CoinInput $activeCoin -VsCurrency $activeCurrency -RunOnce:$Once
