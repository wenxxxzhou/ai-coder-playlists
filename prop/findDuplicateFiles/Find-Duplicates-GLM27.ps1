param(
    [Parameter(Mandatory = $true)]
    [string]$DirectoryPath
)

# --- 辅助函数：将字节数转换为易读的字符串 ---
function Convert-FileSize {
    param ([long]$Bytes)
    
    if ($Bytes -ge 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    }
    elseif ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    }
    elseif ($Bytes -ge 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    }
    else {
        return "$Bytes Bytes"
    }
}

# 1. 验证路径是否存在
if (-not (Test-Path -Path $DirectoryPath)) {
    Write-Error "错误：指定的路径不存在 -> $DirectoryPath"
    return
}

# 2. 获取目标目录下的所有文件（不递归）
try {
    $files = Get-ChildItem -Path $DirectoryPath -File -ErrorAction Stop
}
catch {
    Write-Error "读取目录时出错: $_"
    return
}

# 3. 分组逻辑：忽略后缀，忽略大小写
$duplicateGroups = $files | Group-Object { $_.BaseName.ToLower() } | Where-Object { $_.Count -gt 1 }

# 4. 输出结果
if ($null -eq $duplicateGroups -or $duplicateGroups.Count -eq 0) {
    Write-Host "无重复文件" -ForegroundColor Green
}
else {
    # 按文件名索引（字母顺序）排序
    $sortedGroups = $duplicateGroups | Sort-Object Name

    foreach ($group in $sortedGroups) {
        Write-Host "============================================"  -ForegroundColor Cyan
        Write-Host "发现重复文件名: $($group.Name)" -ForegroundColor Yellow
        Write-Host "重复数量: $($group.Count)" -ForegroundColor Yellow
        Write-Host "============================================"  -ForegroundColor Cyan

        # 遍历组内每一个文件，显示详细信息
        foreach ($file in $group.Group) {
            # 调用辅助函数获取格式化后的大小
            $formattedSize = Convert-FileSize -Bytes $file.Length
            
            Write-Host "`n[文件详情]"
            Write-Host "完整路径: $($file.FullName)"
            Write-Host "文件大小: $formattedSize"
            Write-Host "修改日期: $($file.LastWriteTime)"
        }
        # 每组结束后空一行
        Write-Host ""
    }
}
