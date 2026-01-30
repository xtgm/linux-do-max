@echo off
chcp 65001 >nul
echo ========================================
echo LinuxDO 签到 - Windows 定时任务设置
echo ========================================
echo.

:: 获取脚本所在目录
set SCRIPT_DIR=%~dp0
set PROJECT_DIR=%SCRIPT_DIR%..

:: 检查 Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到 Python，请先安装 Python
    pause
    exit /b 1
)

echo [信息] 项目目录: %PROJECT_DIR%
echo.

:menu
:: 选择操作
echo 请选择操作：
echo   1. 创建定时任务（自定义时间和次数）
echo   2. 删除定时任务
echo   3. 查看定时任务
echo   4. 立即运行签到
echo   5. 首次登录（保存登录状态）
echo   6. 测试 Telegram 提醒
echo   7. 退出
echo.
set /p choice=请输入选项 (1-7):

if "%choice%"=="1" goto create_task
if "%choice%"=="2" goto delete_task
if "%choice%"=="3" goto show_task
if "%choice%"=="4" goto run_now
if "%choice%"=="5" goto first_login
if "%choice%"=="6" goto test_reminder
if "%choice%"=="7" goto end

echo [错误] 无效选项
echo.
goto menu

:create_task
echo.
echo ========================================
echo 定时任务配置
echo ========================================
echo.
echo 请输入每天执行的次数（1-4次）：
set /p task_count=次数:

:: 验证次数
if "%task_count%"=="" set task_count=2
if %task_count% LSS 1 set task_count=1
if %task_count% GTR 4 set task_count=4

echo.
echo 请输入每次执行的时间（24小时制，如 08:00）：
echo.

:: 删除旧任务
schtasks /delete /tn "LinuxDO-Reminder-1" /f 2>nul
schtasks /delete /tn "LinuxDO-Checkin-1" /f 2>nul
schtasks /delete /tn "LinuxDO-Reminder-2" /f 2>nul
schtasks /delete /tn "LinuxDO-Checkin-2" /f 2>nul
schtasks /delete /tn "LinuxDO-Reminder-3" /f 2>nul
schtasks /delete /tn "LinuxDO-Checkin-3" /f 2>nul
schtasks /delete /tn "LinuxDO-Reminder-4" /f 2>nul
schtasks /delete /tn "LinuxDO-Checkin-4" /f 2>nul
schtasks /delete /tn "LinuxDO-Reminder-AM" /f 2>nul
schtasks /delete /tn "LinuxDO-Checkin-AM" /f 2>nul
schtasks /delete /tn "LinuxDO-Reminder-PM" /f 2>nul
schtasks /delete /tn "LinuxDO-Checkin-PM" /f 2>nul

set created=0

:input_time_1
if %task_count% GEQ 1 (
    set /p time1=第 1 次执行时间（如 08:00）:
    if "%time1%"=="" set time1=08:00
    call :create_single_task 1 %time1%
    set /a created+=1
)

:input_time_2
if %task_count% GEQ 2 (
    set /p time2=第 2 次执行时间（如 20:00）:
    if "%time2%"=="" set time2=20:00
    call :create_single_task 2 %time2%
    set /a created+=1
)

:input_time_3
if %task_count% GEQ 3 (
    set /p time3=第 3 次执行时间（如 12:00）:
    if "%time3%"=="" set time3=12:00
    call :create_single_task 3 %time3%
    set /a created+=1
)

:input_time_4
if %task_count% GEQ 4 (
    set /p time4=第 4 次执行时间（如 18:00）:
    if "%time4%"=="" set time4=18:00
    call :create_single_task 4 %time4%
    set /a created+=1
)

echo.
echo ========================================
echo [成功] 已创建 %created% 组定时任务
echo [提示] 可在"任务计划程序"中查看和管理任务
echo ========================================
echo.
pause
goto menu

:create_single_task
:: 参数: %1=序号, %2=时间(HH:MM)
set task_num=%1
set task_time=%2

:: 计算签到时间（提醒后1分钟）
for /f "tokens=1,2 delims=:" %%a in ("%task_time%") do (
    set /a hour=%%a
    set /a minute=%%b + 1
)
if %minute% GEQ 60 (
    set /a minute=minute-60
    set /a hour=hour+1
)
if %hour% GEQ 24 set /a hour=hour-24
if %hour% LSS 10 set hour=0%hour%
if %minute% LSS 10 set minute=0%minute%
set checkin_time=%hour%:%minute%

:: 创建提醒任务
schtasks /create /tn "LinuxDO-Reminder-%task_num%" /tr "python \"%PROJECT_DIR%\reminder.py\"" /sc daily /st %task_time% /f >nul 2>&1
if errorlevel 1 (
    echo [错误] 创建提醒任务 %task_num% 失败
) else (
    echo [成功] %task_time% - Telegram 提醒
)

:: 创建签到任务
schtasks /create /tn "LinuxDO-Checkin-%task_num%" /tr "python \"%PROJECT_DIR%\main.py\"" /sc daily /st %checkin_time% /f >nul 2>&1
if errorlevel 1 (
    echo [错误] 创建签到任务 %task_num% 失败
) else (
    echo [成功] %checkin_time% - 自动签到
)
goto :eof

:delete_task
echo.
echo [信息] 删除定时任务...

schtasks /delete /tn "LinuxDO-Reminder-1" /f 2>nul
schtasks /delete /tn "LinuxDO-Checkin-1" /f 2>nul
schtasks /delete /tn "LinuxDO-Reminder-2" /f 2>nul
schtasks /delete /tn "LinuxDO-Checkin-2" /f 2>nul
schtasks /delete /tn "LinuxDO-Reminder-3" /f 2>nul
schtasks /delete /tn "LinuxDO-Checkin-3" /f 2>nul
schtasks /delete /tn "LinuxDO-Reminder-4" /f 2>nul
schtasks /delete /tn "LinuxDO-Checkin-4" /f 2>nul
schtasks /delete /tn "LinuxDO-Reminder-AM" /f 2>nul
schtasks /delete /tn "LinuxDO-Checkin-AM" /f 2>nul
schtasks /delete /tn "LinuxDO-Reminder-PM" /f 2>nul
schtasks /delete /tn "LinuxDO-Checkin-PM" /f 2>nul

echo [成功] 定时任务已删除
echo.
pause
goto menu

:show_task
echo.
echo [信息] 当前 LinuxDO 定时任务：
echo ----------------------------------------
schtasks /query /fo table | findstr /i "LinuxDO"
if errorlevel 1 echo 无 LinuxDO 相关任务
echo ----------------------------------------
echo.
pause
goto menu

:run_now
echo.
echo [信息] 立即运行签到...
echo.
cd /d "%PROJECT_DIR%"
python main.py
echo.
pause
goto menu

:first_login
echo.
echo [信息] 首次登录模式...
echo.
cd /d "%PROJECT_DIR%"
python main.py --first-login
echo.
pause
goto menu

:test_reminder
echo.
echo [信息] 测试 Telegram 提醒...
echo.
cd /d "%PROJECT_DIR%"
python reminder.py
echo.
pause
goto menu

:end
