@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

set "VERSION=1.3.0"
cd /d "%~dp0.."

echo.
echo ============================================================
echo      LinuxDO 签到一键安装脚本 v%VERSION% [Windows]
echo ============================================================
echo.

echo [信息] 检测系统环境...
echo.
echo +--------------------------------------------+
echo ^|            系统环境检测结果                ^|
echo +--------------------------------------------+
echo ^| 操作系统     ^| Windows                     ^|

if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    echo ^| 架构         ^| x86_64 ^(x64^)                ^|
) else (
    echo ^| 架构         ^| x86 ^(32-bit^)               ^|
)

set "PYTHON_OK=0"
where python >nul 2>&1 && set "PYTHON_OK=1"
if %PYTHON_OK%==1 (
    for /f "tokens=2 delims= " %%v in ('python --version 2^>^&1') do set "PY_VER=%%v"
    echo ^| Python       ^| !PY_VER!                     ^|
) else (
    echo ^| Python       ^| 未安装                       ^|
)

set "CHROME_PATH="
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set "CHROME_PATH=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" set "CHROME_PATH=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" set "CHROME_PATH=%LocalAppData%\Google\Chrome\Application\chrome.exe"

if defined CHROME_PATH (
    echo ^| 浏览器       ^| 已安装                      ^|
) else (
    echo ^| 浏览器       ^| 未安装                       ^|
)
echo +--------------------------------------------+
echo.

if %PYTHON_OK%==0 (
    echo [错误] 未检测到 Python
    echo.
    echo 请安装 Python:
    echo   1. 访问 https://www.python.org/downloads/
    echo   2. 下载并安装 Python 3.8+
    echo   3. 安装时勾选 "Add Python to PATH"
    echo.
    pause
    exit /b 1
)

if not defined CHROME_PATH (
    echo [警告] 未检测到 Chrome 浏览器
    echo [提示] 请访问 https://www.google.com/chrome/ 下载安装
    echo.
)

if not exist "main.py" (
    if not exist "requirements.txt" (
        echo [错误] 请在项目目录下运行此脚本
        echo [提示] 当前目录: %CD%
        echo.
        pause
        exit /b 1
    )
)

REM ============================================================
REM 启动时检查更新
REM ============================================================
call :check_update
if "%UPDATE_DONE%"=="1" goto :exit_script

:menu
echo.
echo +--------------------------------------------+
echo ^|                主菜单                      ^|
echo +--------------------------------------------+
echo ^|  1. 一键安装（推荐）                       ^|
echo ^|  2. 仅配置 Python 环境                     ^|
echo ^|  3. 编辑配置文件                           ^|
echo ^|  4. 设置定时任务                           ^|
echo ^|  5. 首次登录                               ^|
echo ^|  6. 运行签到                               ^|
echo ^|  7. 检查更新                               ^|
echo ^|  0. 退出                                   ^|
echo +--------------------------------------------+
echo.
set "choice="
set /p choice="请选择 [0-7]: "

if "%choice%"=="0" goto :exit_script
if "%choice%"=="1" goto :full_install
if "%choice%"=="2" goto :setup_python
if "%choice%"=="3" goto :edit_config
if "%choice%"=="4" goto :setup_task
if "%choice%"=="5" goto :first_login
if "%choice%"=="6" goto :run_checkin
if "%choice%"=="7" goto :manual_update
echo [错误] 无效选项
goto :menu

:check_update
set "UPDATE_DONE=0"
REM 检查 updater.py 是否存在
if not exist "updater.py" goto :eof

REM 确定使用哪个 Python：优先 venv，否则系统 Python
set "PYTHON_CMD="
if exist "venv\Scripts\python.exe" (
    set "PYTHON_CMD=venv\Scripts\python.exe"
) else (
    REM 检查系统 Python 是否可用
    where python >nul 2>&1
    if not errorlevel 1 (
        set "PYTHON_CMD=python"
    )
)

if "%PYTHON_CMD%"=="" (
    echo [信息] 未检测到 Python 环境，跳过更新检查
    goto :eof
)

echo [信息] 检查更新中...
echo.

REM 使用 Python 检查更新
%PYTHON_CMD% -c "from updater import check_update; from version import __version__; info = check_update(silent=True); print(f'CURRENT={__version__}'); print(f'LATEST={info[\"latest_version\"]}' if info else 'LATEST=NONE')" > "%TEMP%\update_check.txt" 2>nul

if errorlevel 1 (
    echo [警告] 更新检查失败，可能缺少依赖
    echo [提示] 如果是首次使用，请选择 1. 一键安装
    echo.
    goto :eof
)

set "CURRENT_VER="
set "LATEST_VER="
for /f "tokens=1,2 delims==" %%a in (%TEMP%\update_check.txt) do (
    if "%%a"=="CURRENT" set "CURRENT_VER=%%b"
    if "%%a"=="LATEST" set "LATEST_VER=%%b"
)
del "%TEMP%\update_check.txt" 2>nul

if "%LATEST_VER%"=="NONE" (
    echo [成功] 当前版本 v%CURRENT_VER% 已是最新
    echo.
    goto :eof
)

echo ============================================================
echo   发现新版本: v%LATEST_VER%  (当前: v%CURRENT_VER%)
echo ============================================================
echo.
set "do_update="
set /p do_update="是否现在更新？[Y/n]: "
if /i "%do_update%"=="n" (
    echo [信息] 跳过更新
    echo.
    goto :eof
)

echo.
echo [信息] 正在更新...
%PYTHON_CMD% -c "from updater import prompt_update; prompt_update()"
echo.
echo [提示] 更新完成，请重新运行此脚本
set "UPDATE_DONE=1"
pause
goto :eof

:manual_update
echo.
REM 确定使用哪个 Python
set "PYTHON_CMD="
if exist "venv\Scripts\python.exe" (
    set "PYTHON_CMD=venv\Scripts\python.exe"
) else (
    where python >nul 2>&1
    if not errorlevel 1 (
        set "PYTHON_CMD=python"
    )
)

if "%PYTHON_CMD%"=="" (
    echo [错误] 未检测到 Python 环境
    echo [提示] 请先运行 1. 一键安装
    pause
    goto :menu
)

%PYTHON_CMD% main.py --check-update
pause
goto :menu

:full_install
call :setup_python
if errorlevel 1 goto :menu
call :interactive_config
call :setup_task
call :first_login
call :print_completion
goto :menu

:setup_python
echo.
echo [信息] 配置 Python 环境...
if not exist "venv" (
    echo [信息] 创建虚拟环境...
    python -m venv venv
    if errorlevel 1 (
        echo [错误] 创建虚拟环境失败
        pause
        exit /b 1
    )
)
if not exist "venv\Scripts\python.exe" (
    echo [错误] 虚拟环境创建失败，venv\Scripts\python.exe 不存在
    pause
    exit /b 1
)
echo [信息] 升级 pip...
venv\Scripts\python.exe -m pip install --upgrade pip >nul 2>&1
echo [信息] 安装依赖包...
venv\Scripts\pip.exe install -r requirements.txt
if errorlevel 1 (
    echo [错误] 安装依赖失败
    pause
    exit /b 1
)
echo [成功] Python 环境配置完成
echo.
goto :eof

:interactive_config
echo.
echo [信息] 配置向导...
echo.

if exist "config.yaml" (
    echo [警告] 检测到已有配置文件
    set "reconfig="
    set /p reconfig="是否重新配置？[y/N]: "
    if /i not "!reconfig!"=="y" goto :eof
)

echo.
echo === 基本配置 ===
set "USERNAME="
set /p USERNAME="Linux.do 用户名 (可选，按 Enter 跳过): "
if defined USERNAME (
    set "PASSWORD="
    set /p PASSWORD="Linux.do 密码 (可选): "
)

echo.
set "BROWSE_COUNT="
set /p BROWSE_COUNT="浏览帖子数量 [10]: "
if not defined BROWSE_COUNT set "BROWSE_COUNT=10"

set "LIKE_PROB="
set /p LIKE_PROB="点赞概率 (0-1) [0.3]: "
if not defined LIKE_PROB set "LIKE_PROB=0.3"

set "HEADLESS="
set /p HEADLESS="无头模式 (true/false) [false]: "
if not defined HEADLESS set "HEADLESS=false"

echo.
echo === Telegram 通知 (可选) ===
set "TG_TOKEN="
set /p TG_TOKEN="Bot Token (按 Enter 跳过): "
if defined TG_TOKEN (
    set "TG_CHAT_ID="
    set /p TG_CHAT_ID="Chat ID: "
)

set "USER_DATA_DIR=%USERPROFILE%\.linuxdo-browser"

(
echo # LinuxDO 签到配置文件
echo # 由一键安装脚本自动生成
echo.
echo username: "%USERNAME%"
echo password: "%PASSWORD%"
echo user_data_dir: "%USER_DATA_DIR:\=/%"
echo headless: %HEADLESS%
echo browser_path: "%CHROME_PATH:\=/%"
echo browse_count: %BROWSE_COUNT%
echo like_probability: %LIKE_PROB%
echo browse_interval_min: 3
echo browse_interval_max: 8
echo tg_bot_token: "%TG_TOKEN%"
echo tg_chat_id: "%TG_CHAT_ID%"
) > config.yaml

if not exist "%USER_DATA_DIR%" mkdir "%USER_DATA_DIR%"
echo.
echo [成功] 配置已保存: config.yaml
goto :eof

:edit_config
if not exist "config.yaml" (
    echo [错误] 配置文件不存在，请先运行一键安装
    pause
    goto :menu
)
echo [信息] 打开配置文件...
notepad config.yaml
goto :menu

:setup_task
echo.
set "setup="
set /p setup="是否设置 Windows 定时任务？[y/N]: "
if /i not "%setup%"=="y" goto :eof

set "SCRIPT_DIR=%CD%"
set "PYTHON_PATH=%SCRIPT_DIR%\venv\Scripts\python.exe"
set "MAIN_SCRIPT=%SCRIPT_DIR%\main.py"

echo.
echo 选择签到时间:
echo   1. 每天 8:00 和 20:00（推荐）
echo   2. 每天 9:00
echo   3. 自定义时间
set "time_choice="
set /p time_choice="请选择 [1-3]: "

schtasks /delete /tn "LinuxDO-Checkin-1" /f >nul 2>&1
schtasks /delete /tn "LinuxDO-Checkin-2" /f >nul 2>&1

if "%time_choice%"=="1" (
    schtasks /create /tn "LinuxDO-Checkin-1" /tr "\"%PYTHON_PATH%\" \"%MAIN_SCRIPT%\"" /sc daily /st 08:00 /f >nul
    schtasks /create /tn "LinuxDO-Checkin-2" /tr "\"%PYTHON_PATH%\" \"%MAIN_SCRIPT%\"" /sc daily /st 20:00 /f >nul
    echo [成功] 定时任务已设置: 08:00, 20:00
) else if "%time_choice%"=="2" (
    schtasks /create /tn "LinuxDO-Checkin-1" /tr "\"%PYTHON_PATH%\" \"%MAIN_SCRIPT%\"" /sc daily /st 09:00 /f >nul
    echo [成功] 定时任务已设置: 09:00
) else (
    set "custom_time="
    set /p custom_time="输入时间 (格式 HH:MM，如 08:00): "
    schtasks /create /tn "LinuxDO-Checkin-1" /tr "\"%PYTHON_PATH%\" \"%MAIN_SCRIPT%\"" /sc daily /st !custom_time! /f >nul
    echo [成功] 定时任务已设置: !custom_time!
)

echo.
echo [提示] 查看任务: schtasks /query /tn LinuxDO-Checkin-1
echo [提示] 删除任务: schtasks /delete /tn LinuxDO-Checkin-1 /f
goto :eof

:first_login
echo.
set "do_login="
set /p do_login="是否现在进行首次登录？[Y/n]: "
if /i "%do_login%"=="n" goto :eof

echo.
echo [信息] 启动浏览器进行首次登录...
echo [提示] 请在浏览器中登录 Linux.do 账号
echo [提示] 登录成功后关闭浏览器即可
echo.
venv\Scripts\python.exe main.py --first-login
goto :eof

:run_checkin
echo.
echo [信息] 运行签到...
venv\Scripts\python.exe main.py
echo.
pause
goto :menu

:print_completion
echo.
echo ============================================================
echo                      安装完成！
echo ============================================================
echo.
echo 后续操作:
echo   1. 首次登录: venv\Scripts\python.exe main.py --first-login
echo   2. 运行签到: venv\Scripts\python.exe main.py
echo   3. 编辑配置: 选择菜单 3 或直接编辑 config.yaml
echo   4. 查看任务: schtasks /query /tn LinuxDO-Checkin-1
echo.
goto :eof

:exit_script
echo.
echo 感谢使用，再见！
pause >nul
exit /b 0
