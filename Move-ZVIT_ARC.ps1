$ScriptVersion = "1.0.1"

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

<#
.SYNOPSIS
    Перенос файлов архивных копий M.E.Doc из папок пользователей в централизованное хранилище
.DESCRIPTION
    Скрипт выполняет следующие действия:
      - Создаём целевую директорию, если её нет
      - Обходим все папки пользователей
      - Проверяем, существует ли ZVIT_ARC
      - Проверяем, не является ли эта папка уже символьной ссылкой
      - Переносим все файлы/папки в общий каталог
      - Удаляем старую папку
      - Создаём символьную ссылку
      - Папки нет совсем - просто создаём ссылку
.NOTES
    Требуется запуск от имени администратора.
#>

###########################################################################
#
# Configurable settings

$usersPath = "C:\Users"
$targetPath = "C:\Medoc\ZVIT_ARC"

# End of configurable settings. 
# The user does not need to pay attention to what follows below this block.
#
###########################################################################

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "Требуются права администратора. Перезапуск..."
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

if (!(Test-Path $targetPath)) {
    New-Item -ItemType Directory -Path $targetPath | Out-Null
    Write-Host "Создана директория $targetPath"
}

Get-ChildItem $usersPath -Directory | ForEach-Object {
    $zvitArcPath = Join-Path $_.FullName "Documents\ZVIT_ARC"
    if (Test-Path $zvitArcPath) {
        if ((Get-Item $zvitArcPath).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Write-Host "Папка $zvitArcPath уже является символьной ссылкой. Пропускаем..."
        }
        else {
            Write-Host "Обрабатывается: $zvitArcPath"
            Move-Item -Path (Join-Path $zvitArcPath "*") -Destination $targetPath -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item $zvitArcPath -Recurse -Force
            New-Item -Path $zvitArcPath -ItemType SymbolicLink -Target $targetPath
            Write-Host "Символьная ссылка создана: $zvitArcPath -> $targetPath"
        }
    }
    else {
        Write-Host "Папка $zvitArcPath отсутствует. Создаём ссылку..."
        $documentsPath = Join-Path $_.FullName "Documents"
        if (!(Test-Path $documentsPath)) {
            Write-Host "Папка $documentsPath не существует. Создаём..."
            New-Item -ItemType Directory -Path $documentsPath | Out-Null
        }
        New-Item -Path $zvitArcPath -ItemType SymbolicLink -Target $targetPath
        Write-Host "Символьная ссылка создана: $zvitArcPath -> $targetPath"
    }
}
Write-Host "Готово!"
