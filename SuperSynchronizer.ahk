; ----------------------------------------------------------------------------------------------------------------------
; Name .........: SuperSynchronizer
; Description ..: A little script for incremental/mirror directory synchronization.
; AHK Version ..: AHK_L 1.1.13.01 x32 Unicode
; Author .......: Cyruz - http://ciroprincipe.info
; Changelog ....: Oct. 20, 2011 - v0.1   - Fixed some inconsistencies with reverse check exclusions.
; ..............: Oct. 26, 2011 - v0.2   - Fixed a parenthesis glitch and a problem with the reverse check routine where
; ..............:                          a file in destination side doesn't get updated if it's newer than the source
; ..............:                          side causing an incorrect mirroring. Adjusted some comments. 
; ..............: May  25, 2013 - v0.3   - Code refactoring, improved logging, stacking gui, multiscripts feature, large
; ..............:                          files handling.
; ..............: Jan. 06, 2014 - v0.4   - Code refactoring, Unicode and long path support, added simulation feature.
; ..............: Jan. 07, 2014 - v0.4.1 - Added exclusions by file extension.
; How it works .: The script is structured in two stages:
; ..............: 1. REPLICATION CHECK
; ..............:    The files on the DESTINATION SIDE are synchronized with the files on the SOURCE SIDE.
; ..............: 2. REVERSE CHECK
; ..............:    The files on the DESTINATION SIDE that don't exist on SOURCE SIDE are deleted.
; ..............:    The script can be instantiated multiple times, and the GUI will stack automatically starting from 
; ..............:    the TOP-RIGHT corner. A detailed log file is createad by default in A_ScriptDir.
; How to use ...: [] Set the source and destination directory, set copy mode (enable/disable mirroring) and logging.
; ..............: [] To exclude files from the replication or reverse check, add them to the exclusion lists.
; ..............: [] Run the script. If you need to stop the script, flag "Sure?" checkbox and click "Stop" button.
; ..............: [] [] If you stop the script, the actual processed file is deleted to allow a clean restart.
; ..............: [] [] If you close/exit/kill the script it will behave like if the script is stopped.
; License ......: GNU Lesser General Public License
; ..............: This program is free software: you can redistribute it and/or modify it under the terms of the GNU
; ..............: Lesser General Public License as published by the Free Software Foundation, either version 3 of the
; ..............: License, or (at your option) any later version.
; ..............: This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
; ..............: the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser 
; ..............: General Public License for more details.
; ..............: You should have received a copy of the GNU Lesser General Public License along with this program. If 
; ..............: not, see <http://www.gnu.org/licenses/>.
; ----------------------------------------------------------------------------------------------------------------------

;#NoTrayIcon
#Persistent
#SingleInstance Off
DetectHiddenWindows, On
SetTitleMatchMode, 2

; ======================================================================================================================
; ===[ VARIABLES SECTION ]==============================================================================================
; ======================================================================================================================

; SOURCE DIRECTORY
; [ STRING, ABSOLUTE PATH, NO QUOTES ]
SOURCE_DIR = 

; DESTINATION DIRECTORIES
; [ STRING, ABSOLUTE PATH, NO QUOTES ]
DESTIN_DIR = 

; MIRRORING - DELETE DESTINATION FILE NOT PRESENT ON SOURCE
; [ 1: ENABLED, 0: DISABLED ]
MIRRORING := 1

; SIMULATION - JUST SIMULATE THE SYNC AND UPDATE THE LOG FILE
; [ 1: ENABLED, 0: DISABLED ]
SIMULATION := 1

; LOGGING
; [ 1: ENABLED, 0: DISABLED ]
LOG_ENABLE := 1

; LOG FILE - ONLY IF LOG_ENABLE == 1, DEFAULT TO %A_ScriptDir%\%A_ScriptName%.log
; [ STRING, ABSOLUTE PATH, NO QUOTES ]
LOG_FILE =

; INTERACTIVE FLAG - USER INTERACTIVE GUI
; [ 1: ENABLED, 0: DISABLED ]
INTERACTIVE := 1

; LOW PRIORITY FOR THE SCRIPT PROCESS
; [ 1: ENABLED, 0: DISABLED ]
LOW_PRIORITY := 0

; HOW LONG TO SLEEP BETWEEN EACH FILE ITERATION
; [ INTEGER, MILLISECONDS ]
SLEEP_MS := 10

; REPLICATION CHECK GLOBAL EXCLUSIONS - ITEMS NOT TO BE COPIED ON DESTINATION SIDE
; [ CONTINUATION SECTION, NEWLINE SEPARATED, NO QUOTES, ENCLOSED BY <>, FULL PATH OR NAME ]
; Excluded directories.
EX_REPLICATION_DIRS =
( LTrim
)
; Excluded files.
EX_REPLICATION_FILES =
( LTrim
)
; Excluded extensions.
EX_REPLICATION_EXTS =
( LTrim
)

; REVERSE CHECK GLOBAL EXCLUSIONS - ITEMS NOT TO BE DELETED ON DESTINATION SIDE
; [ CONTINUATION SECTION, NEWLINE SEPARATED, NO QUOTES, ENCLOSED BY <>, FULL PATH OR NAME ]
; Excluded directories.
EX_REVERSE_DIRS =
( LTrim
)
; Excluded files.
EX_REVERSE_FILES =
( LTrim
)
; Excluded extensions.
EX_REVERSE_EXTS =
( LTrim
)

; ======================================================================================================================
; ===[ MAIN SECTION ]===================================================================================================
; ======================================================================================================================

; Script start check.
If ( INTERACTIVE )
{
    Msgbox, 0x4, SuperSynchronizer, FROM:`t%SOURCE_DIR%`nTO:`t%DESTIN_DIR%`n`nStart Synchronizing?
    IfMsgBox, No
        ExitApp
}

; Source folder check.
If ( !InStr( FileExist( SOURCE_DIR ), "D" ) )
{
    If ( INTERACTIVE )
        MsgBox,, SuperSynchronizer, Source folder doesn't exists!
    ExitApp ; Fail if source folder doesn't exists.
}

; Destination folder check.
If ( !InStr( FileExist( DESTIN_DIR ), "D" ) )
{
    If ( SIMULATION )
    {
        MsgBox,, SuperSynchronizer, Cannot simulate if destination directory is not existing.
        ExitApp
    }
    If ( INTERACTIVE )
    {
        Msgbox, 0x4, SuperSynchronizer, Destination folder doesn't exists, create it?
        IfMsgBox, No
            ExitApp
        FileCreateDir, %DESTIN_DIR%
    }
    Else ExitApp ; Fail silently if destination folder doesn't exists and !INTERACTIVE.
}

; If SIMULATION == 1, force LOGGING to 1.
If ( SIMULATION )
    LOG_ENABLE := 1

; Modify the OnExit so that the "Stop" feature is correctly handled.
OnExit, STOPSYNC

; Adjust the priority of the current process.
Process, Priority, % DllCall( "GetCurrentProcessId" ), % ( LOW_PRIORITY ) ? "L" : "N"

; Create the callback for the stop feature.
COPY_CALLBACK := RegisterCallback( "CopyCallback", "Fast" )

; Set STOP_SYNC = 0 to start the copy operation (flag "Sure?" and press "Stop" to turn STOP_SYNC = 1).
STOP_SYNC := 0

If ( INTERACTIVE )
{   ; Get monitor resolution and previous windows to calculate the coordinates.
    SysGet, Mon, Monitor
    _X := MonRight - 388
    WinGet, hWndList, LIST, SuperSynchronizer ahk_class AutoHotkeyGUI
    _Y := ( 75 * hWndList ) + 1

    ; Gui management.
    Gui, +LastFound +Hwndh_GUI
    WinSet, Transparent, 240, ahk_id %h_GUI%
    Gui, Margin, 10, 10
    Gui, Add, Text, vSyncText Left w300 h55, Replicating...`n`nFROM:`t%SOURCE_DIR%`nTO:`t%DESTIN_DIR%
    GuiControl, -Wrap, SyncText
    Gui, Add, Checkbox, vAreYouSure x+15 y22, Sure?
    Gui, Add, Button, gSTOPSYNC vSyncButton w50 h20 y+10, &Stop
    Gui, -Caption +Border
    Gui, Show, X%_X% Y%_Y% Autosize, SuperSynchronizer
}

; Get start timestamp.
START_TIMESTAMP = %A_Now%

; !!! REPLICATION CHECK START !!!
; ----------------------------------------------------------------------------------------------------------------------
If ( LOG_ENABLE ) ; Log management.
    WriteLog( 1, "REPLICATION CHECK STARTED`n****************************************************************`n" )

SetWorkingDir, %SOURCE_DIR%
bSyncStopped := ReplicationCheck( "*.*" )
; ----------------------------------------------------------------------------------------------------------------------

; !!! REVERSE CHECK START !!!
; ----------------------------------------------------------------------------------------------------------------------
If ( MIRRORING && !bSyncStopped )
{
    If ( INTERACTIVE )
        GuiControl,, SyncText, Mirroring...`n`nFROM:`t%SOURCE_DIR%`nTO:`t%DESTIN_DIR%

    If ( LOG_ENABLE ) ; Log management.
        WriteLog( 0, "`n" )
      , WriteLog( 1, "REVERSE CHECK STARTED`n****************************************************************`n" )
    
    SetWorkingDir, %DESTIN_DIR%
    bSyncStopped := ReverseCheck( "*.*" )
}
; ----------------------------------------------------------------------------------------------------------------------

; Get end timestamp and calculate elapsed time.
END_TIMESTAMP = %A_Now%
EnvSub, END_TIMESTAMP, START_TIMESTAMP, Seconds
VarSetCapacity( TIME_ELAPSED, 18 ) ; XX:XX:XX + string terminator = 9 chars (UNICODE: 9*2 bytes).
DllCall( "msvcrt\swprintf", Str,TIME_ELAPSED, Str,"%02d:%02d:%02d", Int,Floor(END_TIMESTAMP/3600)
                          , Int,Mod(END_TIMESTAMP/60,60), Int,Mod(END_TIMESTAMP,60) )

If ( INTERACTIVE )
{   ; Gui management.
    Gui, Cancel
    GuiControl,, SyncText, % ( ( bSyncStopped ) ? "Synchronization Stopped!" : "Done!" )
                           . "`n`nTime Elapsed: " TIME_ELAPSED
    GuiControl, Hide, AreYouSure
    GuiControl,, SyncButton, &Ok
    GuiControl, +Default -g gGUIDESTROY, SyncButton
    Gui, Show, X%_X% Y%_Y% Autosize, SuperSynchronizer
    WinWaitClose, ahk_id %h_GUI%
}

If ( LOG_ENABLE )
{   ; Log management - append log to the file.
    If ( !LOG_FILE )
        LOG_FILE := A_ScriptDir "\" SubStr( A_ScriptName, 1, -3 ) "log"
    SplitPath, LOG_FILE,, sFilePath, sFileExt, sFileName
    Loop
    {   ; If file exists loop until it finds a not existing filename.
        If ( FileExist( LOG_FILE ) )
            LOG_FILE = %sFilePath%\%sFileName%_%A_Index%.%sFileExt%
        Else Break
    }
    WriteLog( 0, "`n****************************************************************`n" )
    WriteLog( 1, "SINCHRONIZATION FINISHED IN " TIME_ELAPSED, LOG_FILE )
}

; Restore correct OnExit behaviour and exit from the script.
OnExit, REALQUIT
ExitApp

; ======================================================================================================================
; ===[ LABELS SECTION ]=================================================================================================
; ======================================================================================================================

 STOPSYNC:
 GUICLOSE:
    Critical
    If ( !INTERACTIVE )
    {   ; Stop synchronization if the script is not interactive.
        STOP_SYNC := 1
        Return
    }
    If ( A_GuiControl == "SyncButton" )
        ; "Stop" button pressed, check the "AreYouSure" flag before stopping sync.
        GuiControlGet, STOP_SYNC,, AreYouSure
    Else
        ; Script or GUI closed, stop synchronization.
        STOP_SYNC := 1
    Return
;GUICLOSE
;STOPSYNC

 GUIDESTROY:
    Gui, Destroy
    Return
;GUIDESTROY

 REALQUIT:
    ExitApp
;REALQUIT

; ======================================================================================================================
; ===[ FUNCTIONS SECTION ]==============================================================================================
; ======================================================================================================================

ReplicationCheck( sPattern )
{
    Global SOURCE_DIR, DESTIN_DIR, EX_REPLICATION_DIRS, EX_REPLICATION_FILES, SIMULATION, LOG_ENABLE, COPY_CALLBACK
         , STOP_SYNC

    Loop, %sPattern%, 1
    {
        ; Return 1 if STOP_SYNC is set.
        If ( STOP_SYNC )
            Return 1
        
        If ( InStr( FileExist( A_LoopFileFullPath ), "D" ) )
        {   ; It's a directory.
            If ( !InStr( EX_REPLICATION_DIRS, "<" A_LoopFileLongPath ">" ) )
            && ( !InStr( EX_REPLICATION_DIRS, "<" A_LoopFileName     ">" ) )
            {   ; If directory isn't in exlusion list.
                If ( !InStr( FileExist( DESTIN_DIR "\" A_LoopFileFullPath), "D" ) )
                {   ; If source directory doesn't exists on destination, create it.
                    If ( !SIMULATION )
                    {   ; If SIMULATION is disabled.
                        ; Try to delete an "eventually present" file that has the same name of the source directory.
                        FileDelete, %DESTIN_DIR%\%A_LoopFileFullPath%
                        ; Create the source directory on destination.
                        FileCreateDir, %DESTIN_DIR%\%A_LoopFileFullPath%
                    }
                    If ( LOG_ENABLE ) ; Log management
                        WriteLog( 1, ( !SIMULATION && ErrorLevel )
                                ? "ERROR >> Could not create directory: <" DESTIN_DIR "\" A_LoopFileFullPath "> $`n"
                                : "SUCCESS >> Directory created: <" DESTIN_DIR "\" A_LoopFileFullPath "> $`n" )
                }
                ; Recursion into current directory.
                bStopFlag := ReplicationCheck( A_LoopFileFullPath "\*.*" )
                ; If bStopFlag is set, return 1 (it means that STOP_SYNC == 1).
                If ( bStopFlag )
                    Return 1
            }
            Else
            {   ; Directory skipped.
                If ( LOG_ENABLE ) ; Log management.
                    WriteLog( 1, "SKIPPED >> Directory excluded: <" A_LoopFileLongPath "> $`n" )
            }
        }
        Else
        {   ; It's a file.
            bCopyFlag := 0
            If ( !InStr( EX_REPLICATION_FILES, "<" A_LoopFileLongPath ">" ) )
            && ( !InStr( EX_REPLICATION_FILES, "<" A_LoopFileName     ">" ) )
            && ( !InStr( EX_REPLICATION_EXTS,  "<" A_LoopFileExt      ">" ) )
            {   ; If file isn't in exlusion lists.
                If ( !sFileAttr := FileExist( DESTIN_DIR "\" A_LoopFileFullPath ) || InStr( sFileAttr, "D" ) )
                {   ; If it doesn't exists on destination or it exists and is a directory on destination, set copy flag.
                    If ( !SIMULATION )
                    {   ; If SIMULATION is disabled.
                        ; Try to delete an "eventually present" directory that has the same name of the source file.
                        FileRemoveDir, %DESTIN_DIR%\%A_LoopFileFullPath%, 1
                    }
                    ; Set copy flag.
                    bCopyFlag := 1
                }
                Else
                {   ; Else it exists and is a file with the same name of the source file.
                    ; Get modification time of the destination file.
                    FileGetTime, sFileTime, %DESTIN_DIR%\%A_LoopFileFullPath%
                    ; Calculate the difference with the modification time of the source file.
                    EnvSub, sFileTime, %A_LoopFileTimeModified%, seconds
                    If ( sFileTime < 0 )
                    {   ; If source file is more recent than destination file.
                        If ( !SIMULATION )
                        {   ; If SIMULATION is disabled.
                            ; Remove attributes to destination file, because CopyFileEx fails if readonly or hidden.
                            FileSetAttrib, -RH, %DESTIN_DIR%\%A_LoopFileFullPath%
                        }
                        ; Set copy flag.
                        bCopyFlag := 1
                    }
                }
            }
            Else
            {   ; File skipped.
                If ( LOG_ENABLE ) ; Log management.
                    WriteLog( 1, "SKIPPED >> File excluded: <" A_LoopFileLongPath "> $`n" )
            }
            If ( bCopyFlag )
            {   ; File copy.
                sDestFileLongPath = %DESTIN_DIR%\%A_LoopFileFullPath%
                If ( !SIMULATION )
                {   ; If SIMULATION is disabled.
                    nReturn := DllCall( "CopyFileEx", Str,PrependLongPathPrefix(A_LoopFileLongPath)
                                                    , Str,PrependLongPathPrefix(sDestFileLongPath)
                                                    , UInt,COPY_CALLBACK, UInt,0, UInt,0, UInt,0 )
                    If ( !nReturn && A_LastError == 1235 )
                    {   ; If CopyFileEx failed and GetLastError == ERROR_REQUEST_ABORTED == 1235.
                        If ( LOG_ENABLE ) ; Log management.
                            WriteLog( 1, "STOPPED >> Copy stopped: <" A_LoopFileLongPath "> not copied $`n" )
                        ; Return 1 (it means that STOP_SYNC == 1).
                        Return 1
                    }
                }
                If ( LOG_ENABLE ) ; Log management.
                    WriteLog( 1, ( !SIMULATION && !nReturn ) 
                            ? "ERROR >> Error copying <" A_LoopFileLongPath "> to <" sDestFileLongPath "> $`n"
                            : "SUCCESS >> Copied <" A_LoopFileLongPath "> to <" sDestFileLongPath "> $`n" )
            }
        }
        Sleep, %SLEEP_MS%
    }
    Return 0
}

ReverseCheck( sPattern )
{
    Global SOURCE_DIR, DESTIN_DIR, EX_REVERSE_DIRS, EX_REVERSE_FILES, SIMULATION, LOG_ENABLE, COPY_CALLBACK, STOP_SYNC

    bDontDeleteDirFlag := 0
    Loop, %sPattern%, 1
    {
        ; Return 1 if STOP_SYNC is set.
        If ( STOP_SYNC )
            Return 1
    
        If ( InStr( FileExist( A_LoopFileFullPath ), "D" ) )
        {   ; It's a directory.
            If ( !FileExist( SOURCE_DIR "\" A_LoopFileFullPath ) )
            {   ; If directory doesn't exist on source side.
                If ( !InStr( EX_REVERSE_DIRS, "<" A_LoopFileLongPath ">" ) )
                && ( !InStr( EX_REVERSE_DIRS, "<" A_LoopFileName     ">" ) )
                {   ; If directory isn't in exlusion lists.
                    ; Recurse into the directory.
                    ReverseCheck( A_LoopFileFullPath "\*.*" )
                    If ( !FileExist( A_LoopFileFullPath "\*" ) )
                    {   ; Remove directory only if empty.
                        If ( !SIMULATION )
                        {   ; If SIMULATION is disabled.
                            FileRemoveDir,  %A_LoopFileFullPath%
                        }
                        If ( LOG_ENABLE ) ; Log management.
                            WriteLog( 1, ( !SIMULATION && ErrorLevel )
                                    ? "ERROR >> Could not remove <" A_LoopFileLongPath "> $`n"
                                    : "SUCCESS >> Directory removed: <" A_LoopFileLongPath "> $`n" )
                    }
                    Else
                    {   ; Directory excluded because not empty.
                        If ( LOG_ENABLE ) ; Log management.
                            WriteLog( 1, "SKIPPED >> Directory excluded, not empty: <" A_LoopFileLongPath "> $`n" )
                    }
                }
                Else
                {   ; Directory skipped.
                    If ( LOG_ENABLE ) ; Log management.
                        WriteLog( 1, "SKIPPED >> Directory excluded: <" A_LoopFileLongPath "> $`n" )
                }
            }
            Else
            {   ; Else directory exists in source side.
                bStopFlag := ReverseCheck( A_LoopFileFullPath "\*.*" )
                ; If bStopFlag is set, return 1 (it means that STOP_SYNC == 1).
                If ( bStopFlag )
                    Return 1
            }
        }
        Else
        {   ; It's a file.
            If ( !FileExist( SOURCE_DIR "\" A_LoopFileFullPath ) )
            {   ; If file doesn't exists on source side.
                If ( !InStr( EX_REVERSE_FILES, "<" A_LoopFileLongPath ">" ) )
                && ( !InStr( EX_REVERSE_FILES, "<" A_LoopFileName     ">" ) )
                && ( !InStr( EX_REVERSE_EXTS,  "<" A_LoopFileExt      ">" ) )
                {   ; If file isn't in exclusion lists.
                    If ( !SIMULATION )
                    {   ; If SIMULATION is disabled.
                        FileDelete, %A_LoopFileFullPath%
                    }
                    If ( LOG_ENABLE ) ; Log management.
                        WriteLog( 1, ( !SIMULATION && ErrorLevel )
                                ? "ERROR >> Could not delete <" A_LoopFileLongPath "> $`n"
                                : "SUCCESS >> File deleted: <" A_LoopFileLongPath "> $`n" )
                }
                Else
                {   ; File skipped
                    If ( LOG_ENABLE ) ; Log management.
                        WriteLog( 1, "SKIPPED >> File excluded: <" A_LoopFileLongPath "> $`n" )
                }
            }
            Else
            {   ; Else file exists on source side.
                If ( !InStr( EX_REVERSE_FILES, "<" A_LoopFileLongPath ">" ) )
                && ( !InStr( EX_REVERSE_FILES, "<" A_LoopFileName     ">" ) )
                {   ; If file isn't in exclusion lists.
                    FileGetTime, sFileTime, %SOURCE_DIR%\%A_LoopFileFullPath%
                    EnvSub, sFileTime, %A_LoopFileTimeModified%, seconds
                    If ( sFileTime != 0 )
                    {   ; Check if destination file differs from source file, if yes overwrite destination file.
                        sSourceFileLongPath = %SOURCE_DIR%\%A_LoopFileFullPath%
                        If ( !SIMULATION )
                        {   ; If SIMULATION is disabled.
                            ; Remove attributes to destination file, because CopyFileEx fails if readonly or hidden.
                            FileSetAttrib, -RH, %A_LoopFileLongPath%
                            nReturn := DllCall( "CopyFileEx", Str,PrependLongPathPrefix(sSourceFileLongPath)
                                                            , Str,PrependLongPathPrefix(A_LoopFileLongPath)
                                                            , UInt,COPY_CALLBACK, UInt,0, UInt,0
                                                            , UInt,0 )
                            If ( !nReturn && A_LastError == 1235 )
                            {   ; If CopyFileEx failed and GetLastError == ERROR_REQUEST_ABORTED == 1235.
                                If ( LOG_ENABLE ) ; Log management.
                                    WriteLog( 1, "STOPPED >> Copy stopped: <" A_LoopFileLongPath "> not copied $`n" )
                                ; Return 1 (it means that STOP_SYNC == 1).
                                Return 1
                            }
                        }
                        If ( LOG_ENABLE ) ; Log management.
                            WriteLog( 1, ( !SIMULATION && !nReturn ) 
                            ? "ERROR >> Error copying <" sSourceFileLongPath "> to <" A_LoopFileLongPath "> $`n"
                            : "SUCCESS >> Copied <" sSourceFileLongPath "> to <" A_LoopFileLongPath "> $`n" )
                    }
                }
                Else
                {   ; File skipped.
                    If ( LOG_ENABLE ) ; Log management.
                        WriteLog( 1, "SKIPPED >> File excluded: <" A_LoopFileLongPath "> $`n" )
                }
            }
        }
        Sleep, %SLEEP_MS%
    }
    Return 0
}

WriteLog( bAppendTime, sLogEntry, sAppendLogTo:="" )
{
    Static sLogData
    If ( bAppendTime )
        sLogData .= "[" A_YYYY "." A_MM "." A_DD "]" A_Hour ":" A_Min ":" A_Sec " - " sLogEntry
    Else
        sLogData .= sLogEntry
    If ( sAppendLogTo )
        FileAppend, %sLogData%, %sAppendLogTo%
}

CopyCallback( var1lo, var1hi, var2lo, var2hi, var3lo, var3hi, var4lo, var4hi, var5, var6, var7, var8, var9 )
{
    ; 13 dummy parameters to conform to the CopyProgressRoutine.
    ; http://msdn.microsoft.com/en-us/library/windows/desktop/aa363854%28v=vs.85%29.aspx
    Global STOP_SYNC
    Return STOP_SYNC
}

PrependLongPathPrefix( sPath )
{
    if (SubStr(sPath,1,2) = "\\") ; Remote path
        return "\\?\UNC" SubStr(sPath,2)
    else
        return "\\?\" sPath
}
