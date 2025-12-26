<#
    ============================================
    Find-Duplicates-Ultimate.ps1
    ============================================
    功能：在指定目录下查找重复文件，支持按文件名或文件哈希(Hash)匹配。
    功能：支持将重复文件移动到带时间戳的归档文件夹中。
    作者：智谱清言 (GLM-4.7 by Zhipu AI)
    版本：3.0 (Final)
    ============================================
#>

param(
    [Parameter(Mandatory = $true, HelpMessage = "请输入要扫描的目录路径")]
    [string]$DirectoryPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Name', 'Hash')]
    [string]$MatchMode = 'Hash',

    [Parameter(Mandatory = $false)]
    [ValidateSet('MD5', 'SHA1', 'SHA256')]
    [string]$Algorithm = 'SHA256',

    [Parameter(Mandatory = $false)]
    [switch]$Recurse,

    [Parameter(Mandatory = $false)]
    [string[]]$IncludeExtensions,

    [Parameter(Mandatory = $false)]
    [string[]]$ExcludeExtensions,

    [Parameter(Mandatory = $false)]
    [switch]$MoveDuplicates
)

# ================= 辅助函数 =================

function Write-Report {
    param(
        [string]$Message,
        [ConsoleColor]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
    # 同时写入缓冲区，以便最后导出到文件
    $script:OutputBuffer += $Message
}

function Get-SafeFolderName {
    param (
        [string]$name
    )
    # 1. 移除 Windows 不允许的文件名字符
    $clean = $name -replace '[\\/:*?"<>|]', '_'
    
    # 2. 去除首尾空白和点
    $clean = $clean.Trim().Trim('.')
    
    # 3. 处理 Windows 保留设备名
    $reservedNames = @('CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9')
    if ($clean -in $reservedNames) {
        $clean = "Dup_$clean"
    }
    
    # 4. 防止处理完后的名字为空
    if ([string]::IsNullOrWhiteSpace($clean)) {
        $clean = "Unnamed_$(Get-Random)"
    }
    
    return $clean
}

# ================= 1. 初始化 =================

$script:OutputBuffer = New-Object System.Collections.Generic.List[string]
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ResolvedPath = $null

try {
    $ResolvedPath = Resolve-Path -Path $DirectoryPath -ErrorAction Stop
}
catch {
    Write-Host "错误: 无法找到路径 '$DirectoryPath'。" -ForegroundColor Red
    exit 1
}

# ================= 2. 扫描文件 =================

$splat = @{
    Path        = $ResolvedPath
    File        = $true
    Recurse     = $Recurse
    Force       = $false # 建议设为 false 以免扫描系统文件，如需扫描隐藏文件请改为 true
    ErrorAction = 'SilentlyContinue'
}

if ($IncludeExtensions) {
    $splat['Include'] = $IncludeExtensions
}

if ($ExcludeExtensions) {
    $splat['Exclude'] = $ExcludeExtensions
}

Write-Report "`n========== 重复文件监测 (模式: $MatchMode) ==========" Cyan
Write-Report "扫描路径: $ResolvedPath" White

# 显示递归状态
$recurseStatus = if ($Recurse) { "是" } else { "否" }
Write-Report "递归子目录: $recurseStatus" Gray

Write-Report "获取文件列表中..." Gray
$files = Get-ChildItem @splat

if ($files.Count -eq 0) {
    Write-Report "未找到任何文件。" Yellow
    exit 0
}

Write-Report "已找到 $($files.Count) 个文件，开始分析..." Gray

# ================= 3. 分析逻辑 =================

$duplicateGroups = [System.Collections.Generic.List[object]]::new()
$script:progressIndex = 0

if ($MatchMode -eq 'Name') {
    # 按文件名分组
    $groups = $files | Group-Object -Property BaseName
    
    foreach ($group in $groups) {
        if ($group.Count -gt 1) {
            $duplicateGroups.Add($group)
        }
    }
}
else {
    # 按 Hash 分组
    $hashMap = @{}
    
    foreach ($file in $files) {
        $script:progressIndex++
        # 进度条 (每100个文件更新一次，提升性能)
        if ($script:progressIndex % 100 -eq 0) {
            Write-Progress -Activity "正在计算 Hash ($Algorithm)" -Status "$script:progressIndex / $($files.Count)" -PercentComplete (($script:progressIndex / $files.Count) * 100)
        }

        try {
            $fileHash = (Get-FileHash -Path $file.FullName -Algorithm $Algorithm -ErrorAction Stop).Hash
        }
        catch {
            # 文件被占用或无法读取，跳过
            continue
        }

        if (-not $hashMap.ContainsKey($fileHash)) {
            $hashMap[$fileHash] = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
        }
        $hashMap[$fileHash].Add($file)
    }

    Write-Progress -Activity "Hash计算完成" -Completed

    foreach ($key in $hashMap.Keys) {
        $list = $hashMap[$key]
        if ($list.Count -gt 1) {
            # 将List转换为自定义对象以适配输出格式
            $group = [PSCustomObject]@{
                Name  = $list[0].Name
                Count = $list.Count
                Group = $list
                Key   = $key # Hash值
            }
            $duplicateGroups.Add($group)
        }
    }
}

# ================= 4. 结果输出 =================

Write-Report "`n扫描完成！发现 $($duplicateGroups.Count) 组重复文件。" Green

if ($duplicateGroups.Count -gt 0) {
    Write-Report "`n========== 重复文件列表 ==========" Yellow
    
    # 按文件数量降序排序
    $sortedGroups = $duplicateGroups | Sort-Object -Property Count -Descending

    foreach ($group in $sortedGroups) {
        $filesList = $group.Group | ForEach-Object { $_.FullName }
        $filesString = $filesList -join "`n  -> "
        
        $header = "【重复组】文件: $($group.Name) ($($group.Count) 个副本)"
        if ($MatchMode -eq 'Hash') { $header += " | Hash: $($group.Key.Substring(0, 8))..." }
        
        Write-Report $header Yellow
        Write-Report "  -> $filesString" Gray
    }
}

# ================= 5. 移动文件逻辑 (可选) =================

if ($MoveDuplicates -and $duplicateGroups.Count -gt 0) {
    Write-Report "`n========== 文件归档移动 ==========" Yellow
    
    # 生成带时间戳的根文件夹名
    $dupFolderName = "_duplicates_$timestamp"
    $dupRoot = Join-Path -Path $ResolvedPath -ChildPath $dupFolderName
    
    Write-Report "目标归档文件夹: $dupRoot" Gray
    Write-Report "准备将 $($duplicateGroups.Count) 组重复文件移入上述文件夹的子目录中。" Gray
    
    # CLI 交互确认
    $confirmation = Read-Host "确认要移动这些文件吗？输入 'Y' 继续，其他任意键取消"
    
    if ($confirmation -eq 'Y' -or $confirmation -eq 'y') {
        # 确保根归档文件夹存在
        if (-not (Test-Path -Path $dupRoot)) {
            try {
                New-Item -Path $dupRoot -ItemType Directory -Force | Out-Null
            }
            catch {
                Write-Warning "无法创建归档文件夹: $_"
                exit 1
            }
        }

        $moveCount = 0
        $errorCount = 0

        foreach ($group in $sortedGroups) {
            # 获取每组中的第一个文件作为文件夹命名依据
            $firstFile = $group.Group[0]
            
            # 生成安全的文件夹名
            $safeFolderName = Get-SafeFolderName -name $firstFile.BaseName
            
            # 构建子文件夹路径
            $targetDir = Join-Path -Path $dupRoot -ChildPath $safeFolderName
            
            # 创建子文件夹 (如果不存在)
            if (-not (Test-Path -Path $targetDir)) {
                New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
            }

            # 移动该组内的所有文件
            foreach ($file in $group.Group) {
                try {
                    # -Force 允许覆盖目标文件夹中同名文件
                    Move-Item -Path $file.FullName -Destination $targetDir -Force -ErrorAction Stop
                    $moveCount++
                }
                catch {
                    Write-Warning "移动失败: $($file.FullName) - 原因: $($_.Exception.Message)"
                    $errorCount++
                }
            }
        }
        
        Write-Report "✅ 移动完成。成功: $moveCount 个，失败: $errorCount 个。" Green
    }
    else {
        Write-Report "已取消移动操作。" Yellow
    }
}

# ================= 6. 导出结果到文件 =================

# 定义导出文件名
$finalExportPath = Join-Path -Path $ResolvedPath -ChildPath "_duplicate_$timestamp.txt"

try {
    $script:OutputBuffer | Out-File -FilePath $finalExportPath -Encoding UTF8 -ErrorAction Stop
    Write-Report "`n📄 报告已导出至: $finalExportPath" Green
}
catch {
    Write-Warning "警告：无法写入报告文件 '$finalExportPath'。原因: $($_.Exception.Message)"
}

<#
    ============================================================
    参数解释与使用示例 (CLI Reference)
    ============================================================

    【参数解释】
    1. -DirectoryPath (必填): 要扫描的根目录路径。
    2. -MatchMode (可选): 查重模式。
       - 'Name' (默认为 Hash): 仅按文件基础名(不含扩展名)分组，速度快。
       - 'Hash': 计算文件哈希值分组，准确性高，但慢。
    3. -Algorithm (可选): Hash模式下的算法。
       - 'MD5' (默认为 SHA256): 速度最快。
       - 'SHA256': 安全性最高，默认选项。
       - 'SHA1': 中等。
    4. -Recurse (可选): 开关参数。如果存在，则递归扫描所有子目录。
    5. -IncludeExtensions (可选): 字符串数组。仅扫描指定扩展名的文件 (如 "*.jpg")。
    6. -ExcludeExtensions (可选): 字符串数组。排除指定扩展名的文件。
    7. -MoveDuplicates (可选): 开关参数。如果存在，则将重复文件移动到归档文件夹，并在移动前提示确认。

    【使用示例】

    1. 默认扫描 (Hash模式，不递归)
       .\Find-Duplicates-Ultimate.ps1 -DirectoryPath "D:\Data"

    2. 递归扫描整个盘符
       .\Find-Duplicates-Ultimate.ps1 -DirectoryPath "D:\" -Recurse

    3. 按文件名快速查重，并递归
       .\Find-Duplicates-Ultimate.ps1 -DirectoryPath "D:\Photos" -MatchMode Name -Recurse

    4. 仅扫描图片文件，使用 MD5 加速
       .\Find-Duplicates-Ultimate.ps1 -DirectoryPath "D:\Pictures" -IncludeExtensions "*.jpg","*.png","*.bmp" -Algorithm MD5

    5. 排除日志和临时文件
       .\Find-Duplicates-Ultimate.ps1 -DirectoryPath "D:\Logs" -ExcludeExtensions "*.log","*.tmp" -Recurse

    6. 扫描完成后移动重复文件到归档区
       .\Find-Duplicates-Ultimate.ps1 -DirectoryPath "D:\Downloads" -MoveDuplicates

    7. 全盘深度扫描 + MD5 + 归档
       .\Find-Duplicates-Ultimate.ps1 -DirectoryPath "E:\Backup" -Recurse -Algorithm MD5 -MoveDuplicates
#>
