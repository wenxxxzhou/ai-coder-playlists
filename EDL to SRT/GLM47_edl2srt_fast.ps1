<#
.SYNOPSIS
    EDL 转 SRT 字幕转换工具 (全格式覆盖版)
.DESCRIPTION
    涵盖标准音频、游戏音频、老旧视频、工程文件等所有常见及罕见格式。
    支持小数帧率、手动指定编码、多种 EDL 格式。
.EXAMPLE
    .\edl2srt.ps1 input.edl
.EXAMPLE
    .\edl2srt.ps1 input.edl -Encoding UTF8 -Fps 29.97
#>

param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputPath,

    [Parameter(Position = 1)]
    [string]$OutputPath,

    [ValidateRange(0.1, 300.0)]
    [double]$Fps = 30,

    [ValidateSet("Default", "UTF8")]
    [string]$Encoding = "Default",

    [switch]$UseSourceTime
)

# === 配置区域：全格式扩展名列表 (含漏网之鱼) ===
# 包含：常见音频/视频、无损、游戏音乐、老旧格式、工程文件等
$ExtensionsToRemove = @(
    # --- 常见音频 (无损/有损) ---
    '.mp3', '.wav', '.flac', '.aac', '.wma', '.ogg', '.m4a', '.aif', '.aiff', 
    '.alac', '.ape', '.wv', '.opus', '.m4b', '.m4p', '.gsm', '.caf', '.au', 
    '.ra', '.amr', '.mid', '.midi', '.ac3', '.dts', '.dsd', '.pcm', '.tta',
    '.spx', '.vox', '.oga', '.mka', '.iff', '.8svx', '.16svx', '.snd', '.omf', '.omfi',

    # --- 游戏与模块音乐 (漏网之鱼) ---
    '.psf', '.psf2', '.usf', '.gym', '.spc', '.nsf', '.nsfe', '.vgm', '.gbs',
    '.mod', '.s3m', '.it', '.xm', '.669', '.med', '.mtm', '.ptm', '.dsm',
    '.far', '.dbm', '.imf', '.j2b', '.digi', '.dmf', '.umx', '.mt2', '.prowizard',

    # --- 索尼/游戏机专用 (漏网之鱼) ---
    '.at3', '.aa3', '.3ga', '.wv', '.wvc', '.rstm', '.cwav', '.brstm', '.bcstm',

    # --- 视频流与老旧格式 (漏网之鱼) ---
    '.mp4', '.avi', '.mov', '.mkv', '.webm', '.flv', '.wmv', '.m4v', '.ts', 
    '.mts', '.m2ts', '.vob', '.dv', '.rmvb', '.3gp', '.3g2', '.f4v', '.asf',
    '.mpg', '.mpeg', '.m2v', '.mpv', '.divx', '.xvid', '.ogm', '.ogv', '.mk3d',
    '.evo', '.trp', '.wtv', '.dvr-ms', '.vp6', '.rm', '.yuv', '.y4m',

    # --- 电话/录音/原始数据 (漏网之鱼) ---
    '.raw', '.dat', '.sds', '.sml', '.dwd', '.dct', '.vox', '.g721', '.g723', '.g726',
    '.g729', '.l16', '.ulaw', '.alaw', '.msv', '.dvf', '.m4r', '.m4u',

    # --- 工程/元数据/其他 ---
    '.mxf', '.xmp', '.aep', '.prproj', '.ppj', '.edl', '.xml', '.txt', '.json',
    '.log', '.aaf', '.cine', '.mcf', '.dpx'
)
# ============================================

if (-not (Test-Path $InputPath)) {
    Write-Host "错误: 输入文件 '$InputPath' 不存在" -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = [System.IO.Path]::ChangeExtension($InputPath, ".srt")
}

Write-Host "正在转换（全格式覆盖模式）..." -ForegroundColor Green
Write-Host "源文件: $InputPath" -ForegroundColor Cyan
Write-Host "输出文件: $OutputPath" -ForegroundColor Cyan
$FpsDisplay = if ($Fps -eq [math]::Truncate($Fps)) { $Fps.ToString("F0") } else { $Fps.ToString("F2") }
Write-Host "帧率: $FpsDisplay FPS" -ForegroundColor Cyan
Write-Host "编码模式: $Encoding" -ForegroundColor Cyan

if ($UseSourceTime) { Write-Host "警告: 已强制使用 Source Time (原始素材时间)" -ForegroundColor Yellow } 
else { Write-Host "模式: Record Time (成片时间轴时间)" -ForegroundColor Cyan }

$srtIndex = 0
$lines = Get-Content -Path $InputPath -Encoding $Encoding
$streamWriter = [System.IO.StreamWriter]::new($OutputPath, $false, [System.Text.Encoding]::UTF8)

function Convert-Time {
    param ($timeStr)
    if ($timeStr -match "^(\d{2}):(\d{2}):(\d{2}):(\d{2})$") {
        $h = [int]$matches[1]
        $m = [int]$matches[2]
        $s = [int]$matches[3]
        $f = [int]$matches[4]
        $ms = [int][math]::Round($f * 1000 / $Fps)
        return "{0:00}:{1:00}:{2:00},{3:000}" -f $h, $m, $s, $ms
    }
    return $timeStr
}

foreach ($line in $lines) {
    $trimLine = $line.Trim()
    if ($trimLine.Length -eq 0) { continue }

    $matches = [regex]::Matches($trimLine, "\d{2}:\d{2}:\d{2}:\d{2}")
    
    $time1 = $null
    $time2 = $null
    $text = $null

    if ($matches.Count -ge 4) {
        $time1 = $matches[2].Value
        $time2 = $matches[3].Value
        if ($UseSourceTime) {
            $time1 = $matches[0].Value
            $time2 = $matches[1].Value
        }
    }
    elseif ($matches.Count -eq 2) {
        $time1 = $matches[0].Value
        $time2 = $matches[1].Value
    }

    if ($time1 -and $time2) {
        $pendingStart = Convert-Time $time1
        $pendingEnd = Convert-Time $time2
    }

    # 依次尝试匹配名字字段
    if ($trimLine -match "\*\s*FROM\s+CLIP\s+NAME:\s*(.*)") {
        $text = $matches[1].Trim()
    }
    elseif ($trimLine -match "\*\s*TO\s+CLIP\s+NAME:\s*(.*)") {
        $text = $matches[1].Trim()
    }
    elseif ($trimLine -match "\*\s*CLIP\s+NAME:\s*(.*)") {
        $text = $matches[1].Trim()
    }
    elseif ($trimLine -match "\*\s*COMMENT:\s*(.*)") {
        $text = $matches[1].Trim()
    }

    if ($text -and $pendingStart -and $pendingEnd) {
        $srtIndex++
        
        # 清理扩展名（循环遍历大列表）
        foreach ($ext in $ExtensionsToRemove) {
            if ($text.EndsWith($ext, [StringComparison]::OrdinalIgnoreCase)) {
                $text = $text.Substring(0, $text.Length - $ext.Length).Trim()
                break
            }
        }
        
        $streamWriter.WriteLine($srtIndex)
        $streamWriter.WriteLine("$pendingStart --> $pendingEnd")
        $streamWriter.WriteLine($text)
        $streamWriter.WriteLine()

        $pendingStart = $null
        $pendingEnd = $null
    }
}

$streamWriter.Close()
Write-Host "转换完成！共生成 $srtIndex 条字幕。" -ForegroundColor Green
