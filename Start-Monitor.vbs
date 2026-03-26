' Start-Monitor.vbs
' Launches ProcessMonitor.ps1 silently (no console window)
' Double-click this file, or call it from Start-Monitor.bat

Dim fso, scriptDir, ps1Path, cmd, shell

Set fso       = CreateObject("Scripting.FileSystemObject")
Set shell     = CreateObject("WScript.Shell")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
ps1Path   = fso.BuildPath(scriptDir, "ProcessMonitor.ps1")

If Not fso.FileExists(ps1Path) Then
    MsgBox "Cannot find ProcessMonitor.ps1 in:" & vbCrLf & scriptDir, _
           vbExclamation, "ProcessMonitor"
    WScript.Quit 1
End If

cmd = "powershell.exe -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File """ & ps1Path & """"

' Window style 0 = completely hidden, False = don't wait for it to finish
shell.Run cmd, 0, False

WScript.Quit 0
