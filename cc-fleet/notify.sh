#!/usr/bin/env bash
# cc-fleet desktop toast. Usage: notify.sh "Title" "Body".
# WSL: fires a Windows toast via powershell.exe. Falls back to notify-send.
# Never errors out (best-effort).

title="${1:-Claude}"
body="${2:-needs you}"

if command -v powershell.exe >/dev/null 2>&1; then
  CC_TITLE="$title" CC_BODY="$body" powershell.exe -NoProfile -NonInteractive -Command '
    $ErrorActionPreference = "Stop"
    $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime]
    $tpl  = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
    $txt  = $tpl.GetElementsByTagName("text")
    $txt[0].AppendChild($tpl.CreateTextNode($env:CC_TITLE)) | Out-Null
    $txt[1].AppendChild($tpl.CreateTextNode($env:CC_BODY))  | Out-Null
    $toast = [Windows.UI.Notifications.ToastNotification]::new($tpl)
    $aumid = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($aumid).Show($toast)
  ' >/dev/null 2>&1
elif command -v notify-send >/dev/null 2>&1; then
  notify-send "$title" "$body" >/dev/null 2>&1
fi

exit 0
