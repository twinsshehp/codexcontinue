-- codexcontinue-managed-autolaunch
-- Runs when iTerm2 opens. A manually stopped guard stays stopped.
-- Does NOT run Codex CLI or send any text into its terminal.
on run
    try
        set homePath to POSIX path of (path to home folder)
        set markerPath to homePath & "Library/Application Support/CodexCapacityGuard/disabled"
        if (do shell script "/bin/test -f " & quoted form of markerPath & "; echo $?") is "0" then
            return
        end if

        set userId to do shell script "/usr/bin/id -u"
        set jobTarget to "gui/" & userId & "/com.peakmain.codex-capacity-guard"
        set plistPath to homePath & "Library/LaunchAgents/com.peakmain.codex-capacity-guard.plist"
        try
            do shell script "/bin/launchctl print " & jobTarget & " >/dev/null 2>&1"
            do shell script "/bin/launchctl kickstart " & jobTarget & " >/dev/null 2>&1"
        on error
            -- If the LaunchAgent was unloaded, register it again.
            do shell script "/bin/launchctl bootstrap gui/" & userId & " " & quoted form of plistPath & " >/dev/null 2>&1"
        end try
    on error errText
        log "codexcontinue AutoLaunch failed: " & errText
    end try
end run
