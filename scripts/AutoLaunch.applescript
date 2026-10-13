-- codexcontinue-managed-autolaunch
-- Triggered by iTerm2 at startup. Does NOT run Codex or send input.
-- The LaunchAgent uses KeepAlive=false so the Python guard may exit on app quit.
on run
    try
        set userId to do shell script "/usr/bin/id -u"
        do shell script "/bin/launchctl kickstart gui/" & userId & "/com.peakmain.codex-capacity-guard >/dev/null 2>&1"
    on error errText
        log "codexcontinue auto-launch failed: " & errText
    end try
end run
