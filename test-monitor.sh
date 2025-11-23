#!/bin/bash
# Debug script to test terminal monitoring

SESSION_NAME="test-notification-$$"
MONITOR_LOG="$HOME/.smart-gif-converter/test-monitor-debug.log"
TERMINAL_PID=$$

echo "=== Terminal Monitor Debug Test ===" | tee "$MONITOR_LOG"
echo "Session: $SESSION_NAME" | tee -a "$MONITOR_LOG"
echo "Current PID: $$" | tee -a "$MONITOR_LOG"
echo "Parent PID: $PPID" | tee -a "$MONITOR_LOG"
echo "" | tee -a "$MONITOR_LOG"

# Check environment
echo "--- Environment ---" | tee -a "$MONITOR_LOG"
echo "DISPLAY: ${DISPLAY:-NOT SET}" | tee -a "$MONITOR_LOG"
echo "DBUS_SESSION_BUS_ADDRESS: ${DBUS_SESSION_BUS_ADDRESS:-NOT SET}" | tee -a "$MONITOR_LOG"
echo "XDG_RUNTIME_DIR: ${XDG_RUNTIME_DIR:-NOT SET}" | tee -a "$MONITOR_LOG"
echo "" | tee -a "$MONITOR_LOG"

# Test notification immediately
echo "--- Testing notify-send ---" | tee -a "$MONITOR_LOG"
if command -v notify-send >/dev/null 2>&1; then
    echo "notify-send found" | tee -a "$MONITOR_LOG"
    if notify-send -u low -t 3000 -i info "Debug Test" "Monitor environment test" 2>&1 | tee -a "$MONITOR_LOG"; then
        echo "notify-send SUCCESS" | tee -a "$MONITOR_LOG"
    else
        echo "notify-send FAILED with exit code: $?" | tee -a "$MONITOR_LOG"
    fi
else
    echo "notify-send NOT FOUND" | tee -a "$MONITOR_LOG"
fi
echo "" | tee -a "$MONITOR_LOG"

# Find parent terminal
echo "--- Finding Terminal ---" | tee -a "$MONITOR_LOG"
current_pid=$$
depth=0
while [[ $depth -lt 20 ]]; do
    parent_pid=$(ps -o ppid= -p $current_pid 2>/dev/null | tr -d ' ')
    [[ -z "$parent_pid" || "$parent_pid" == "1" ]] && break
    
    proc_name=$(ps -o comm= -p $parent_pid 2>/dev/null | tr -d ' ')
    echo "Depth $depth: PID $parent_pid = $proc_name" | tee -a "$MONITOR_LOG"
    
    if [[ "$proc_name" =~ ^(konsole|gnome-terminal|xterm|alacritty|kitty)$ ]]; then
        TERMINAL_PID=$parent_pid
        echo "Found terminal: $proc_name (PID: $TERMINAL_PID)" | tee -a "$MONITOR_LOG"
        break
    fi
    
    current_pid=$parent_pid
    ((depth++))
done
echo "" | tee -a "$MONITOR_LOG"

# Test instant monitoring
echo "--- Testing INSTANT monitoring with tail --pid ---" | tee -a "$MONITOR_LOG"
echo "Terminal PID to monitor: $TERMINAL_PID" | tee -a "$MONITOR_LOG"
echo "Starting 5-second test..." | tee -a "$MONITOR_LOG"

if command -v timeout >/dev/null 2>&1; then
    # Test for 5 seconds
    timeout 5 tail --pid="$TERMINAL_PID" -f /dev/null 2>&1 | tee -a "$MONITOR_LOG" &
    wait $!
    exit_code=$?
    
    if [[ $exit_code -eq 124 ]]; then
        echo "Test timed out (terminal still running) - GOOD" | tee -a "$MONITOR_LOG"
    elif [[ $exit_code -eq 0 ]]; then
        echo "Terminal exited during test!" | tee -a "$MONITOR_LOG"
    else
        echo "tail --pid failed with exit code: $exit_code" | tee -a "$MONITOR_LOG"
    fi
else
    echo "timeout command not found, skipping tail test" | tee -a "$MONITOR_LOG"
fi

echo "" | tee -a "$MONITOR_LOG"
echo "=== Test Complete ===" | tee -a "$MONITOR_LOG"
echo "Log saved to: $MONITOR_LOG"
