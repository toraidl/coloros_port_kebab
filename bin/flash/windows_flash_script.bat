@echo off
cls
setlocal enabledelayedexpansion
reg query "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Nls\Language" /v InstallLanguage|find "0804">nul&& set LANG=Chinese
if "%LANG%"=="Chinese" (
    TITLE windows 刷机脚本 [请勿选中窗口，卡住按右键或回车或放大缩小窗口恢复]
) else (
    TITLE Windows Flash Script
)
color 3f
echo.
if exist "super.zst" (
    if "%LANG%"=="Chinese" (
        echo. 正在解压super镜像,耐心等待
    ) else (
        echo. Extracting the super image, wait patiently
    )
    platform-tools-windows\zstd.exe --rm -d super.zst -o super.img
    if not "%errorlevel%" == "0" (
        if "%LANG%"=="Chinese" (
            echo. 转换失败,按任意键退出
        ) else (
            echo. Conversion failed. Press any key to exit
        )
        pause >nul 2>nul
        exit
    )
)

if "%LANG%"=="Chinese" (
    echo.
    echo. 1. 保留数据刷入
    echo.
    echo. 2. 双清刷入
    echo.
    set /p input=请选择-默认选择1,回车执行:
) else (
    echo.
    echo. 1. Preserve user data during flashing
    echo.
    echo. 2. Wiping data without wiping /data/media
    echo.
    set /p input=Please select - 1 is selected by default, and enter to execute:
)

if "%LANG%"=="Chinese" (
    echo.
    echo. 机型验证中...请确保您的设备代号为device_code，并已经进入fastbootd模式 adb reboot fastboot。

    echo.
) else (
    echo.
    echo. Validating device...please boot your device into bootloader and make sure your device code is device_code
    echo.
)

:: 获取设备代码
for /f "tokens=2 delims=: " %%i in ('fastboot %* getvar product 2^>^&1') do set "product=%%i"

:: 预期设备代码
set "expected_device_code=device_code"

:: 设置语言相关的消息
if "%LANG%"=="Chinese" (
    set "msg_mismatch= 设备device_code不匹配。请检查是否是进入fastbootd模式"
    set "msg_continue=你想继续吗？(y/n): "
    set "msg_abort= 操作已被用户中止。"
    set "msg_continue_process=继续操作..."
) else (
    set "msg_mismatch=Mismatching image and device."
    set "msg_continue=Do you want to continue anyway? (y/n): "
    set "msg_abort=Operation aborted by user."
    set "msg_continue_process=Continuing with the process..."
)

:: 检查是否匹配
if /i "!product!" neq "%expected_device_code%" (
    echo %msg_mismatch%
    set /p "choice=%msg_continue%"
    if /i "!choice!" neq "y" (
        echo %msg_abort%
        exit /B 1
    )
)

if "%LANG%"=="Chinese" (
    echo.
    echo. 1. 刷入KSU内核
    echo.
    echo. 2. 刷入官方内核
    echo.
    set /p kernel=请选择-默认选择1,回车执行:
) else (
    echo.
    echo. 1. Flashing KernelSU boot.img
    echo.
    echo. 2. Flahsing Official boot.img
    echo.
    set /p kernel=Please select - 1 is selected by default, and enter to execute:
)

if  "%kernel%"=="1" (
    if "%LANG%"=="Chinese" (
	    echo. 刷入第三方boot_ksu.img
        
    ) else (
        echo. Flashing custom boot.img
    ) 
    platform-tools-windows\fastboot.exe flash boot %~dp0boot_ksu.img
    platform-tools-windows\fastboot.exe flash dtbo %~dp0firmware-update/dtbo_ksu.img

) else (
    platform-tools-windows\fastboot.exe flash boot %~dp0boot_official.img
    platform-tools-windows\fastboot.exe flash dtbo %~dp0firmware-update/dtbo.img
)

REM firmware

platform-tools-windows\fastboot.exe erase super
platform-tools-windows\fastboot.exe reboot bootloader
ping 127.0.0.1 -n 5 >nul 2>nul
platform-tools-windows\fastboot.exe flash super %~dp0super.img
if "%input%" == "2" (
	if "%LANG%"=="Chinese" (
	    echo. 正在双清系统,耐心等待
    ) else (
        echo. Wiping data without wiping /data/media/, please wait patiently
    ) 
	platform-tools-windows\fastboot.exe erase userdata
	platform-tools-windows\fastboot.exe erase metadata
)
REM SET_ACTION_SLOT_A_BEGIN
if "%LANG%"=="Chinese" (
	echo. 设置活动分区为 'a'。可能需要一些时间。请勿手动重新启动或拔掉数据线，否则可能导致设备变砖。
) else (
    echo. Starting the process to set the active slot to 'a.' This may take some time. Please refrain from manually restarting or unplugging the data cable, as doing so could result in the device becoming unresponsive.
)
platform-tools-windows\fastboot.exe set_active a

REM SET_ACTION_SLOT_A_END

platform-tools-windows\fastboot.exe reboot

if "%LANG%"=="Chinese" (
    echo. 刷机完成,若手机长时间未重启请手动重启,按任意键退出
) else (
    echo. Flash completed. If the phone does not restart for an extended period, please manually restart. Press any key to exit.
)
pause
exit
