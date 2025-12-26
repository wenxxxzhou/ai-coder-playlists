param(
    [Parameter(Mandatory = $true)]
    [string]$DirectoryPath
)

# 验证目录是否存在
if (-not (Test-Path $DirectoryPath)) {
    Write-Host "错误：目录 '$DirectoryPath' 不存在" -ForegroundColor Red
    exit 1
}

# 获取目录下的所有文件（不递归子目录）
$files = Get-ChildItem -Path $DirectoryPath -File

# 按基础文件名分组（不区分大小写）
$groupedFiles = $files | Group-Object -Property { $_.BaseName.ToLower() } -CaseSensitive:$false

# 筛选出重复的文件组
$duplicateGroups = $groupedFiles | Where-Object { $_.Count -gt 1 } | Sort-Object -Property Name

# 内部函数：格式化文件大小
function Format-FileSize {
    param([int64]$FileSize)
    
    if ($FileSize -lt 1KB) {
        return "$FileSize B"
    }
    elseif ($FileSize -lt 1MB) {
        return "{0:N2} KB" -f ($FileSize / 1KB)
    }
    elseif ($FileSize -lt 1GB) {
        return "{0:N2} MB" -f ($FileSize / 1MB)
    }
    else {
        return "{0:N2} GB" -f ($FileSize / 1GB)
    }
}

# 检查是否存在重复文件
if ($duplicateGroups.Count -eq 0) {
    Write-Host "无重复文件" -ForegroundColor Green
}
else {
    Write-Host "`n========== 重复文件监测结果 ==========" -ForegroundColor Cyan
    Write-Host "目录: $DirectoryPath" -ForegroundColor White
    Write-Host "扫描文件数: $($files.Count)" -ForegroundColor White
    Write-Host "重复文件组数: $($duplicateGroups.Count)" -ForegroundColor Yellow
    Write-Host $("=" * 40) -ForegroundColor Cyan
    
    # 输出重复文件信息
    $groupIndex = 1
    foreach ($group in $duplicateGroups) {
        # 显示基础文件名（使用原始大小写）
        $originalName = ($group.Group | Select-Object -First 1).BaseName
        Write-Host "`n[$groupIndex] $originalName" -ForegroundColor Yellow
        Write-Host $("-" * 40) -ForegroundColor Gray
        
        $fileIndex = 1
        foreach ($file in $group.Group) {
            # 格式化文件大小
            $size = Format-FileSize -FileSize $file.Length
            
            # 格式化修改日期
            $modified = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            
            # 输出文件详细信息
            Write-Host "   [$fileIndex] $($file.FullName)" -ForegroundColor White
            Write-Host "       大小: $size" -ForegroundColor Gray
            Write-Host "       修改: $modified" -ForegroundColor Gray
            
            $fileIndex++
        }
        
        $groupIndex++
    }
    
    Write-Host "`n$("=" * 40)" -ForegroundColor Cyan
    Write-Host "✅ 检测完成，共发现 $($duplicateGroups.Count) 组重复文件" -ForegroundColor Magenta
}