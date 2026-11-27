﻿# HDMISwitch-Tray.ps1 - Windows 系统托盘输入源切换（与 macOS 菜单栏版对应）
# 双击 HDMISwitch.bat 启动；托盘右键出菜单：
#   一键切换 / 当前输入 / 输入源列表 / 开机自启 / 语言 / 退出

$ErrorActionPreference = "Stop"

# 加载核心脚本（只加载函数，不执行 CLI）
$coreScript = Join-Path $PSScriptRoot "switch_hdmi.ps1"
. $coreScript

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------- 多语言 ----------
# 配置存 %USERPROFILE%\.hdmi_switch_lang，可选 system / zh / en
$script:LangFile = Join-Path $env:USERPROFILE ".hdmi_switch_lang"
$script:Lang = "system"
if (Test-Path $script:LangFile) {
    $saved = (Get-Content $script:LangFile -Raw -ErrorAction SilentlyContinue)
    if ($null -ne $saved) { $script:Lang = $saved.Trim().ToLower() }
}
if ($script:Lang -notin @("system", "zh", "en")) { $script:Lang = "system" }

function Get-UiLanguage {
    return $script:Lang
}

function Set-UiLanguage([string]$Value) {
    $script:Lang = $Value
    Set-Content -Path $script:LangFile -Value $Value -Encoding ASCII
}

# 翻译：按当前语言设置返回中文或英文文案
function T([string]$zh, [string]$en) {
    $lang = Get-UiLanguage
    if ($lang -eq "zh") { return $zh }
    if ($lang -eq "en") { return $en }
    $culture = (Get-Culture).TwoLetterISOLanguageName
    if ($culture -eq "zh") { return $zh } else { return $en }
}

# 托盘图标（使用同目录 PNG，避免依赖 .ico）
$iconPath = Join-Path $PSScriptRoot "HDMISwitch.png"
$bmp = [System.Drawing.Image]::FromFile($iconPath)
$trayIcon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())

$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = $trayIcon
$notify.Text = "HDMI Switch"
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

    $toggle = $menu.Items.Add((T "一键切换" "One-click Switch"))
    $toggle.Font = New-Object System.Drawing.Font($toggle.Font, [System.Drawing.FontStyle]::Bold)
    $toggle.add_Click({
        $target = Get-NextInputCode
        $ok = Invoke-Switch $target
        $tip = T "HDMI 切换" "HDMI Switch"
        $msg = if ($ok) { (T "已切换到 " "Switched to ") + (Get-Label $target) } else { (T "切换失败" "Switch failed") }
        $notify.ShowBalloonTip(800, $tip, $msg, [System.Windows.Forms.ToolTipIcon]::Info)
    }.GetNewClosure())

    $statusRow = $menu.Items.Add((T "当前输入: 读取中…" "Current input: reading…"))
    $statusRow.Enabled = $false

    Add-Separator $menu

    foreach ($item in (Get-InputList)) {
        $row = $menu.Items.Add($item.Label)
        $row.Tag = $item.Code
        $row.add_Click({
            $code = $this.Tag
            $ok = Invoke-Switch $code
            $tip = T "HDMI 切换" "HDMI Switch"
            $msg = if ($ok) { (T "已切换到 " "Switched to ") + (Get-Label $code) } else { (T "切换失败" "Switch failed") }
            $notify.ShowBalloonTip(800, $tip, $msg, [System.Windows.Forms.ToolTipIcon]::Info)
        }.GetNewClosure())
    }

    Add-Separator $menu

    $autoRun = $menu.Items.Add((T "开机自启" "Launch at Login"))
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

    # 语言子菜单
    $langRow = $menu.Items.Add((T "语言 Language" "Language / 语言"))
    $langMenu = New-Object System.Windows.Forms.ToolStripDropDownMenu
    $options = @(
        @{ Value = "system"; Title = (T "跟随系统 / System" "System / 系统") },
        @{ Value = "zh";     Title = "中文" },
        @{ Value = "en";     Title = "English" }
    )
    foreach ($opt in $options) {
        $langItem = $langMenu.Items.Add($opt.Title)
        $langItem.Tag = $opt.Value
        if ($opt.Value -eq (Get-UiLanguage)) { $langItem.Checked = $true }
        $langItem.add_Click({
            Set-UiLanguage $this.Tag
            Update-MenuItems $menuStrip
        }.GetNewClosure())
    }
    $langRow.DropDownItems = $langMenu

    Add-Separator $menu

    $quit = $menu.Items.Add((T "退出" "Quit"))
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
    $statusText = if ($null -ne $cur) { (T "当前输入: " "Current input: ") + (Get-Label $cur) } else { (T "当前输入: 读取失败" "Current input: read failed") }
    foreach ($it in $menuStrip.Items) {
        if ($it.Text -like ((T "当前输入" "Current input") + "*")) {
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
