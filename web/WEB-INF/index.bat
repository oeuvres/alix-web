@echo off 
setlocal
SET DIR=%~dp0
java -cp "%DIR%/lib/*" alix.cli.Load 1 "$@"
REM touch $DIR/web.xml # reload webapp
