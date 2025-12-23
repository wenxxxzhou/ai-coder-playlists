@echo off
setlocal enabledelayedexpansion

:: 切换到 UTF-8 代码页以正确处理特殊字符
for /f "tokens=2 delims=:." %%a in ('chcp') do set "original_codepage=%%a"
chcp 65001 >nul

:: 检查参数
if "%~1"=="" (
    echo 用法: %~nx0 输入文件.edl [输出文件.srt]
    echo 如果不指定输出文件，将自动生成同名 .srt 文件
    chcp %original_codepage% >nul
    exit /b 1
)

set "input_file=%~1"
set "output_file=%~2"

:: 如果未指定输出文件，使用同名 .srt
if "%output_file%"=="" (
    set "output_file=%~dpn1.srt"
)

:: 检查输入文件是否存在
if not exist "%input_file%" (
    echo 错误: 输入文件 "%input_file%" 不存在
    chcp %original_codepage% >nul
    exit /b 1
)

:: 删除已存在的输出文件
if exist "%output_file%" del "%output_file%"

:: 设置帧率（默认为 25fps）
set "fps=25"

echo 正在转换 "%input_file%" 到 "%output_file%"...

set "line_count=0"
set "subtitle_index=0"

:: 读取输入文件
for /f "delims=" %%a in ('type "%input_file%"') do (
    set "line=%%a"
    set /a line_count+=1
    
    :: 检查是否为时间戳行
    echo !line! | findstr /r /c:"^[0-9][0-9]*[ ][ ]*[a-zA-Z][a-zA-Z]*" >nul
    if !errorlevel! equ 0 (
        for /f "tokens=1,7,8 delims= " %%i in ("!line!") do (
            set "start_time_orig=%%j"
            set "end_time_orig=%%k"
            
            call :convert_time_edl_to_srt "!start_time_orig!" start_time_srt
            call :convert_time_edl_to_srt "!end_time_orig!" end_time_srt
        )
    )
    
    :: 检查是否为 * FROM CLIP NAME: 行
    echo !line! | findstr /i /c:"* FROM CLIP NAME:" >nul
    if !errorlevel! equ 0 (
        :: 提取并清理文本
        set "text=!line:* FROM CLIP NAME:=!"
        call :clean_and_prepare_text text
        
        if defined start_time_srt (
            set /a subtitle_index+=1
            
            :: 直接构建 SRT 条目到文件，不经过 echo
            call :write_srt_entry !subtitle_index! "!start_time_srt!" "!end_time_srt!" "!text!"
            
            set "start_time_srt="
            set "end_time_srt="
        )
    )
)

:: 恢复原始代码页
chcp %original_codepage% >nul

if %subtitle_index% equ 0 (
    echo 警告: 未找到有效的字幕数据
) else (
    echo 转换完成！共生成 %subtitle_index% 个字幕
)

exit /b 0

:: 转换时间格式
:convert_time_edl_to_srt
set "input_time=%~1"
set "output_var=%~2"

for /f "tokens=1-4 delims=:" %%a in ("!input_time!") do (
    set "hh=%%a"
    set "mm=%%b"
    set "ss=%%c"
    set "ff=%%d"
)

set /a "ms=ff * 1000 / fps"
if !ms! lss 100 (if !ms! lss 10 (set "ms=00!ms!") else (set "ms=0!ms!"))

set "%output_var%=%hh%:%mm%:%ss%,%ms%"
exit /b 0

:: 清理和准备文本
:clean_and_prepare_text
set "var_name=%~1"
set "text=!%var_name%!"

:: 移除开头/结尾的空格和制表符
:trim_spaces
if "!text:~0,1!"==" " set "text=!text:~1!" & goto trim_spaces
if "!text:~0,1!"=="	" set "text=!text:~1!" & goto trim_spaces
if "!text:~-1!"==" " set "text=!text:~0,-1!" & goto trim_spaces
if "!text:~-1!"=="	" set "text=!text:~0,-1!" & goto trim_spaces

:: 移除文件扩展名（从最后一个点开始）
:remove_ext
set "ext_found=0"
for %%c in (!text!) do (
    echo %%c | findstr /r "\." >nul
    if !errorlevel! equ 0 (
        :: 包含点的部分，可能是文件名
        for /f "delims=." %%d in ("%%c") do set "base_name=%%d"
        set "ext_found=1"
    )
)

if !ext_found! equ 1 (
    :: 重建不带扩展名的文本
    set "new_text="
    for %%c in (!text!) do (
        if not "%%c"=="" (
            if "!new_text!"=="" (
                set "new_text=%%c"
            ) else (
                :: 检查是否包含点
                echo %%c | findstr /r "\." >nul
                if !errorlevel! equ 0 (
                    :: 包含点，只取点前的部分
                    for /f "delims=." %%d in ("%%c") do set "new_text=!new_text! %%d"
                ) else (
                    :: 不包含点，直接添加
                    set "new_text=!new_text! %%c"
                )
            )
        )
    )
    set "text=!new_text!"
)

:: 移除扩展名后的额外空格
:trim_final
if "!text:~-1!"==" " set "text=!text:~0,-1!" & goto trim_final

set "%var_name%=%text%"
exit /b 0

:: 写入 SRT 条目（使用最安全的重定向方法）
:write_srt_entry
setlocal
set "idx=%~1"
set "stime=%~2"
set "etime=%~3"
set "txt=%~4"

:: 使用 set 和 echo 组合写入文件，避免特殊字符干扰
>> "!output_file!" echo(!idx!
>> "!output_file!" echo(!stime! --^> !etime!
>> "!output_file!" echo(!txt!
>> "!output_file!" echo(

endlocal
exit /b 0