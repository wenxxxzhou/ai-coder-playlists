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

# 检查是否存在重复文件
if ($duplicateGroups.Count -eq 0) {
    Write-Host "无重复文件" -ForegroundColor Green
}
else {
    # 输出重复文件信息
    foreach ($group in $duplicateGroups) {
        # 显示基础文件名（使用原始大小写，但分组时不区分）
        $originalName = ($group.Group | Select-Object -First 1).BaseName
        Write-Host "`n重复基础文件名: $($originalName)" -ForegroundColor Yellow
        Write-Host $("=" * 60)
        
        foreach ($file in $group.Group) {
            # 格式化文件大小
            if ($file.Length -lt 1KB) {
                $size = "$($file.Length) B"
            }
            elseif ($file.Length -lt 1MB) {
                $size = "{0:N2} KB" -f ($file.Length / 1KB)
            }
            elseif ($file.Length -lt 1GB) {
                $size = "{0:N2} MB" -f ($file.Length / 1MB)
            }
            else {
                $size = "{0:N2} GB" -f ($file.Length / 1GB)
            }
            
            # 格式化修改日期
            $modified = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            
            # 输出文件详细信息
            Write-Host "📄 完整路径: $($file.FullName)" -ForegroundColor Cyan
            Write-Host "   文件大小: $size" -ForegroundColor White
            Write-Host "   修改日期: $modified" -ForegroundColor White
            Write-Host "-" * 60
        }
    }
    
    Write-Host "`n✅ 总计发现 $($duplicateGroups.Count) 组重复文件" -ForegroundColor Magenta
}