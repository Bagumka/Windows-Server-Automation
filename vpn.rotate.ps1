# Имя вашего VPN-подключения
$VpnName = "TT Auto"

# 1. Получаем текущую конфигурацию (для всех пользователей)
$vpn = Get-VpnConnection -Name $VpnName

if (-not $vpn) {
    Write-Host "VPN с именем '$VpnName' не найдено." -ForegroundColor Red
    return
}

# 2. Извлекаем список серверов из ServerList (CimInstance объектов)
#    и берём из них свойство Address (строки).
$servers = $vpn.ServerList | Select-Object -ExpandProperty ServerAddress

if (-not $servers) {
    Write-Host "ServerList пуст или не содержит адресов. Нечего переключать." -ForegroundColor Yellow
    return
}

# 3. Определяем, какой адрес сейчас установлен "главным"
$currentAddress = $vpn.ServerAddress  # Строка, например "127.0.0.1"
Write-Host "Текущий адрес:" $currentAddress

# 4. Находим индекс текущего адреса в массиве. Если не найдено, считаем индекс 0.
$idx = [Array]::IndexOf($servers, $currentAddress)

if ($idx -lt 0) {
    # Если вдруг текущий адрес не нашли в списке - начнём с нуля
    $idx = 0
} else {
    # Иначе берём следующий индекс циклически
    $idx = ($idx + 1) % $servers.Count
}

$newServer = $servers[$idx]
Write-Host "Переключаемся на:" $newServer

# 5. Если VPN сейчас подключён - желательно отключиться
if ($vpn.ConnectionStatus -eq "Connected") {
    Write-Host "VPN '$VpnName' активно. Отключаем..."
    rasdial $VpnName /disconnect | Out-Null
    Start-Sleep -Seconds 1
}

# 6. Устанавливаем новый адрес серверa.
Set-VpnConnection -Name $VpnName -ServerAddress $newServer -Force

Write-Host "Адрес VPN '$VpnName' обновлён. Теперь ServerAddress=$newServer."

# 7. (Необязательно) Снова подключаемся
# rasdial $VpnName

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# -- СОЗДАЁМ ФОРМУ --
$form = New-Object System.Windows.Forms.Form
$form.Text = "Информация"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(300, 150)
$form.Topmost = $true  # по желанию, чтобы было поверх всех окон

# -- НАДПИСЬ --
$label = New-Object System.Windows.Forms.Label
$label.Text = "Сервер изменен"
$label.AutoSize = $true
$label.Font = 'Microsoft Sans Serif,12'
$label.Location = New-Object System.Drawing.Point(85, 20)
$form.Controls.Add($label)

# -- КНОПКА --
$button = New-Object System.Windows.Forms.Button
$button.Size = New-Object System.Drawing.Size(100, 30)
$button.Location = New-Object System.Drawing.Point(95, 60)
$form.Controls.Add($button)

# -- ОБРАТНЫЙ ОТСЧЁТ --
$secondsLeft = 5
$button.Text = "Закрыть ($secondsLeft)"

# Кнопка «Закрыть» вручную
$button.Add_Click({ $form.Close() })

# -- ТАЙМЕР --
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000  # 1 сек

$timer.Add_Tick({
    $secondsLeft--
    if ($secondsLeft -le 0) {
        $timer.Stop()
        $form.Close()
    }
    else {
        $button.Text = "Закрыть ($secondsLeft)"
    }
})

# Запускаем таймер, когда форма показана
$form.Add_Shown({
    $timer.Start()
})

# -- ОТОБРАЖАЕМ ФОРМУ МОДАЛЬНО --
$form.ShowDialog()