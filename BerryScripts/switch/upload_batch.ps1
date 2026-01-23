# Configuración
$retryCount = 3
$timeoutSeconds = 25

# Asegurar que estamos en el directorio correcto
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Directorio del script: $scriptDir" -ForegroundColor Gray
Set-Location $scriptDir

$filePath = Join-Path $scriptDir "switch_esp32s3.tapp"
Write-Host "Ruta completa del archivo: $filePath" -ForegroundColor Gray

# Paso 1: Comprimir archivos de la carpeta scripts
Write-Host "Comprimiendo archivos desde carpeta scripts..." -ForegroundColor Cyan
try {
    # Eliminar archivo existente si existe
    Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue
    
    # Comprimir archivos
    Push-Location scripts
    $relativePath = Split-Path $filePath -Leaf  # Solo el nombre del archivo
    & 7z a -tzip -mx=0 "..\$relativePath" *
    Pop-Location
    
    Write-Host "[OK] Compresion completada: $filePath" -ForegroundColor Green
}
catch {
    Write-Error "Error al comprimir archivos: $($_.Exception.Message)"
    exit 1
}

# Paso 2: Verificar que el archivo comprimido existe
if (-not (Test-Path $filePath)) {
    Write-Error "El archivo $filePath no se encontro despues de la compresion."
    exit 1
}

# Leer las IPs
$ips = Get-Content "upload_batch_ips.txt"
$successfulUploads = @()
$failedUploads = @()

Write-Host ""
Write-Host "IPs encontradas: $($ips -join ', ')" -ForegroundColor Gray
Write-Host "Iniciando proceso de subida a $($ips.Length) dispositivos..." -ForegroundColor Cyan

$deviceCount = 0
foreach ($ip in $ips) {
    $deviceCount++
    Write-Host ""
    Write-Host "[$deviceCount/$($ips.Length)] Procesando IP: $ip" -ForegroundColor Cyan
    
    # Verificar conectividad basica
    try {
        $ping = Test-Connection -ComputerName $ip -Count 1 -Quiet
        if (-not $ping) {
            Write-Warning "No se puede hacer ping a $ip. Saltando..."
            continue
        }
        
        # Verificar que el servidor web responde
        Write-Host "  Verificando servidor web en $ip..." -ForegroundColor Gray
        $testUri = "http://$ip/"
        $testResponse = Invoke-WebRequest -Uri $testUri -Method Get -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
        Write-Host "  [OK] Servidor web responde (Status: $($testResponse.StatusCode))" -ForegroundColor Green
    }
    catch {
        Write-Warning "Error al verificar conectividad con $ip. Saltando..."
        Write-Host "  Detalle: $($_.Exception.Message)" -ForegroundColor Yellow
        $failedUploads += $ip
        continue
    }
    
    # Borrar archivo existente para evitar problemas de espacio
    try {
        $deleteUrl = "http://$ip/ufsd?delete=/switch_esp32s3.tapp"
        Write-Host "  Borrando archivo existente..." -ForegroundColor Yellow
        $deleteResponse = Invoke-WebRequest -Uri $deleteUrl -Method Get -TimeoutSec 10 -UseBasicParsing -ErrorAction SilentlyContinue
        Write-Host "  [OK] Archivo borrado" -ForegroundColor Green
    }
    catch {
        Write-Host "  [INFO] No se pudo borrar archivo (puede que no existiera)" -ForegroundColor Gray
    }

    # Esperar un momento tras el borrado
    Start-Sleep -Seconds 1
    
    # Intentar subida con reintentos
    $uploaded = $false
    for ($attempt = 1; $attempt -le $retryCount; $attempt++) {
        try {
            # Solo mostrar intentos si es un reintento (no el primer intento)
            if ($attempt -gt 1) {
                Write-Host "  Intento $attempt de $retryCount para $ip..." -ForegroundColor Yellow
            }
            
            # Usar formato simple con WebClient
            $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
            $fileName = Split-Path $filePath -Leaf
            
            # URL con parámetro fsz (file size) como en el navegador
            $uri = "http://$ip/ufsu?fsz=$($fileBytes.Length)"
            
            Write-Host "  Subiendo archivo $fileName ($([math]::Round($fileBytes.Length/1024, 2)) KB) -> $uri..." -ForegroundColor Gray
            
            # Usar WebClient simple - el timeout se maneja a nivel de excepción
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add("Content-Type", "application/octet-stream")
            
            $response = $webClient.UploadFile($uri, "POST", $filePath)
            $responseText = [System.Text.Encoding]::UTF8.GetString($response)
            
            # Verificar éxito en la respuesta HTML
            if ($responseText -like "*Upload*Successful*" -or $responseText -like "*success*") {
                Write-Host "  [OK] Subida exitosa a $ip" -ForegroundColor Green
                $uploaded = $true
            } else {
                Write-Warning "  [WARN] Respuesta inesperada de $ip"
                # Mostrar la respuesta completa para análisis
                Write-Host "  === RESPUESTA COMPLETA ===" -ForegroundColor Yellow
                Write-Host $responseText -ForegroundColor White
                Write-Host "  =========================" -ForegroundColor Yellow
            }
            
            # Limpiar WebClient
            $webClient.Dispose()
            
            # Solo reiniciar si la subida fue exitosa
            if ($uploaded) {
                # Reiniciar el dispositivo despues de subida exitosa
                try {
                    Write-Host "  Reiniciando dispositivo en $ip..." -ForegroundColor Yellow
                    $restartUri = "http://$ip/?rst="
                    $restartResponse = Invoke-WebRequest -Uri $restartUri -Method Get -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
                    Write-Host "  [OK] Reinicio enviado a $ip" -ForegroundColor Green
                    
                    # Esperar un poco tras el reinicio
                    Start-Sleep -Seconds 2
                }
                catch {
                    Write-Warning "  [WARN] No se pudo enviar reinicio a $ip : $($_.Exception.Message)"
                }
            }
            
            break  # Salir del loop de reintentos si llegamos aquí
        }
        catch [System.Net.WebException] {
            $errorMsg = $_.Exception.Message
            $webResponse = $_.Exception.Response
            
            # Diagnosticar tipo específico de error
            if ($errorMsg -like "*terminado de forma inesperada*" -or $errorMsg -like "*connection was closed*") {
                Write-Warning "  [ERROR] Conexión cerrada inesperadamente en intento $attempt para $ip"
                Write-Host "    Posibles causas: archivo muy grande, timeout del servidor, o falta de memoria en ESP32" -ForegroundColor Yellow
            } elseif ($webResponse -ne $null) {
                Write-Warning "  [ERROR] HTTP $($webResponse.StatusCode) en intento $attempt para $ip : $errorMsg"
            } else {
                Write-Warning "  [ERROR] Intento $attempt fallo para $ip : $errorMsg"
            }
            
            if ($attempt -eq $retryCount) {
                Write-Warning "  [ERROR] Fallo después de $retryCount intentos para $ip"
            } else {
                Write-Host "  Esperando 3 segundos antes del siguiente intento..." -ForegroundColor Yellow
                Start-Sleep -Seconds 3
            }
        }
        catch [System.TimeoutException] {
            Write-Warning "  [ERROR] Timeout en intento $attempt para $ip"
            
            if ($attempt -eq $retryCount) {
                Write-Warning "  [ERROR] Timeout definitivo después de $retryCount intentos para $ip"
            } else {
                Write-Host "  Esperando 3 segundos antes del siguiente intento..." -ForegroundColor Yellow
                Start-Sleep -Seconds 3
            }
        }
        catch {
            Write-Warning "  [ERROR] Error inesperado en $ip : $($_.Exception.Message)"
            if ($attempt -lt $retryCount) {
                Write-Host "  Esperando 3 segundos antes del siguiente intento..." -ForegroundColor Yellow
                Start-Sleep -Seconds 3
            }
            # No break aquí - continuar con el siguiente intento o salir naturalmente del for loop
        }
    }
    
    # Verificar éxito final
    if ($uploaded) {
        $successfulUploads += $ip
    } else {
        $failedUploads += $ip
        Write-Warning "FALLO TOTAL: No se pudo subir archivo a $ip después de $retryCount intentos"
    }
}

# Mostrar resumen final
Write-Host ""
Write-Host ("=" * 50) -ForegroundColor White
Write-Host "RESUMEN FINAL" -ForegroundColor White
Write-Host ("=" * 50) -ForegroundColor White

if ($successfulUploads.Length -gt 0) {
    Write-Host ""
    Write-Host "EXITOS ($($successfulUploads.Length)):" -ForegroundColor Green
    foreach ($successIp in $successfulUploads) {
        Write-Host "  OK $successIp" -ForegroundColor Green
    }
}

if ($failedUploads.Length -gt 0) {
    Write-Host ""
    Write-Host "FALLOS ($($failedUploads.Length)):" -ForegroundColor Red
    foreach ($failIp in $failedUploads) {
        Write-Host "  X $failIp" -ForegroundColor Red
    }
} else {
    Write-Host ""
    Write-Host "Todos los dispositivos actualizados correctamente!" -ForegroundColor Green
}

Write-Host ""
Write-Host "Total: $($successfulUploads.Length) exitos, $($failedUploads.Length) fallos de $($ips.Length) dispositivos" -ForegroundColor White