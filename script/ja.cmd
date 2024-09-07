@echo off
setlocal

:: Check if a version number was provided
if "%~1"=="" (
    echo Usage: %0 <java_version> [java_options...]
    exit /b 1
)

set JAVA_VERSION=%1
set JAVA_HOME_ENV=%JAVA_HOME%
set JDK_HOME_ENV=JDK_%JAVA_VERSION%_HOME

:: Check if the environment variable for the specific JDK version exists
if defined %JDK_HOME_ENV% (
    set JAVA_HOME=%!JDK_HOME_ENV!
) else (
    set JAVA_HOME=%JAVA_HOME_ENV%
)

:: Print JAVA_HOME for debugging
echo JAVA_HOME is set to %JAVA_HOME%


if not exist "%JAVA_HOME%\bin\java.exe" (
    echo ERROR: Java executable not found in "%JAVA_HOME%\bin\java.exe"
    exit /b 1
)


set "javafx_args="
if "%JAVA_VERSION%" neq "8" (
    if defined JAVAFX_HOME (
    if exist "%JAVAFX_HOME%\lib" (
        set "javafx_args=--module-path %JAVAFX_HOME%\lib --add-modules javafx.controls,javafx.fxml"
    ) else (
        echo WARNING: JAVAFX_HOME is defined but the lib directory is missing.
    )
)
)


:: 将所有参数保存到一个临时变量中
set "params=%*"

:: 初始化参数索引
set "index=0"

:: 移除第一个参数
shift

:: 重新构建参数列表，从第二个参数开始
set "newParams="

:buildParams
if "%1"=="" goto done
if defined newParams (
    set "newParams=%newParams% %1"
) else (
    set "newParams=%1"
)
shift
goto buildParams

:done
echo New parameters: %newParams%

@pushd %~dp0
"%JAVA_HOME%\bin\java.exe" %javafx_args% -jar %newParams%
@popd

endlocal

