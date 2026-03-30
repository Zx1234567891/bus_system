@echo off
chcp 65001 >nul
color 0B
title 公交安全管理系统 - 系统状态

:loop
cls
echo.
echo ╔════════════════════════════════════════════╗
echo ║      公交安全管理系统 - 状态监控          ║
echo ╚════════════════════════════════════════════╝
echo.
echo 刷新时间: %date% %time%
echo.

:: 检查Python环境
echo [Python环境]
python --version 2>nul
if %errorlevel% neq 0 (
    echo × Python未安装或未配置
) else (
    echo ✓ Python已安装
)
echo.

:: 检查MySQL服务
echo [MySQL服务]
sc query MySQL80 | find "RUNNING" >nul
if %errorlevel% equ 0 (
    echo ✓ MySQL服务运行中
) else (
    echo × MySQL服务未运行
)
echo.

:: 检查数据库
echo [数据库连接]
"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -proot -e "USE bus_safety_system; SELECT COUNT(*) FROM employee;" 2>nul | findstr /r "[0-9]" >nul
if %errorlevel% equ 0 (
    echo ✓ 数据库连接正常
    for /f "skip=1 tokens=*" %%i in ('"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -proot -N -s -e "USE bus_safety_system; SELECT COUNT(*) FROM employee;" 2^>nul') do (
        echo   └─ 员工记录数: %%i
    )
    for /f "skip=1 tokens=*" %%i in ('"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -proot -N -s -e "USE bus_safety_system; SELECT COUNT(*) FROM driver;" 2^>nul') do (
        echo   └─ 司机记录数: %%i
    )
    for /f "skip=1 tokens=*" %%i in ('"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -proot -N -s -e "USE bus_safety_system; SELECT COUNT(*) FROM violation;" 2^>nul') do (
        echo   └─ 违章记录数: %%i
    )
) else (
    echo × 数据库连接失败
)
echo.

:: 检查Flask进程
echo [Flask服务]
tasklist | find /i "python.exe" >nul
if %errorlevel% equ 0 (
    echo ✓ Flask服务运行中
    echo   进程列表:
    for /f "tokens=1,2" %%a in ('tasklist ^| find /i "python.exe"') do (
        echo   └─ %%a (PID: %%b^)
    )
) else (
    echo × Flask服务未运行
)
echo.

:: 检查端口占用
echo [端口状态]
netstat -ano | findstr ":5000" >nul
if %errorlevel% equ 0 (
    echo ✓ 端口5000已占用
    for /f "tokens=2,5" %%a in ('netstat -ano ^| findstr ":5000" ^| findstr "LISTENING"') do (
        echo   └─ 本地地址: %%a (PID: %%b^)
    )
) else (
    echo ℹ 端口5000未占用
)
echo.

:: 检查网络连接
echo [网络连接]
ping -n 1 127.0.0.1 >nul
if %errorlevel% equ 0 (
    echo ✓ 本地回环正常
) else (
    echo × 本地回环异常
)
echo.

echo ════════════════════════════════════════════
echo.
echo 按任意键刷新状态，或按 Ctrl+C 退出...
timeout /t 5 >nul
goto loop
