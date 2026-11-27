# HDMISwitch-Tray.ps1 - Windows 系统托盘输入源切换（与 macOS 菜单栏版对应）
# 双击 HDMISwitch.bat 启动；托盘右键出菜单：
#   一键切换 / 当前输入 / 输入源列表 / 开机自启 / 退出

$ErrorActionPreference = "Stop"

# 加载核心脚本（只加载函数，不执行 CLI）
$coreScript = Join-Path $PSScriptRoot "switch_hdmi.ps1"
. $coreScript

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 托盘图标（使用同目录 PNG，避免依赖 .ico）
$iconPath = Join-Path $PSScriptRoot "HDMISwitch.png"
$bmp = [System.Drawing.Image]::FromFile($iconPath)
$trayIcon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())

$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = $trayIcon
$notify.Text = "HDMI 输入切换"
$notify.Visible = $true

$form = New-Object System.Windows.Forms.Form
$form.ShowInTaskbar = $false
$form.WindowState = "Minimized"
$form.FormBorderStyle = "FixedToolWindow"

# ---------- 菜单构建 ----------
function Add-Separator($menu) {
    $null = $menu.Items.Add(New-Object System.Windows.Forms.ToolStripSeparator)
}

function Update-MenuItems($menu) {
    $menu.Items.Clear()

    $toggle = $menu.Items.Add("一键切换")
    $toggle.Font = New-Object System.Drawing.Font($toggle.Font, [System.Drawing.FontStyle]::Bold)
    $toggle.add_Click({
        $msg = Invoke-CycleSwitch
        $notify.ShowBalloonTip(800, "HDMI 切换", $msg, [System.Windows.Forms.ToolTipIcon]::Info)
    }.GetNewClosure())

    $statusText = "当前输入: 读取中…"
    $statusRow = $menu.Items.Add($statusText)
    $statusRow.Enabled = $false

    Add-Separator $menu

    foreach ($item in (Get-InputList)) {
        $row = $menu.Items.Add($item.Label)
        $row.Tag = $item.Code
        $row.add_Click({
            $code = $this.Tag
            $ok = Invoke-Switch $code
            $msg = if ($ok) { "已切换到 " + (Get-Label $code) } else { "切换失败" }
            $notify.ShowBalloonTip(800, "HDMI 切换", $msg, [System.Windows.Forms.ToolTipIcon]::Info)
        }.GetNewClosure())
    }

    Add-Separator $menu

    $autoRun = $menu.Items.Add("开机自启")
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $existing = (Get-ItemProperty -Path $runKey -Name "HDMISwitch" -ErrorAction SilentlyContinue)
    if ($null -ne $existing) { $autoRun.Checked = $true }
    $autoRun.add_Click({
        $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSScriptRoot\HDMISwitch-Tray.ps1`""
        if ($this.Checked) {
            Remove-ItemProperty -Path $runKey -Name "HDMISwitch" -ErrorAction SilentlyContinue
            $this.Checked = $false
        } else {
            Set-ItemProperty -Path $runKey -Name "HDMISwitch" -Value $cmd
            $this.Checked = $true
        }
    }.GetNewClosure())

    Add-Separator $menu

    $quit = $menu.Items.Add("退出")
    $quit.add_Click({
        $notify.Visible = $false
        $form.Close()
        [System.Windows.Forms.Application]::Exit()
    }.GetNewClosure())
}

# ---------- 菜单打开时刷新当前输入 ----------
$menuStrip = New-Object System.Windows.Forms.ContextMenuStrip
$menuStrip.add_Opening({
    Update-MenuItems $menuStrip
    # 快速读一次当前输入（读不到就标记读取失败）
    $cur = Get-InputCode
    $statusText = if ($null -ne $cur) { "当前输入: " + (Get-Label $cur) } else { "当前输入: 读取失败" }
    foreach ($it in $menuStrip.Items) {
        if ($it.Text -like "当前输入*") {
            $it.Text = $statusText
            if ($null -ne $cur) {
                foreach ($it2 in $menuStrip.Items) {
                    if ($it2.Tag -eq $cur) { $it2.Checked = $true } else { $it2.Checked = $false }
                }
            }
            break
        }
    }
})
Update-MenuItems $menuStrip
$notify.ContextMenuStrip = $menuStrip

# 左键单击托盘图标也弹出菜单
$notify.add_MouseUp({
    if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $notify.ContextMenuStrip.Show([System.Windows.Forms.Cursor]::Position)
    }
})

[System.Windows.Forms.Application]::Run($form)
