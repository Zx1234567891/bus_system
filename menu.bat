@echo off
chcp 65001 >nul
color 0F

:menu
cls
title 公交安全管理系统 - 管理菜单
echo.
echo ╔════════════════════════════════════════════╗
echo ║      公交安全管理系统 - 管理菜单          ║
echo ╚════════════════════════════════════════════╝
echo.
echo  请选择操作：
echo.
echo  [1] 启动系统          - 启动Flask服务器
echo  [2] 停止系统          - 停止所有相关进程
echo  [3] 重启系统          - 重启Flask服务器
echo  [4] 查看状态          - 实时监控系统状态
echo  [5] 数据库管理        - 数据库相关操作
echo  [6] 打开浏览器        - 访问系统页面
echo  [0] 退出              - 退出管理菜单
echo.
echo ════════════════════════════════════════════
echo.

set /p choice=请输入选项编号 (0-6): 

if "%choice%"=="1" goto start
if "%choice%"=="2" goto stop
if "%choice%"=="3" goto restart
if "%choice%"=="4" goto status
if "%choice%"=="5" goto database
if "%choice%"=="6" goto browser
if "%choice%"=="0" goto exit

echo.
echo × 无效的选项，请重新选择
timeout /t 2 >nul
goto menu

:start
cls
echo.
echo ════════════════════════════════════════════
echo   正在启动系统...
echo ════════════════════════════════════════════
echo.
call start.bat
goto menu

:stop
cls
echo.
echo ════════════════════════════════════════════
echo   正在停止系统...
echo ════════════════════════════════════════════
echo.
call stop.bat
goto menu

:restart
cls
echo.
echo ════════════════════════════════════════════
echo   正在重启系统...
echo ════════════════════════════════════════════
echo.
call restart.bat
goto menu

:status
cls
call status.bat
goto menu

:database
cls
echo.
echo ╔════════════════════════════════════════════╗
echo ║           数据库管理菜单                   ║
echo ╚════════════════════════════════════════════╝
echo.
echo  [1] 重新导入主数据库
echo  [2] 重新导入用户凭证
echo  [3] 备份数据库
echo  [4] 清理重复数据
echo  [5] 查看数据库统计
echo  [0] 返回主菜单
echo.
set /p dbchoice=请选择操作: 

if "%dbchoice%"=="1" goto import_main
if "%dbchoice%"=="2" goto import_user
if "%dbchoice%"=="3" goto backup
if "%dbchoice%"=="4" goto cleanup
if "%dbchoice%"=="5" goto stats
if "%dbchoice%"=="0" goto menu

echo × 无效的选项
timeout /t 2 >nul
goto database

:import_main
echo.
echo 正在导入主数据库...
"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -proot --default-character-set=utf8mb4 -e "source bus_safety_system.sql"
echo ✓ 导入完成
pause
goto database

:import_user
echo.
echo 正在导入用户凭证...
"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -proot --default-character-set=utf8mb4 < user_credentials.sql
echo ✓ 导入完成
pause
goto database

:backup
echo.
set backup_file=backup_%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%.sql
set backup_file=%backup_file: =0%
echo 正在备份数据库到: %backup_file%
"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqldump.exe" -u root -proot --default-character-set=utf8mb4 bus_safety_system > %backup_file%
if %errorlevel% equ 0 (
    echo ✓ 备份成功: %backup_file%
) else (
    echo × 备份失败
)
pause
goto database

:cleanup
echo.
echo 正在执行清理重复数据脚本...
"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -proot --default-character-set=utf8mb4 < fix_duplicate_data.sql
echo ✓ 清理完成
pause
goto database

:stats
cls
echo.
echo ════════════════════════════════════════════
echo   数据库统计信息
echo ════════════════════════════════════════════
echo.
"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -proot -e "USE bus_safety_system; SELECT '车队数量:' as stat, COUNT(*) as value FROM fleet UNION ALL SELECT '线路数量:', COUNT(*) FROM route UNION ALL SELECT '员工数量:', COUNT(*) FROM employee UNION ALL SELECT '司机数量:', COUNT(*) FROM driver UNION ALL SELECT '车辆数量:', COUNT(*) FROM bus UNION ALL SELECT '违章记录:', COUNT(*) FROM violation UNION ALL SELECT '用户账号:', COUNT(*) FROM user_credentials;"
echo.
pause
goto database

:browser
echo.
echo 正在打开浏览器...
start http://127.0.0.1:5000
timeout /t 2 >nul
goto menu

:exit
cls
echo.
echo ════════════════════════════════════════════
echo   感谢使用公交安全管理系统！
echo ════════════════════════════════════════════
echo.
timeout /t 2 >nul
exit
