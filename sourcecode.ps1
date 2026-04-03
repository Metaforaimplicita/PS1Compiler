$Host.UI.RawUI.WindowTitle = "Compilador Maestro ps2exe - V1.0" by metaforaimplicita

# 1. Verificacion y Auto-Elevacion a Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[!] Solicitando permisos de seguridad..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"") -Verb RunAs
    exit
}

# 2. Bucle Principal del Menu
while ($true) {
    Clear-Host
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "          SISTEMA DE EMPAQUETADO DE SOFTWARE (.EXE)" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1. INSTALAR RECURSOS (Preparar entorno de compilacion)"
    Write-Host "  2. COMPILAR SCRIPT (Convertir .ps1 a .exe)"
    Write-Host "  3. SALIR"
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Cyan
    
    $mainOpt = Read-Host "Seleccione una opcion (1-3)"

    switch ($mainOpt) {
        "1" {
            Write-Host "`n[*] INICIANDO PREPARACION DEL ENTORNO..." -ForegroundColor Yellow
            Write-Host "--------------------------------------------------------"
            
            # A. Verificar e instalar el proveedor NuGet (Requisito oculto de Windows)
            Write-Host "[+] Verificando proveedor de paquetes base (NuGet)..."
            if (-not (Get-PackageProvider -Name "NuGet" -ListAvailable -ErrorAction SilentlyContinue)) {
                Write-Host "  -> Instalando NuGet..." -ForegroundColor Yellow
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
                Write-Host "  -> NuGet instalado." -ForegroundColor Green
            } else {
                Write-Host "  -> NuGet ya esta listo." -ForegroundColor Green
            }

            # B. Confiar en PSGallery temporalmente (Evita confirmaciones manuales que rompen el script)
            Write-Host "[+] Configurando repositorio oficial de Microsoft..."
            Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction SilentlyContinue

            # C. Verificar e instalar el motor ps2exe
            Write-Host "[+] Verificando motor de compilacion (ps2exe)..."
            if (-not (Get-Module -ListAvailable -Name ps2exe)) {
                Write-Host "  -> Descargando e instalando ps2exe (esto puede tomar un minuto)..." -ForegroundColor Yellow
                Install-Module -Name ps2exe -Force -AllowClobber
                Write-Host "  -> ps2exe instalado correctamente." -ForegroundColor Green
            } else {
                Write-Host "  -> ps2exe ya esta instalado y listo para usar." -ForegroundColor Green
            }
            
            # D. Restaurar seguridad de PSGallery (Buenas practicas de limpieza)
            Set-PSRepository -Name "PSGallery" -InstallationPolicy Untrusted -ErrorAction SilentlyContinue

            Write-Host "--------------------------------------------------------"
            Write-Host "[OK] EL ENTORNO ESTA 100% LISTO PARA COMPILAR." -ForegroundColor Green
            Pause
        }
        "2" {
            # Bloqueo de seguridad: Evitar intentar compilar si no estan los recursos
            if (-not (Get-Module -ListAvailable -Name ps2exe)) {
                Write-Host "`n[X] ERROR: El motor de compilacion no esta instalado." -ForegroundColor Red
                Write-Host "    -> Por favor, ejecuta la Opcion 1 del menu primero." -ForegroundColor Red
                Pause
                continue
            }

            Write-Host "`n[*] INICIANDO ASISTENTE DE COMPILACION..." -ForegroundColor Yellow
            
            $inputPath = Read-Host "[?] Ingresa la ruta de la carpeta con tus scripts (Ej: C:\Users\TuUsuario\Desktop)"
            
            if (-not (Test-Path $inputPath)) {
                Write-Host "`n[X] ERROR: La ruta no existe. Verifica e intenta de nuevo." -ForegroundColor Red
                Pause
                continue
            }

            $files = Get-ChildItem -Path $inputPath -Filter "*.ps1" -File
            
            if ($files.Count -eq 0) {
                Write-Host "`n[!] No se encontraron archivos .ps1 en la carpeta seleccionada." -ForegroundColor Yellow
                Pause
                continue
            }

            Write-Host "`n[*] Archivos compatibles encontrados:" -ForegroundColor Green
            Write-Host "--------------------------------------------------------"
            for ($i = 0; $i -lt $files.Count; $i++) {
                Write-Host "  [$($i + 1)] $($files[$i].Name)" -ForegroundColor White
            }
            Write-Host "--------------------------------------------------------"

            $selectedFile = $null
            while ($null -eq $selectedFile) {
                $selection = Read-Host "`n[?] Selecciona el numero del archivo que deseas compilar"
                if ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $files.Count) {
                    $selectedIndex = [int]$selection - 1
                    $selectedFile = $files[$selectedIndex].FullName
                    $selectedName = $files[$selectedIndex].BaseName
                } else {
                    Write-Host "[X] Numero invalido. Intenta nuevamente." -ForegroundColor Red
                }
            }

            $outputPath = Read-Host "`n[?] Ingresa la carpeta de destino (Presiona ENTER para guardar en la misma carpeta origen)"
            if ([string]::IsNullOrWhiteSpace($outputPath)) {
                $outputPath = $inputPath
            } elseif (-not (Test-Path $outputPath)) {
                Write-Host "[-] Creando nueva carpeta de destino..." -ForegroundColor Yellow
                New-Item -ItemType Directory -Path $outputPath | Out-Null
            }

            $outputName = Read-Host "`n[?] Ingresa el nombre final para tu programa (Ej: MiSoftware) [Presiona ENTER para usar '$selectedName']"
            if ([string]::IsNullOrWhiteSpace($outputName)) {
                $outputName = $selectedName
            }
            
            if (-not $outputName.EndsWith(".exe", [System.StringComparison]::OrdinalIgnoreCase)) {
                $outputName += ".exe"
            }

            $finalOutputPath = Join-Path -Path $outputPath -ChildPath $outputName

            Write-Host "`n========================================================" -ForegroundColor Cyan
            Write-Host "[+] INICIANDO COMPILACION..." -ForegroundColor Yellow
            Write-Host "    Origen:  $selectedFile"
            Write-Host "    Destino: $finalOutputPath"
            Write-Host "========================================================`n"

            try {
                Invoke-ps2exe -inputFile $selectedFile -outputFile $finalOutputPath -requireAdmin
                Write-Host "`n[OK] COMPILACION EXITOSA. Tu software esta listo para ser distribuido." -ForegroundColor Green
            } catch {
                Write-Host "`n[X] ERROR CRITICO DURANTE LA COMPILACION:" -ForegroundColor Red
                Write-Host $_.Exception.Message
            }
            Pause
        }
        "3" {
            exit
        }
    }
}
