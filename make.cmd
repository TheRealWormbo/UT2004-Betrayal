@ECHO OFF
ECHO Build Script for Unreal Engine 1 and 2 single file projects
ECHO Copyright (c) 2015, Wormbo
ECHO.
REM (1) This this build script is provided "as-is", without warranty of any
REM     kind. (In other words, if it breaks something for you, that's entirely
REM     your problem, not mine.)
REM (2) You are allowed to reuse parts of this build script in any way that
REM     does not involve making money, breaking applicable laws or restricting
REM     anyone's human or civil rights.
REM (3) You are allowed to distribute modified versions of this build script.
REM     I'd prefer being mentioned in the credits for or comments in such
REM     modified versions, but please do not make it seem like I endorse them
REM     in any way.

SETLOCAL

REM Enable command extensions. The VERIFY line sets an error level in case SETLOCAL doesn't.
VERIFY OTHER 2>nul
SETLOCAL EnableExtensions
IF ERRORLEVEL 1 GOTO ErrorExtensions

REM determine project folder
SET ProjectFolder=%~dp0
ECHO Running from project folder %ProjectFolder%

REM Read the project name
IF NOT EXIST "%ProjectFolder%Build\ProjectName.cfg" GOTO ErrorProject
SET /P ProjectName=<"%ProjectFolder%Build\ProjectName.cfg"
IF NOT DEFINED ProjectName GOTO ErrorProject

REM Read project version
IF NOT EXIST "%ProjectFolder%Build\ProjectVersion.cfg" GOTO ErrorProject
SET /P ProjectVersion=<"%ProjectFolder%Build\ProjectVersion.cfg"
IF NOT DEFINED ProjectVersion GOTO ErrorProject

REM Read the game name for this project
IF NOT EXIST "%ProjectFolder%Build\ProjectGame.cfg" GOTO ErrorProject
SET /P ProjectGame=<"%ProjectFolder%Build\ProjectGame.cfg"
IF NOT DEFINED ProjectGame GOTO ErrorProject

ECHO Building %ProjectName%%ProjectVersion% for %ProjectGame%

REM Go to assumed game base folder
SET GameBase=%ProjectFolder%..
IF EXIST "%GameBase%\System\UCC.exe" IF EXIST "%GameBase%\System\%ProjectGame%.exe" GOTO FoundGame

SET GameBase=%ProjectFolder%..\..
IF EXIST "%GameBase%\System\UCC.exe" IF EXIST "%GameBase%\System\%ProjectGame%.exe" GOTO FoundGame

REM game not found at assumed location, try finding in registry for 64bit Windows
FOR /F "tokens=2* delims=	 " %%A IN ('reg query "HKLM\SOFTWARE\Wow6432Node\Unreal Technology\Installed Apps\%ProjectGame%" /v Folder') DO SET GameBase=%%B
IF EXIST "%GameBase%\System\UCC.exe" IF EXIST "%GameBase%\System\%ProjectGame%.exe" GOTO FoundGame

REM still not found, try finding in registry for 32bit Windows
FOR /F "tokens=2* delims=	 " %%A IN ('reg query "HKLM\SOFTWARE\Unreal Technology\Installed Apps\%ProjectGame%" /v Folder') DO SET GameBase=%%B
IF EXIST "%GameBase%\System\UCC.exe" IF EXIST "%GameBase%\System\%ProjectGame%.exe" GOTO FoundGame

REM Use game base previously stored in a file
IF NOT EXIST %ProjectFolder%Build\%ProjectGame%Base.cfg GOTO GETGameBase
SET /P GameBase=<%ProjectFolder%Build\%ProjectGame%Base.cfg
IF EXIST "%GameBase%\System\UCC.exe" IF EXIST "%GameBase%\System\%ProjectGame%.exe" GOTO FoundGame

REM Let user enter game install location...
:GetGameBase
SET /P GameBase="Please specify your %ProjectGame% install dir (without trailing backslash): "
IF EXIST "%GameBase%\System\UCC.exe" IF EXIST "%GameBase%\System\%ProjectGame%.exe" (
	REM ...and store it in a file
	ECHO %GameBase%>%ProjectFolder%Build\%ProjectGame%Base.cfg
	ECHO.
	GOTO FoundGame
)
ECHO "%GameBase%" does not seem to be a %ProjectGame% directory.
ECHO Hint: Do not enter the System folder, but its parent. Press Ctrl+C to abort.
GOTO GetGameBase


:FoundGame
REM Convert to absolute local path, potentially assigning a temporary network drive letter
PUSHD %GameBase%
SET GameBase=%CD%
SET BuildFolder=%GameBase%\%ProjectName%%ProjectVersion%

ECHO %ProjectGame% is located in %GameBase%
ECHO Building from %BuildFolder%

IF EXIST "%BuildFolder%" (
	ECHO Warning: Build folder already exists and will be deleted!
	ECHO Press Ctrl+C to abort or any other key to continue...
	PAUSE>nul
	RMDIR /S /Q "%BuildFolder%"
)

ECHO.
MKDIR "%BuildFolder%"
IF ERRORLEVEL 1 GOTO ErrorCreateDir

REM The /EXCLUDE option does not accept quoted file names, but I want to be "space-safe" here
CD "%ProjectFolder%"
ECHO Copying source files from %ProjectFolder% to %BuildFolder%...
XCOPY .\* "%BuildFolder%" /EXCLUDE:Build\CopyExcludes.cfg /S
IF ERRORLEVEL 1 GOTO ErrorCreateDir

ECHO Writing build configuration...
FOR /F "eol=; tokens=1,2* delims==" %%A IN (%ProjectFolder%make.ini) DO IF "%%B" EQU "" (
	ECHO %%A>>"%BuildFolder%\make.ini"
) ELSE IF /I "%%A=%%B" EQU "EditPackages=%ProjectName%" (
	ECHO %%A=%ProjectName%%ProjectVersion%>>"%BuildFolder%\make.ini"
) ELSE (
	ECHO %%A=%%B>>"%BuildFolder%\make.ini"
)

CD %GameBase%\System

REM backup existing package
SET OutputFile=%ProjectName%%ProjectVersion%.u
IF EXIST "%OutputFile%.backup" DEL "%OutputFile%.backup"
IF EXIST "%OutputFile%" (
	ECHO Backing up %GameBase%\System\%OutputFile%
	REN "%OutputFile%" "%OutputFile%.backup"
)

ECHO.
ECHO Running compiler...
UCC Editor.Make -ini=%BuildFolder%\make.ini
ECHO.

IF NOT EXIST "%OutputFile%" (
	REM restore backed up previous package
	IF EXIST "%OutputFile%.backup" (
		ECHO Build failed, restoring previous backup of %GameBase%\System\%OutputFile%
		REN "%OutputFile%.backup" "%OutputFile%"
	) ELSE (
		ECHO Build failed.
	)
) ELSE (
	ECHO Build successfully created %GameBase%\System\%OutputFile%
	ECHO Applying timestamp...
	%ProjectFolder%Build\Timestamp "%OutputFile%"
	ECHO Compressing package for redirect...
	UCC Compress %OutputFile%
	ECHO.
	ECHO Build complete.
)

PAUSE
ECHO Cleaning up...
RMDIR /S /Q "%BuildFolder%"
POPD
EXIT /B 0


REM Build error handlers
:ErrorCreateDir
ECHO Error: Can't set up build folder %BuildFolder%
PAUSE
EXIT /B 2

:ErrorProject
ECHO Error: Project setup seems incomplete, please ensure you checked out everything.
PAUSE
EXIT /B 2

:ErrorExtensions
ECHO Error: Command extensions are not available.
PAUSE
EXIT /B 2
