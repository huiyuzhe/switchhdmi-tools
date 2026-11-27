# switch_hdmi.ps1 - Windows 显示器输入源切换核心脚本（DDC/CI，无第三方依赖）
# 用法: powershell -NoProfile -ExecutionPolicy Bypass -File switch_hdmi.ps1 [toggle|list|current|status|<代码>]
#   toggle  按输入源列表顺序循环切换（默认）
#   list    列出所有输入源（代码<TAB>名称）
#   current 输出当前输入源代码（失败则非 0 退出）
#   status  人类可读的当前输入源
#   <代码>  直接切到指定输入源
# 也可被托盘脚本 dot-source 复用函数

# ============ 可配置区 ============
# 输入源列表，格式 "代码:名称"，按顺序排列；一键切换按此列表循环
# 常见 VCP 0x60 代码: 15=HDMI1 17=HDMI2 18=HDMI3 4=DP1 11=DP2
$script:INPUTS = @(
    "15:HDMI 1（另一台电脑）",
    "17:HDMI 2（本机）"
)
$script:StateFile = Join-Path $env:USERPROFILE ".hdmi_switch_state"
$script:VcpCode = 0x60
# ==================================

Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class DdcTool
{
    public delegate bool MonitorEnumDelegate(IntPtr hMonitor, IntPtr hdcMonitor, ref RECT rect, IntPtr data);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct PHYSICAL_MONITOR
    {
        public IntPtr hPhysicalMonitor;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string szPhysicalMonitorDescription;
    }

    [DllImport("user32.dll")]
    public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr rect, MonitorEnumDelegate fn, IntPtr data);

    [DllImport("dxva2.dll")]
    public static extern bool GetNumberOfPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, ref uint count);

    [DllImport("dxva2.dll")]
    public static extern bool GetPhysicalMonitorsFromHMONITOR(IntPtr hMonitor, uint count, [In, Out] PHYSICAL_MONITOR[] monitors);

    [DllImport("dxva2.dll")]
    public static extern bool GetVCPFeatureAndVCPFeatureReply(IntPtr hMonitor, byte code, ref uint type, ref uint current, ref uint max);

    [DllImport("dxva2.dll")]
    public static extern bool SetVCPFeature(IntPtr hMonitor, byte code, uint value);

    [DllImport("dxva2.dll")]
    public static extern bool DestroyPhysicalMonitor(IntPtr hMonitor);

    private static List<IntPtr> _logical = new List<IntPtr>();

    private static bool EnumCallback(IntPtr hMonitor, IntPtr hdc, ref RECT rect, IntPtr data)
    {
        _logical.Add(hMonitor);
        return true;
    }

    // 枚举所有逻辑显示器并展开成物理显示器句柄
    public static List<IntPtr> GetPhysicalMonitors()
    {
        var result = new List<IntPtr>();
        _logical.Clear();
        var del = new MonitorEnumDelegate(EnumCallback);
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, del, IntPtr.Zero);
        foreach (var logical in _logical)
        {
            uint count = 0;
            if (!GetNumberOfPhysicalMonitorsFromHMONITOR(logical, ref count) || count == 0) continue;
            var arr = new PHYSICAL_MONITOR[count];
            if (!GetPhysicalMonitorsFromHMONITOR(logical, count, arr)) continue;
            foreach (var m in arr) result.Add(m.hPhysicalMonitor);
        }
        return result;
    }

    public static uint? GetVCP(IntPtr monitor, byte code)
    {
        uint type = 0, current = 0, max = 0;
        if (GetVCPFeatureAndVCPFeatureReply(monitor, code, ref type, ref current, ref max)) return current;
        return null;
    }

    public static bool SetVCP(IntPtr monitor, byte code, uint value)
    {
        return SetVCPFeature(monitor, code, value);
    }
}
"@

function Get-InputCode {
    # 读取当前输入源代码，重试 3 次，失败返回 $null
    for ($try = 0; $try -lt 3; $try++) {
        foreach ($mon in [DdcTool]::GetPhysicalMonitors()) {
            $val = [DdcTool]::GetVCP($mon, $script:VcpCode)
            if ($null -ne $val -and $val -gt 0) { return [string]$val }
        }
        Start-Sleep -Milliseconds 300
    }
    return $null
}

function Get-Label([string]$Code) {
    foreach ($entry in $script:INPUTS) {
        $parts = $entry -split ":", 2
        if ($parts[0] -eq $Code) { return $parts[1] }
    }
    return "输入 $Code"
}

function Get-InputList {
    # 返回 @(@{Code=..;Label=..}, ...)
    $list = @()
    foreach ($entry in $script:INPUTS) {
        $parts = $entry -split ":", 2
        $list += , @{ Code = $parts[0]; Label = $parts[1] }
    }
    return $list
}

function Get-IndexOfCode([string]$Code) {
    $list = Get-InputList
    for ($i = 0; $i -lt $list.Count; $i++) {
        if ($list[$i].Code -eq $Code) { return $i }
    }
    return $null
}

function Invoke-Switch([string]$Target) {
    # 切换到指定代码；返回 $true/$false
    $ok = $false
    foreach ($mon in [DdcTool]::GetPhysicalMonitors()) {
        if ([DdcTool]::SetVCP($mon, $script:VcpCode, [uint32]::Parse($Target))) { $ok = $true }
    }
    if ($ok) {
        Set-Content -Path $script:StateFile -Value $Target -Encoding ASCII
    }
    return $ok
}

function Invoke-CycleSwitch {
    # 按列表顺序循环切换，返回结果描述字符串
    $cur = Get-InputCode
    $idx = $null
    if ($null -ne $cur) {
        $idx = Get-IndexOfCode $cur
    }
    if ($null -eq $idx -and (Test-Path $script:StateFile)) {
        # 读取失败时退回状态文件记忆
        $last = (Get-Content $script:StateFile -Raw -ErrorAction SilentlyContinue)
        if ($null -ne $last) { $idx = Get-IndexOfCode $last.Trim() }
    }
    $list = Get-InputList
    if ($null -ne $idx) {
        $next = ($idx + 1) % $list.Count
    } else {
        $next = 0
    }
    $target = $list[$next].Code
    if (Invoke-Switch $target) {
        return "已切换到 " + (Get-Label $target)
    }
    return "切换失败"
}

function Main([string[]]$Arguments) {
    $cmd = if ($Arguments.Count -ge 1) { $Arguments[0] } else { "toggle" }
    switch -Regex ($cmd) {
        "^toggle$" { Invoke-CycleSwitch }
        "^list$" {
            foreach ($item in (Get-InputList)) {
                "{0}`t{1}" -f $item.Code, $item.Label
            }
        }
        "^current$" {
            $c = Get-InputCode
            if ($null -eq $c) { exit 1 } else { $c }
        }
        "^status$" {
            $c = Get-InputCode
            if ($null -eq $c) { "读取失败（显示器无响应）" } else { "当前输入: " + (Get-Label $c) + " ($c)" }
        }
        "^[0-9]+$" {
            if (Invoke-Switch $cmd) { "已切换到 " + (Get-Label $cmd) } else { "切换失败" }
        }
        default {
            Write-Output "用法: switch_hdmi.ps1 [toggle|list|current|status|<输入代码>]"
            exit 2
        }
    }
}

# 直接执行时才运行 CLI；被托盘脚本 dot-source 时只加载函数
if ($MyInvocation.InvocationName -ne ".") {
    Main $args
}
