#!/bin/bash
# Test if monitor works inside tmux

SESSION_NAME="test-monitor-$$"
LOG_FILE="$HOME/.smart-gif-converter/tmux-monitor-test.log"

echo "Starting tmux session: $SESSION_NAME"
echo "Monitor log will be at: $LOG_FILE"

# Create tmux session with embedded monitor
tmux new-session -d -s "$SESSION_NAME" bash -c "
    echo 'Inside tmux session' > '$LOG_FILE'
    echo 'DISPLAY: \$DISPLAY' >> '$LOG_FILE'
    echo 'DBUS: \$DBUS_SESSION_BUS_ADDRESS' >> '$LOG_FILE'
    echo 'Parent PIDs:' >> '$LOG_FILE'
    ps -o pid,ppid,comm,args -p \$\$ >> '$LOG_FILE'
    ps -o pid,ppid,comm,args -p \$PPID >> '$LOG_FILE'
    
    # Find terminal PID
    TERMINAL_PID=''
    current_pid=\$\$
    depth=0
    while [[ \$depth -lt 30 ]]; do
        parent_pid=\$(ps -o ppid= -p \$current_pid 2>/dev/null | tr -d ' ')
        [[ -z \"\$parent_pid\" || \"\$parent_pid\" == \"1\" || \"\$parent_pid\" == \"0\" ]] && break
        
        proc_name=\$(ps -o comm= -p \$parent_pid 2>/dev/null | tr -d ' ')
        echo \"Depth \$depth: PID \$parent_pid = \$proc_name\" >> '$LOG_FILE'
        
        if [[ \"\$proc_name\" =~ ^(konsole|gnome-terminal|xterm|alacritty|kitty|wezterm|warp|warp-terminal|tilix|terminator)$ ]]; then
            TERMINAL_PID=\$parent_pid
            echo \"Found terminal: \$proc_name (PID: \$TERMINAL_PID)\" >> '$LOG_FILE'
            break
        fi
        
        current_pid=\$parent_pid
        ((depth++))
    done
    
    if [[ -z \"\$TERMINAL_PID\" ]]; then
        echo 'ERROR: Could not find terminal PID' >> '$LOG_FILE'
        exit 1
    fi
    
    # Start background monitor
    (
        echo 'Monitor started, waiting for terminal to close...' >> '$LOG_FILE'
        tail --pid=\"\$TERMINAL_PID\" -f /dev/null 2>/dev/null || while kill -0 \"\$TERMINAL_PID\" 2>/dev/null; do sleep 0.5; done
        
        echo 'Terminal closed! Sending notification...' >> '$LOG_FILE'
        notify-send -u critical -t 0 'TEST: Terminal Closed' 'Monitor detected terminal closure from inside tmux!' 2>&1 >> '$LOG_FILE'
        echo 'Notification sent (exit code: \$?)' >> '$LOG_FILE'
    ) &
    
    MONITOR_PID=\$!
    echo \"Monitor PID: \$MONITOR_PID\" >> '$LOG_FILE'
    
    # Keep session alive
    echo ''
    echo 'Monitor is running in background'
    echo 'Close this Konsole window to test notification'
    echo ''
    bash -i
"

# Attach to the session
tmux attach-session -t "$SESSION_NAME"

# After detaching/exiting, show the log
echo ""
echo "=== Monitor Log ==="
cat "$LOG_FILE" 2>/dev/null || echo "No log file found"
