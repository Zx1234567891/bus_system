@echo off
chcp 65001 >nul
color 0E
title 公交安全管理系统 - 重启服务

echo.
echo ╔════════════════════════════════════════════╗
echo ║      重启公交安全管理系统服务              ║
echo ╚════════════════════════════════════════════╝
echo.

echo [1/2] 停止现有服务...
echo.

:: 停止Python进程
tasklist | find /i "python.exe" >nul
if %errorlevel% equ 0 (
    echo 正在停止Flask服务器...
    taskkill /F /IM "python.exe" >nul 2>&1
    timeout /t 2 /nobreak >nul
    echo ✓ 服务已停止
) else (
    echo ℹ 没有运行中的服务
)

:: 清理端口占用
netstat -ano | findstr ":5000" >nul
if %errorlevel% equ 0 (
    echo 正在清理端口占用...
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":5000"') do (
        taskkill /F /PID %%a >nul 2>&1
    )
    timeout /t 1 /nobreak >nul
)

echo.
echo [2/2] 启动服务（包含视频功能检查）...
call start.bat
echo ════════════════════════════════════════════
echo.
