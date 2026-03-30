@echo off
chcp 65001 >nul
color 0A
title 公交安全管理系统 - 启动中...

echo.
echo ╔════════════════════════════════════════════╗
echo ║      公交安全管理系统 - 启动脚本          ║
echo ╚════════════════════════════════════════════╝
echo.

:: 检查Python是否安装
echo [1/5] 检查Python环境...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo × Python未安装或未配置到PATH
    echo   请先安装Python 3.7+
    pause
    exit /b 1
) else (
    for /f "tokens=2" %%i in ('python --version 2^>^&1') do echo ✓ Python版本: %%i
)

echo.
echo [2/5] 检查MySQL服务状态...
sc query MySQL80 | find "RUNNING" >nul
if %errorlevel% equ 0 (
    echo ✓ MySQL服务已运行
) else (
    echo × MySQL服务未运行，正在启动...
    net start MySQL80
    if %errorlevel% equ 0 (
        echo ✓ MySQL服务启动成功
    ) else (
        echo × MySQL服务启动失败，请手动启动或检查管理员权限
        pause
        exit /b 1
    )
)

echo.
echo [3/5] 检查数据库是否存在...
"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -proot -e "USE bus_safety_system;" 2>nul
if %errorlevel% neq 0 (
    echo × 数据库不存在，正在导入...
    echo   导入主数据库（包含基础数据）...
    "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -proot --default-character-set=utf8mb4 -e "source bus_safety_system.sql" 2>nul
    if %errorlevel% equ 0 (
        echo ✓ 主数据库导入成功
    ) else (
        echo ⚠ 主数据库可能已存在或导入失败
    )
) else (
    echo ✓ 主数据库已存在
)

echo.
echo [4/5] 检查用户凭证表...
"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -proot -N -s -e "USE bus_safety_system; SHOW TABLES LIKE 'user_credentials';" 2>nul | findstr "user_credentials" >nul
if %errorlevel% neq 0 (
    echo × 用户凭证表不存在，正在导入...
    "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -proot --default-character-set=utf8mb4 < user_credentials.sql >nul 2>&1
    "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -proot -N -s -e "USE bus_safety_system; SHOW TABLES LIKE 'user_credentials';" 2>nul | findstr "user_credentials" >nul
    if %errorlevel% equ 0 (
        echo ✓ 用户凭证表创建成功
        echo ✓ 默认admin账号已创建（密码：admin123）
        echo ✓ 所有现有员工账号已创建（默认密码：123456）
    ) else (
        echo × 用户凭证表导入失败，请手动运行：
        echo   mysql -u root -proot ^< user_credentials.sql
        pause
    )
) else (
    echo ✓ 用户凭证表已存在
)

echo.
echo [5/7] 创建上传目录...
if not exist "static\uploads\videos" (
    mkdir "static\uploads\videos"
    echo ✓ 视频上传目录已创建
) else (
    echo ✓ 视频上传目录已存在
)

echo.
echo [6/7] 检查数据库更新（视频功能）...
"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -proot -N -s -e "USE bus_safety_system; SHOW COLUMNS FROM violation_record LIKE 'video_url';" 2>nul | findstr "video_url" >nul
if %errorlevel% neq 0 (
    echo ⚠ 视频字段不存在，正在更新数据库...
    "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -proot --default-character-set=utf8mb4 < add_video_field.sql >nul 2>&1
    if %errorlevel% equ 0 (
        echo ✓ 视频字段添加成功（violation_record.video_url）
    ) else (
        echo × 数据库更新失败，视频上传功能可能无法使用
        echo   请手动运行: mysql -u root -proot ^< add_video_field.sql
    )
) else (
    echo ✓ 视频字段已存在
)

echo.
echo [7/7] 启动Flask应用...
echo.
echo ╔════════════════════════════════════════════╗
echo ║           系统已成功启动！                 ║
echo ╚════════════════════════════════════════════╝
echo.
echo 📍 访问地址：
echo   └─ 本地:   http://127.0.0.1:5000
echo   └─ 局域网: http://10.198.21.124:5000
echo.
echo 👤 默认管理员账号：
echo   └─ 用户名: admin
echo   └─ 密码:   admin123
echo.
echo 💡 提示：
echo   └─ 按 Ctrl+C 停止服务器
echo   └─ 运行 stop.bat 停止所有相关进程
echo.
echo ════════════════════════════════════════════
echo.

title 公交安全管理系统 - 运行中
python app.py

echo.
echo ════════════════════════════════════════════
echo 服务器已停止
pause
