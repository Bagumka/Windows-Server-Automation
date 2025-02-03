<#
 Licensed to Vadym Klymenko under one or more contributor license agreements.
 See the NOTICE file distributed with this work for additional information regarding copyright ownership.
 Vadym Klymenko licenses this file to You under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
#>

$ScriptVersion = "1.0.0"

# Проверка и перезапуск с повышением прав, если нужно
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "Требуются права администратора. Перезапуск..."
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$targetPath = "D:\Medoc\ZVIT_ARC"

# Создаём целевую директорию, если её нет
if (!(Test-Path $targetPath)) {
    New-Item -ItemType Directory -Path $targetPath | Out-Null
    Write-Host "Создана директория $targetPath"
}

# Обходим все папки пользователей
Get-ChildItem "D:\Users" -Directory | ForEach-Object {
    $zvitArcPath = Join-Path $_.FullName "Documents\ZVIT_ARC"

    # Проверяем, существует ли ZVIT_ARC
    if (Test-Path $zvitArcPath) {
        # Проверяем, не является ли эта папка уже символьной ссылкой
        if ((Get-Item $zvitArcPath).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Write-Host "Папка $zvitArcPath уже является символьной ссылкой. Пропускаем..."
        }
        else {
            Write-Host "Обрабатывается: $zvitArcPath"
            # Переносим все файлы/папки в общий каталог
            Move-Item -Path (Join-Path $zvitArcPath "*") -Destination $targetPath -Recurse -Force -ErrorAction SilentlyContinue

            # Удаляем старую папку
            Remove-Item $zvitArcPath -Recurse -Force

            # Создаём символьную ссылку (через cmd)
            cmd /c "mklink /D `"$zvitArcPath`" `"$targetPath`""
            Write-Host "Символьная ссылка создана: $zvitArcPath -> $targetPath"
        }
    }
    else {
        # Папки нет совсем - просто создаём ссылку
        Write-Host "Папка $zvitArcPath отсутствует. Создаём ссылку..."
        # Убедимся, что папка Documents существует, чтобы корректно создать ссылку
        $documentsPath = Join-Path $_.FullName "Documents"
        if (!(Test-Path $documentsPath)) {
            Write-Host "Папка $documentsPath не существует. Создаём..."
            New-Item -ItemType Directory -Path $documentsPath | Out-Null
        }

        cmd /c "mklink /D `"$zvitArcPath`" `"$targetPath`""
        Write-Host "Символьная ссылка создана: $zvitArcPath -> $targetPath"
    }
}

Write-Host "Готово!"
