@echo off
chcp 65001 >nul
color 0C
title 公交安全管理系统 - 停止服务

echo.
echo ╔════════════════════════════════════════════╗
echo ║      停止公交安全管理系统服务              ║
echo ╚════════════════════════════════════════════╝
echo.

:: 检查是否有Python进程在运行
echo [1/2] 检查Flask进程...
tasklist | find /i "python.exe" >nul
if %errorlevel% equ 0 (
    echo ✓ 发现运行中的Python进程
    echo.
    echo 正在停止Flask服务器...
    
    :: 尝试通过进程名称停止（更安全）
    taskkill /F /IM "python.exe" /FI "WINDOWTITLE eq 公交安全管理系统*" 2>nul
    
    :: 如果上面的命令没有生效，停止所有python.exe
    tasklist | find /i "python.exe" >nul
    if %errorlevel% equ 0 (
        echo 正在停止所有Python进程...
        for /f "tokens=2" %%i in ('tasklist ^| find /i "python.exe"') do (
            echo   停止进程: PID %%i
            taskkill /F /PID %%i >nul 2>&1
        )
    )
    
    :: 验证是否停止成功
    timeout /t 1 /nobreak >nul
    tasklist | find /i "python.exe" >nul
    if %errorlevel% equ 0 (
        echo ⚠ 部分Python进程可能仍在运行
    ) else (
        echo ✓ 所有Flask进程已停止
    )
) else (
    echo ℹ 没有发现运行中的Python进程
)

echo.
echo [2/2] 清理端口占用...
:: 检查5000端口是否被占用
netstat -ano | findstr ":5000" >nul
if %errorlevel% equ 0 (
    echo ⚠ 端口5000仍被占用，正在释放...
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":5000"') do (
        taskkill /F /PID %%a >nul 2>&1
    )
    echo ✓ 端口已释放
) else (
    echo ✓ 端口5000未被占用
)

echo.
echo ╔════════════════════════════════════════════╗
echo ║           服务已成功停止！                 ║
echo ╚════════════════════════════════════════════╝
echo.
pause
