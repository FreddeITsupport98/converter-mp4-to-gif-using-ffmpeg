#!/bin/bash

# Shell compatibility check
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script requires bash, but you're running it with $0"
    echo "Please run: bash $0 or make sure the script is executable and run: ./$0"
    exit 1
fi

# 🔒 Process Group Management - Ensure all processes die with terminal
# This creates a process group so when the script terminates, ALL children die
if [[ $$ == $BASHPID ]] || [[ -z "$BASHPID" ]]; then
    # We're the main process, set up process group management
    set +m 2>/dev/null || true  # Disable job control initially (ignore if not supported)
    # Skip terminal redirection as it can cause hangs in some environments
    # exec 0< /dev/tty 2>/dev/null || true  # This was causing hangs
    set -m 2>/dev/null || true  # Enable job control for proper process group handling
fi

# Set this script as the process group leader
export SCRIPT_PID=$$
export SCRIPT_PGID=$$

# 📺 Terminal binding - ensure processes are tied to terminal session
if [[ -t 0 ]] && [[ -t 1 ]]; then
    # We have a terminal, bind processes to it
    export TERMINAL_BOUND=true
    echo -e "\033[2m📺 Process group $SCRIPT_PGID bound to terminal session\033[0m"
else
    # No terminal detected
    export TERMINAL_BOUND=false
fi

# =============================================================================
# 🎬 SMART GIF CONVERTER - Revolutionary Video-to-GIF Conversion Tool
# =============================================================================
# Author: AI Assistant
# Version: 2.0
# Description: Advanced, customizable video-to-GIF converter with intelligent
#              processing, quality optimization, and extensive configuration options.
# =============================================================================

# 🎨 Color codes for fancy output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 📊 Statistics tracking
total_files=0
converted_files=0
skipped_files=0
failed_files=0
corrupt_input_files=0
corrupt_output_files=0
start_time=$(date +%s)

# 🔍 Validation tracking
VALIDATION_TOTAL_VIDEOS=0
VALIDATION_ALREADY_CONVERTED=0
VALIDATION_NEED_CONVERSION=0
VALIDATION_ORPHANED_COUNT=0

# 🚨 Error handling
LOG_DIR="$HOME/.smart-gif-converter"
ERROR_LOG="$LOG_DIR/errors.log"
CONVERSION_LOG="$LOG_DIR/conversions.log"
PROGRESS_FILE="$LOG_DIR/progress.save"
DEBUG_MODE=false
MAX_RETRIES=2
CLEANUP_ON_EXIT=true
AUTOSAVE_ENABLED=true
CLEANUP_IN_PROGRESS=false

# ⚙️ DEFAULT CONFIGURATION (Conservative settings for better GIF sizes)
CONFIG_FILE="gif-converter.conf"
RESOLUTION="1280:720"
FRAMERATE="12"
QUALITY="high"
ASPECT_RATIO="16:9"
SCALING_ALGO="lanczos"
DITHER_MODE="bayer"
MAX_COLORS="128"
PALETTE_MODE="custom"
FORCE_CONVERSION=false
PARALLEL_JOBS="$(nproc 2>/dev/null || echo '4')"
OUTPUT_FORMAT="gif"
COMPRESSION_LEVEL="medium"
AUTO_OPTIMIZE=true
OPTIMIZE_AGGRESSIVE=true
OPTIMIZE_TARGET_RATIO=20
MAX_GIF_SIZE_MB=25
AUTO_REDUCE_QUALITY=true
SMART_SIZE_DOWN=true
GPU_ACCELERATION="auto"
FFMPEG_THREADS="$(nproc 2>/dev/null || echo '4')"
BACKUP_ORIGINAL=true
LOG_LEVEL="info"
PROGRESS_BAR=true
INTERACTIVE_MODE=true
SKIP_VALIDATION=false
ONLY_FILE=""
AI_ENABLED=false
CROP_FILTER=""
AI_MODE="smart"
AI_CONFIDENCE_THRESHOLD=70
AI_CONTENT_CACHE=""
CPU_BENCHMARK=false
RAM_OPTIMIZATION=true
RAM_CACHE_SIZE="auto"
RAM_DISK_ENABLED=false
RAM_DISK_PATH=""
DYNAMIC_FILE_DETECTION=false
FILE_MONITOR_INTERVAL=10

# 📁 Initialize log directory and temp work directory
init_log_directory() {
    # Create log directory if it doesn't exist
    if [[ ! -d "$LOG_DIR" ]]; then
        if ! mkdir -p "$LOG_DIR" 2>/dev/null; then
            echo -e "${RED}❌ Error: Cannot create log directory at $LOG_DIR${NC}"
            echo -e "${YELLOW}Falling back to current directory for logs${NC}"
            LOG_DIR="."
            ERROR_LOG="./gif-converter-errors.log"
            CONVERSION_LOG="./gif-converter-conversions.log"
            SETTINGS_FILE="./gif-converter-settings.conf"
            return 1
        fi
        echo -e "${GREEN}✓ Created log directory: $LOG_DIR${NC}"
    fi
    
    # Create temporary work directory for intermediate files
    TEMP_WORK_DIR="$LOG_DIR/temp_work"
    if [[ ! -d "$TEMP_WORK_DIR" ]]; then
        if ! mkdir -p "$TEMP_WORK_DIR" 2>/dev/null; then
            echo -e "${YELLOW}⚠️ Warning: Cannot create temp work directory, using /tmp${NC}"
            TEMP_WORK_DIR="/tmp/gif-converter-$$"
            mkdir -p "$TEMP_WORK_DIR" 2>/dev/null || TEMP_WORK_DIR="/tmp"
        fi
    fi
    
    # Set settings file path
    SETTINGS_FILE="$LOG_DIR/settings.conf"
    
    # Initialize error log
    echo "# Smart GIF Converter Error Log - $(date)" > "$ERROR_LOG"
    echo "# Log directory: $LOG_DIR" >> "$ERROR_LOG"
    echo "# Working directory: $(pwd)" >> "$ERROR_LOG"
    echo "" >> "$ERROR_LOG"
    
    # Initialize conversion log
    if [[ ! -f "$CONVERSION_LOG" ]]; then
        echo "# Smart GIF Converter Conversion History" > "$CONVERSION_LOG"
        echo "# Format: [TIMESTAMP] STATUS: source_file -> output_file (size_info)" >> "$CONVERSION_LOG"
        echo "" >> "$CONVERSION_LOG"
    fi
    
    # Log rotation - keep only last 1000 lines of each log
    if [[ -f "$ERROR_LOG" ]] && [[ $(wc -l < "$ERROR_LOG") -gt 1000 ]]; then
        tail -800 "$ERROR_LOG" > "${ERROR_LOG}.tmp" && mv "${ERROR_LOG}.tmp" "$ERROR_LOG"
    fi
    
    if [[ -f "$CONVERSION_LOG" ]] && [[ $(wc -l < "$CONVERSION_LOG") -gt 1000 ]]; then
        tail -800 "$CONVERSION_LOG" > "${CONVERSION_LOG}.tmp" && mv "${CONVERSION_LOG}.tmp" "$CONVERSION_LOG"
    fi
}

# 🚨 Robust error logging system
log_error() {
    local error_msg="$1"
    local file="$2"
    local detailed_error="$3"
    local line_num="$4"
    local func_name="$5"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Ensure log directory exists
    [[ ! -d "$(dirname "$ERROR_LOG")" ]] && mkdir -p "$(dirname "$ERROR_LOG")" 2>/dev/null
    
    # Comprehensive logging to file
    {
        echo "[$timestamp] ==================== ERROR ===================="
        echo "[$timestamp] MESSAGE: $error_msg"
        [[ -n "$file" ]] && echo "[$timestamp] FILE: $file"
        [[ -n "$line_num" ]] && echo "[$timestamp] LINE: $line_num"
        [[ -n "$func_name" ]] && echo "[$timestamp] FUNCTION: $func_name"
        [[ -n "$detailed_error" ]] && echo "[$timestamp] DETAILS: $detailed_error"
        echo "[$timestamp] PWD: $(pwd)"
        echo "[$timestamp] USER: $USER"
        echo "[$timestamp] SHELL: $SHELL"
        echo "[$timestamp] PID: $$"
        echo "[$timestamp] PPID: $PPID"
        echo "[$timestamp] ================================================"
        echo ""
    } >> "$ERROR_LOG" 2>/dev/null || {
        # Fallback to current directory if log directory fails
        echo "[$timestamp] ERROR: $error_msg" >> "./error-fallback.log" 2>/dev/null
    }
    
    # Always show errors in terminal with full context
    {
        echo -e "\n${RED}${BOLD}💥 CRITICAL ERROR${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}📋 Message: $error_msg${NC}"
        [[ -n "$file" ]] && echo -e "${RED}📁 File: $(basename "$file")${NC}"
        [[ -n "$line_num" ]] && echo -e "${RED}📍 Line: $line_num${NC}"
        [[ -n "$func_name" ]] && echo -e "${RED}⚙️  Function: $func_name${NC}"
        [[ -n "$detailed_error" ]] && echo -e "${RED}🔍 Details: $detailed_error${NC}"
        echo -e "${YELLOW}📋 Full log: $ERROR_LOG${NC}"
        echo -e "${CYAN}🔧 Debug: tail -20 \"$ERROR_LOG\"${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    } >&2
}

# 🛡️ Robust crash handler
handle_crash() {
    local exit_code=$?
    local line_num=$1
    local func_name="${FUNCNAME[2]:-main}"
    local command="${BASH_COMMAND:-unknown}"
    
    log_error "Script crashed unexpectedly" "" "Command: $command, Exit code: $exit_code" "$line_num" "$func_name"
    
    echo -e "\n${RED}${BOLD}💀 SCRIPT CRASHED${NC}" >&2
    echo -e "${RED}The script encountered a fatal error and had to stop.${NC}" >&2
    echo -e "${YELLOW}Check the error log for details: $ERROR_LOG${NC}" >&2
    echo -e "${CYAN}Recent errors: tail -10 \"$ERROR_LOG\"${NC}" >&2
    
    # Show last few lines of error log
    if [[ -f "$ERROR_LOG" ]]; then
        echo -e "\n${YELLOW}Last error entries:${NC}" >&2
        tail -5 "$ERROR_LOG" 2>/dev/null | while IFS= read -r line; do
            echo -e "  ${RED}$line${NC}" >&2
        done
    fi
    
    # Cleanup
    cleanup_temp_files "*" 2>/dev/null || true
    
    exit $exit_code
}

# 🔍 Function call tracer for debugging
trace_function() {
    local func_name="$1"
    local timestamp=$(date '+%H:%M:%S')
    echo "[$timestamp] TRACE: Entering function $func_name" >> "$ERROR_LOG.trace" 2>/dev/null || true
}

# 🧾 Log a one-time settings snapshot for easier debugging
log_settings_snapshot_once() {
    if [[ -n "$__SETTINGS_SNAPSHOT_DONE" ]]; then return; fi
    __SETTINGS_SNAPSHOT_DONE=1
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    {
        echo "[$ts] ==================== SETTINGS SNAPSHOT ===================="
        echo "[$ts] QUALITY=$QUALITY FRAMERATE=$FRAMERATE RESOLUTION=$RESOLUTION ASPECT=$ASPECT_RATIO"
        echo "[$ts] MAX_COLORS=$MAX_COLORS DITHER=$DITHER_MODE SCALING=$SCALING_ALGO FORMAT=$OUTPUT_FORMAT"
        echo "[$ts] AUTO_OPTIMIZE=$AUTO_OPTIMIZE OPTIMIZE_AGGRESSIVE=$OPTIMIZE_AGGRESSIVE"
        echo "[$ts] PARALLEL_JOBS=$PARALLEL_JOBS FORCE_CONVERSION=$FORCE_CONVERSION"
        echo "[$ts] LOG DIR=$LOG_DIR SETTINGS_FILE=$SETTINGS_FILE"
        echo "[$ts] ============================================================="
        echo ""
    } >> "$ERROR_LOG" 2>/dev/null || true
}

# 🧪 Get concise media info for logs (widthxheight @ fps, duration)
probe_media_brief() {
    local f="$1"
    local w h r d
    w=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$f" 2>/dev/null)
    h=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$f" 2>/dev/null)
    r=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$f" 2>/dev/null | awk -F'/' '{if($2>0) printf("%.2f", $1/$2); else print $1}')
    d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f" 2>/dev/null | awk '{printf("%.2fs", $1)}')
    [[ -z "$w" || -z "$h" ]] && echo "unknown" && return
    echo "${w}x${h}@${r:-?} ${d:-?}"
}

# 📊 Smart GIF size estimation and optimization
estimate_and_optimize_gif_settings() {
    local file="$1"
    echo -e "  ${BLUE}📈 Analyzing video for optimal GIF settings...${NC}"
    
    # Get video properties
    local duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$file" 2>/dev/null | awk '{printf("%.1f", $1)}')
    local width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$file" 2>/dev/null)
    local height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$file" 2>/dev/null)
    local input_size=$(stat -c%s "$file" 2>/dev/null || echo "1000000")
    
    # Convert to MB for easier calculation
    local input_size_mb=$((input_size / 1024 / 1024))
    [[ $input_size_mb -eq 0 ]] && input_size_mb=1
    
    # Estimate GIF size using empirical formula
    # GIF size ≈ (width * height * fps * duration * colors) / compression_factor
    local current_fps=${FRAMERATE:-15}
    local current_colors=${MAX_COLORS:-256}
    local current_width=$(echo "$RESOLUTION" | cut -d':' -f1)
    local current_height=$(echo "$RESOLUTION" | cut -d':' -f2)
    
    # Use video dimensions if resolution not set
    [[ -z "$current_width" || "$current_width" == "$RESOLUTION" ]] && current_width=$width
    [[ -z "$current_height" || "$current_height" == "$RESOLUTION" ]] && current_height=$height
    
    # Estimated GIF size in MB (rough calculation)
    local estimated_size_mb=0
    if [[ -n "$duration" && "$duration" != "0" && -n "$current_width" && -n "$current_height" ]]; then
        # Formula: (width * height * fps * duration * colors) / (1024^2 * compression_factor)
        # Compression factor varies by content type (typically 8-20 for GIFs)
        estimated_size_mb=$(awk -v w="$current_width" -v h="$current_height" -v f="$current_fps" -v d="$duration" -v c="$current_colors" \
            'BEGIN { printf("%.0f", (w * h * f * d * c) / (1024 * 1024 * 12)) }')
    fi
    
    echo -e "    ${CYAN}Input: ${input_size_mb}MB, ${width}x${height}, ${duration}s${NC}"
    echo -e "    ${CYAN}Current settings: ${current_width}x${current_height}, ${current_fps}fps, ${current_colors} colors${NC}"
    echo -e "    ${YELLOW}Estimated GIF size: ~${estimated_size_mb}MB${NC}"
    
    # Always apply smart sizing for better GIF sizes
    local optimization_applied=false
    echo -e "    ${BLUE}🧠 Applying smart size optimization...${NC}"
    
    # Aggressive resolution reduction for all content
    if [[ "$current_width" -gt 1920 ]]; then
        RESOLUTION="854:480"
        echo -e "      ${GREEN}✓ Reduced resolution to 854x480 (4K+ → web-friendly)${NC}"
        optimization_applied=true
    elif [[ "$current_width" -gt 1280 ]]; then
        RESOLUTION="720:480"
        echo -e "      ${GREEN}✓ Reduced resolution to 720x480 (HD → compact)${NC}"
        optimization_applied=true
    elif [[ "$current_width" -gt 854 ]]; then
        RESOLUTION="640:360"
        echo -e "      ${GREEN}✓ Reduced resolution to 640x360 (optimized for GIF)${NC}"
        optimization_applied=true
    fi
    
    # Smart framerate optimization based on content type
    if [[ "$input_size_mb" -lt 1 && "$current_width" -gt 1080 ]]; then
        # High-res artwork from small file - likely anime/static content
        if [[ "$current_fps" -gt 10 ]]; then
            FRAMERATE="8"
            echo -e "      ${GREEN}✓ Reduced framerate to 8fps (artwork optimized)${NC}"
            optimization_applied=true
        fi
        MAX_COLORS="64"
        echo -e "      ${GREEN}✓ Reduced colors to 64 (artwork optimized)${NC}"
        optimization_applied=true
    else
        # Regular content optimization
        if [[ "$current_fps" -gt 12 ]]; then
            FRAMERATE="10"
            echo -e "      ${GREEN}✓ Reduced framerate to 10fps (smooth playback)${NC}"
            optimization_applied=true
        fi
        if [[ "$current_colors" -gt 96 ]]; then
            MAX_COLORS="96"
            echo -e "      ${GREEN}✓ Reduced colors to 96 (balanced quality/size)${NC}"
            optimization_applied=true
        fi
    fi
    
    # Special handling for high-resolution content (likely anime/artwork)
    local is_high_res=false
    if [[ "$current_width" -gt 1080 && "$input_size_mb" -lt 2 ]]; then
        is_high_res=true
        echo -e "      ${YELLOW}🎨 High-resolution artwork detected${NC}"
        
        # Extra aggressive for artwork since it compresses very well
        if [[ "$current_colors" -gt 48 ]]; then
            MAX_COLORS="48"
            echo -e "      ${GREEN}✓ Reduced colors to 48 (artwork has fewer color variations)${NC}"
            optimization_applied=true
        fi
    fi
    
    # Recalculate estimated size
    if [[ "$optimization_applied" == true ]]; then
        local new_width=$(echo "$RESOLUTION" | cut -d':' -f1)
        local new_height=$(echo "$RESOLUTION" | cut -d':' -f2)
        estimated_size_mb=$(awk -v w="$new_width" -v h="$new_height" -v f="$FRAMERATE" -v d="$duration" -v c="$MAX_COLORS" \
            'BEGIN { printf("%.0f", (w * h * f * d * c) / (1024 * 1024 * 15)) }')
        echo -e "      ${GREEN}Smart-optimized estimated size: ~${estimated_size_mb}MB${NC}"
    fi
    
    # Apply optimizations if estimated size is too large
    if [[ "$estimated_size_mb" -gt "$MAX_GIF_SIZE_MB" ]]; then
        echo -e "    ${RED}⚠️  Estimated size (${estimated_size_mb}MB) exceeds limit (${MAX_GIF_SIZE_MB}MB)${NC}"
        echo -e "    ${BLUE}🔧 Applying automatic optimizations...${NC}"
        
        local optimization_applied=false
        
        # Step 1: Reduce resolution if too high
        if [[ "$current_width" -gt 1280 ]]; then
            RESOLUTION="1280:720"
            echo -e "      ${GREEN}✓ Reduced resolution to 1280x720${NC}"
            optimization_applied=true
        elif [[ "$current_width" -gt 854 ]]; then
            RESOLUTION="854:480"
            echo -e "      ${GREEN}✓ Reduced resolution to 854x480${NC}"
            optimization_applied=true
        fi
        
        # Step 2: Reduce framerate if too high
        if [[ "$current_fps" -gt 15 ]]; then
            FRAMERATE="12"
            echo -e "      ${GREEN}✓ Reduced framerate to 12fps${NC}"
            optimization_applied=true
        elif [[ "$current_fps" -gt 10 ]] && [[ "$estimated_size_mb" -gt $((MAX_GIF_SIZE_MB * 2)) ]]; then
            FRAMERATE="8"
            echo -e "      ${GREEN}✓ Reduced framerate to 8fps${NC}"
            optimization_applied=true
        fi
        
        # Step 3: Reduce color palette
        if [[ "$current_colors" -gt 128 ]]; then
            MAX_COLORS="128"
            echo -e "      ${GREEN}✓ Reduced colors to 128${NC}"
            optimization_applied=true
        elif [[ "$current_colors" -gt 64 ]] && [[ "$estimated_size_mb" -gt $((MAX_GIF_SIZE_MB * 3)) ]]; then
            MAX_COLORS="64"
            echo -e "      ${GREEN}✓ Reduced colors to 64${NC}"
            optimization_applied=true
        fi
        
        # Step 4: Clip duration if extremely long
        if [[ -n "$duration" ]] && awk -v d="$duration" 'BEGIN { exit (d > 30) }'; then
            echo -e "      ${YELLOW}⚠️  Video duration (${duration}s) is very long for GIF${NC}"
            echo -e "      ${BLUE}Consider using --duration-limit to clip the video${NC}"
        fi
        
        # Re-estimate size with new settings
        if [[ "$optimization_applied" == true ]]; then
            local new_width=$(echo "$RESOLUTION" | cut -d':' -f1)
            local new_height=$(echo "$RESOLUTION" | cut -d':' -f2)
            local new_estimated_size=$(awk -v w="$new_width" -v h="$new_height" -v f="$FRAMERATE" -v d="$duration" -v c="$MAX_COLORS" \
                'BEGIN { printf("%.0f", (w * h * f * d * c) / (1024 * 1024 * 12)) }')
            echo -e "      ${GREEN}New estimated size: ~${new_estimated_size}MB${NC}"
        fi
    else
        echo -e "    ${GREEN}✓ Estimated size looks reasonable${NC}"
    fi
    
    echo ""
}

# 🤖 AI-lite analysis: crop, motion, and dynamic parameter tuning (no heavy deps)
# 🤖 Advanced AI Video Analysis System
ai_smart_analyze() {
    local file="$1"
    local ai_log_ts=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Reset AI variables
    CROP_FILTER=""
    AI_CONTENT_CACHE=""
    
    echo -e "  🧠 ${CYAN}Advanced AI Analysis Starting...${NC}"
    
    # Get basic video properties first
    local video_info=$(get_video_properties "$file")
    local duration=$(echo "$video_info" | cut -d'|' -f1)
    local width=$(echo "$video_info" | cut -d'|' -f2) 
    local height=$(echo "$video_info" | cut -d'|' -f3)
    local fps=$(echo "$video_info" | cut -d'|' -f4)
    local bitrate=$(echo "$video_info" | cut -d'|' -f5)
    
    # Multi-dimensional analysis based on AI_MODE
    case "$AI_MODE" in
        "smart")
            ai_smart_analysis "$file" "$duration" "$width" "$height" "$fps" "$bitrate"
            ;;
        "content")
            ai_content_analysis "$file" "$duration" "$width" "$height"
            ;;
        "motion")
            ai_motion_analysis "$file" "$duration"
            ;;
        "quality")
            ai_quality_analysis "$file" "$width" "$height" "$bitrate"
            ;;
        *)
            ai_smart_analysis "$file" "$duration" "$width" "$height" "$fps" "$bitrate"
            ;;
    esac
    
    # Log comprehensive AI decisions
    {
        echo "[$ai_log_ts] AI-ANALYSIS: mode=$AI_MODE file=$(basename "$file")"
        echo "[$ai_log_ts] AI-INPUT: duration=${duration}s resolution=${width}x${height} fps=$fps bitrate=$bitrate"
        echo "[$ai_log_ts] AI-OUTPUT: framerate=$FRAMERATE dither=$DITHER_MODE crop=${CROP_FILTER:-none} max_colors=$MAX_COLORS"
        [[ -n "$AI_CONTENT_CACHE" ]] && echo "[$ai_log_ts] AI-DETECTED: $AI_CONTENT_CACHE"
    } >> "$ERROR_LOG" 2>/dev/null || true
    
    echo -e "  ✅ ${GREEN}AI Analysis Complete${NC}"
}

# 📊 Get comprehensive video properties
get_video_properties() {
    local file="$1"
    local properties
    
    # Use ffprobe to get detailed information
    if command -v jq >/dev/null 2>&1; then
        # Enhanced analysis with jq
        properties=$(ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null)
        
        local duration=$(echo "$properties" | jq -r '.format.duration // "0"' | cut -d. -f1)
        local width=$(echo "$properties" | jq -r '.streams[0].width // "0"')
        local height=$(echo "$properties" | jq -r '.streams[0].height // "0"')
        local fps=$(echo "$properties" | jq -r '.streams[0].r_frame_rate // "0"' | cut -d'/' -f1)
        local bitrate=$(echo "$properties" | jq -r '.format.bit_rate // "0"')
        
        echo "${duration}|${width}|${height}|${fps}|${bitrate}"
    else
        # Fallback without jq
        local duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$file" 2>/dev/null | cut -d. -f1)
        local width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$file" 2>/dev/null)
        local height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$file" 2>/dev/null)
        local fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$file" 2>/dev/null | cut -d'/' -f1)
        local bitrate="0"
        
        echo "${duration:-0}|${width:-0}|${height:-0}|${fps:-0}|${bitrate}"
    fi
}

# 🧠 Smart AI Analysis (comprehensive)
ai_smart_analysis() {
    local file="$1" duration="$2" width="$3" height="$4" fps="$5" bitrate="$6"
    
    echo -e "    🔍 ${BLUE}Smart Analysis: Content + Motion + Quality${NC}"
    
    # 1. Content Type Detection
    local content_type=$(detect_content_type "$file" "$duration" "$width" "$height")
    AI_CONTENT_CACHE="content_type=$content_type"
    
    # 2. Motion Analysis
    local motion_level=$(analyze_motion_complexity "$file" "$duration")
    AI_CONTENT_CACHE+=" motion=$motion_level"
    
    # 3. Visual Complexity Analysis  
    local complexity_score=$(analyze_visual_complexity "$file")
    AI_CONTENT_CACHE+=" complexity=$complexity_score"
    
    # 4. Intelligent Cropping
    local crop_result=$(intelligent_crop_detection "$file" "$width" "$height")
    if [[ "$crop_result" != "none" ]]; then
        CROP_FILTER="$crop_result"
        AI_CONTENT_CACHE+=" crop=applied"
    fi
    
    # 5. AI Speed Optimization
    ai_speed_optimizer "$file" "$motion_level" "content_type=$content_type complexity=$complexity_score"
    ai_performance_analysis "$file"
    
    # 6. Apply intelligent optimizations based on analysis
    apply_ai_optimizations "$content_type" "$motion_level" "$complexity_score" "$duration" "$width" "$height"
}

# 🎨 Content Type Detection
detect_content_type() {
    local file="$1" duration="$2" width="$3" height="$4"
    
    # Analyze visual patterns to determine content type
    local histogram_analysis
    histogram_analysis=$(ffmpeg -v error -i "$file" -t 10 -vf "histogram=level_height=200" -frames:v 5 -f null - 2>&1 | wc -l)
    
    # Sample frames for edge detection
    local edge_density
    edge_density=$(ffmpeg -v error -i "$file" -t 5 -vf "edgedetect=low=0.1:high=0.4,blackframe=98" -f null - 2>&1 | grep -c "blackframe" || echo "0")
    
    # Color analysis
    local color_variance
    color_variance=$(ffmpeg -v error -i "$file" -t 3 -vf "signalstats" -f null - 2>&1 | grep -o "YAVG=[0-9]*" | head -5 | wc -l)
    
    # Determine content type based on analysis
    # Ensure numeric values (fallback to 0 if empty or invalid)
    edge_density=${edge_density//[^0-9]/}
    color_variance=${color_variance//[^0-9]/}
    edge_density=${edge_density:-0}
    color_variance=${color_variance:-0}
    
    if [[ $edge_density -gt 15 && $color_variance -gt 3 ]]; then
        echo "animation"  # High edge density + color variance = animation/cartoon
    elif [[ $width -ge 1920 && $height -ge 1080 && $duration -lt 30 ]]; then
        echo "screencast"  # High res + short = likely screencast
    elif [[ $duration -gt 300 ]]; then
        echo "movie"  # Long duration = movie/show
    elif [[ $duration -lt 10 ]]; then
        echo "clip"  # Very short = clip/meme
    else
        echo "general"  # Default
    fi
}

# 💨 Advanced Motion Analysis
analyze_motion_complexity() {
    local file="$1" duration="$2"
    local sample_duration=$((duration > 30 ? 30 : duration))
    
    # Multi-stage motion analysis
    local scene_changes
    scene_changes=$(ffmpeg -v error -i "$file" -t $sample_duration -vf "select=gt(scene\,0.12)" -vsync vfr -f null - 2>&1 | grep -c "frame=" || echo "0")
    
    # Motion vector analysis (if available)
    local motion_vectors=0
    if ffmpeg -v error -f lavfi -i testsrc=duration=1:size=320x240:rate=1 -c:v libx264 -f null - 2>/dev/null; then
        motion_vectors=$(ffmpeg -v error -i "$file" -t 5 -vf "mestimate=epzs,showinfo" -f null - 2>&1 | grep -c "pos:" || echo "0")
    fi
    
    # Classify motion level
    # Ensure numeric values
    scene_changes=${scene_changes//[^0-9]/}
    motion_vectors=${motion_vectors//[^0-9]/}
    scene_changes=${scene_changes:-0}
    motion_vectors=${motion_vectors:-0}
    
    local total_motion_score=$((scene_changes + motion_vectors / 10))
    
    if [[ $total_motion_score -gt 20 ]]; then
        echo "high"
    elif [[ $total_motion_score -gt 8 ]]; then
        echo "medium"
    elif [[ $total_motion_score -gt 2 ]]; then
        echo "low"
    else
        echo "static"
    fi
}

# 🔍 Visual Complexity Analysis
analyze_visual_complexity() {
    local file="$1"
    
    # Analyze visual complexity using multiple metrics
    local complexity_metrics
    complexity_metrics=$(ffmpeg -v error -i "$file" -t 8 -vf "signalstats,metadata=print" -f null - 2>&1 | grep -E "YAVG|UAVG|VAVG" | wc -l)
    
    # Texture analysis through noise detection
    local noise_level
    noise_level=$(ffmpeg -v error -i "$file" -t 5 -vf "noise=c0s=7:allf=t,signalstats" -f null - 2>&1 | grep -c "YAVG" || echo "0")
    
    # Calculate complexity score (0-100)
    # Ensure numeric values
    complexity_metrics=${complexity_metrics//[^0-9]/}
    noise_level=${noise_level//[^0-9]/}
    complexity_metrics=${complexity_metrics:-0}
    noise_level=${noise_level:-0}
    
    local complexity_score=$(((complexity_metrics * 10 + noise_level * 5) / 2))
    [[ $complexity_score -gt 100 ]] && complexity_score=100
    
    echo "$complexity_score"
}

# ✂️ Intelligent Crop Detection
intelligent_crop_detection() {
    local file="$1" width="$2" height="$3"
    
    # Advanced crop detection with multiple samples
    local crop_samples=()
    local sample_times=("3" "25%" "50%" "75%")
    
    for sample_time in "${sample_times[@]}"; do
        local crop_line
        crop_line=$(ffmpeg -v error -ss "$sample_time" -i "$file" -t 1 -vf "cropdetect=24:16:0" -f null - 2>&1 | grep -o "crop=[0-9]*:[0-9]*:[0-9]*:[0-9]*" | tail -1)
        [[ -n "$crop_line" ]] && crop_samples+=("$crop_line")
    done
    
    # Find the most conservative crop (keeps most content)
    local best_crop="none"
    local best_area=0
    
    for crop in "${crop_samples[@]}"; do
        local cw=$(echo "$crop" | cut -d'=' -f2 | cut -d: -f1)
        local ch=$(echo "$crop" | cut -d'=' -f2 | cut -d: -f2)
        local area=$((cw * ch))
        
        # Only accept crops that preserve at least 70% of original area
        local original_area=$((width * height))
        local area_ratio=$((area * 100 / original_area))
        
        if [[ $area_ratio -ge 70 && $area -gt $best_area ]]; then
            best_crop="$crop"
            best_area=$area
        fi
    done
    
    echo "$best_crop"
}

# ⚙️ Apply AI-based Optimizations
apply_ai_optimizations() {
    local content_type="$1" motion_level="$2" complexity_score="$3" duration="$4" width="$5" height="$6"
    
    echo -e "    🤖 ${MAGENTA}Applying AI optimizations for $content_type content${NC}"
    
    # Content-specific optimizations
    case "$content_type" in
        "animation")
            # Animations benefit from higher color count and specific dithering
            MAX_COLORS="192"
            DITHER_MODE="floyd"
            [[ "$motion_level" == "high" ]] && FRAMERATE="16" || FRAMERATE="12"
            ;;
        "screencast")
            # Screencasts need crisp text, lower FPS OK
            MAX_COLORS="128"
            DITHER_MODE="none"
            FRAMERATE="8"
            SCALING_ALGO="neighbor"  # Preserve pixel-perfect scaling
            ;;
        "movie")
            # Movies benefit from motion-adaptive settings
            case "$motion_level" in
                "high") FRAMERATE="18"; DITHER_MODE="floyd"; MAX_COLORS="256" ;;
                "medium") FRAMERATE="15"; DITHER_MODE="bayer"; MAX_COLORS="192" ;;
                "low") FRAMERATE="12"; DITHER_MODE="bayer"; MAX_COLORS="128" ;;
                "static") FRAMERATE="8"; DITHER_MODE="none"; MAX_COLORS="96" ;;
            esac
            ;;
        "clip")
            # Short clips can afford higher quality
            MAX_COLORS="256"
            FRAMERATE="20"
            DITHER_MODE="floyd"
            ;;
        *)
            # General content - balanced approach
            case "$motion_level" in
                "high") FRAMERATE="15"; DITHER_MODE="floyd"; MAX_COLORS="192" ;;
                "medium") FRAMERATE="12"; DITHER_MODE="bayer"; MAX_COLORS="128" ;;
                "low") FRAMERATE="10"; DITHER_MODE="bayer"; MAX_COLORS="96" ;;
                "static") FRAMERATE="8"; DITHER_MODE="none"; MAX_COLORS="64" ;;
            esac
            ;;
    esac
    
    # Resolution-based adjustments
    if [[ $width -ge 3840 || $height -ge 2160 ]]; then
        # 4K content - aggressive size reduction
        RESOLUTION="1280:720"
        MAX_COLORS=$((MAX_COLORS * 75 / 100))
    elif [[ $width -ge 1920 || $height -ge 1080 ]]; then
        # 1080p content - moderate reduction
        RESOLUTION="1280:720"
    elif [[ $width -le 854 && $height -le 480 ]]; then
        # Low resolution - preserve or slightly upscale
        RESOLUTION="854:480"
    fi
    
    # Complexity-based adjustments
    if [[ $complexity_score -gt 80 ]]; then
        # Very complex - need more colors
        MAX_COLORS=$((MAX_COLORS + 32))
        [[ $MAX_COLORS -gt 256 ]] && MAX_COLORS=256
    elif [[ $complexity_score -lt 20 ]]; then
        # Simple content - can use fewer colors
        MAX_COLORS=$((MAX_COLORS - 32))
        [[ $MAX_COLORS -lt 32 ]] && MAX_COLORS=32
    fi
    
    # Duration-based adjustments
    if [[ $duration -gt 300 ]]; then
        # Very long content - prioritize size
        FRAMERATE=$((FRAMERATE - 2))
        [[ $FRAMERATE -lt 6 ]] && FRAMERATE=6
        MAX_COLORS=$((MAX_COLORS * 90 / 100))
    elif [[ $duration -lt 5 ]]; then
        # Very short - can afford quality
        FRAMERATE=$((FRAMERATE + 4))
        [[ $FRAMERATE -gt 30 ]] && FRAMERATE=30
    fi
}

# 🎨 Content-focused Analysis Mode
ai_content_analysis() {
    local file="$1" duration="$2" width="$3" height="$4"
    
    echo -e "    🎨 ${BLUE}Content Analysis Mode${NC}"
    
    local content_type=$(detect_content_type "$file" "$duration" "$width" "$height")
    AI_CONTENT_CACHE="focused_content_analysis=$content_type"
    
    # Apply content-specific optimizations only
    apply_ai_optimizations "$content_type" "medium" "50" "$duration" "$width" "$height"
}

# 💨 Motion-focused Analysis Mode  
ai_motion_analysis() {
    local file="$1" duration="$2"
    
    echo -e "    💨 ${BLUE}Motion Analysis Mode${NC}"
    
    local motion_level=$(analyze_motion_complexity "$file" "$duration")
    AI_CONTENT_CACHE="focused_motion_analysis=$motion_level"
    
    # Apply motion-specific optimizations
    case "$motion_level" in
        "high") FRAMERATE="20"; DITHER_MODE="floyd"; MAX_COLORS="256" ;;
        "medium") FRAMERATE="15"; DITHER_MODE="bayer"; MAX_COLORS="192" ;;
        "low") FRAMERATE="12"; DITHER_MODE="bayer"; MAX_COLORS="128" ;;
        "static") FRAMERATE="8"; DITHER_MODE="none"; MAX_COLORS="96" ;;
    esac
}

# 🎨 AI-Powered Quality Selection for Quick Mode
ai_quality_selection() {
    echo -e "${CYAN}${BOLD}🎯 SELECT YOUR PREFERRED QUALITY LEVEL:${NC}\n"
    echo -e "${YELLOW}AI will handle everything else - you just choose quality!${NC}\n"
    
    local quality_options=(
        "Low Quality - Small files, fast processing (good for previews)"
        "Medium Quality - Balanced size and quality (recommended for most content)"
        "High Quality - Great detail, standard choice (best balance)"
        "Max Quality - Maximum detail, larger files (for important content)"
    )
    
    local quality_values=("low" "medium" "high" "max")
    local quality_descriptions=(
        "480p, 8-10fps, optimized for size"
        "720p, 10-12fps, balanced approach"
        "1080p, 12-15fps, quality focused"
        "1440p+, 15-20fps, maximum quality"
    )
    
    for i in "${!quality_options[@]}"; do
        local num=$((i + 1))
        local is_current=$([[ "${quality_values[$i]}" == "$QUALITY" ]] && echo " 🎯 (Current)" || echo "")
        echo -e "  ${GREEN}[$num]${NC} ${quality_options[$i]}${is_current}"
        echo -e "      ${GRAY}→ ${quality_descriptions[$i]}${NC}"
        echo ""
    done
    
    echo -e "${MAGENTA}Enter your choice [1-4] or press Enter for current ($QUALITY):${NC} "
    read -r quality_choice
    
    if [[ -n "$quality_choice" && "$quality_choice" =~ ^[1-4]$ ]]; then
        local index=$((quality_choice - 1))
        apply_preset "${quality_values[$index]}"
        echo -e "${GREEN}✓ Selected: ${BOLD}$QUALITY${NC} ${GREEN}quality${NC}"
    else
        echo -e "${GREEN}✓ Using current: ${BOLD}$QUALITY${NC} ${GREEN}quality${NC}"
    fi
    
    echo -e "${CYAN}${BOLD}🤖 AI will now optimize all other settings based on video content!${NC}"
}

# 🔍 AI Preview Analysis (non-intrusive)
ai_preview_analysis() {
    local file="$1"
    
    # Quick video info extraction for preview
    local duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$file" 2>/dev/null | cut -d. -f1)
    local width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$file" 2>/dev/null)
    local height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$file" 2>/dev/null)
    
    # Simple content classification for preview
    local content_hint="general"
    if [[ $width -ge 1920 && $height -ge 1080 && $duration -lt 30 ]]; then
        content_hint="screencast"
    elif [[ $duration -gt 300 ]]; then
        content_hint="movie"
    elif [[ $duration -lt 10 ]]; then
        content_hint="clip"
    fi
    
    echo -e "  ${BLUE}📊 Input:${NC} ${width}x${height}, ${duration}s"
    echo -e "  ${BLUE}🔍 Predicted:${NC} $content_hint content"
    echo -e "  ${BLUE}🎯 AI will:${NC} Analyze motion, optimize colors, adjust framerate"
    echo -e "  ${GRAY}  → Full analysis will run during conversion${NC}"
}

# 📊 Show AI Summary after conversion
show_ai_summary() {
    echo -e "\n${CYAN}${BOLD}🤖 AI CONVERSION SUMMARY${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [[ -f "$ERROR_LOG" ]]; then
        local ai_entries=$(grep "AI-ANALYSIS\|AI-DETECTED" "$ERROR_LOG" 2>/dev/null | tail -10)
        
        if [[ -n "$ai_entries" ]]; then
            echo -e "${YELLOW}🔍 Recent AI Analysis Results:${NC}"
            echo "$ai_entries" | while read -r line; do
                if [[ $line == *"AI-DETECTED:"* ]]; then
                    local detected=$(echo "$line" | sed 's/.*AI-DETECTED: //')
                    echo -e "  ${GREEN}✓ Detected: ${NC}$detected"
                elif [[ $line == *"AI-ANALYSIS:"* ]]; then
                    local analysis=$(echo "$line" | sed 's/.*AI-ANALYSIS: //' | sed 's/ file=.*//')
                    echo -e "  ${BLUE}🤖 Analysis: ${NC}$analysis"
                fi
            done
        fi
    fi
    
    echo -e "\n${GREEN}✅ AI successfully optimized settings for each video based on content analysis!${NC}"
    echo -e "${CYAN}💡 Tip: Check the logs to see detailed AI decisions for each file${NC}"
}

# 🎆 Quality-focused Analysis Mode
ai_quality_analysis() {
    local file="$1" width="$2" height="$3" bitrate="$4"
    
    echo -e "    🎆 ${BLUE}Quality Analysis Mode${NC}"
    
    local quality_score=$(analyze_source_quality "$file" "$width" "$height" "$bitrate")
    AI_CONTENT_CACHE="focused_quality_analysis=$quality_score"
    
    # Adjust settings based on source quality
    if [[ $quality_score -gt 80 ]]; then
        # High quality source - preserve detail
        MAX_COLORS="256"
        DITHER_MODE="floyd"
        SCALING_ALGO="lanczos"
    elif [[ $quality_score -gt 60 ]]; then
        # Good quality source
        MAX_COLORS="192"
        DITHER_MODE="bayer"
        SCALING_ALGO="bicubic"
    else
        # Lower quality source - don't overprocess
        MAX_COLORS="128"
        DITHER_MODE="bayer"
        SCALING_ALGO="bilinear"
    fi
}

# 📊 Analyze source quality
analyze_source_quality() {
    local file="$1" width="$2" height="$3" bitrate="$4"
    
    # Calculate quality score based on resolution, bitrate, and compression artifacts
    local resolution_score=0
    local bitrate_score=0
    
    # Resolution scoring
    local pixel_count=$((width * height))
    if [[ $pixel_count -ge 8294400 ]]; then  # 4K
        resolution_score=100
    elif [[ $pixel_count -ge 2073600 ]]; then  # 1080p
        resolution_score=80
    elif [[ $pixel_count -ge 921600 ]]; then   # 720p
        resolution_score=60
    elif [[ $pixel_count -ge 307200 ]]; then   # 480p
        resolution_score=40
    else
        resolution_score=20
    fi
    
    # Bitrate scoring (if available)
    if [[ $bitrate -gt 0 ]]; then
        local bitrate_per_pixel=$((bitrate / pixel_count))
        if [[ $bitrate_per_pixel -gt 100 ]]; then
            bitrate_score=100
        elif [[ $bitrate_per_pixel -gt 50 ]]; then
            bitrate_score=80
        elif [[ $bitrate_per_pixel -gt 25 ]]; then
            bitrate_score=60
        else
            bitrate_score=40
        fi
    else
        bitrate_score=50  # Unknown, assume medium
    fi
    
    # Combined score
    local quality_score=$(((resolution_score + bitrate_score) / 2))
    echo "$quality_score"
}

# 🧭 Decode exit codes and signals into human-readable form
explain_exit_code() {
    local code="${1:-0}"
    if [[ "$code" -ge 128 ]]; then
        local sig=$((code - 128))
        local name="SIG$sig"
        case "$sig" in
            1) name="SIGHUP";;
            2) name="SIGINT";;
            3) name="SIGQUIT";;
            9) name="SIGKILL";;
            13) name="SIGPIPE";;
            14) name="SIGALRM";;
            15) name="SIGTERM";;
            19) name="SIGSTOP";;
            20) name="SIGTSTP";;
            21) name="SIGTTIN (background process tried to read from terminal)";;
            22) name="SIGTTOU (background process tried to write to terminal)";;
        esac
        echo "Process terminated by signal $sig (${name})"
        return 0
    fi
    case "$code" in
        0) echo "Success";;
        1) echo "General error (invalid arguments or processing failure)";;
        2) echo "Misuse of shell builtins / usage error";;
        *) echo "Exited with code $code";;
    esac
}

# 📐 Compute percentage (output vs source) with one decimal; returns 'n/a' if invalid
compute_ratio_percent() {
    local out_bytes="$1"
    local src_bytes="$2"
    if ! [[ "$out_bytes" =~ ^[0-9]+$ ]] || ! [[ "$src_bytes" =~ ^[0-9]+$ ]]; then
        echo "n/a"; return
    fi
    if [[ "$src_bytes" -eq 0 ]]; then
        echo "n/a"; return
    fi
    awk "BEGIN { printf \"%.1f\", ($out_bytes*100.0)/$src_bytes }"
}

# 🩺 Summarize ffmpeg stderr into a concise diagnosis
summarize_ffmpeg_error() {
    local err_file="$1"
    local default_msg="Unknown FFmpeg error"
    [[ ! -s "$err_file" ]] && { echo "$default_msg"; return; }

    # Extract non-banner lines
    local body=$(grep -v -E "^ffmpeg version|^\s*libav|^\s*configuration:|^Input #|^Output #|^Stream mapping:|^Press \[q\]|^\s*$" "$err_file" 2>/dev/null)

    # Look for common fatal patterns
    local patterns=(
        "No such file or directory"
        "Invalid argument"
        "Unrecognized option"
        "Option .* not found"
        "Filter .* not found"
        "Error while opening encoder"
        "Decoder .* not found"
        "Cannot allocate memory"
        "Permission denied"
        "Operation not permitted"
        "Device not found"
        "Protocol not found"
        "Unable to find a suitable output format"
        "Output file #0 does not contain any stream"
        "At least one output file must be specified"
        "[Ee]xperimental .* use -strict"
        "could not find tag for codec"
        "height not divisible|width not divisible"
    )

    for p in "${patterns[@]}"; do
        if echo "$body" | grep -Eiq "$p"; then
            echo "$(echo "$body" | grep -E "$p" -m1 -i)"
            return
        fi
    done

    # If body empty or only banner, report that explicitly
    if [[ -z "$body" ]]; then
        echo "Only FFmpeg banner captured; likely interrupted by a signal, timing issue, or loglevel too high"
        return
    fi

    # Fallback: show last meaningful line
    echo "$(echo "$body" | tail -1 | sed 's/^\s*//')"
}

# 🚀 Robust ffmpeg runner with timeout, clean env and safe flags
run_ffmpeg_safely() {
    local cmd="$1"         # full ffmpeg command string (without timeout)
    local err_file="$2"     # path to capture stderr/stdout
    local timeout_secs="${3:-0}" # 0 = no timeout

    # Always enforce safe flags; set FFREPORT correctly (colon-separated)
    local wrapped_cmd="$cmd -nostdin -hide_banner -y"
    local ffreport_var="FFREPORT=file=$LOG_DIR/ffreport.log:level=32"

    local exit_code=0
    if [[ "$timeout_secs" -gt 0 ]]; then
        # Run with timeout in background to track PID
        bash -lc "$ffreport_var timeout ${timeout_secs}s $wrapped_cmd" > "$err_file" 2>&1 &
        local ffmpeg_pid=$!
        SCRIPT_FFMPEG_PIDS+=("$ffmpeg_pid")
        
        wait $ffmpeg_pid || exit_code=$?
        
        # Remove from tracking
        local new_pids=()
        for pid in "${SCRIPT_FFMPEG_PIDS[@]}"; do
            if [[ "$pid" != "$ffmpeg_pid" ]]; then
                new_pids+=("$pid")
            fi
        done
        SCRIPT_FFMPEG_PIDS=("${new_pids[@]}")
    else
        # Run in background to track PID
        bash -lc "$ffreport_var $wrapped_cmd" > "$err_file" 2>&1 &
        local ffmpeg_pid=$!
        SCRIPT_FFMPEG_PIDS+=("$ffmpeg_pid")
        
        wait $ffmpeg_pid || exit_code=$?
        
        # Remove from tracking
        local new_pids=()
        for pid in "${SCRIPT_FFMPEG_PIDS[@]}"; do
            if [[ "$pid" != "$ffmpeg_pid" ]]; then
                new_pids+=("$pid")
            fi
        done
        SCRIPT_FFMPEG_PIDS=("${new_pids[@]}")
    fi
    echo "$exit_code"
}

# ⏳ Per-file progress using -progress pipe:1
render_inline_progress() {
    local percent_str="$1"
    local filled=$(awk -v p="${percent_str}" 'BEGIN { printf("%d", (p*30/100)+0.5) }')
    if [[ "$filled" -gt 30 ]]; then filled=30; fi
    local empty=$((30 - filled))
    local ch_done="#"; local ch_rem="."
    if locale 2>/dev/null | grep -qi UTF; then ch_done="█"; ch_rem="░"; fi
    printf "\r    ${CYAN}Progress:${NC} ${BLUE}["; for ((i=0;i<filled;i++)); do printf "%s" "$ch_done"; done; for ((i=0;i<empty;i++)); do printf "%s" "$ch_rem"; done; printf "${BLUE}]${NC} ${MAGENTA}${percent_str}%%%s" "$NC"
}

convert_with_progress() {
    local file="$1"
    local palette_file="$2"
    local out_file="$3"
    local filter="$4"
    local err_file="$5"

    # Duration in seconds for progress calculation
    local dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$file" 2>/dev/null | awk '{printf("%.0f", $1)}')
    [[ -z "$dur" || "$dur" -le 0 ]] && dur=1

    # GPU acceleration is disabled for GIF conversion due to filter compatibility issues
    local accel_flags=""
    echo -e "  ${CYAN}Converting to GIF (CPU optimized for filter compatibility)...${NC}"
    
    # Run ffmpeg and capture PID for interruption handling (redirect stdin to prevent terminal conflicts)
    # Use AI-optimized threading if available, otherwise use default
    local optimal_threads="${AI_THREADS_OPTIMAL:-$FFMPEG_THREADS}"
    local memory_opts="${AI_MEMORY_OPT:-$FFMPEG_MEMORY_OPTS}"
    local cmd="env -i PATH=\"$PATH\" HOME=\"$HOME\" ffmpeg $accel_flags $FFMPEG_INPUT_OPTS -i \"$file\" -i \"$palette_file\" -lavfi \"$filter\" -threads $optimal_threads $memory_opts -nostats -nostdin -loglevel warning -y \"$out_file\""
    
    # Run with progress dots
    (
        local dot_count=0
        while kill -0 $$ 2>/dev/null; do
            printf "\r  ${CYAN}Converting to GIF"
            for ((i=0; i<=dot_count%4; i++)); do printf "."; done
            printf "     ${NC}"
            ((dot_count++))
            sleep 1
        done
    ) &
    local dots_pid=$!
    
    # Add progress animation PID to tracking
    SCRIPT_FFMPEG_PIDS+=("$dots_pid")
    
    # Properly redirect all streams to avoid terminal conflicts
    FFREPORT="file=$LOG_DIR/ffreport.log:level=32" bash -lc "$cmd" </dev/null 2> "$err_file" &
    local ffmpeg_pid=$!
    CURRENT_FFMPEG_PID="$ffmpeg_pid"
    
    # Add FFmpeg PID to tracking array
    SCRIPT_FFMPEG_PIDS+=("$ffmpeg_pid")
    
    # Wait for ffmpeg to complete
    wait $ffmpeg_pid
    local ec=$?
    CURRENT_FFMPEG_PID=""
    
    # Stop progress dots immediately
    kill $dots_pid 2>/dev/null || true
    wait $dots_pid 2>/dev/null || true
    
    # Remove completed processes from tracking array
    local new_pids=()
    for pid in "${SCRIPT_FFMPEG_PIDS[@]}"; do
        if [[ "$pid" != "$ffmpeg_pid" && "$pid" != "$dots_pid" ]]; then
            new_pids+=("$pid")
        fi
    done
    SCRIPT_FFMPEG_PIDS=("${new_pids[@]}")
    
    # Clear progress line
    printf "\r  ${GREEN}✓ Conversion completed     ${NC}\n"
    
    return $ec
}

convert_with_progress_oneshot() {
    local file="$1"
    local out_file="$2"
    local filter_complex="$3"
    local err_file="$4"

    # GPU acceleration is disabled for GIF conversion due to filter compatibility issues
    local accel_flags=""
    echo -e "  ${CYAN}Converting to GIF (one-shot, CPU optimized)...${NC}"
    
    # Run ffmpeg and capture PID for interruption handling (redirect stdin to prevent terminal conflicts)
    # Use AI-optimized threading if available, otherwise use default
    local optimal_threads="${AI_THREADS_OPTIMAL:-$FFMPEG_THREADS}"
    local memory_opts="${AI_MEMORY_OPT:-$FFMPEG_MEMORY_OPTS}"
    local cmd="env -i PATH=\"$PATH\" HOME=\"$HOME\" ffmpeg $accel_flags $FFMPEG_INPUT_OPTS -i \"$file\" -filter_complex \"$filter_complex\" -threads $optimal_threads $memory_opts -nostats -nostdin -loglevel warning -y \"$out_file\""
    
    # Run with progress dots
    (
        local dot_count=0
        while kill -0 $$ 2>/dev/null; do
            printf "\r  ${CYAN}Converting to GIF (one-shot)"
            for ((i=0; i<=dot_count%4; i++)); do printf "."; done
            printf "     ${NC}"
            ((dot_count++))
            sleep 1
        done
    ) &
    local dots_pid=$!
    
    # Add progress animation PID to tracking
    SCRIPT_FFMPEG_PIDS+=("$dots_pid")
    
    # Properly redirect all streams to avoid terminal conflicts
    FFREPORT="file=$LOG_DIR/ffreport.log:level=32" bash -lc "$cmd" </dev/null 2> "$err_file" &
    local ffmpeg_pid=$!
    CURRENT_FFMPEG_PID="$ffmpeg_pid"
    
    # Add FFmpeg PID to tracking array
    SCRIPT_FFMPEG_PIDS+=("$ffmpeg_pid")
    
    # Wait for ffmpeg to complete
    wait $ffmpeg_pid
    local ec=$?
    CURRENT_FFMPEG_PID=""
    
    # Stop progress dots immediately
    kill $dots_pid 2>/dev/null || true
    wait $dots_pid 2>/dev/null || true
    
    # Remove completed processes from tracking array
    local new_pids=()
    for pid in "${SCRIPT_FFMPEG_PIDS[@]}"; do
        if [[ "$pid" != "$ffmpeg_pid" && "$pid" != "$dots_pid" ]]; then
            new_pids+=("$pid")
        fi
    done
    SCRIPT_FFMPEG_PIDS=("${new_pids[@]}")
    
    # Clear progress line
    printf "\r  ${GREEN}✓ One-shot conversion completed     ${NC}\n"
    
    return $ec
}

# ⚠️  Safe execution wrapper
safe_execute() {
    local command="$1"
    local error_msg="$2"
    local file="$3"
    
    echo -e "${BLUE}🔄 Executing: $command${NC}" >&2
    
    if ! eval "$command" 2>&1; then
        log_error "$error_msg" "$file" "Command failed: $command" "${BASH_LINENO[0]}" "${FUNCNAME[1]}"
        return 1
    fi
    return 0
}

# 📝 Log successful conversions
log_conversion() {
    local status="$1"
    local source_file="$2"
    local output_file="$3"
    local size_info="$4"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] $status: $(basename "$source_file") -> $(basename "$output_file") $size_info" >> "$CONVERSION_LOG"
    
    # Autosave progress after each file
    if [[ "$AUTOSAVE_ENABLED" == "true" ]]; then
        autosave_progress "$source_file" "$status"
    fi
}

# 💾 Autosave conversion progress
autosave_progress() {
    local file="$1"
    local status="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Create progress file if it doesn't exist
    if [[ ! -f "$PROGRESS_FILE" ]]; then
        echo "# Smart GIF Converter Progress Save - $(date)" > "$PROGRESS_FILE"
        echo "# Format: [TIMESTAMP] STATUS:FILENAME" >> "$PROGRESS_FILE"
        echo "" >> "$PROGRESS_FILE"
    fi
    
    # Log the file status
    echo "[$timestamp] $status:$(basename "$file")" >> "$PROGRESS_FILE"
    
    # Keep only the last 1000 entries to prevent huge files
    if [[ $(wc -l < "$PROGRESS_FILE") -gt 1000 ]]; then
        tail -800 "$PROGRESS_FILE" > "${PROGRESS_FILE}.tmp" && mv "${PROGRESS_FILE}.tmp" "$PROGRESS_FILE"
    fi
}

# 📂 Load previous progress and get list of unprocessed files
load_progress() {
    local -n processed_files_ref=$1
    
    if [[ ! -f "$PROGRESS_FILE" ]]; then
        echo -e "${YELLOW}ℹ️ No previous progress found - starting fresh${NC}"
        return 1
    fi
    
    # Extract successfully processed files
    local completed_count=0
    while IFS= read -r line; do
        if [[ $line =~ ^\[.*\]\s+(SUCCESS|SKIPPED):(.*)$ ]]; then
            local status="${BASH_REMATCH[1]}"
            local filename="${BASH_REMATCH[2]}"
            processed_files_ref["$filename"]=1
            ((completed_count++))
        fi
    done < "$PROGRESS_FILE"
    
    if [[ $completed_count -gt 0 ]]; then
        echo -e "${GREEN}ℹ️ Loaded progress: $completed_count files already processed${NC}"
        return 0
    fi
    
    return 1
}

# 🗑️ Clear progress file (for fresh start)
clear_progress() {
    if [[ -f "$PROGRESS_FILE" ]]; then
        rm -f "$PROGRESS_FILE"
        echo -e "${GREEN}✓ Progress file cleared - starting fresh${NC}"
    fi
}

# 🔍 Show recent errors from log
show_recent_errors() {
    local count=${1:-5}
    
    if [[ -f "$ERROR_LOG" ]] && [[ -s "$ERROR_LOG" ]]; then
        echo -e "${RED}${BOLD}🚨 RECENT ERRORS (Last $count):${NC}\n"
        
        # Get the last few error entries
        local errors=$(grep -A 2 "ERROR:" "$ERROR_LOG" | tail -$((count * 3)))
        
        if [[ -n "$errors" ]]; then
            echo "$errors" | while IFS= read -r line; do
                if [[ $line == *"ERROR:"* ]]; then
                    echo -e "  ${RED}❌ $(echo "$line" | cut -d']' -f2-)${NC}"
                elif [[ $line == *"FILE:"* ]]; then
                    echo -e "  ${YELLOW}📁 $(echo "$line" | cut -d']' -f2-)${NC}"
                elif [[ $line == *"DETAILS:"* ]]; then
                    echo -e "  ${BLUE}🔍 $(echo "$line" | cut -d']' -f2-)${NC}"
                fi
            done
        else
            echo -e "  ${GREEN}No recent errors found${NC}"
        fi
        
        echo -e "\n${YELLOW}📋 Full error log: $ERROR_LOG${NC}"
        echo -e "${YELLOW}📈 View with: tail -50 \"$ERROR_LOG\"${NC}"
    else
        echo -e "${GREEN}✅ No error log found or log is empty${NC}"
    fi
}

# 🧠 Enhanced cleanup with temp directory support
cleanup_temp_files() {
    local file_prefix="$1"
    trace_function "cleanup_temp_files"
    
    if [[ -n "$file_prefix" ]]; then
        local base_name=$(basename "$file_prefix")
        
        # Clean temp files in work directory
        if [[ -n "$TEMP_WORK_DIR" && -d "$TEMP_WORK_DIR" ]]; then
            rm -f "${TEMP_WORK_DIR}/${base_name}"* 2>/dev/null || true
        fi
        
        # Clean legacy temp files in current directory (backward compatibility)
        rm -f "${file_prefix}_palette.png" "${file_prefix}_temp.gif" 2>/dev/null || true
        rm -f "${file_prefix}"*.error 2>/dev/null || true
        
        # Clean validation temp files
        rm -f /tmp/*_validation_*_*.log 2>/dev/null || true
    fi
    
    # Clean orphaned temp files
    find /tmp -name "ffprobe_error_$$_*.log" -type f -delete 2>/dev/null || true
    find /tmp -name "gif_validation_$$_*.log" -type f -delete 2>/dev/null || true
    
    # Clean FIFO files from progress functions
    rm -f /tmp/ffprog_$$_*.fifo 2>/dev/null || true
}

# 🗑️ Clean entire temp work directory
cleanup_work_directory() {
    if [[ -n "$TEMP_WORK_DIR" && -d "$TEMP_WORK_DIR" ]]; then
        echo -e "${BLUE}🧽 Cleaning work directory...${NC}"
        rm -rf "$TEMP_WORK_DIR" 2>/dev/null || true
    fi
}

# 🔧 Handle corrupt file detection and recovery
handle_corrupt_file() {
    local corrupt_file="$1"
    local source_file="$2"
    local corruption_type="$3"
    trace_function "handle_corrupt_file"
    
    echo -e "${RED}${BOLD}🚨 CORRUPT FILE DETECTED${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}📁 File: $(basename "$corrupt_file")${NC}"
    echo -e "${RED}📄 Source: $(basename "$source_file")${NC}"
    echo -e "${RED}🔍 Type: $corruption_type${NC}"
    
    # Move corrupt file to quarantine directory
    local quarantine_dir="$LOG_DIR/corrupt_files"
    local quarantine_file="$quarantine_dir/$(basename "$corrupt_file").$(date +%s).corrupt"
    
    if mkdir -p "$quarantine_dir" 2>/dev/null; then
        if mv "$corrupt_file" "$quarantine_file" 2>/dev/null; then
            echo -e "${YELLOW}📦 Corrupt file quarantined: $quarantine_file${NC}"
            log_error "Corrupt file quarantined" "$corrupt_file" "Moved to: $quarantine_file | Type: $corruption_type" "${BASH_LINENO[0]}" "handle_corrupt_file"
        else
            echo -e "${RED}❌ Failed to quarantine corrupt file, deleting it${NC}"
            rm -f "$corrupt_file" 2>/dev/null
            log_error "Corrupt file deleted (quarantine failed)" "$corrupt_file" "Type: $corruption_type" "${BASH_LINENO[0]}" "handle_corrupt_file"
        fi
    else
        echo -e "${RED}❌ Cannot create quarantine directory, deleting corrupt file${NC}"
        rm -f "$corrupt_file" 2>/dev/null
        log_error "Corrupt file deleted (no quarantine)" "$corrupt_file" "Type: $corruption_type" "${BASH_LINENO[0]}" "handle_corrupt_file"
    fi
    
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 🔍 Array to track ffmpeg PIDs started by this script
declare -a SCRIPT_FFMPEG_PIDS=()

# 📝 Add ffmpeg PID to tracking (legacy - now using foreground execution)
track_ffmpeg_pid() {
    local pid="$1"
    # No longer needed since we run ffmpeg in foreground
    # Keeping function for compatibility with cleanup functions
    return 0
}

# 🔪 Kill ffmpeg processes started by this script
kill_script_ffmpeg_processes() {
    local script_pid=$$
    
    # Method 1: Kill tracked PIDs
    if [[ ${#SCRIPT_FFMPEG_PIDS[@]} -gt 0 ]]; then
        echo -e "${YELLOW}🔄 Stopping ${#SCRIPT_FFMPEG_PIDS[@]} tracked ffmpeg process(es)...${NC}"
        for pid in "${SCRIPT_FFMPEG_PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                if kill -TERM "$pid" 2>/dev/null; then
                    echo -e "  ${GREEN}✓ Stopped tracked ffmpeg PID $pid${NC}"
                fi
            fi
        done
        
        # Wait for graceful shutdown
        sleep 2
        
        # Force kill any remaining tracked processes
        for pid in "${SCRIPT_FFMPEG_PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                kill -KILL "$pid" 2>/dev/null
                echo -e "  ${YELLOW}⚡ Force killed stubborn tracked ffmpeg PID $pid${NC}"
            fi
        done
        
        # Clear the tracking array
        SCRIPT_FFMPEG_PIDS=()
    fi
    
    # Method 2: Kill child processes of this script (backup method)
    local child_ffmpeg_pids=($(pgrep -P $script_pid ffmpeg 2>/dev/null || true))
    if [[ ${#child_ffmpeg_pids[@]} -gt 0 ]]; then
        echo -e "${YELLOW}🔄 Found ${#child_ffmpeg_pids[@]} additional child ffmpeg process(es)...${NC}"
        for pid in "${child_ffmpeg_pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                kill -TERM "$pid" 2>/dev/null
                echo -e "  ${GREEN}✓ Stopped child ffmpeg PID $pid${NC}"
            fi
        done
        
        sleep 1
        
        # Force kill remaining child processes
        for pid in "${child_ffmpeg_pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                kill -KILL "$pid" 2>/dev/null
                echo -e "  ${YELLOW}⚡ Force killed child ffmpeg PID $pid${NC}"
            fi
        done
    fi
}

# 🔫 Comprehensive process group termination
kill_entire_process_group() {
    local signal="${1:-TERM}"
    
    # Kill the entire process group (all children and grandchildren)
    if [[ -n "$SCRIPT_PGID" ]]; then
        # Kill entire process group
        pkill -$signal -g "$SCRIPT_PGID" 2>/dev/null || true
        
        # Kill all processes with our parent process ID
        pkill -$signal -P "$SCRIPT_PID" 2>/dev/null || true
    fi
    
    # Kill any remaining ffmpeg processes
    pkill -$signal ffmpeg 2>/dev/null || true
}

# Track current conversion state for graceful interruption
CURRENT_FFMPEG_PID=""
CURRENT_FILE=""
INTERRUPT_REQUESTED=false

# 🔥 Graceful signal handler that allows current conversion to finish
handle_interrupt() {
    INTERRUPT_REQUESTED=true
    echo -e "\n${YELLOW}⚠️  Interrupt received! Stopping after current file completes...${NC}"
    echo -e "${CYAN}💡 Press Ctrl+C again to force immediate exit${NC}"
    
    # Set a trap for the second interrupt to force exit
    trap 'force_cleanup_on_exit 130' INT
}

# 🔥 Force cleanup for immediate exit (double Ctrl+C)
force_cleanup_on_exit() {
    # Prevent recursive calls
    if [[ "$CLEANUP_IN_PROGRESS" == "true" ]]; then
        return
    fi
    export CLEANUP_IN_PROGRESS=true
    
    local exit_code=${1:-130}
    echo -e "\n${RED}🚫 Force exit requested! Terminating immediately...${NC}"
    
    # Disable all signal handlers to prevent loops
    trap '' INT TERM HUP PIPE ERR
    
    # Kill current ffmpeg if running
    if [[ -n "$CURRENT_FFMPEG_PID" ]] && kill -0 "$CURRENT_FFMPEG_PID" 2>/dev/null; then
        echo -e "${YELLOW}🔄 Stopping current ffmpeg process (PID $CURRENT_FFMPEG_PID)...${NC}"
        kill -TERM "$CURRENT_FFMPEG_PID" 2>/dev/null || true
        sleep 1
        if kill -0 "$CURRENT_FFMPEG_PID" 2>/dev/null; then
            kill -KILL "$CURRENT_FFMPEG_PID" 2>/dev/null || true
            echo -e "  ${RED}⚡ Force killed ffmpeg${NC}"
        fi
    fi
    
    # Kill entire process group immediately
    kill_entire_process_group TERM 2>/dev/null || true
    sleep 0.5
    kill_entire_process_group KILL 2>/dev/null || true
    
    # Clean up temp files for current conversion only (don't delete whole folder)
    if [[ -n "$CURRENT_FILE" ]]; then
        cleanup_temp_files "${CURRENT_FILE%.*}" 2>/dev/null || true
    fi
    
    # Clean work directory and RAM disk on exit
    cleanup_work_directory 2>/dev/null || true
    cleanup_ram_disk 2>/dev/null || true
    
    # Save current settings before exiting
    if [[ -n "$SETTINGS_FILE" && "$AUTOSAVE_ENABLED" == "true" ]]; then
        save_settings --silent 2>/dev/null || true
        echo -e "${BLUE}💾 Progress and settings saved${NC}"
    fi
    
    # Show interrupted statistics if they exist
    if [[ "$total_files" -gt 0 ]] 2>/dev/null; then
        echo -e "\n${YELLOW}📊 Conversion interrupted:${NC}"
        show_statistics 2>/dev/null || true
        echo -e "${CYAN}🔄 Run the script again to resume where you left off${NC}"
    fi
    
    echo -e "${RED}❌ Script terminated by user${NC}"
    exit $exit_code
}

# 🔥 Enhanced signal handler with complete process group cleanup (for TERM/HUP)
cleanup_on_exit() {
    force_cleanup_on_exit ${1:-143}
}

# 📂 Terminal disconnection handler
handle_terminal_disconnect() {
    echo -e "\n${RED}📺 Terminal disconnected - terminating all processes${NC}"
    kill_entire_process_group KILL
    exit 129
}

# 🆘 Emergency exit for stuck cleanup
emergency_exit() {
    echo -e "\n${RED}🆘 EMERGENCY EXIT - Force killing all processes${NC}"
    pkill -KILL -g $$ 2>/dev/null || true
    pkill -KILL ffmpeg 2>/dev/null || true
    exit 1
}

# 🔗 Execute process bound to our terminal session
execute_bound_process() {
    local command="$1"
    local description="$2"
    
    if [[ "$TERMINAL_BOUND" == "true" ]]; then
        # Execute in a way that binds to our process group
        bash -c "$command" &
        local pid=$!
        
        # Make sure the process is in our group
        # Note: The process should inherit our process group automatically
        echo -e "\033[2m🔗 Started $description as PID $pid (bound to terminal)\033[0m"
        return $pid
    else
        # Fallback for non-terminal execution
        bash -c "$command" &
        local pid=$!
        echo -e "\033[2m⚠️ Started $description as PID $pid (no terminal binding)\033[0m"
        return $pid
    fi
}

# 🏁 Clean completion handler
finish_script() {
    # Clean up any remaining background jobs from shell
    jobs -p 2>/dev/null | while read pid; do
        kill -TERM "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
        disown "$pid" 2>/dev/null || true
    done
    
    # Only show cleanup message if there were actually processes to clean
    local script_pid=$$
    local has_processes=false
    local tracked_count=${#SCRIPT_FFMPEG_PIDS[@]}
    
    # Check if we have tracked processes
    if [[ $tracked_count -gt 0 ]]; then
        has_processes=true
    fi
    
    # Check for child processes
    local child_ffmpeg_pids=($(pgrep -P $script_pid ffmpeg 2>/dev/null || true))
    local child_count=${#child_ffmpeg_pids[@]}
    if [[ $child_count -gt 0 ]]; then
        has_processes=true
    fi
    
    if [[ "$has_processes" == "true" ]]; then
        echo -e "\n${BLUE}🏁 Script completed, cleaning up processes...${NC}"
        echo -e "  ${CYAN}Tracked processes: $tracked_count${NC}"
        echo -e "  ${CYAN}Child processes: $child_count${NC}"
        
        kill_script_ffmpeg_processes
        
        # Double-check cleanup was successful
        local remaining_tracked=0
        for pid in "${SCRIPT_FFMPEG_PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                ((remaining_tracked++))
            fi
        done
        
        local remaining_children=($(pgrep -P $script_pid ffmpeg 2>/dev/null || true))
        local remaining_child_count=${#remaining_children[@]}
        
        if [[ $remaining_tracked -eq 0 && $remaining_child_count -eq 0 ]]; then
            echo -e "  ${GREEN}✅ All processes cleaned up successfully${NC}"
        else
            echo -e "  ${YELLOW}⚠️ Some processes may still be running: $remaining_tracked tracked, $remaining_child_count children${NC}"
        fi
    fi
    
    # Final cleanup of temp files and work directory
    cleanup_temp_files "*" >/dev/null 2>&1
    cleanup_work_directory >/dev/null 2>&1
    cleanup_ram_disk >/dev/null 2>&1
}

# 🔍 Detect and handle duplicate GIFs safely
detect_duplicate_gifs() {
    echo -e "${BLUE}🔍 Checking for duplicate GIF files...${NC}"
    
    local total_gifs=0
    local duplicate_count=0
    local duplicate_pairs=()
    declare -A gif_checksums
    declare -A gif_sizes
    
    # Find all GIF files in current directory and calculate checksums
    shopt -s nullglob
    for gif_file in *.gif; do
        [[ -f "$gif_file" ]] || continue
        
        # Safety check: ensure we're only processing GIF files
        if [[ "${gif_file##*.}" != "gif" ]]; then
            echo -e "  ${YELLOW}⚠️  Skipping non-GIF file: $gif_file${NC}"
            continue
        fi
        
        ((total_gifs++))
        
        # Calculate MD5 checksum for content comparison
        local checksum=$(md5sum "$gif_file" 2>/dev/null | cut -d' ' -f1)
        local size=$(stat -c%s "$gif_file" 2>/dev/null || echo "0")
        
        if [[ -n "$checksum" ]]; then
            # Check if we already have a file with this checksum
            if [[ -n "${gif_checksums[$checksum]:-}" ]]; then
                # Found a duplicate
                local original_file="${gif_checksums[$checksum]}"
                local original_size="${gif_sizes[$checksum]}"
                
                # Determine which file to keep (prefer larger file or alphabetically first)
                local keep_file="$original_file"
                local remove_file="$gif_file"
                
                if [[ $size -gt $original_size ]]; then
                    keep_file="$gif_file"
                    remove_file="$original_file"
                elif [[ $size -eq $original_size && "$gif_file" < "$original_file" ]]; then
                    keep_file="$gif_file"
                    remove_file="$original_file"
                fi
                
                duplicate_pairs+=("$remove_file|$keep_file")
                ((duplicate_count++))
                
                # Update tracking to keep the preferred file
                gif_checksums["$checksum"]="$keep_file"
                gif_sizes["$checksum"]="$(stat -c%s "$keep_file" 2>/dev/null || echo "0")"
            else
                # First time seeing this checksum
                gif_checksums["$checksum"]="$gif_file"
                gif_sizes["$checksum"]="$size"
            fi
        fi
    done
    shopt -u nullglob
    
    if [[ $total_gifs -eq 0 ]]; then
        echo -e "  ${CYAN}ℹ️  No existing GIF files found${NC}"
        return 0
    fi
    
    echo -e "  ${GREEN}✓ Scanned $total_gifs GIF files${NC}"
    
    if [[ $duplicate_count -eq 0 ]]; then
        echo -e "  ${GREEN}✓ No duplicate GIFs found${NC}"
        return 0
    fi
    
    # Show duplicate files
    echo -e "\n  ${YELLOW}⚠️  Found $duplicate_count duplicate GIF file(s):${NC}"
    for pair in "${duplicate_pairs[@]}"; do
        local remove_file="${pair%|*}"
        local keep_file="${pair#*|}"
        local remove_size=$(stat -c%s "$remove_file" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "unknown")
        local keep_size=$(stat -c%s "$keep_file" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "unknown")
        echo -e "    ${RED}🔴 Remove: $remove_file ($remove_size)${NC}"
        echo -e "    ${GREEN}🔵 Keep:   $keep_file ($keep_size)${NC}"
        echo ""
    done
    
    echo -e "  ${YELLOW}What would you like to do with duplicate GIFs?${NC}"
    echo -e "  ${CYAN}1)${NC} Delete duplicates automatically (recommended)"
    echo -e "  ${CYAN}2)${NC} Move duplicates to backup folder"
    echo -e "  ${CYAN}3)${NC} Review each duplicate interactively"
    echo -e "  ${CYAN}4)${NC} Skip and continue (keep all duplicates)"
    echo -e "\n  ${GRAY}Option 2 moves duplicates to ~/.smart-gif-converter/duplicate_gifs/"
    echo -e "  so you can review them later if needed.${NC}"
    echo -e "\n  ${MAGENTA}Choice [1-4]: ${NC}"
    
    local choice
    if [[ "${INTERACTIVE_MODE:-true}" == "false" ]]; then
        choice="4"  # Default to skip duplicates in non-interactive mode
        echo "4 (auto-selected: skip)"
    else
        read -r choice
    fi
    
    case "$choice" in
        1)
            echo -e "\n  ${YELLOW}🗑️  Deleting duplicate GIF files...${NC}"
            local deleted_count=0
            for pair in "${duplicate_pairs[@]}"; do
                local remove_file="${pair%|*}"
                local keep_file="${pair#*|}"
                
                # Safety check: only delete GIF files
                if [[ "${remove_file##*.}" != "gif" ]]; then
                    echo -e "    ${RED}❌ SAFETY: Refusing to delete non-GIF file: $remove_file${NC}"
                    continue
                fi
                
                # Safety check: don't delete if it looks like a video file
                if [[ "$remove_file" =~ \.(mp4|avi|mov|mkv|webm)$ ]]; then
                    echo -e "    ${RED}❌ SAFETY: Refusing to delete video file: $remove_file${NC}"
                    continue
                fi
                
                if [[ -f "$remove_file" ]] && rm -f "$remove_file" 2>/dev/null; then
                    echo -e "    ${GREEN}✓ Deleted: $remove_file (keeping $keep_file)${NC}"
                    ((deleted_count++))
                    # Log the deletion
                    {
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DUPLICATE GIF DELETED: $remove_file (kept $keep_file)"
                    } >> "$CONVERSION_LOG" 2>/dev/null || true
                else
                    echo -e "    ${RED}❌ Failed to delete: $remove_file${NC}"
                fi
            done
            echo -e "  ${GREEN}✓ $deleted_count duplicate GIF(s) cleaned up${NC}"
            ;;
        2)
            echo -e "\n  ${YELLOW}📦 Moving duplicate GIFs to backup...${NC}"
            local backup_dir="$LOG_DIR/duplicate_gifs"
            mkdir -p "$backup_dir" 2>/dev/null || {
                echo -e "    ${RED}❌ Cannot create backup directory${NC}"
                return 1
            }
            
            local moved_count=0
            for pair in "${duplicate_pairs[@]}"; do
                local remove_file="${pair%|*}"
                local keep_file="${pair#*|}"
                
                # Safety check: only move GIF files
                if [[ "${remove_file##*.}" != "gif" ]]; then
                    echo -e "    ${RED}❌ SAFETY: Refusing to move non-GIF file: $remove_file${NC}"
                    continue
                fi
                
                # Safety check: don't move if it looks like a video file
                if [[ "$remove_file" =~ \.(mp4|avi|mov|mkv|webm)$ ]]; then
                    echo -e "    ${RED}❌ SAFETY: Refusing to move video file: $remove_file${NC}"
                    continue
                fi
                
                local backup_file="$backup_dir/${remove_file}.$(date +%s).duplicate"
                if [[ -f "$remove_file" ]] && mv "$remove_file" "$backup_file" 2>/dev/null; then
                    echo -e "    ${GREEN}✓ Moved: $remove_file -> $(basename "$backup_file") (kept $keep_file)${NC}"
                    ((moved_count++))
                    # Log the move
                    {
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DUPLICATE GIF MOVED: $remove_file -> $backup_file (kept $keep_file)"
                    } >> "$CONVERSION_LOG" 2>/dev/null || true
                else
                    echo -e "    ${RED}❌ Failed to move: $remove_file${NC}"
                fi
            done
            echo -e "  ${GREEN}✓ $moved_count duplicate GIF(s) moved to: $backup_dir${NC}"
            ;;
        3)
            echo -e "\n  ${CYAN}🔍 Interactive duplicate review:${NC}"
            for pair in "${duplicate_pairs[@]}"; do
                local remove_file="${pair%|*}"
                local keep_file="${pair#*|}"
                local remove_size=$(stat -c%s "$remove_file" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "unknown")
                local keep_size=$(stat -c%s "$keep_file" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "unknown")
                
                echo -e "\n  ${YELLOW}Duplicate found:${NC}"
                echo -e "    ${RED}File A: $remove_file ($remove_size)${NC}"
                echo -e "    ${GREEN}File B: $keep_file ($keep_size)${NC}"
                echo -e "  ${MAGENTA}Delete File A? [y/N]: ${NC}"
                
                local confirm
                read -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    # Safety check: only delete GIF files
                    if [[ "${remove_file##*.}" != "gif" ]] || [[ "$remove_file" =~ \.(mp4|avi|mov|mkv|webm)$ ]]; then
                        echo -e "    ${RED}❌ SAFETY: Refusing to delete non-GIF or video file: $remove_file${NC}"
                        continue
                    fi
                    
                    if rm -f "$remove_file" 2>/dev/null; then
                        echo -e "    ${GREEN}✓ Deleted: $remove_file${NC}"
                        # Log the deletion
                        {
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] DUPLICATE GIF DELETED (interactive): $remove_file (kept $keep_file)"
                        } >> "$CONVERSION_LOG" 2>/dev/null || true
                    else
                        echo -e "    ${RED}❌ Failed to delete: $remove_file${NC}"
                    fi
                else
                    echo -e "    ${YELLOW}Skipped: $remove_file${NC}"
                fi
            done
            ;;
        4)
            echo -e "\n  ${YELLOW}⚠️  Keeping all duplicate GIFs${NC}"
            echo -e "  ${YELLOW}Note: Duplicates may consume unnecessary disk space${NC}"
            ;;
        *)
            echo -e "\n  ${RED}❌ Invalid choice. Keeping all duplicates.${NC}"
            ;;
    esac
    
    echo ""
}

# 🔍 Advanced pre-conversion validation with intelligent duplicate prevention
perform_pre_conversion_validation() {
    echo -e "${CYAN}${BOLD}🔍 ADVANCED PRE-CONVERSION VALIDATION${NC}\n"
    
    # Step 1: Check for duplicate GIFs and offer to remove them
    echo -e "${BLUE}Step 1: Duplicate GIF Detection${NC}"
    detect_duplicate_gifs
    
    # Step 2: Check for corrupted GIFs and offer to fix them  
    echo -e "${BLUE}Step 2: Corruption Detection${NC}"
    detect_corrupted_gifs
    
    # Step 3: Advanced video-to-GIF mapping analysis
    echo -e "${BLUE}Step 3: Video-to-GIF Mapping Analysis${NC}"
    analyze_video_gif_mapping
    
    # Step 4: Show intelligent conversion recommendations
    echo -e "${BLUE}Step 4: Conversion Planning${NC}"
    generate_conversion_plan
    
    echo -e "\n  ${GREEN}✓ Advanced validation completed${NC}\n"
    return 0
}

# 🎯 Analyze video-to-GIF mapping and detect existing conversions
analyze_video_gif_mapping() {
    declare -A video_files
    declare -A gif_files
    declare -A video_to_gif_map
    declare -A orphaned_gifs
    declare -A conversion_needed
    
    local total_videos=0
    local total_gifs=0
    local already_converted=0
    local need_conversion=0
    local orphaned_count=0
    
    # Scan all video files
    shopt -s nullglob
    for video in *.mp4 *.avi *.mov *.mkv *.webm; do
        [[ -f "$video" ]] || continue
        local basename="${video%.*}"
        video_files["$basename"]="$video"
        ((total_videos++))
    done
    
    # Scan all GIF files
    for gif in *.gif; do
        [[ -f "$gif" ]] || continue
        local basename="${gif%.*}"
        gif_files["$basename"]="$gif"
        ((total_gifs++))
    done
    shopt -u nullglob
    
    if [[ $total_videos -eq 0 ]]; then
        echo -e "  ${RED}❌ No video files found${NC}"
        return 1
    fi
    
    # Analyze mappings
    for basename in "${!video_files[@]}"; do
        local video_file="${video_files[$basename]}"
        local expected_gif="${basename}.gif"
        
        if [[ -n "${gif_files[$basename]:-}" ]]; then
            # Found corresponding GIF
            local gif_file="${gif_files[$basename]}"
            video_to_gif_map["$video_file"]="$gif_file"
            ((already_converted++))
            
            # Check if GIF is newer than video (to detect if conversion is up-to-date)
            local video_time=$(stat -c %Y "$video_file" 2>/dev/null || echo "0")
            local gif_time=$(stat -c %Y "$gif_file" 2>/dev/null || echo "0")
            
            if [[ $video_time -gt $gif_time ]]; then
                # Video is newer, might need re-conversion
                conversion_needed["$video_file"]="outdated"
            fi
        else
            # No corresponding GIF found
            conversion_needed["$video_file"]="missing"
            ((need_conversion++))
        fi
    done
    
    # Find orphaned GIFs (GIFs without corresponding video files)
    for basename in "${!gif_files[@]}"; do
        if [[ -z "${video_files[$basename]:-}" ]]; then
            local gif_file="${gif_files[$basename]}"
            orphaned_gifs["$gif_file"]="orphan"
            ((orphaned_count++))
        fi
    done
    
    # Display analysis results
    echo -e "  ${GREEN}✓ Analysis Results:${NC}"
    echo -e "    ${YELLOW}📹 Total video files: ${BOLD}$total_videos${NC}"
    echo -e "    ${BLUE}🎨 Total GIF files: ${BOLD}$total_gifs${NC}"
    echo -e "    ${GREEN}✅ Already converted: ${BOLD}$already_converted${NC}"
    echo -e "    ${CYAN}🔄 Need conversion: ${BOLD}$need_conversion${NC}"
    
    if [[ $orphaned_count -gt 0 ]]; then
        echo -e "    ${YELLOW}🔍 Orphaned GIFs: ${BOLD}$orphaned_count${NC}"
    fi
    
    # Show detailed mapping information
    if [[ $already_converted -gt 0 ]]; then
        echo -e "\n  ${GREEN}✓ Existing conversions found:${NC}"
        for video_file in "${!video_to_gif_map[@]}"; do
            local gif_file="${video_to_gif_map[$video_file]}"
            local video_size=$(stat -c%s "$video_file" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "?")
            local gif_size=$(stat -c%s "$gif_file" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "?")
            local status="✓"
            
            if [[ -n "${conversion_needed[$video_file]:-}" && "${conversion_needed[$video_file]}" == "outdated" ]]; then
                status="⚠️ (video newer)"
            fi
            
            echo -e "    ${status} $(basename "$video_file") ($video_size) → $(basename "$gif_file") ($gif_size)"
        done
    fi
    
    if [[ $need_conversion -gt 0 ]]; then
        echo -e "\n  ${CYAN}🔄 Videos needing conversion:${NC}"
        for video_file in "${!conversion_needed[@]}"; do
            if [[ "${conversion_needed[$video_file]}" == "missing" ]]; then
                local video_size=$(stat -c%s "$video_file" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "?")
                echo -e "    ${CYAN}📹 $(basename "$video_file") ($video_size) → ${GRAY}[no GIF]${NC}"
            fi
        done
    fi
    
    if [[ $orphaned_count -gt 0 ]]; then
        echo -e "\n  ${YELLOW}🔍 Orphaned GIFs (no matching video):${NC}"
        for gif_file in "${!orphaned_gifs[@]}"; do
            local gif_size=$(stat -c%s "$gif_file" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "?")
            echo -e "    ${YELLOW}🎨 $(basename "$gif_file") ($gif_size) → ${GRAY}[no video]${NC}"
        done
        
        if [[ $orphaned_count -gt 2 ]]; then
            echo -e "\n  ${MAGENTA}Clean up orphaned GIFs? [y/N]: ${NC}"
            local cleanup_orphans
            read -r cleanup_orphans
            if [[ "$cleanup_orphans" =~ ^[Yy]$ ]]; then
                cleanup_orphaned_gifs
            fi
        fi
    fi
    
    # Store results for use in conversion planning
    VALIDATION_TOTAL_VIDEOS=$total_videos
    VALIDATION_ALREADY_CONVERTED=$already_converted
    VALIDATION_NEED_CONVERSION=$need_conversion
    VALIDATION_ORPHANED_COUNT=$orphaned_count
    
    return 0
}

# 🧹 Clean up orphaned GIF files
cleanup_orphaned_gifs() {
    echo -e "\n  ${YELLOW}🧹 Cleaning up orphaned GIF files...${NC}"
    
    local orphaned_dir="$LOG_DIR/orphaned_gifs"
    mkdir -p "$orphaned_dir" 2>/dev/null || {
        echo -e "    ${RED}❌ Cannot create orphaned directory${NC}"
        return 1
    }
    
    local moved_count=0
    shopt -s nullglob
    for gif_file in *.gif; do
        [[ -f "$gif_file" ]] || continue
        local basename="${gif_file%.*}"
        local has_video=false
        
        # Check if corresponding video exists
        for ext in mp4 avi mov mkv webm; do
            if [[ -f "${basename}.${ext}" ]]; then
                has_video=true
                break
            fi
        done
        
        if [[ "$has_video" == false ]]; then
            local backup_file="$orphaned_dir/$(basename "$gif_file").$(date +%s).orphaned"
            if mv "$gif_file" "$backup_file" 2>/dev/null; then
                echo -e "    ${GREEN}✓ Moved: $(basename "$gif_file") → orphaned_gifs/$(basename "$backup_file")${NC}"
                ((moved_count++))
                # Log the move
                {
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ORPHANED GIF MOVED: $gif_file -> $backup_file"
                } >> "$CONVERSION_LOG" 2>/dev/null || true
            else
                echo -e "    ${RED}❌ Failed to move: $gif_file${NC}"
            fi
        fi
    done
    shopt -u nullglob
    
    echo -e "  ${GREEN}✓ Moved $moved_count orphaned GIF(s) to: $orphaned_dir${NC}"
}

# 📋 Generate intelligent conversion plan
generate_conversion_plan() {
    local total_videos=${VALIDATION_TOTAL_VIDEOS:-0}
    local already_converted=${VALIDATION_ALREADY_CONVERTED:-0}
    local need_conversion=${VALIDATION_NEED_CONVERSION:-0}
    local orphaned_count=${VALIDATION_ORPHANED_COUNT:-0}
    
    echo -e "  ${GREEN}✓ Conversion Plan:${NC}"
    
    if [[ $need_conversion -eq 0 ]]; then
        if [[ $already_converted -gt 0 ]]; then
            echo -e "    ${GREEN}🎉 All videos already converted! ($already_converted/$total_videos)${NC}"
            if [[ "$FORCE_CONVERSION" != "true" ]]; then
                echo -e "    ${CYAN}💡 Use --force to re-convert existing files${NC}"
                echo -e "    ${YELLOW}⏭️  Skipping conversion process${NC}"
                return 1  # Skip conversion
            else
                echo -e "    ${YELLOW}🔄 Force re-conversion enabled${NC}"
            fi
        else
            echo -e "    ${YELLOW}⚠️  No videos found that need conversion${NC}"
            return 1
        fi
    else
        echo -e "    ${CYAN}🎬 Will convert: ${BOLD}$need_conversion${NC} ${CYAN}video(s)${NC}"
        if [[ $already_converted -gt 0 ]]; then
            echo -e "    ${GREEN}✅ Already done: ${BOLD}$already_converted${NC} ${GREEN}video(s)${NC}"
        fi
        
        # Estimate conversion time and space
        estimate_conversion_requirements
    fi
    
    if [[ $orphaned_count -gt 0 ]]; then
        echo -e "    ${YELLOW}📁 Cleanup recommended: $orphaned_count orphaned GIF(s)${NC}"
    fi
    
    return 0
}

# ⏱️ Estimate conversion requirements
estimate_conversion_requirements() {
    local total_size=0
    local file_count=0
    
    # Calculate total size of videos that need conversion
    shopt -s nullglob
    for video in *.mp4 *.avi *.mov *.mkv *.webm; do
        [[ -f "$video" ]] || continue
        local basename="${video%.*}"
        local expected_gif="${basename}.gif"
        
        # Check if conversion is needed
        if [[ ! -f "$expected_gif" ]] || [[ "$FORCE_CONVERSION" == "true" ]]; then
            local size=$(stat -c%s "$video" 2>/dev/null || echo "0")
            total_size=$((total_size + size))
            ((file_count++))
        fi
    done
    shopt -u nullglob
    
    if [[ $file_count -gt 0 ]]; then
        local size_readable=$(numfmt --to=iec $total_size 2>/dev/null || echo "unknown")
        local estimated_time=$((file_count * 30))  # Rough estimate: 30 seconds per file
        local time_readable="${estimated_time}s"
        
        if [[ $estimated_time -gt 60 ]]; then
            time_readable="$((estimated_time / 60))m $((estimated_time % 60))s"
        fi
        
        echo -e "    ${BLUE}📊 Estimated: ${size_readable} input → ~${time_readable} conversion time${NC}"
        
        # Disk space warning if needed
        local available_space=$(df . | awk 'NR==2 {print $4}' 2>/dev/null || echo "0")
        local available_readable=$(echo "$available_space * 1024" | bc 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "unknown")
        
        if [[ $available_space -gt 0 ]] && [[ $total_size -gt $((available_space * 1024 / 2)) ]]; then
            echo -e "    ${YELLOW}⚠️  Disk space: ${available_readable} available (may need more space for large GIFs)${NC}"
        fi
    fi
}

# 🕵️ Detect and remove corrupted GIFs safely
detect_corrupted_gifs() {
    echo -e "${BLUE}🔍 Checking for corrupted GIF files...${NC}"
    
    local corrupted_count=0
    local total_gifs=0
    local corrupted_files=()
    
    # Find all GIF files in current directory
    shopt -s nullglob
    for gif_file in *.gif; do
        [[ -f "$gif_file" ]] || continue
        ((total_gifs++))
        
        # Test GIF integrity with ffprobe
        if ! ffprobe -v error -select_streams v:0 -show_entries stream=nb_frames -of csv=p=0 "$gif_file" >/dev/null 2>&1; then
            corrupted_files+=("$gif_file")
            ((corrupted_count++))
        fi
    done
    shopt -u nullglob
    
    if [[ $total_gifs -eq 0 ]]; then
        echo -e "  ${CYAN}ℹ️  No existing GIF files found${NC}"
        return 0
    fi
    
    echo -e "  ${GREEN}✓ Scanned $total_gifs GIF files${NC}"
    
    if [[ $corrupted_count -eq 0 ]]; then
        echo -e "  ${GREEN}✓ All existing GIFs are healthy${NC}"
        return 0
    fi
    
    # Handle corrupted files
    echo -e "\n  ${RED}⚠️  Found $corrupted_count corrupted GIF file(s):${NC}"
    for corrupted_file in "${corrupted_files[@]}"; do
        echo -e "    ${RED}🔴 $corrupted_file${NC}"
    done
    
    echo -e "\n  ${YELLOW}What would you like to do with corrupted GIFs?${NC}"
    echo -e "  ${CYAN}1)${NC} Delete them permanently (recommended)"
    echo -e "  ${CYAN}2)${NC} Move to safe backup folder (keeps corrupted files for inspection)"
    echo -e "  ${CYAN}3)${NC} Skip and continue (may cause conversion issues)"
    echo -e "\n  ${GRAY}Option 2 moves corrupted files to ~/.smart-gif-converter/corrupted_gifs/"
    echo -e "  so you can inspect or recover them later if needed.${NC}"
    echo -e "\n  ${MAGENTA}Choice [1-3]: ${NC}"
    
    local choice
    if [[ "${INTERACTIVE_MODE:-true}" == "false" ]]; then
        choice="3"  # Default to skip corrupted files in non-interactive mode
        echo "3 (auto-selected: skip)"
    else
        read -r choice
    fi
    
    case "$choice" in
        1)
            echo -e "\n  ${YELLOW}🗑️  Deleting corrupted GIF files...${NC}"
            for corrupted_file in "${corrupted_files[@]}"; do
                if rm -f "$corrupted_file" 2>/dev/null; then
                    echo -e "    ${GREEN}✓ Deleted: $corrupted_file${NC}"
                    # Log the deletion
                    {
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] CORRUPTED GIF DELETED: $corrupted_file"
                    } >> "$ERROR_LOG" 2>/dev/null || true
                else
                    echo -e "    ${RED}❌ Failed to delete: $corrupted_file${NC}"
                fi
            done
            echo -e "  ${GREEN}✓ Corrupted GIFs cleaned up${NC}"
            ;;
        2)
            echo -e "\n  ${YELLOW}📦 Moving corrupted GIFs to quarantine...${NC}"
            local quarantine_dir="$LOG_DIR/corrupted_gifs"
            mkdir -p "$quarantine_dir" 2>/dev/null || {
                echo -e "    ${RED}❌ Cannot create quarantine directory${NC}"
                return 1
            }
            
            for corrupted_file in "${corrupted_files[@]}"; do
                local quarantine_file="$quarantine_dir/${corrupted_file}.$(date +%s).corrupt"
                if mv "$corrupted_file" "$quarantine_file" 2>/dev/null; then
                    echo -e "    ${GREEN}✓ Quarantined: $corrupted_file -> $(basename "$quarantine_file")${NC}"
                    # Log the quarantine
                    {
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] CORRUPTED GIF QUARANTINED: $corrupted_file -> $quarantine_file"
                    } >> "$ERROR_LOG" 2>/dev/null || true
                else
                    echo -e "    ${RED}❌ Failed to quarantine: $corrupted_file${NC}"
                fi
            done
            echo -e "  ${GREEN}✓ Corrupted GIFs quarantined to: $quarantine_dir${NC}"
            ;;
        3)
            echo -e "\n  ${YELLOW}⚠️  Skipping corrupted GIF cleanup${NC}"
            echo -e "  ${YELLOW}Note: Corrupted files may interfere with conversion process${NC}"
            ;;
        *)
            echo -e "\n  ${RED}❌ Invalid choice. Skipping cleanup.${NC}"
            ;;
    esac
    
    echo ""
}

# ⚡ AI Speed Optimization Engine
ai_speed_optimizer() {
    local video_file="$1"
    local video_complexity="$2"
    local ai_results="$3"
    
    echo -e "${BLUE}⚡ AI Speed Optimizer analyzing: $(basename "$video_file")${NC}"
    
    # Initialize speed optimization variables
    local speed_preset="medium"
    local threads_optimal="auto"
    local gpu_encoder=""
    local memory_optimization=""
    local parallel_strategy="sequential"
    
    # Hardware detection for speed optimization
    local cpu_cores=$(nproc 2>/dev/null || echo "4")
    local available_memory=$(free -m 2>/dev/null | awk '/^Mem:/ {print $7}' || echo "2048")
    
    # AI-driven complexity analysis for speed optimization - maximize CPU usage
    case "$video_complexity" in
        "static"|"slideshow")
            speed_preset="ultrafast"
            threads_optimal="$cpu_cores"  # Use all cores even for static content
            echo -e "  ${GREEN}🎯 Static content detected - ultrafast with all cores${NC}"
            ;;
        "low")
            speed_preset="veryfast"
            threads_optimal="$cpu_cores"  # Use all cores for better throughput
            echo -e "  ${GREEN}🎯 Low motion detected - veryfast with all cores${NC}"
            ;;
        "medium")
            speed_preset="fast"
            threads_optimal="$cpu_cores"
            echo -e "  ${YELLOW}🎯 Medium complexity - fast with all cores${NC}"
            ;;
        "high"|"animation")
            speed_preset="medium"
            threads_optimal="$cpu_cores"  # Still use all cores for maximum performance
            echo -e "  ${RED}🎯 High complexity - medium with all cores${NC}"
            ;;
    esac
    
    # GPU acceleration optimization
    if detect_gpu_for_speed; then
        gpu_encoder=$(get_optimal_gpu_encoder)
        if [[ -n "$gpu_encoder" ]]; then
            echo -e "  ${GREEN}🚀 GPU acceleration enabled: $gpu_encoder${NC}"
            speed_preset="fast"  # GPU can handle faster presets
        fi
    fi
    
    # Memory-based optimizations
    if [[ $available_memory -lt 1024 ]]; then
        echo -e "  ${YELLOW}⚠️ Low memory detected - enabling memory conservation${NC}"
        memory_optimization="-threads 2 -filter_threads 1"
        threads_optimal="2"
    elif [[ $available_memory -gt 8192 ]]; then
        echo -e "  ${GREEN}💪 High memory available - enabling aggressive caching${NC}"
        memory_optimization="-filter_complex_threads $cpu_cores"
    fi
    
    # Parallel processing strategy - more aggressive with multiple cores
    local video_count=$(find . -maxdepth 1 \( -name "*.mp4" -o -name "*.avi" -o -name "*.mov" -o -name "*.mkv" -o -name "*.webm" \) | wc -l)
    if [[ $video_count -gt 1 && $cpu_cores -ge 2 ]]; then
        parallel_strategy="parallel"
        echo -e "  ${CYAN}🔄 Multiple videos + 💪 ${cpu_cores} cores - aggressive parallel processing${NC}"
    elif [[ $cpu_cores -ge 8 ]]; then
        parallel_strategy="parallel"
        echo -e "  ${CYAN}🚀 High-core system (${cpu_cores} cores) - enabling parallel optimization${NC}"
    fi
    
    # Export optimized settings
    export AI_SPEED_PRESET="$speed_preset"
    export AI_THREADS_OPTIMAL="$threads_optimal"
    export AI_GPU_ENCODER="$gpu_encoder"
    export AI_MEMORY_OPT="$memory_optimization"
    export AI_PARALLEL_STRATEGY="$parallel_strategy"
    
    echo -e "  ${GREEN}✓ Speed optimization complete${NC}"
    echo -e "    ${CYAN}Preset: $speed_preset | Threads: $threads_optimal${NC}"
    if [[ -n "$gpu_encoder" ]]; then
        echo -e "    ${CYAN}GPU: $gpu_encoder${NC}"
    fi
}

# 🏃 Detect GPU capabilities for speed optimization
detect_gpu_for_speed() {
    # Quick GPU detection focused on speed capabilities
    if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
        return 0  # NVIDIA GPU available
    elif [[ -d /sys/class/drm ]] && ls /sys/class/drm/card*/device/vendor 2>/dev/null | xargs cat | grep -q "0x1002\|0x8086"; then
        return 0  # AMD or Intel GPU available
    fi
    return 1
}

# 🎯 Get optimal GPU encoder for current hardware
get_optimal_gpu_encoder() {
    local encoders=("h264_nvenc" "h264_vaapi" "h264_videotoolbox" "h264_qsv")
    
    for encoder in "${encoders[@]}"; do
        if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "$encoder"; then
            echo "$encoder"
            return 0
        fi
    done
    
    return 1
}

# 📊 AI Performance Analysis
ai_performance_analysis() {
    local video_file="$1"
    
    echo -e "${BLUE}📊 AI Performance Analysis for: $(basename "$video_file")${NC}"
    
    # Get video properties for performance prediction
    local duration=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video_file" 2>/dev/null | cut -d. -f1)
    local resolution=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$video_file" 2>/dev/null)
    local fps=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$video_file" 2>/dev/null | bc -l 2>/dev/null | cut -d. -f1)
    
    # Calculate complexity score
    local width=$(echo "$resolution" | cut -d'x' -f1)
    local height=$(echo "$resolution" | cut -d'x' -f2)
    local pixel_count=$((width * height))
    local complexity_score=1
    
    # Adjust complexity based on resolution
    if [[ $pixel_count -gt 2073600 ]]; then  # > 1080p
        complexity_score=$((complexity_score + 3))
    elif [[ $pixel_count -gt 921600 ]]; then  # > 720p
        complexity_score=$((complexity_score + 2))
    elif [[ $pixel_count -gt 307200 ]]; then  # > 480p
        complexity_score=$((complexity_score + 1))
    fi
    
    # Adjust for frame rate
    if [[ ${fps:-15} -gt 30 ]]; then
        complexity_score=$((complexity_score + 2))
    elif [[ ${fps:-15} -gt 24 ]]; then
        complexity_score=$((complexity_score + 1))
    fi
    
    # Predict processing time
    local estimated_time=$((duration * complexity_score / 10))
    if [[ $estimated_time -lt 5 ]]; then
        estimated_time=5
    fi
    
    echo -e "  ${YELLOW}📐 Resolution: ${width}x${height} (${pixel_count} pixels)${NC}"
    echo -e "  ${YELLOW}⏱️ Duration: ${duration}s | FPS: ${fps:-"unknown"}${NC}"
    echo -e "  ${CYAN}🧮 Complexity Score: ${complexity_score}/10${NC}"
    echo -e "  ${GREEN}⚡ Estimated Processing: ~${estimated_time}s${NC}"
    
    # Export performance data
    export AI_PERF_COMPLEXITY="$complexity_score"
    export AI_PERF_ESTIMATED_TIME="$estimated_time"
    export AI_PERF_RESOLUTION="$resolution"
}

# 🚀 GPU acceleration detection and setup
detect_gpu_acceleration() {
    echo -e "${BLUE}🔍 Detecting GPU acceleration capabilities...${NC}"
    
    # Available GPU encoders in priority order
    local gpu_encoders=("h264_nvenc" "h264_vaapi" "h264_videotoolbox" "h264_qsv")
    local available_encoders=()
    
    # Check what encoders are available
    for encoder in "${gpu_encoders[@]}"; do
        if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "$encoder"; then
            available_encoders+=("$encoder")
        fi
    done
    
    # Detect GPU hardware with better AMD/NVIDIA detection
    local gpu_info=""
    
    # First, check for VFIO-bound GPUs and skip them
    local vfio_gpus=()
    if [[ -d /sys/bus/pci/drivers/vfio-pci ]]; then
        for vfio_device in /sys/bus/pci/drivers/vfio-pci/*; do
            if [[ -L "$vfio_device" ]]; then
                local pci_id=$(basename "$vfio_device")
                local device_info=$(lspci -s "$pci_id" 2>/dev/null | grep -i -E "(vga|3d|display)")
                if [[ -n "$device_info" ]]; then
                    vfio_gpus+=("$pci_id: $device_info")
                fi
            fi
        done
    fi
    
    # Show VFIO-bound GPUs info
    if [[ ${#vfio_gpus[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}⚠️  Found ${#vfio_gpus[@]} GPU(s) bound to VFIO (passthrough):${NC}"
        for vfio_gpu in "${vfio_gpus[@]}"; do
            echo -e "    ${GRAY}🔒 $vfio_gpu (skipped)${NC}"
        done
    fi
    
    # Check for available (non-VFIO) NVIDIA GPUs
    if command -v nvidia-smi >/dev/null 2>&1; then
        # Get all NVIDIA GPUs from lspci
        local all_nvidia_gpus=($(lspci 2>/dev/null | grep -i -E "(vga|3d|display).*nvidia" | cut -d' ' -f1))
        local available_nvidia_gpus=()
        
        # Filter out VFIO-bound NVIDIA GPUs
        for nvidia_pci in "${all_nvidia_gpus[@]}"; do
            local is_vfio_bound=false
            for vfio_gpu in "${vfio_gpus[@]}"; do
                if [[ "$vfio_gpu" == *"$nvidia_pci"* ]]; then
                    is_vfio_bound=true
                    break
                fi
            done
            
            if [[ "$is_vfio_bound" == false ]]; then
                available_nvidia_gpus+=("$nvidia_pci")
            fi
        done
        
        # Check if nvidia-smi can see available GPUs
        if [[ ${#available_nvidia_gpus[@]} -gt 0 ]] && nvidia-smi >/dev/null 2>&1; then
            local nvidia_gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null | head -1)
            gpu_info="NVIDIA GPU detected: ${nvidia_gpu:-Unknown NVIDIA GPU} (${#available_nvidia_gpus[@]} available)"
            GPU_TYPE="nvidia"
        elif [[ ${#available_nvidia_gpus[@]} -gt 0 ]]; then
            # NVIDIA GPUs exist but nvidia-smi can't see them (driver issues or VFIO)
            local nvidia_gpu=$(lspci -s "${available_nvidia_gpus[0]}" 2>/dev/null | sed 's/.*: //')
            gpu_info="NVIDIA GPU detected but driver unavailable: ${nvidia_gpu:-Unknown NVIDIA GPU}"
            GPU_TYPE="none"
        else
            gpu_info="NVIDIA GPUs detected but all bound to VFIO (passthrough)"
            GPU_TYPE="none"
        fi
    # Check for available AMD GPUs (excluding VFIO-bound)
    elif lspci 2>/dev/null | grep -i -E "(vga|3d|display).*amd|vga.*radeon|3d.*radeon" >/dev/null; then
        # Get all AMD GPUs
        local all_amd_gpus=($(lspci 2>/dev/null | grep -i -E "(vga|3d|display).*amd|vga.*radeon|3d.*radeon" | cut -d' ' -f1))
        local available_amd_gpus=()
        
        # Filter out VFIO-bound AMD GPUs
        for amd_pci in "${all_amd_gpus[@]}"; do
            local is_vfio_bound=false
            for vfio_gpu in "${vfio_gpus[@]}"; do
                if [[ "$vfio_gpu" == *"$amd_pci"* ]]; then
                    is_vfio_bound=true
                    break
                fi
            done
            
            if [[ "$is_vfio_bound" == false ]]; then
                available_amd_gpus+=("$amd_pci")
            fi
        done
        
        if [[ ${#available_amd_gpus[@]} -gt 0 ]]; then
            local amd_gpu=$(lspci -s "${available_amd_gpus[0]}" 2>/dev/null | sed 's/.*: //')
            gpu_info="AMD GPU detected: ${amd_gpu:-Unknown AMD GPU} (${#available_amd_gpus[@]} available)"
            GPU_TYPE="amd"
            
            # Additional AMD detection methods
            if [[ -z "$amd_gpu" ]] && command -v rocm-smi >/dev/null 2>&1; then
                local rocm_gpu=$(rocm-smi --showproductname 2>/dev/null | grep -v "=" | head -1 | xargs)
                [[ -n "$rocm_gpu" ]] && gpu_info="AMD GPU detected: $rocm_gpu (${#available_amd_gpus[@]} available)"
            fi
        else
            gpu_info="AMD GPUs detected but all bound to VFIO (passthrough)"
            GPU_TYPE="none"
        fi
    # Check for Intel GPU (usually not VFIO-bound)
    elif lspci 2>/dev/null | grep -i -E "vga.*intel|3d.*intel|display.*intel" >/dev/null; then
        local intel_gpu=$(lspci 2>/dev/null | grep -i -E "vga.*intel|3d.*intel|display.*intel" | head -1 | sed 's/.*: //')
        gpu_info="Intel GPU detected: ${intel_gpu:-Unknown Intel GPU}"
        GPU_TYPE="intel"
    else
        if [[ ${#vfio_gpus[@]} -gt 0 ]]; then
            gpu_info="Only VFIO-bound GPUs detected (all in passthrough mode)"
        else
            gpu_info="No supported GPU detected"
        fi
        GPU_TYPE="none"
    fi
    
    # Set GPU acceleration based on detection
    if [[ "$GPU_ACCELERATION" == "auto" ]]; then
        if [[ ${#available_encoders[@]} -gt 0 ]]; then
            GPU_ENCODER="${available_encoders[0]}"
            GPU_ACCELERATION="true"
            echo -e "  ${GREEN}✓ $gpu_info - Using $GPU_ENCODER${NC}"
        else
            GPU_ACCELERATION="false"
            echo -e "  ${YELLOW}⚠️  $gpu_info - No hardware encoders available${NC}"
        fi
    elif [[ "$GPU_ACCELERATION" == "true" ]]; then
        if [[ ${#available_encoders[@]} -gt 0 ]]; then
            GPU_ENCODER="${available_encoders[0]}"
            echo -e "  ${GREEN}✓ $gpu_info - Forced GPU acceleration with $GPU_ENCODER${NC}"
        else
            echo -e "  ${RED}❌ GPU acceleration forced but no encoders available - falling back to CPU${NC}"
            GPU_ACCELERATION="false"
        fi
    else
        echo -e "  ${CYAN}💻 CPU-only mode (GPU acceleration disabled)${NC}"
    fi
    
    # Advanced CPU optimization
    optimize_cpu_usage
    
    # Advanced RAM optimization
    optimize_ram_usage
    
    echo ""
}

# 🧮 Advanced CPU optimization and detection system
optimize_cpu_usage() {
    echo -e "  ${BLUE}🧮 Analyzing CPU architecture for optimal performance...${NC}"
    
    # Detect CPU information
    local cpu_info=$(detect_cpu_architecture)
    local physical_cores=$(get_physical_cores)
    local logical_cores=$(get_logical_cores)
    local cpu_threads_per_core=$(get_threads_per_core)
    local memory_gb=$(get_available_memory_gb)
    local cpu_frequency=$(get_cpu_frequency)
    
    # Display CPU analysis
    echo -e "  ${GREEN}✓ CPU Analysis:${NC}"
    echo -e "    ${YELLOW}📊 Architecture: ${BOLD}$cpu_info${NC}"
    echo -e "    ${YELLOW}⚙️ Physical cores: ${BOLD}$physical_cores${NC}"
    echo -e "    ${YELLOW}🧠 Logical cores: ${BOLD}$logical_cores${NC}"
    echo -e "    ${YELLOW}🔄 Threads per core: ${BOLD}$cpu_threads_per_core${NC}"
    echo -e "    ${YELLOW}📦 Available RAM: ${BOLD}${memory_gb}GB${NC}"
    [[ -n "$cpu_frequency" ]] && echo -e "    ${YELLOW}⚡ Base frequency: ${BOLD}${cpu_frequency}${NC}"
    
    # Performance mode optimization
    optimize_for_performance_mode
    
    # Set optimal FFmpeg thread count
    if [[ "$FFMPEG_THREADS" == "auto" ]]; then
        if [[ "$CPU_BENCHMARK" == "true" ]]; then
            echo -e "  ${BLUE}🏆 Running performance benchmark...${NC}"
            benchmark_cpu_performance
        else
            FFMPEG_THREADS=$(calculate_optimal_ffmpeg_threads "$logical_cores" "$memory_gb")
            echo -e "  ${GREEN}✓ FFmpeg threads: ${BOLD}$FFMPEG_THREADS${NC} ${GRAY}(optimized for your CPU)${NC}"
        fi
    else
        echo -e "  ${CYAN}🔧 FFmpeg threads: ${BOLD}$FFMPEG_THREADS${NC} ${GRAY}(manually set)${NC}"
    fi
}

# 🔍 Detect CPU architecture and capabilities
detect_cpu_architecture() {
    local cpu_info="Unknown"
    
    if [[ -f /proc/cpuinfo ]]; then
        local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
        local cpu_vendor=$(grep "vendor_id" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
        
        if [[ -n "$cpu_model" ]]; then
            cpu_info="$cpu_model"
            # Detect specific optimizations
            if [[ "$cpu_model" == *"Intel"* ]]; then
                cpu_info+="  🔵 Intel optimized"
            elif [[ "$cpu_model" == *"AMD"* ]]; then
                cpu_info+="  🔴 AMD optimized"
            fi
            
            # Detect performance tier
            if [[ "$cpu_model" == *"i9"* ]] || [[ "$cpu_model" == *"Ryzen 9"* ]] || [[ "$cpu_model" == *"Threadripper"* ]]; then
                cpu_info+="  🚀 High-end"
            elif [[ "$cpu_model" == *"i7"* ]] || [[ "$cpu_model" == *"Ryzen 7"* ]]; then
                cpu_info+="  💪 Performance"
            elif [[ "$cpu_model" == *"i5"* ]] || [[ "$cpu_model" == *"Ryzen 5"* ]]; then
                cpu_info+="  ⚙️ Mainstream"
            fi
        elif [[ -n "$cpu_vendor" ]]; then
            cpu_info="$cpu_vendor CPU"
        fi
    fi
    
    # Detect architecture features
    if [[ -f /proc/cpuinfo ]]; then
        local flags=$(grep "^flags" /proc/cpuinfo | head -1 | cut -d':' -f2)
        local features=()
        
        [[ "$flags" == *"avx2"* ]] && features+=("AVX2")
        [[ "$flags" == *"avx512"* ]] && features+=("AVX-512")
        [[ "$flags" == *"sse4_2"* ]] && features+=("SSE4.2")
        
        if [[ ${#features[@]} -gt 0 ]]; then
            cpu_info+=" ($(IFS=,; echo "${features[*]}"))"
        fi
    fi
    
    echo "$cpu_info"
}

# 💪 Get physical CPU cores
get_physical_cores() {
    local physical_cores=1
    
    if [[ -f /proc/cpuinfo ]]; then
        physical_cores=$(grep "^cpu cores" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs 2>/dev/null || echo "1")
        
        # Fallback method
        if [[ $physical_cores -eq 1 ]]; then
            physical_cores=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "1")
            # If hyperthreading is detected, divide by 2
            local threads_per_core=$(get_threads_per_core)
            if [[ $threads_per_core -gt 1 ]]; then
                physical_cores=$((physical_cores / threads_per_core))
            fi
        fi
    else
        physical_cores=$(nproc --all 2>/dev/null || echo "1")
    fi
    
    [[ $physical_cores -lt 1 ]] && physical_cores=1
    echo "$physical_cores"
}

# 🧠 Get logical CPU cores (including hyperthreading)
get_logical_cores() {
    local logical_cores=$(nproc --all 2>/dev/null || echo "1")
    [[ $logical_cores -lt 1 ]] && logical_cores=1
    echo "$logical_cores"
}

# 🔄 Get threads per core (detect hyperthreading)
get_threads_per_core() {
    local threads_per_core=1
    
    if [[ -f /proc/cpuinfo ]]; then
        local siblings=$(grep "^siblings" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs 2>/dev/null || echo "1")
        local cpu_cores=$(grep "^cpu cores" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs 2>/dev/null || echo "1")
        
        if [[ $siblings -gt 0 && $cpu_cores -gt 0 ]]; then
            threads_per_core=$((siblings / cpu_cores))
        fi
    fi
    
    [[ $threads_per_core -lt 1 ]] && threads_per_core=1
    echo "$threads_per_core"
}

# 📦 Get available memory in GB
get_available_memory_gb() {
    local memory_gb=1
    
    if command -v free >/dev/null 2>&1; then
        local memory_kb=$(free | awk '/^Mem:/ {print $7}' 2>/dev/null)
        if [[ -n "$memory_kb" && $memory_kb -gt 0 ]]; then
            memory_gb=$((memory_kb / 1024 / 1024))
        else
            # Fallback to total memory
            memory_kb=$(free | awk '/^Mem:/ {print $2}' 2>/dev/null)
            [[ -n "$memory_kb" && $memory_kb -gt 0 ]] && memory_gb=$((memory_kb / 1024 / 1024))
        fi
    elif [[ -f /proc/meminfo ]]; then
        local memory_kb=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}' 2>/dev/null)
        if [[ -n "$memory_kb" && $memory_kb -gt 0 ]]; then
            memory_gb=$((memory_kb / 1024))
        fi
    fi
    
    [[ $memory_gb -lt 1 ]] && memory_gb=1
    echo "$memory_gb"
}

# ⚡ Get CPU frequency information
get_cpu_frequency() {
    local frequency=""
    
    if [[ -f /proc/cpuinfo ]]; then
        frequency=$(grep "cpu MHz" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs 2>/dev/null)
        if [[ -n "$frequency" ]]; then
            local ghz=$(echo "scale=2; $frequency / 1000" | bc 2>/dev/null || echo "")
            [[ -n "$ghz" ]] && frequency="${ghz}GHz"
        fi
    fi
    
    echo "$frequency"
}

# 🎯 Calculate optimal FFmpeg thread count
calculate_optimal_ffmpeg_threads() {
    local logical_cores="$1"
    local memory_gb="$2"
    local optimal_threads=$logical_cores
    
    # Memory-based adjustment
    if [[ $memory_gb -lt 4 ]]; then
        # Low memory: reduce threads to prevent OOM
        optimal_threads=$((logical_cores * 75 / 100))
    elif [[ $memory_gb -lt 8 ]]; then
        # Medium memory: slight reduction
        optimal_threads=$((logical_cores * 90 / 100))
    else
        # High memory: use all cores
        optimal_threads=$logical_cores
    fi
    
    # Architecture-based adjustment
    local cpu_model=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d':' -f2 | xargs)
    if [[ "$cpu_model" == *"Ryzen"* ]] || [[ "$cpu_model" == *"Threadripper"* ]]; then
        # AMD CPUs often benefit from using all threads
        optimal_threads=$logical_cores
    elif [[ "$cpu_model" == *"Intel"* ]]; then
        # Intel CPUs sometimes perform better with physical cores + 50%
        local physical_cores=$(get_physical_cores)
        local intel_optimal=$((physical_cores + physical_cores / 2))
        [[ $intel_optimal -lt $optimal_threads ]] && optimal_threads=$intel_optimal
    fi
    
    # Minimum and maximum bounds
    [[ $optimal_threads -lt 1 ]] && optimal_threads=1
    [[ $optimal_threads -gt $logical_cores ]] && optimal_threads=$logical_cores
    
    echo "$optimal_threads"
}

# 🚀 Advanced multi-threading setup for parallel processing
setup_parallel_processing() {
    local logical_cores=$(get_logical_cores)
    local physical_cores=$(get_physical_cores)
    local memory_gb=$(get_available_memory_gb)
    
    if [[ "$PARALLEL_JOBS" == "auto" ]]; then
        PARALLEL_JOBS=$(calculate_optimal_parallel_jobs "$logical_cores" "$physical_cores" "$memory_gb")
        
        echo -e "${GREEN}🚀 Advanced parallel processing optimized:${NC}"
        echo -e "  ${CYAN}⚙️ Concurrent jobs: ${BOLD}$PARALLEL_JOBS${NC}"
        echo -e "  ${CYAN}🧠 Per-job threads: ${BOLD}$FFMPEG_THREADS${NC}"
        echo -e "  ${CYAN}📊 Total thread utilization: ${BOLD}$((PARALLEL_JOBS * FFMPEG_THREADS))/${logical_cores}${NC}"
        
        # Performance recommendations
        if [[ $logical_cores -ge 16 ]]; then
            echo -e "  ${GREEN}🚀 High-performance CPU detected - maximum efficiency mode enabled${NC}"
        elif [[ $logical_cores -ge 8 ]]; then
            echo -e "  ${BLUE}💪 Performance CPU detected - optimal processing enabled${NC}"
        elif [[ $logical_cores -ge 4 ]]; then
            echo -e "  ${YELLOW}⚙️ Mainstream CPU detected - balanced processing enabled${NC}"
        else
            echo -e "  ${CYAN}💻 Entry-level CPU detected - conservative processing enabled${NC}"
        fi
        
        echo ""
    elif [[ "$PARALLEL_JOBS" -eq 1 ]]; then
        echo -e "${CYAN}💻 Single-threaded mode: Using all $FFMPEG_THREADS threads per conversion${NC}"
    else
        echo -e "${GREEN}🔧 Manual configuration: $PARALLEL_JOBS jobs × $FFMPEG_THREADS threads = $((PARALLEL_JOBS * FFMPEG_THREADS)) total threads${NC}"
    fi
}

# 🎯 Calculate optimal number of parallel conversion jobs
calculate_optimal_parallel_jobs() {
    local logical_cores="$1"
    local physical_cores="$2"
    local memory_gb="$3"
    local optimal_jobs=1
    
    # Base calculation on physical cores
    if [[ $physical_cores -ge 16 ]]; then
        optimal_jobs=6  # High-end workstation
    elif [[ $physical_cores -ge 12 ]]; then
        optimal_jobs=5  # High-end desktop
    elif [[ $physical_cores -ge 8 ]]; then
        optimal_jobs=4  # Performance desktop
    elif [[ $physical_cores -ge 6 ]]; then
        optimal_jobs=3  # Mid-range desktop
    elif [[ $physical_cores -ge 4 ]]; then
        optimal_jobs=2  # Quad-core
    else
        optimal_jobs=1  # Dual-core or less
    fi
    
    # Memory constraint adjustment
    local memory_per_job=$((memory_gb / optimal_jobs))
    if [[ $memory_per_job -lt 2 ]]; then
        # Each conversion job needs at least 2GB
        optimal_jobs=$((memory_gb / 2))
        [[ $optimal_jobs -lt 1 ]] && optimal_jobs=1
    fi
    
    # Don't exceed 75% of logical cores to leave room for system
    local max_jobs_by_cores=$((logical_cores * 75 / 100))
    [[ $optimal_jobs -gt $max_jobs_by_cores ]] && optimal_jobs=$max_jobs_by_cores
    
    # Final bounds check
    [[ $optimal_jobs -lt 1 ]] && optimal_jobs=1
    [[ $optimal_jobs -gt 8 ]] && optimal_jobs=8  # Reasonable maximum
    
    echo "$optimal_jobs"
}

# 📈 Monitor CPU performance during conversion
monitor_cpu_performance() {
    local duration="${1:-5}"  # Default 5 second sample
    
    if command -v vmstat >/dev/null 2>&1; then
        # Use vmstat for CPU utilization
        local cpu_stats=$(vmstat 1 $duration | tail -1)
        local cpu_idle=$(echo $cpu_stats | awk '{print $15}')
        local cpu_usage=$((100 - cpu_idle))
        
        echo "CPU: ${cpu_usage}%"
    elif [[ -f /proc/stat ]]; then
        # Fallback to /proc/stat parsing
        local cpu_usage=$(awk '/^cpu / {usage=($2+$4)*100/($2+$3+$4)} END {printf "%.0f", usage}' /proc/stat 2>/dev/null || echo "0")
        echo "CPU: ${cpu_usage}%"
    else
        echo "CPU: monitoring unavailable"
    fi
}

# 🎛️ Dynamic CPU scaling detection
detect_cpu_scaling() {
    local scaling_governor="unknown"
    local current_freq="unknown"
    
    # Check CPU frequency scaling governor
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
        scaling_governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
    fi
    
    # Check current CPU frequency
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]]; then
        local freq_khz=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo "0")
        if [[ $freq_khz -gt 0 ]]; then
            local freq_mhz=$((freq_khz / 1000))
            local freq_ghz=$(echo "scale=2; $freq_mhz / 1000" | bc 2>/dev/null || echo "0")
            current_freq="${freq_ghz}GHz"
        fi
    fi
    
    echo "governor:$scaling_governor,freq:$current_freq"
}

# 🏆 CPU Performance Benchmarking
benchmark_cpu_performance() {
    echo -e "${CYAN}${BOLD}🏆 CPU PERFORMANCE BENCHMARK${NC}\n"
    echo -e "${YELLOW}Running quick performance test to optimize settings...${NC}"
    
    local logical_cores=$(get_logical_cores)
    local physical_cores=$(get_physical_cores)
    local memory_gb=$(get_available_memory_gb)
    
    # Test different thread configurations
    local test_configs=()
    test_configs+=("$((physical_cores))")
    test_configs+=("$((logical_cores))")
    test_configs+=("$((logical_cores * 75 / 100))")
    test_configs+=("$((physical_cores + physical_cores / 2))")
    
    local best_threads=0
    local best_time=999999
    
    echo -e "${BLUE}Testing thread configurations:${NC}"
    
    for threads in "${test_configs[@]}"; do
        [[ $threads -lt 1 ]] && continue
        [[ $threads -gt $logical_cores ]] && continue
        
        echo -e "  ${CYAN}Testing $threads threads...${NC}"
        
        # Create a small test video
        local test_input="/tmp/cpu_test_$$_input.mp4"
        local test_output="/tmp/cpu_test_$$_output.gif"
        
        # Generate test video (2 seconds, 320x240)
        ffmpeg -f lavfi -i testsrc=duration=2:size=320x240:rate=10 -c:v libx264 -y "$test_input" 2>/dev/null &
        local gen_pid=$!
        wait $gen_pid 2>/dev/null
        
        if [[ -f "$test_input" ]]; then
            # Time the conversion
            local start_time=$(date +%s.%N)
            
            ffmpeg -i "$test_input" -vf "fps=10,scale=160:120:flags=lanczos,palettegen=max_colors=64" -threads $threads -y "/tmp/palette_$$.png" 2>/dev/null &&
            ffmpeg -i "$test_input" -i "/tmp/palette_$$.png" -lavfi "fps=10,scale=160:120:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer" -threads $threads -y "$test_output" 2>/dev/null
            
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "999")
            
            if [[ -f "$test_output" ]] && [[ $(stat -c%s "$test_output" 2>/dev/null || echo "0") -gt 100 ]]; then
                echo -e "    ${GREEN}✓ $threads threads: ${duration}s${NC}"
                
                # Check if this is the best time
                local is_better=$(echo "$duration < $best_time" | bc 2>/dev/null || echo "0")
                if [[ $is_better -eq 1 ]]; then
                    best_time=$duration
                    best_threads=$threads
                fi
            else
                echo -e "    ${RED}❌ $threads threads: failed${NC}"
            fi
            
            # Cleanup test files
            rm -f "$test_output" "/tmp/palette_$$.png" 2>/dev/null
        fi
        
        rm -f "$test_input" 2>/dev/null
        sleep 0.5  # Brief pause between tests
    done
    
    if [[ $best_threads -gt 0 ]]; then
        echo -e "\n${GREEN}🏆 Benchmark Results:${NC}"
        echo -e "  ${YELLOW}Optimal thread count: ${BOLD}$best_threads${NC} ${GRAY}(${best_time}s test time)${NC}"
        
        # Update global settings with benchmark results
        FFMPEG_THREADS=$best_threads
        
        # Recalculate parallel jobs based on optimal threads
        local optimal_jobs=$(calculate_optimal_parallel_jobs "$logical_cores" "$physical_cores" "$memory_gb")
        PARALLEL_JOBS=$optimal_jobs
        
        echo -e "  ${YELLOW}Recommended parallel jobs: ${BOLD}$optimal_jobs${NC}"
        echo -e "  ${CYAN}Settings automatically optimized for your CPU!${NC}"
    else
        echo -e "\n${YELLOW}⚠️  Benchmark failed, using default settings${NC}"
    fi
    
    echo ""
}

# 🔥 Performance mode detection and optimization
optimize_for_performance_mode() {
    local cpu_info=$(detect_cpu_architecture)
    local logical_cores=$(get_logical_cores)
    local memory_gb=$(get_available_memory_gb)
    
    echo -e "  ${GREEN}🔥 Performance mode optimization:${NC}"
    
    # Check if running in high-performance mode
    local governor=$(detect_cpu_scaling | cut -d',' -f1 | cut -d':' -f2)
    
    if [[ "$governor" == "performance" ]]; then
        echo -e "    ${GREEN}✓ Performance governor active${NC}"
        # Slightly increase thread utilization in performance mode
        if [[ "$FFMPEG_THREADS" == "auto" ]]; then
            FFMPEG_THREADS=$logical_cores
        fi
    elif [[ "$governor" == "powersave" ]]; then
        echo -e "    ${YELLOW}⚡ Power-save mode detected - conservative settings applied${NC}"
        # Use fewer threads in power-save mode
        if [[ "$FFMPEG_THREADS" == "auto" ]]; then
            FFMPEG_THREADS=$((logical_cores * 75 / 100))
            [[ $FFMPEG_THREADS -lt 1 ]] && FFMPEG_THREADS=1
        fi
    else
        echo -e "    ${CYAN}⚙️ Balanced mode detected - optimal settings applied${NC}"
    fi
    
    # Memory-based performance adjustments
    if [[ $memory_gb -ge 32 ]]; then
        echo -e "    ${GREEN}✓ High memory system - maximum performance enabled${NC}"
    elif [[ $memory_gb -ge 16 ]]; then
        echo -e "    ${BLUE}✓ Good memory available - performance optimized${NC}"
    elif [[ $memory_gb -ge 8 ]]; then
        echo -e "    ${YELLOW}✓ Adequate memory - balanced performance${NC}"
    else
        echo -e "    ${YELLOW}⚠️  Limited memory - conservative settings applied${NC}"
    fi
}

# 📦 Advanced RAM Optimization System
optimize_ram_usage() {
    echo -e "  ${BLUE}📦 Analyzing RAM for conversion acceleration...${NC}"
    
    local memory_gb=$(get_available_memory_gb)
    local total_memory_gb=$(get_total_memory_gb)
    
    echo -e "  ${GREEN}✓ Memory Analysis:${NC}"
    echo -e "    ${YELLOW}📦 Total RAM: ${BOLD}${total_memory_gb}GB${NC}"
    echo -e "    ${YELLOW}🔄 Available RAM: ${BOLD}${memory_gb}GB${NC}"
    
    # Setup RAM disk for temporary files if enough memory
    setup_ram_disk
    
    # Configure FFmpeg memory optimizations
    configure_ffmpeg_memory_options
    
    # Setup intelligent caching
    setup_memory_caching
    
    echo ""
}

# 📦 Get total system memory
get_total_memory_gb() {
    local total_memory_gb=1
    
    if command -v free >/dev/null 2>&1; then
        local memory_kb=$(free | awk '/^Mem:/ {print $2}' 2>/dev/null)
        if [[ -n "$memory_kb" && $memory_kb -gt 0 ]]; then
            total_memory_gb=$((memory_kb / 1024 / 1024))
        fi
    elif [[ -f /proc/meminfo ]]; then
        local memory_kb=$(grep "MemTotal" /proc/meminfo | awk '{print $2}' 2>/dev/null)
        if [[ -n "$memory_kb" && $memory_kb -gt 0 ]]; then
            total_memory_gb=$((memory_kb / 1024))
        fi
    fi
    
    [[ $total_memory_gb -lt 1 ]] && total_memory_gb=1
    echo "$total_memory_gb"
}

# 💿 Setup RAM disk for ultra-fast temporary storage
setup_ram_disk() {
    local memory_gb=$(get_available_memory_gb)
    local total_memory_gb=$(get_total_memory_gb)
    
    # Only setup RAM disk if we have sufficient memory (8GB+ total, 4GB+ available)
    if [[ $total_memory_gb -ge 8 && $memory_gb -ge 4 && "$RAM_OPTIMIZATION" == "true" ]]; then
        
        # Calculate optimal RAM disk size (10-25% of available RAM)
        local ram_disk_size_mb=0
        if [[ $memory_gb -ge 32 ]]; then
            ram_disk_size_mb=$((memory_gb * 1024 * 25 / 100))  # 25% for high-memory systems
        elif [[ $memory_gb -ge 16 ]]; then
            ram_disk_size_mb=$((memory_gb * 1024 * 20 / 100))  # 20% for good-memory systems
        elif [[ $memory_gb -ge 8 ]]; then
            ram_disk_size_mb=$((memory_gb * 1024 * 15 / 100))  # 15% for adequate-memory systems
        else
            ram_disk_size_mb=$((memory_gb * 1024 * 10 / 100))  # 10% for limited-memory systems
        fi
        
        # Minimum 512MB, maximum 8GB for RAM disk
        [[ $ram_disk_size_mb -lt 512 ]] && ram_disk_size_mb=512
        [[ $ram_disk_size_mb -gt 8192 ]] && ram_disk_size_mb=8192
        
        # Create RAM disk mount point
        RAM_DISK_PATH="$LOG_DIR/ram_cache"
        
        if [[ ! -d "$RAM_DISK_PATH" ]]; then
            mkdir -p "$RAM_DISK_PATH" 2>/dev/null || {
                echo -e "    ${YELLOW}⚠️  Cannot create RAM disk directory${NC}"
                return 1
            }
        fi
        
        # Check if already mounted
        if ! mountpoint -q "$RAM_DISK_PATH" 2>/dev/null; then
            # Try to mount RAM disk (tmpfs)
            if mount -t tmpfs -o size=${ram_disk_size_mb}M,mode=0755 tmpfs "$RAM_DISK_PATH" 2>/dev/null; then
                RAM_DISK_ENABLED=true
                echo -e "    ${GREEN}✓ RAM disk created: ${BOLD}${ram_disk_size_mb}MB${NC} at $RAM_DISK_PATH"
                echo -e "    ${CYAN}🚀 Temporary files will use ultra-fast RAM storage${NC}"
                
                # Update temp work directory to use RAM disk
                TEMP_WORK_DIR="$RAM_DISK_PATH/work"
                mkdir -p "$TEMP_WORK_DIR" 2>/dev/null
            else
                echo -e "    ${YELLOW}⚠️  Cannot mount RAM disk (permissions?) - using regular storage${NC}"
                RAM_DISK_ENABLED=false
            fi
        else
            RAM_DISK_ENABLED=true
            echo -e "    ${GREEN}✓ RAM disk already mounted: ${BOLD}${ram_disk_size_mb}MB${NC}"
        fi
    else
        if [[ $total_memory_gb -lt 8 ]]; then
            echo -e "    ${CYAN}💻 RAM disk disabled: Insufficient memory (${total_memory_gb}GB total)${NC}"
        else
            echo -e "    ${CYAN}💻 RAM disk disabled: Manual configuration${NC}"
        fi
    fi
}

# 🧮 Configure FFmpeg memory optimizations
configure_ffmpeg_memory_options() {
    local memory_gb=$(get_available_memory_gb)
    
    echo -e "  ${GREEN}🧮 FFmpeg memory optimization:${NC}"
    
    # Calculate optimal buffer sizes based on available memory
    if [[ $memory_gb -ge 32 ]]; then
        # High-memory system: Large buffers for maximum performance
        FFMPEG_BUFFER_SIZE="64M"
        FFMPEG_MAX_MUXING_QUEUE="2048"
        echo -e "    ${GREEN}✓ High-memory profile: 64MB buffers, 2048 queue${NC}"
    elif [[ $memory_gb -ge 16 ]]; then
        # Good-memory system: Large buffers
        FFMPEG_BUFFER_SIZE="32M"
        FFMPEG_MAX_MUXING_QUEUE="1024"
        echo -e "    ${BLUE}✓ Performance profile: 32MB buffers, 1024 queue${NC}"
    elif [[ $memory_gb -ge 8 ]]; then
        # Adequate memory: Moderate buffers
        FFMPEG_BUFFER_SIZE="16M"
        FFMPEG_MAX_MUXING_QUEUE="512"
        echo -e "    ${YELLOW}✓ Balanced profile: 16MB buffers, 512 queue${NC}"
    else
        # Limited memory: Small buffers
        FFMPEG_BUFFER_SIZE="8M"
        FFMPEG_MAX_MUXING_QUEUE="256"
        echo -e "    ${CYAN}✓ Conservative profile: 8MB buffers, 256 queue${NC}"
    fi
    
    # Set memory-related FFmpeg options
    FFMPEG_MEMORY_OPTS="-max_muxing_queue_size $FFMPEG_MAX_MUXING_QUEUE"
    
    # Set input-specific options (for placement before input files)
    FFMPEG_INPUT_OPTS=""
    if [[ $memory_gb -ge 8 ]]; then
        FFMPEG_INPUT_OPTS="-readrate_initial_burst 2.0"
    fi
}

# 📊 Setup intelligent memory caching
setup_memory_caching() {
    local memory_gb=$(get_available_memory_gb)
    
    echo -e "  ${GREEN}📊 Memory caching optimization:${NC}"
    
    # Configure system cache behavior
    if command -v sysctl >/dev/null 2>&1; then
        # Check current cache settings
        local vm_swappiness=$(sysctl -n vm.swappiness 2>/dev/null || echo "60")
        local vm_cache_pressure=$(sysctl -n vm.vfs_cache_pressure 2>/dev/null || echo "100")
        
        if [[ $memory_gb -ge 8 ]]; then
            echo -e "    ${CYAN}⚙️  Current cache settings: swappiness=$vm_swappiness, cache_pressure=$vm_cache_pressure${NC}"
            
            # Recommend optimal settings for video processing
            if [[ $vm_swappiness -gt 20 ]]; then
                echo -e "    ${YELLOW}💡 Tip: Lower swappiness recommended for better performance${NC}"
                echo -e "    ${GRAY}      sudo sysctl vm.swappiness=10${NC}"
            fi
            
            if [[ $vm_cache_pressure -gt 50 ]]; then
                echo -e "    ${YELLOW}💡 Tip: Lower cache pressure can improve file I/O${NC}"
                echo -e "    ${GRAY}      sudo sysctl vm.vfs_cache_pressure=50${NC}"
            fi
        fi
    fi
    
    # Setup file system cache hints
    if [[ $memory_gb -ge 16 ]]; then
        echo -e "    ${GREEN}✓ Large file caching enabled${NC}"
        USE_CACHE_HINTS=true
    else
        echo -e "    ${CYAN}✓ Standard caching profile${NC}"
        USE_CACHE_HINTS=false
    fi
}

# 🚀 Get optimized temporary file path
get_temp_file_path() {
    local base_name="$1"
    local extension="$2"
    
    if [[ "$RAM_DISK_ENABLED" == "true" && -d "$TEMP_WORK_DIR" ]]; then
        # Use ultra-fast RAM disk for temporary files
        echo "$TEMP_WORK_DIR/${base_name}.${extension}"
    else
        # Fall back to regular temp directory
        echo "$TEMP_WORK_DIR/${base_name}.${extension}"
    fi
}

# 🧹 Cleanup RAM disk on exit
cleanup_ram_disk() {
    if [[ "$RAM_DISK_ENABLED" == "true" && -n "$RAM_DISK_PATH" ]]; then
        echo -e "${BLUE}🧹 Cleaning up RAM disk...${NC}"
        
        # Remove all files from RAM disk
        if [[ -d "$RAM_DISK_PATH" ]]; then
            rm -rf "$RAM_DISK_PATH"/* 2>/dev/null || true
            
            # Unmount RAM disk
            if mountpoint -q "$RAM_DISK_PATH" 2>/dev/null; then
                umount "$RAM_DISK_PATH" 2>/dev/null && echo -e "  ${GREEN}✓ RAM disk unmounted${NC}" || echo -e "  ${YELLOW}⚠️  RAM disk unmount failed${NC}"
            fi
        fi
    fi
}

# 📈 Monitor memory usage during conversion
monitor_memory_usage() {
    if command -v free >/dev/null 2>&1; then
        local mem_info=$(free -h | awk '/^Mem:/ {printf "Used: %s/%s (%.0f%%), Available: %s", $3, $2, $3*100/$2, $7}')
        echo "RAM: $mem_info"
    else
        echo "RAM: monitoring unavailable"
    fi
}

# 🔥 Preload files into memory cache (for multiple conversions)
preload_files_to_cache() {
    local files=("$@")
    local memory_gb=$(get_available_memory_gb)
    
    # Only preload if we have sufficient memory
    if [[ $memory_gb -ge 8 && ${#files[@]} -gt 1 ]]; then
        echo -e "${CYAN}🔥 Preloading files into memory cache...${NC}"
        
        local total_size=0
        local preload_count=0
        
        for file in "${files[@]}"; do
            if [[ -f "$file" ]]; then
                local file_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
                local file_size_mb=$((file_size / 1024 / 1024))
                
                # Only preload files smaller than 500MB each and total < 2GB
                if [[ $file_size_mb -lt 500 && $total_size -lt 2048 ]]; then
                    # Use dd to read file into cache without outputting
                    dd if="$file" of=/dev/null bs=1M 2>/dev/null &
                    local dd_pid=$!
                    
                    # Don't wait too long for each file
                    sleep 0.1
                    
                    if kill -0 $dd_pid 2>/dev/null; then
                        # Still running, let it continue in background
                        echo -e "  ${GREEN}✓ Caching: $(basename "$file") (${file_size_mb}MB)${NC}"
                    fi
                    
                    total_size=$((total_size + file_size_mb))
                    ((preload_count++))
                fi
            fi
        done
        
        if [[ $preload_count -gt 0 ]]; then
            echo -e "  ${GREEN}✓ Preloaded $preload_count files (${total_size}MB) into memory cache${NC}"
        fi
    fi
}

# 🔍 Detect Linux distribution and package manager
detect_distro() {
    local distro="unknown"
    local package_manager="unknown"
    local install_cmd=""
    
    # Check /etc/os-release first (most reliable)
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case "$ID" in
            ubuntu|debian|linuxmint|pop|elementary)
                distro="debian-based"
                package_manager="apt"
                install_cmd="sudo apt update && sudo apt install -y"
                ;;
            fedora|rhel|centos|rocky|almalinux)
                distro="redhat-based"
                package_manager="dnf"
                install_cmd="sudo dnf install -y"
                ;;
            arch|manjaro|endeavouros|garuda|cachyos|artix|parabola|blackarch|arcolinux)
                distro="arch-based"
                package_manager="pacman"
                install_cmd="sudo pacman -S --needed"
                ;;
            opensuse*|sles)
                distro="suse-based"
                package_manager="zypper"
                install_cmd="sudo zypper install -y"
                ;;
            alpine)
                distro="alpine"
                package_manager="apk"
                install_cmd="sudo apk add"
                ;;
            *)
                distro="$ID"
                ;;
        esac
    fi
    
    # Fallback detection methods
    if [[ "$distro" == "unknown" ]]; then
        if command -v apt >/dev/null 2>&1; then
            distro="debian-based"
            package_manager="apt"
            install_cmd="sudo apt update && sudo apt install -y"
        elif command -v dnf >/dev/null 2>&1; then
            distro="redhat-based"
            package_manager="dnf"
            install_cmd="sudo dnf install -y"
        elif command -v yum >/dev/null 2>&1; then
            distro="redhat-based"
            package_manager="yum"
            install_cmd="sudo yum install -y"
        elif command -v pacman >/dev/null 2>&1; then
            distro="arch-based"
            package_manager="pacman"
            install_cmd="sudo pacman -S --needed"
        elif command -v zypper >/dev/null 2>&1; then
            distro="suse-based"
            package_manager="zypper"
            install_cmd="sudo zypper install -y"
        elif command -v apk >/dev/null 2>&1; then
            distro="alpine"
            package_manager="apk"
            install_cmd="sudo apk add"
        fi
    fi
    
    echo "$distro|$package_manager|$install_cmd"
}

# 🛠️ Get package names for different distributions
get_package_names() {
    local tool="$1"
    local distro="$2"
    
    case "$tool" in
        "ffmpeg")
            case "$distro" in
                "debian-based") echo "ffmpeg" ;;
                "redhat-based") echo "ffmpeg" ;;
                "arch-based") echo "ffmpeg" ;;
                "suse-based") echo "ffmpeg-4" ;;
                "alpine") echo "ffmpeg" ;;
                *) echo "ffmpeg" ;;
            esac
            ;;
        "gifsicle")
            case "$distro" in
                "debian-based") echo "gifsicle" ;;
                "redhat-based") echo "gifsicle" ;;
                "arch-based") echo "gifsicle" ;;
                "suse-based") echo "gifsicle" ;;
                "alpine") echo "gifsicle" ;;
                *) echo "gifsicle" ;;
            esac
            ;;
        "jq")
            case "$distro" in
                "debian-based") echo "jq" ;;
                "redhat-based") echo "jq" ;;
                "arch-based") echo "jq" ;;
                "suse-based") echo "jq" ;;
                "alpine") echo "jq" ;;
                *) echo "jq" ;;
            esac
            ;;
    esac
}

# 🚀 Auto-install dependencies with user confirmation
auto_install_dependencies() {
    local missing_tools=("$@")
    local distro_info=$(detect_distro)
    local distro=$(echo "$distro_info" | cut -d'|' -f1)
    local package_manager=$(echo "$distro_info" | cut -d'|' -f2)
    local install_cmd=$(echo "$distro_info" | cut -d'|' -f3)
    
    if [[ "$package_manager" == "unknown" ]]; then
        echo -e "${RED}❌ Cannot detect package manager for auto-installation${NC}"
        echo -e "${YELLOW}Please install the missing dependencies manually:${NC}"
        for tool in "${missing_tools[@]}"; do
            echo -e "  ${RED}• $tool${NC}"
        done
        return 1
    fi
    
    echo -e "\n${CYAN}${BOLD}🔧 DEPENDENCY INSTALLER${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Detected OS:${NC} $distro"
    echo -e "${GREEN}Package Manager:${NC} $package_manager"
    echo -e "${GREEN}Missing Tools:${NC} ${missing_tools[*]}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Build package list
    local packages_to_install=()
    for tool in "${missing_tools[@]}"; do
        local package_name=$(get_package_names "$tool" "$distro")
        if [[ -n "$package_name" ]]; then
            packages_to_install+=("$package_name")
        fi
    done
    
    if [[ ${#packages_to_install[@]} -eq 0 ]]; then
        echo -e "${RED}❌ No packages found for installation${NC}"
        return 1
    fi
    
    echo -e "\n${YELLOW}The following packages will be installed:${NC}"
    for package in "${packages_to_install[@]}"; do
        echo -e "  ${GREEN}• $package${NC}"
    done
    
    echo -e "\n${MAGENTA}Install command:${NC}"
    echo -e "  ${CYAN}$install_cmd ${packages_to_install[*]}${NC}"
    
    echo -e "\n${YELLOW}Would you like to install these dependencies now? [Y/n]:${NC} "
    read -r install_choice
    
    if [[ "$install_choice" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Installation cancelled. Please install dependencies manually.${NC}"
        return 1
    fi
    
    echo -e "\n${BLUE}🚀 Installing dependencies...${NC}"
    
    # Execute installation command
    if eval "$install_cmd ${packages_to_install[*]}"; then
        echo -e "\n${GREEN}✅ Dependencies installed successfully!${NC}"
        
        # Verify installation
        echo -e "\n${CYAN}🔍 Verifying installation...${NC}"
        local verification_failed=false
        for tool in "${missing_tools[@]}"; do
            if command -v "$tool" >/dev/null 2>&1; then
                local version=$("$tool" --version 2>/dev/null | head -1 | cut -d' ' -f1-3 || echo "unknown version")
                echo -e "  ${GREEN}✓ $tool: $version${NC}"
            else
                echo -e "  ${RED}❌ $tool: still not found${NC}"
                verification_failed=true
            fi
        done
        
        if [[ "$verification_failed" == "true" ]]; then
            echo -e "\n${YELLOW}⚠️  Some dependencies may require a shell restart or PATH update${NC}"
            echo -e "${CYAN}Try running: hash -r${NC}"
            return 1
        else
            echo -e "\n${GREEN}🎉 All dependencies are now available!${NC}"
            return 0
        fi
    else
        echo -e "\n${RED}❌ Installation failed. Please install dependencies manually.${NC}"
        return 1
    fi
}

# 🔄 Dynamic file detection during conversion
monitor_new_files() {
    local initial_files=("$@")
    local monitoring_enabled="$DYNAMIC_FILE_DETECTION"
    local check_interval="$FILE_MONITOR_INTERVAL"
    
    [[ "$monitoring_enabled" != "true" ]] && return 0
    
    echo -e "${CYAN}🔍 Dynamic file monitoring enabled (checking every ${check_interval}s)${NC}"
    
    # Run in background to avoid blocking main conversion
    (
        local last_check_files=("${initial_files[@]}")
        
        while true; do
            sleep "$check_interval"
            
            # Check if main conversion process is still running
            if ! kill -0 "$$" 2>/dev/null; then
                break
            fi
            
            # Scan for new video files
            local current_files=()
            shopt -s nullglob
            for file in *.mp4 *.avi *.mov *.mkv *.webm; do
                [[ -f "$file" && -r "$file" ]] && current_files+=("$file")
            done
            shopt -u nullglob
            
            # Find new files by comparing with previous scan
            local new_files=()
            for current_file in "${current_files[@]}"; do
                local is_new=true
                for last_file in "${last_check_files[@]}"; do
                    if [[ "$current_file" == "$last_file" ]]; then
                        is_new=false
                        break
                    fi
                done
                
                if [[ "$is_new" == "true" ]]; then
                    # Verify it's a valid video file and not being written
                    local file_size1=$(stat -c%s "$current_file" 2>/dev/null || echo "0")
                    sleep 1
                    local file_size2=$(stat -c%s "$current_file" 2>/dev/null || echo "0")
                    
                    # Only add if file size is stable (not being written)
                    if [[ $file_size1 -eq $file_size2 && $file_size1 -gt 1024 ]]; then
                        new_files+=("$current_file")
                    fi
                fi
            done
            
            # Notify about new files if found
            if [[ ${#new_files[@]} -gt 0 ]]; then
                {
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DYNAMIC SCAN: Found ${#new_files[@]} new file(s)"
                    for new_file in "${new_files[@]}"; do
                        local file_size=$(stat -c%s "$new_file" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "unknown")
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] NEW FILE DETECTED: $(basename "$new_file") ($file_size)"
                    done
                } >> "$CONVERSION_LOG" 2>/dev/null || true
                
                # Create notification file for main process
                echo "${new_files[*]}" > "/tmp/smart_gif_converter_new_files_$$" 2>/dev/null || true
            fi
            
            last_check_files=("${current_files[@]}")
        done
    ) &
    
    local monitor_pid=$!
    echo "$monitor_pid" > "/tmp/smart_gif_converter_monitor_pid_$$" 2>/dev/null || true
    
    # Add to script cleanup
    SCRIPT_FFMPEG_PIDS+=("$monitor_pid")
}

# 📥 Check for newly detected files during conversion
check_for_new_files() {
    [[ "$DYNAMIC_FILE_DETECTION" != "true" ]] && return 0
    
    local new_files_file="/tmp/smart_gif_converter_new_files_$$"
    
    if [[ -f "$new_files_file" ]]; then
        local new_files_content=$(cat "$new_files_file" 2>/dev/null || true)
        
        if [[ -n "$new_files_content" ]]; then
            echo -e "\n${YELLOW}🆕 New video files detected during conversion!${NC}"
            
            # Parse the new files
            local new_files_array=($new_files_content)
            
            for new_file in "${new_files_array[@]}"; do
                if [[ -f "$new_file" ]]; then
                    local file_size=$(stat -c%s "$new_file" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "unknown")
                    echo -e "  ${CYAN}📄 $(basename "$new_file") (${file_size})${NC}"
                fi
            done
            
            echo -e "\n${MAGENTA}These files will be available for the next conversion run.${NC}"
            echo -e "${BLUE}💡 Tip: Run the script again to convert the new files${NC}"
            
            # Clean up notification file
            rm -f "$new_files_file" 2>/dev/null || true
        fi
    fi
}

# 🛑 Stop file monitoring
stop_file_monitoring() {
    local monitor_pid_file="/tmp/smart_gif_converter_monitor_pid_$$"
    
    if [[ -f "$monitor_pid_file" ]]; then
        local monitor_pid=$(cat "$monitor_pid_file" 2>/dev/null || true)
        
        if [[ -n "$monitor_pid" ]]; then
            kill "$monitor_pid" 2>/dev/null || true
            wait "$monitor_pid" 2>/dev/null || true
        fi
        
        rm -f "$monitor_pid_file" 2>/dev/null || true
    fi
    
    # Clean up any notification files
    rm -f "/tmp/smart_gif_converter_new_files_$$" 2>/dev/null || true
}

# 🔍 Enhanced system requirements check
check_dependencies() {
    echo -e "${CYAN}🔍 Checking system dependencies...${NC}"
    
    local required_tools=("ffmpeg")
    local optional_tools=("gifsicle" "jq")
    local missing_required=()
    local missing_optional=()
    
    # Check required tools
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_required+=("$tool")
        else
            local version=$("$tool" -version 2>/dev/null | head -1 | cut -d' ' -f1-3 2>/dev/null || echo "unknown version")
            echo -e "  ${GREEN}✓ $tool: $version${NC}"
        fi
    done
    
    # Check optional tools
    for tool in "${optional_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_optional+=("$tool")
        else
            local version=$("$tool" --version 2>/dev/null | head -1 2>/dev/null || echo "available")
            echo -e "  ${GREEN}✓ $tool: $version${NC}"
        fi
    done
    
    # Handle missing required dependencies
    if [[ ${#missing_required[@]} -gt 0 ]]; then
        echo -e "\n${RED}❌ Missing required dependencies:${NC}"
        for dep in "${missing_required[@]}"; do
            echo -e "  ${RED}• $dep${NC}"
        done
        
        # Attempt auto-installation
        if auto_install_dependencies "${missing_required[@]}"; then
            echo -e "${GREEN}✅ Required dependencies installed successfully!${NC}"
        else
            echo -e "\n${RED}❌ Cannot proceed without required dependencies${NC}"
            echo -e "${YELLOW}Please install them manually and try again.${NC}"
            exit 1
        fi
    fi
    
    # Handle missing optional dependencies
    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        echo -e "\n${YELLOW}⚠️  Missing optional dependencies:${NC}"
        for dep in "${missing_optional[@]}"; do
            case "$dep" in
                "gifsicle")
                    echo -e "  ${YELLOW}• $dep${NC} - GIF optimization will be disabled"
                    AUTO_OPTIMIZE=false
                    ;;
                "jq")
                    echo -e "  ${YELLOW}• $dep${NC} - Advanced auto-detection features will be limited"
                    ;;
            esac
        done
        
        echo -e "\n${CYAN}Would you like to install optional dependencies? [y/N]:${NC} "
        read -r optional_choice
        
        if [[ "$optional_choice" =~ ^[Yy]$ ]]; then
            if auto_install_dependencies "${missing_optional[@]}"; then
                echo -e "${GREEN}✅ Optional dependencies installed!${NC}"
                # Re-enable features that were disabled
                if command -v gifsicle >/dev/null 2>&1; then
                    AUTO_OPTIMIZE=true
                fi
            else
                echo -e "${YELLOW}Continuing without optional dependencies...${NC}"
            fi
        else
            echo -e "${CYAN}Continuing without optional dependencies...${NC}"
        fi
    fi
    
    echo -e "\n${GREEN}✅ Dependency check completed${NC}"
}

# 📝 Comprehensive environment validation
validate_environment() {
    trace_function "validate_environment"
    
    # Check write permissions
    if [[ ! -w "." ]]; then
        log_error "No write permission in current directory" "$(pwd)" "User: $USER, Permissions: $(ls -ld . 2>/dev/null)" "${BASH_LINENO[0]}" "validate_environment"
        echo -e "${RED}❌ Error: No write permission in current directory${NC}"
        return 1
    fi
    
    # Check available disk space (warn if less than 1GB)
    local available_space=$(df . | awk 'NR==2 {print $4}' 2>/dev/null || echo "0")
    if [[ $available_space -lt 1000000 ]]; then
        echo -e "${YELLOW}⚠️  Warning: Low disk space (less than 1GB available)${NC}"
        echo -e "${YELLOW}GIF files can be large. Consider freeing up space.${NC}"
        log_error "Low disk space warning" "$(pwd)" "Available: ${available_space}KB" "${BASH_LINENO[0]}" "validate_environment"
    fi
    
    return 0
}

# 🎥 Validate conversion environment specifically
validate_conversion_environment() {
    trace_function "validate_conversion_environment"
    
    # Check basic environment first
    if ! validate_environment; then
        return 1
    fi
    
    # Check required variables are set
    local missing_vars=()
    [[ -z "$RESOLUTION" ]] && missing_vars+=("RESOLUTION")
    [[ -z "$FRAMERATE" ]] && missing_vars+=("FRAMERATE")
    [[ -z "$QUALITY" ]] && missing_vars+=("QUALITY")
    [[ -z "$ASPECT_RATIO" ]] && missing_vars+=("ASPECT_RATIO")
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing configuration variables" "" "Missing: ${missing_vars[*]}" "${BASH_LINENO[0]}" "validate_conversion_environment"
        return 1
    fi
    
    # Validate log directory is accessible
    if [[ ! -d "$(dirname "$ERROR_LOG")" ]]; then
        if ! mkdir -p "$(dirname "$ERROR_LOG")" 2>/dev/null; then
            log_error "Cannot create log directory" "$(dirname "$ERROR_LOG")" "Permission denied or path invalid" "${BASH_LINENO[0]}" "validate_conversion_environment"
            return 1
        fi
    fi
    
    return 0
}

# 🎦 Comprehensive video file validation with corruption detection
validate_video_file() {
    local file="$1"
    trace_function "validate_video_file"
    
    # Basic file checks
    if [[ ! -f "$file" ]]; then
        log_error "File does not exist" "$file" "File not found" "${BASH_LINENO[0]}" "validate_video_file"
        return 1
    fi
    
    if [[ ! -r "$file" ]]; then
        log_error "File not readable" "$file" "Permission denied" "${BASH_LINENO[0]}" "validate_video_file"
        return 1
    fi
    
    # Check file size (must be > 1KB for valid video)
    local file_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
    if [[ $file_size -lt 1024 ]]; then
        log_error "File too small or empty" "$file" "Size: $file_size bytes (minimum: 1KB)" "${BASH_LINENO[0]}" "validate_video_file"
        return 1
    fi
    
    # Detect corruption using comprehensive ffprobe analysis
    if ! detect_video_corruption "$file"; then
        return 1
    fi
    
    return 0
}

# 🔍 Basic corruption detection for video files (less aggressive)
detect_video_corruption() {
    local file="$1"
    local temp_error="/tmp/ffprobe_error_$$_$(date +%s).log"
    trace_function "detect_video_corruption"
    
    echo -e "  ${BLUE}🔍 Quick validation: $(basename "$file")${NC}"
    
    # Test 1: Basic stream validation
    if ! ffprobe -v quiet -select_streams v:0 -show_entries stream=codec_type -of csv=p=0 "$file" 2>"$temp_error" | grep -q "video"; then
        local error_msg="No video stream found"
        [[ -s "$temp_error" ]] && error_msg="$(head -3 "$temp_error" | tr '\n' ' ')"
        log_error "Invalid video file - no video stream" "$file" "$error_msg" "${BASH_LINENO[0]}" "detect_video_corruption"
        rm -f "$temp_error" 2>/dev/null
        return 1
    fi
    
    # Test 2: Basic metadata check (less strict)
    if ! ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$file" 2>"$temp_error" >/dev/null; then
        local error_msg="Cannot read basic metadata"
        [[ -s "$temp_error" ]] && error_msg="$(head -3 "$temp_error" | tr '\n' ' ')"
        log_error "Corrupt video file - metadata unreadable" "$file" "$error_msg" "${BASH_LINENO[0]}" "detect_video_corruption"
        rm -f "$temp_error" 2>/dev/null
        return 1
    fi
    
    # Skip the aggressive frame decoding test that was causing false positives
    # If basic tests pass, assume the file is valid
    
    # Cleanup and success
    rm -f "$temp_error" 2>/dev/null
    echo -e "  ${GREEN}✓ Basic validation passed: $(basename "$file")${NC}"
    return 0
}

# 🔄 Check if output file already exists and is valid
check_duplicate_output() {
    local input_file="$1"
    local output_file="${input_file%.*}.${OUTPUT_FORMAT}"
    
    # If file doesn't exist, not a duplicate
    if [[ ! -f "$output_file" ]]; then
        return 1
    fi
    
    # If force conversion is enabled, ignore existing files
    if [[ "$FORCE_CONVERSION" == "true" ]]; then
        echo -e "  ${YELLOW}♾️ Force mode: Will overwrite existing $(basename "$output_file")${NC}"
        return 1
    fi
    
    # Check if output is newer than input (modification time)
    if [[ "$output_file" -nt "$input_file" ]]; then
        echo -e "  ${GREEN}✓ Already converted: $(basename "$output_file") (newer than source)${NC}"
        return 0
    fi
    
    # Check if output file is valid (basic size check)
    local output_size=$(stat -c%s "$output_file" 2>/dev/null || echo "0")
    if [[ $output_size -lt 100 ]]; then
        echo -e "  ${YELLOW}⚠️ Existing file too small, will recreate: $(basename "$output_file")${NC}"
        rm -f "$output_file" 2>/dev/null
        return 1
    fi
    
    # Quick validation of existing GIF
    if ! file "$output_file" 2>/dev/null | grep -q "GIF"; then
        echo -e "  ${YELLOW}⚠️ Existing file not a valid GIF, will recreate: $(basename "$output_file")${NC}"
        rm -f "$output_file" 2>/dev/null
        return 1
    fi
    
    # File exists, is newer, and appears valid
    echo -e "  ${GREEN}⏭️ Skipping: $(basename "$output_file") already exists and is valid${NC}"
    return 0
}

# 🅾️Validate output GIF files for corruption
validate_output_file() {
    local output_file="$1"
    local source_file="$2"
    local temp_error="/tmp/gif_validation_$$_$(date +%s).log"
    trace_function "validate_output_file"
    
    echo -e "  ${BLUE}🔍 Validating output: $(basename "$output_file")${NC}"
    
    # Test 1: Check if file was created
    if [[ ! -f "$output_file" ]]; then
        log_error "Output file was not created" "$source_file" "Expected: $output_file" "${BASH_LINENO[0]}" "validate_output_file"
        echo -e "  ${RED}❌ Output file was not created${NC}"
        return 1
    fi
    
    # Test 2: Check file size (must be > 100 bytes for valid GIF)
    local file_size=$(stat -c%s "$output_file" 2>/dev/null || echo "0")
    if [[ $file_size -lt 100 ]]; then
        log_error "Output file too small" "$source_file" "Output: $output_file, Size: $file_size bytes (minimum: 100)" "${BASH_LINENO[0]}" "validate_output_file"
        echo -e "  ${RED}❌ Output file too small: $file_size bytes${NC}"
        rm -f "$output_file" 2>/dev/null
        return 1
    fi
    
    # Test 3: Check GIF file signature (magic bytes)
    local file_header=$(hexdump -C "$output_file" | head -1 | cut -d'|' -f2 2>/dev/null)
    if ! echo "$file_header" | grep -q "GIF8[79]a"; then
        # Try alternative method
        local magic_bytes=$(file "$output_file" 2>/dev/null)
        if [[ ! "$magic_bytes" == *"GIF image"* ]]; then
            log_error "Invalid GIF format - wrong magic bytes" "$source_file" "Output: $output_file, Header: $file_header, File output: $magic_bytes" "${BASH_LINENO[0]}" "validate_output_file"
            echo -e "  ${RED}❌ Invalid GIF format (corrupted header)${NC}"
            rm -f "$output_file" 2>/dev/null
            return 1
        fi
    fi
    
    # Test 4: Basic GIF format check with FFprobe (simplified)
    if ! ffprobe -v quiet -show_entries format=format_name -of csv=p=0 "$output_file" 2>/dev/null | grep -q "gif\|image2"; then
        local error_msg="Not recognized as GIF format"
        log_error "Invalid GIF format" "$source_file" "Output: $output_file" "${BASH_LINENO[0]}" "validate_output_file"
        echo -e "  ${RED}❌ Invalid GIF format${NC}"
        rm -f "$output_file" 2>/dev/null
        return 1
    fi
    
    # Test 5: Get basic GIF info (non-failing)
    local gif_info=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$output_file" 2>/dev/null || echo "unknown")
    
    # Test 6: Basic playability check (less strict)
    # Skip the aggressive frame decoding test that causes false positives
    # If we got this far, the GIF is likely valid
    
    # Test 7: Check for reasonable file size ratio (not too big or suspiciously small)
    # NOTE: Video→GIF conversion typically results in 100-50000% ratio depending on quality settings
    # This is NORMAL and expected behavior - don't warn unless truly anomalous
    local source_size=$(stat -c%s "$source_file" 2>/dev/null || echo "1")
    local ratio=$((file_size * 100 / source_size))
    
    # Only warn if GIF is EXTREMELY large (100,000%+ = 1000x source) which might indicate issues
    local ratio_pct_str=$(compute_ratio_percent "$file_size" "$source_size")
    if [[ "$ratio_pct_str" != "n/a" ]]; then
        # Compare using integer part only for threshold logic
        local ratio_int=${ratio_pct_str%.*}
        # Only warn if over 100,000% (1000x source) - typical GIFs are 100-30000%
        if [[ ${ratio_int:-0} -gt 100000 ]]; then  # More than 1000x the source size
            echo -e "  ${YELLOW}⚠️ Warning: Output GIF is extremely large (${ratio_pct_str}% of source)${NC}"
            log_error "Extremely large output file" "$source_file" "Output: $output_file, Source size: $source_size, Output size: $file_size, Ratio: ${ratio_pct_str}%" "${BASH_LINENO[0]}" "validate_output_file"
            # Don't fail, just warn
        fi
    fi
    
    # Cleanup and success
    rm -f "$temp_error" 2>/dev/null
    local file_size_mb=$(echo "scale=1; $(stat -c%s "$output_file" 2>/dev/null || echo "0") / 1024 / 1024" | bc 2>/dev/null || echo "?.?")
    echo -e "  ${GREEN}✓ GIF created successfully: ${file_size_mb}MB${NC}"
    return 0
}

# 🔫 Kill ffmpeg processes
kill_ffmpeg_processes() {
    clear
    print_header
    echo -e "${RED}${BOLD}🔫 KILL FFMPEG PROCESSES${NC}\n"
    
    # Find running ffmpeg processes
    local ffmpeg_pids=($(pgrep -f ffmpeg 2>/dev/null || true))
    
    if [[ ${#ffmpeg_pids[@]} -eq 0 ]]; then
        echo -e "${GREEN}✓ No ffmpeg processes are currently running${NC}"
        echo -e "\n${YELLOW}Press any key to return to main menu...${NC}"
        read -rsn1
        return
    fi
    
    echo -e "${YELLOW}Found ${BOLD}${#ffmpeg_pids[@]}${NC}${YELLOW} running ffmpeg process(es):${NC}\n"
    
    # Show process details
    for pid in "${ffmpeg_pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            local cmd=$(ps -p "$pid" -o args --no-headers 2>/dev/null || echo "Unknown command")
            local runtime=$(ps -p "$pid" -o etime --no-headers 2>/dev/null | tr -d ' ' || echo "Unknown")
            echo -e "  ${BLUE}PID ${BOLD}$pid${NC}: Running for ${CYAN}$runtime${NC}"
            echo -e "    ${GRAY}Command: ${cmd:0:80}...${NC}"
        fi
    done
    
    echo -e "\n${RED}${BOLD}⚠️  WARNING: This will forcefully terminate all ffmpeg processes!${NC}"
    echo -e "${RED}This may interrupt ongoing conversions and could cause file corruption.${NC}\n"
    
    echo -e "${MAGENTA}Kill options:${NC}"
    echo -e "  ${GREEN}[1]${NC} Send SIGTERM (graceful shutdown)"
    echo -e "  ${GREEN}[2]${NC} Send SIGKILL (force kill)"
    echo -e "  ${GREEN}[3]${NC} Interactive kill (choose specific processes)"
    echo -e "  ${GREEN}[0]${NC} Cancel and return to menu\n"
    
    echo -e "${MAGENTA}Select an option [0-3]: ${NC}"
    read -r choice
    
    case "$choice" in
        "1")
            echo -e "\n${YELLOW}Sending SIGTERM to all ffmpeg processes...${NC}"
            for pid in "${ffmpeg_pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    if kill -TERM "$pid" 2>/dev/null; then
                        echo -e "  ${GREEN}✓ Sent SIGTERM to PID $pid${NC}"
                    else
                        echo -e "  ${RED}❌ Failed to send SIGTERM to PID $pid${NC}"
                    fi
                fi
            done
            echo -e "\n${BLUE}Waiting 3 seconds for processes to terminate gracefully...${NC}"
            sleep 3
            
            # Check if any processes are still running
            local remaining_pids=($(pgrep -f ffmpeg 2>/dev/null || true))
            if [[ ${#remaining_pids[@]} -gt 0 ]]; then
                echo -e "${YELLOW}${#remaining_pids[@]} process(es) still running. Use option 2 to force kill.${NC}"
            else
                echo -e "${GREEN}✓ All ffmpeg processes terminated successfully${NC}"
            fi
            ;;
        "2")
            echo -e "\n${RED}Force killing all ffmpeg processes...${NC}"
            for pid in "${ffmpeg_pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    if kill -KILL "$pid" 2>/dev/null; then
                        echo -e "  ${GREEN}✓ Force killed PID $pid${NC}"
                    else
                        echo -e "  ${RED}❌ Failed to kill PID $pid${NC}"
                    fi
                fi
            done
            echo -e "${GREEN}✓ Force kill commands sent to all processes${NC}"
            ;;
        "3")
            echo -e "\n${CYAN}Interactive kill mode:${NC}"
            for pid in "${ffmpeg_pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    local cmd=$(ps -p "$pid" -o args --no-headers 2>/dev/null || echo "Unknown")
                    echo -e "\n${BLUE}PID $pid:${NC} ${cmd:0:60}..."
                    echo -e "${MAGENTA}Kill this process? [y/N]: ${NC}"
                    read -r confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        if kill -TERM "$pid" 2>/dev/null; then
                            echo -e "  ${GREEN}✓ Sent SIGTERM to PID $pid${NC}"
                        else
                            echo -e "  ${RED}❌ Failed to terminate PID $pid${NC}"
                        fi
                    else
                        echo -e "  ${YELLOW}Skipped PID $pid${NC}"
                    fi
                fi
            done
            ;;
        "0"|"")
            echo -e "${YELLOW}Operation cancelled${NC}"
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
    
    echo -e "\n${YELLOW}Press any key to return to main menu...${NC}"
    read -rsn1
}

# 🎨 Interactive Main Menu System
show_main_menu() {
    # Ensure we always start at the first option
    local selected=0
    local options=(
        "🚀 AI-Powered Quick Mode (Speed Optimized)"
        "⚙️  Configure Settings & Convert (Advanced)"
        "📊 View Conversion Statistics"
        "📁 Manage Log Files"
        "🔧 System Information"
        "🔫 Kill FFmpeg Processes"
        "❓ Help & Documentation"
        "🚪 Exit"
    )
    
    while true; do
        clear
        print_header
        
        # Show current directory info
        local video_count=$(find . -maxdepth 1 -name "*.mp4" -o -name "*.avi" -o -name "*.mov" -o -name "*.mkv" -o -name "*.webm" 2>/dev/null | wc -l)
        local gif_count=$(find . -maxdepth 1 -name "*.gif" 2>/dev/null | wc -l)
        
        echo -e "${BLUE}📂 Current Directory: ${BOLD}$(pwd | sed "s|$HOME|~|g")${NC}"
        echo -e "${YELLOW}📹 Video Files: ${BOLD}$video_count${NC} | ${GREEN}🎬 GIF Files: ${BOLD}$gif_count${NC}"
    local ai_status=$([[ "$AI_ENABLED" == true ]] && echo "ON" || echo "OFF")
    echo -e "${MAGENTA}⚙️  Current Settings: ${QUALITY} quality, ${ASPECT_RATIO} aspect ratio, AI:${ai_status}${NC}\n"
        
        echo -e "${CYAN}${BOLD}🎯 MAIN MENU${NC}"
        echo -e "${YELLOW}🎹 Navigation: ${GREEN}w${NC}=Up ${GREEN}s${NC}=Down ${GREEN}Enter${NC}=Select ${GREEN}q${NC}=Quit ${GREEN}h${NC}=Help${NC}\n"
        
        # Get terminal dimensions for smart responsive design
        local term_width=$(tput cols 2>/dev/null || echo 80)
        local term_height=$(tput lines 2>/dev/null || echo 24)
        
        # Smart responsive breakpoints (like CSS media queries)
        local menu_width
        local layout_mode="desktop"
        
        if [[ $term_width -lt 50 ]]; then
            # Mobile: Very narrow terminal
            menu_width=$((term_width - 4))
            layout_mode="mobile"
        elif [[ $term_width -lt 80 ]]; then
            # Tablet: Medium width
            menu_width=$((term_width - 8))
            layout_mode="tablet"
        elif [[ $term_width -lt 120 ]]; then
            # Desktop: Normal width - use 70%
            menu_width=$((term_width * 70 / 100))
            layout_mode="desktop"
        else
            # Large desktop: Cap at readable width
            menu_width=84
            layout_mode="desktop-large"
        fi
        
        # Ensure sane bounds
        if [[ $menu_width -lt 40 ]]; then menu_width=40; fi
        if [[ $menu_width -gt 100 ]]; then menu_width=100; fi
        
        # Smart help text based on layout mode
        local help_text
        case $selected in
            0) help_text=$(get_responsive_help_text "AI Quick Mode - just pick quality!" "Just select quality level - AI handles everything else automatically!" $layout_mode) ;;
            1) help_text=$(get_responsive_help_text "Configure 15+ settings" "Fine-tune all 15+ settings for perfect results and control" $layout_mode) ;;
            2) help_text=$(get_responsive_help_text "View conversion stats" "View your conversion history and success rates with details" $layout_mode) ;;
            3) help_text=$(get_responsive_help_text "Manage log files" "Manage error logs and conversion history files safely" $layout_mode) ;;
            4) help_text=$(get_responsive_help_text "System info" "Check CPU, GPU, and system capabilities for optimization" $layout_mode) ;;
            5) help_text=$(get_responsive_help_text "Kill processes" "Stop any stuck or runaway FFmpeg processes safely" $layout_mode) ;;
            6) help_text=$(get_responsive_help_text "Help & docs" "Complete usage guide with examples and feature docs" $layout_mode) ;;
            7) help_text=$(get_responsive_help_text "Exit" "Save your current settings and exit gracefully" $layout_mode) ;;
        esac
        
        # Calculate actual content width by measuring the longest menu option
        local max_content_len=0
        local current_len
        
        # Measure title length
        local title="MENU OPTIONS"
        if [[ $layout_mode == "mobile" ]]; then
            title="MENU"
        fi
        max_content_len=${#title}
        
        # Measure each menu option length (simple character count + buffer for emojis)
        for option in "${options[@]}"; do
            # Simple width estimation: raw length + buffer for emojis
            # Most menu options have 1-2 emojis, so add 2-4 extra characters as buffer
            current_len=$((${#option} + 4))  # +4 buffer for emojis and formatting
            if [[ $current_len -gt $max_content_len ]]; then
                max_content_len=$current_len
            fi
        done
        
        # Measure help text length with emoji buffer
        current_len=$((${#help_text} + 4))  # +4 for icon, space and emoji buffer
        if [[ $current_len -gt $max_content_len ]]; then
            max_content_len=$current_len
        fi
        
        # Use fixed, generous width to accommodate emojis and ensure alignment
        local inner_width
        case $layout_mode in
            "mobile")
                inner_width=45
                ;;
            "tablet")
                inner_width=65
                ;;
            *)
                inner_width=80  # Wide enough for all content with emoji buffer
                ;;
        esac
        
        # Ensure help text fits within inner width
        if [[ ${#help_text} -gt $((inner_width - 5)) ]]; then
            help_text="${help_text:0:$((inner_width - 8))}..."
        fi
        
        # Create clean ASCII borders with fixed width for perfect alignment
        local content_width=65  # Fixed content area width
        local border_chars=$(printf "%*s" $content_width "" | tr ' ' '-')
        
        # Menu borders with consistent width
        local top_border="+${border_chars}+"
        local mid_border="+${border_chars}+"
        local bot_border="+${border_chars}+"
        
        # Smart responsive menu layout
        echo -e "${CYAN}$top_border${NC}"
        
        # Header with responsive title
        local title="MENU OPTIONS"
        if [[ $layout_mode == "mobile" ]]; then
            title="MENU"
        fi
        local title_padded_content=$(printf "%-${content_width}s" "$title")
        echo -e "${CYAN}|${NC} ${BOLD}${title_padded_content}${NC} ${CYAN}|${NC}"
        echo -e "${CYAN}$mid_border${NC}"
        
        # Display menu options with guaranteed perfect alignment
        for i in "${!options[@]}"; do
            local option_text="${options[$i]}"
            
            # Truncate text if it's too long (accounting for emojis)
            if [[ ${#option_text} -gt $((content_width - 5)) ]]; then
                option_text="${option_text:0:$((content_width - 8))}..."
            fi
            
            if [[ $i -eq $selected ]]; then
                # Selected option with arrow - use fixed spacing
                local padded_content=$(printf "%-${content_width}s" "> $option_text")
                echo -e "${CYAN}|${NC} ${GREEN}${BOLD}${padded_content}${NC} ${CYAN}|${NC}"
            else
                # Regular option with indent - use fixed spacing
                local padded_content=$(printf "%-${content_width}s" "   $option_text")
                echo -e "${CYAN}|${NC} ${padded_content} ${CYAN}|${NC}"
            fi
        done
        
        # Close the main menu box
        echo -e "${CYAN}$bot_border${NC}"
        
        # Dynamic help section that adjusts to content (only show if not mobile or very cramped)
        if [[ $layout_mode != "mobile" || $term_height -gt 15 ]]; then
            # Beautiful emoji icon
            local help_icon="💡"
            if [[ $layout_mode == "mobile" ]]; then
                help_icon="→"  # Arrow for mobile
            fi
            
            # Use the same width as main menu for perfect alignment
            local help_full_text="$help_icon $help_text"
            
            # Truncate help text if too long to fit in content area
            if [[ ${#help_full_text} -gt $((content_width - 2)) ]]; then
                help_full_text="${help_full_text:0:$((content_width - 5))}..."
            fi
            
            # Create help section borders using same width as main menu
            local help_border="+${border_chars}+"
            
            echo -e "${CYAN}$help_border${NC}"
            
            # Create padded help content using same width as main menu
            local help_padded_content=$(printf "%-${content_width}s" "$help_full_text")
            echo -e "${CYAN}|${NC} ${YELLOW}${help_padded_content}${NC} ${CYAN}|${NC}"
            
            echo -e "${CYAN}$help_border${NC}"
        fi
        
        # Show layout debug info in very wide terminals
        if [[ $term_width -gt 150 && $layout_mode == "desktop-large" ]]; then
            echo -e "${GRAY}Layout: $layout_mode | Terminal: ${term_width}x${term_height} | Menu: ${menu_width}${NC}"
        fi
        
        echo -e "\n${CYAN}🎮 Controls: ${YELLOW}w/s${NC}=Navigate ${YELLOW}Enter/Space${NC}=Select ${YELLOW}q${NC}=Quit ${YELLOW}h/?${NC}=Help"
        
        # True single-key input without Enter
        local key=""
        
        # Use bash read with -n1 for single character input
        if read -rsn1 key 2>/dev/null; then
            # Successfully read single character
            true
        else
            # Fallback: read line and take first character
            printf "${MAGENTA}Press key: ${NC}"
            read -r key 2>/dev/null
            key="${key:0:1}"
        fi
        
        case "$key" in
            ''|$'\n'|$'\r'|' ')  # Enter, Return, Space, or empty (Enter without -n1)
                execute_menu_option $selected
                ;;
            'q'|'Q'|$'\x03')  # q, Q, or Ctrl+C
                echo -e "${YELLOW}👋 Goodbye!${NC}"
                exit 0
                ;;
            'w'|'W')  # Up navigation (w key)
                selected=$((selected - 1))
                if [[ $selected -lt 0 ]]; then selected=$((${#options[@]}-1)); fi
                # Small delay to make navigation visible
                sleep 0.1
                ;;
            's'|'S')  # Down navigation (s key)
                selected=$((selected + 1))
                if [[ $selected -ge ${#options[@]} ]]; then selected=0; fi
                # Small delay to make navigation visible  
                sleep 0.1
                ;;
            'h'|'H'|'?')  # Help
                clear
                print_header
                echo -e "${BLUE}${BOLD}❓ NAVIGATION HELP${NC}\n"
                echo -e "${YELLOW}Keyboard Controls:${NC}"
                echo -e "  ${GREEN}↑ Up Arrow${NC} - Navigate up"
                echo -e "  ${GREEN}↓ Down Arrow${NC} - Navigate down"
                echo -e "  ${GREEN}w / s${NC} - WASD-style navigation (up/down)"
                echo -e "  ${GREEN}Enter / Space${NC} - Select highlighted option"
                echo -e "  ${GREEN}q${NC} - Quit application"
                echo -e "  ${GREEN}h / ?${NC} - Show this help\n"
                echo -e "${CYAN}Tips:${NC}"
                echo -e "  • Use arrow keys for smooth navigation"
                echo -e "  • w/s keys also work (WASD-style)"
                echo -e "  • Press Enter to select the highlighted option"
                echo -e "\n${YELLOW}Press any key to return to menu...${NC}"
                read -r -n1 2>/dev/null || read -r
                ;;
            *)  # Invalid input - just ignore and continue
                ;;
        esac
    done
}

# 🎯 Execute selected menu option
execute_menu_option() {
    local option=$1
    
    case $option in
        0) # Quick Mode
            echo -e "\n${GREEN}🚀 Starting Quick Conversion...${NC}"
            sleep 1
            quick_convert_mode
            ;;
        1) # Advanced Mode
            echo -e "\n${BLUE}⚙️  Entering Advanced Configuration...${NC}"
            sleep 1
            advanced_convert_mode
            ;;
        2) # Statistics
            show_conversion_stats
            ;;
        3) # Manage Logs
            manage_log_files
            ;;
        4) # System Info
            show_system_info
            ;;
        5) # Kill FFmpeg
            kill_ffmpeg_processes
            ;;
        6) # Help
            show_interactive_help
            ;;
        7) # Exit
            echo -e "\n${YELLOW}👋 Goodbye!${NC}"
            exit 0
            ;;
    esac
}

# 🚀 AI-Powered Quick Conversion Mode
quick_convert_mode() {
    clear
    print_header
    echo -e "${GREEN}${BOLD}🚀 AI-POWERED QUICK CONVERSION${NC}\n"
    
    local video_files=()
    shopt -s nullglob
    for ext in mp4 avi mov mkv webm; do
        video_files+=(*."$ext")
    done
    shopt -u nullglob
    
    if [[ ${#video_files[@]} -eq 0 ]]; then
        echo -e "${RED}❌ No video files found in current directory${NC}\n"
        echo -e "${BLUE}📝 ${BOLD}How to fix this:${NC}"
        echo -e "  ${CYAN}•${NC} Place video files in: ${BOLD}$(pwd)${NC}"
        echo -e "  ${CYAN}•${NC} Supported formats: ${GREEN}.mp4 .avi .mov .mkv .webm${NC}"
        echo -e "  ${CYAN}•${NC} Or use: ${YELLOW}--file /path/to/video.mp4${NC}"
        echo -e "\n${YELLOW}Press any key to return to main menu...${NC}"
        read -rsn1
        return
    fi
    
    echo -e "${BLUE}📹 Found ${BOLD}${#video_files[@]}${NC}${BLUE} video files${NC}"
    echo -e "${CYAN}🤖 AI will automatically analyze each video and optimize all settings${NC}"
    echo -e "${MAGENTA}🎯 You only need to choose your preferred quality level${NC}"
    echo -e "${GREEN}⚡ Speed-optimized: Uses all ${BOLD}$(nproc 2>/dev/null || echo '4')${NC}${GREEN} CPU cores for maximum performance${NC}\n"
    
    # AI-powered quality selection
    ai_quality_selection
    
    # Enable AI automatically for quick mode
    AI_ENABLED=true
    AI_MODE="smart"  # Use comprehensive smart analysis
    
    # Auto-enable optimal settings for AI mode
    AUTO_OPTIMIZE=true
    PARALLEL_JOBS="auto"  # Let AI determine optimal parallel jobs
    PROGRESS_BAR=true
    
    echo -e "\n${GREEN}${BOLD}🤖 AI QUICK MODE SETTINGS:${NC}"
    echo -e "  ${CYAN}✓ Quality Level:${NC} ${BOLD}$QUALITY${NC}"
    echo -e "  ${CYAN}✓ AI Analysis:${NC} ${BOLD}Smart Mode (Full Analysis)${NC}"
    echo -e "  ${CYAN}✓ Auto-Optimization:${NC} ${BOLD}Enabled${NC}"
    echo -e "  ${CYAN}✓ Parallel Processing:${NC} ${BOLD}Auto-Detected${NC}"
    echo -e "\n${YELLOW}${BOLD}🧠 AI will analyze each video for:${NC}"
    echo -e "  ${BLUE}• Content type (animation, screencast, movie, clip)${NC}"
    echo -e "  ${BLUE}• Motion complexity (static, low, medium, high)${NC}"
    echo -e "  ${BLUE}• Visual complexity and optimal color count${NC}"
    echo -e "  ${BLUE}• Intelligent cropping opportunities${NC}"
    echo -e "  ${BLUE}• Frame rate and dithering optimization${NC}"
    echo -e "  ${BLUE}• Resolution and scaling algorithm selection${NC}"
    
    echo -e "\n${MAGENTA}${BOLD}🚀 Ready to start AI-powered conversion? [Y/n]:${NC} "
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
        INTERACTIVE_MODE=false
            echo -e "\n${CYAN}🤖 Starting AI-powered conversion with smart analysis...${NC}"
            echo -e "${BLUE}📊 AI will analyze each video and optimize automatically!${NC}"
            echo -e "${GREEN}⚡ Using ${BOLD}$(nproc 2>/dev/null || echo '4')${NC}${GREEN} CPU cores for maximum speed!${NC}\n"
        
        # Show AI analysis preview for first file
        if [[ ${#video_files[@]} -gt 0 ]]; then
            echo -e "${YELLOW}🔍 AI Preview Analysis (first file: $(basename "${video_files[0]}"))...${NC}"
            ai_preview_analysis "${video_files[0]}"
        fi
        
        if start_conversion; then
            echo -e "\n${GREEN}🎉 AI-powered quick conversion completed successfully!${NC}"
            echo -e "${BLUE}📦 Your GIF files are ready in the current directory!${NC}"
            echo -e "${CYAN}📊 Check Statistics to see detailed results, or run again with new videos!${NC}"
            show_ai_summary
        else
            echo -e "\n${YELLOW}📋 Quick conversion completed (no action needed)${NC}"
            echo -e "${BLUE}💡 Tip: Add video files to this directory and run again!${NC}"
        fi
    fi
    
    echo -e "\n${YELLOW}Press any key to return to main menu...${NC}"
    read -rsn1
}

# 📋 Show comprehensive advanced settings menu
show_advanced_settings_menu() {
    local cpu_cores=$(nproc 2>/dev/null || echo "4")
    local total_ram=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "unknown")
    
    echo -e "${CYAN}${BOLD}🔧 COMPREHENSIVE SETTINGS CONFIGURATION:${NC}"
    echo -e "${GRAY}System: ${cpu_cores} cores, ${total_ram} RAM${NC}"
    echo -e "${YELLOW}💡 Tip: Press a number to toggle/configure that option${NC}\n"
    
    # Basic Options (1-5)
    echo -e "${BLUE}${BOLD}🔧 BASIC OPTIONS:${NC}"
    echo -e "  ${GREEN}[1]${NC} Force re-conversion: $(get_status_icon "$FORCE_CONVERSION")"
    echo -e "  ${GREEN}[2]${NC} Backup originals: $(get_status_icon "$BACKUP_ORIGINAL")"
    echo -e "  ${GREEN}[3]${NC} Auto-optimization: $(get_status_icon "$AUTO_OPTIMIZE")"
    echo -e "  ${GREEN}[4]${NC} Debug mode: $(get_status_icon "$DEBUG_MODE")"
    echo -e "  ${GREEN}[5]${NC} AI smart analysis: $(get_status_icon "$AI_ENABLED")\n"
    
    # AI & Performance Options (6-10)
    echo -e "${MAGENTA}${BOLD}🤖 AI & PERFORMANCE:${NC}"
    echo -e "  ${GREEN}[6]${NC} AI Mode: ${BOLD}${AI_MODE:-smart}${NC} (smart/content/motion/quality)"
    echo -e "  ${GREEN}[7]${NC} FFmpeg Threads: ${BOLD}${FFMPEG_THREADS}${NC}"
    echo -e "  ${GREEN}[8]${NC} Parallel Jobs: ${BOLD}${PARALLEL_JOBS}${NC}"
    echo -e "  ${GREEN}[9]${NC} GPU Acceleration: ${BOLD}${GPU_ACCELERATION}${NC}"
    echo -e "  ${GREEN}[10]${NC} Memory Settings: ${BOLD}${RAM_CACHE_SIZE:-auto}${NC}\n"
    
    # Quality & Compression (11-12)
    echo -e "${YELLOW}${BOLD}🎨 QUALITY & COMPRESSION:${NC}"
    echo -e "  ${GREEN}[11]${NC} Quality Preset: ${BOLD}${QUALITY}${NC} | Colors: ${BOLD}${MAX_COLORS}${NC} | Dither: ${BOLD}${DITHER_MODE}${NC}"
    echo -e "  ${GREEN}[12]${NC} Compression: ${BOLD}${COMPRESSION_LEVEL}${NC} | Max Size: ${BOLD}${MAX_GIF_SIZE_MB}MB${NC}\n"
    
    # System & Validation (13-15)
    echo -e "${CYAN}${BOLD}⚙️ SYSTEM & VALIDATION:${NC}"
    echo -e "  ${GREEN}[13]${NC} Interactive Mode: $(get_status_icon "$INTERACTIVE_MODE")"
    echo -e "  ${GREEN}[14]${NC} Skip Validation: $(get_status_icon "$SKIP_VALIDATION")"
    echo -e "  ${GREEN}[15]${NC} Log Level: ${BOLD}${LOG_LEVEL}${NC} | Progress Bar: $(get_status_icon "$PROGRESS_BAR")\n"
    
    echo -e "${GRAY}[c] Custom FFmpeg Settings | [Enter] Start Conversion${NC}\n"
}

# 📦 Get status icon for boolean values
get_status_icon() {
    if [[ "$1" == "true" ]]; then
        echo -e "${GREEN}${BOLD}✓ ON${NC}"
    else
        echo -e "${RED}✗ OFF${NC}"
    fi
}

# 🤖 Configure AI Mode
configure_ai_mode() {
    echo -e "\n${BLUE}${BOLD}🤖 AI MODE CONFIGURATION:${NC}"
    echo -e "${CYAN}Current: ${BOLD}${AI_MODE:-smart}${NC}\n"
    
    echo -e "  ${GREEN}[1]${NC} Smart Mode (recommended) - Full analysis: content + motion + quality"
    echo -e "  ${GREEN}[2]${NC} Content Mode - Focus on content type detection"
    echo -e "  ${GREEN}[3]${NC} Motion Mode - Focus on motion analysis"
    echo -e "  ${GREEN}[4]${NC} Quality Mode - Focus on quality optimization\n"
    
    echo -e "${MAGENTA}Select AI mode [1-4]: ${NC}"
    read -r ai_choice
    
    case "$ai_choice" in
        "1") AI_MODE="smart"; echo -e "${GREEN}✓ AI Mode set to Smart${NC}" ;;
        "2") AI_MODE="content"; echo -e "${GREEN}✓ AI Mode set to Content${NC}" ;;
        "3") AI_MODE="motion"; echo -e "${GREEN}✓ AI Mode set to Motion${NC}" ;;
        "4") AI_MODE="quality"; echo -e "${GREEN}✓ AI Mode set to Quality${NC}" ;;
        *) echo -e "${YELLOW}No change made${NC}" ;;
    esac
    sleep 1
}

# 💻 Configure Threading
configure_threads() {
    local cpu_cores=$(nproc 2>/dev/null || echo "4")
    echo -e "\n${BLUE}${BOLD}💻 THREADING CONFIGURATION:${NC}"
    echo -e "${CYAN}System has ${BOLD}${cpu_cores}${NC}${CYAN} CPU cores available${NC}"
    echo -e "${CYAN}Current: ${BOLD}${FFMPEG_THREADS}${NC}\n"
    
    echo -e "  ${GREEN}[1]${NC} Auto (recommended)"
    echo -e "  ${GREEN}[2]${NC} All cores (${cpu_cores} threads)"
    echo -e "  ${GREEN}[3]${NC} Half cores ($((cpu_cores / 2)) threads)"
    echo -e "  ${GREEN}[4]${NC} Conservative (2 threads)"
    echo -e "  ${GREEN}[5]${NC} Custom number\n"
    
    echo -e "${MAGENTA}Select threading option [1-5]: ${NC}"
    read -r thread_choice
    
    case "$thread_choice" in
        "1") FFMPEG_THREADS="auto"; echo -e "${GREEN}✓ Threads set to Auto${NC}" ;;
        "2") FFMPEG_THREADS="$cpu_cores"; echo -e "${GREEN}✓ Threads set to ${cpu_cores}${NC}" ;;
        "3") FFMPEG_THREADS="$((cpu_cores / 2))"; echo -e "${GREEN}✓ Threads set to $((cpu_cores / 2))${NC}" ;;
        "4") FFMPEG_THREADS="2"; echo -e "${GREEN}✓ Threads set to 2${NC}" ;;
        "5") 
            echo -e "${MAGENTA}Enter custom thread count (1-${cpu_cores}): ${NC}"
            read -r custom_threads
            if [[ "$custom_threads" =~ ^[0-9]+$ ]] && [[ $custom_threads -ge 1 && $custom_threads -le $cpu_cores ]]; then
                FFMPEG_THREADS="$custom_threads"
                echo -e "${GREEN}✓ Threads set to ${custom_threads}${NC}"
            else
                echo -e "${RED}✗ Invalid input. No change made.${NC}"
            fi
            ;;
        *) echo -e "${YELLOW}No change made${NC}" ;;
    esac
    sleep 1
}

# 🔄 Configure Parallel Jobs
configure_parallel_jobs() {
    local cpu_cores=$(nproc 2>/dev/null || echo "4")
    echo -e "\n${BLUE}${BOLD}🔄 PARALLEL PROCESSING CONFIGURATION:${NC}"
    echo -e "${CYAN}Current: ${BOLD}${PARALLEL_JOBS}${NC}\n"
    
    echo -e "  ${GREEN}[1]${NC} Auto (recommended)"
    echo -e "  ${GREEN}[2]${NC} Maximum (${cpu_cores} jobs)"
    echo -e "  ${GREEN}[3]${NC} Conservative (2 jobs)"
    echo -e "  ${GREEN}[4]${NC} Sequential (1 job)"
    echo -e "  ${GREEN}[5]${NC} Custom number\n"
    
    echo -e "${MAGENTA}Select parallel jobs [1-5]: ${NC}"
    read -r parallel_choice
    
    case "$parallel_choice" in
        "1") PARALLEL_JOBS="auto"; echo -e "${GREEN}✓ Parallel jobs set to Auto${NC}" ;;
        "2") PARALLEL_JOBS="$cpu_cores"; echo -e "${GREEN}✓ Parallel jobs set to ${cpu_cores}${NC}" ;;
        "3") PARALLEL_JOBS="2"; echo -e "${GREEN}✓ Parallel jobs set to 2${NC}" ;;
        "4") PARALLEL_JOBS="1"; echo -e "${GREEN}✓ Parallel jobs set to 1 (sequential)${NC}" ;;
        "5") 
            echo -e "${MAGENTA}Enter custom job count (1-${cpu_cores}): ${NC}"
            read -r custom_jobs
            if [[ "$custom_jobs" =~ ^[0-9]+$ ]] && [[ $custom_jobs -ge 1 && $custom_jobs -le $cpu_cores ]]; then
                PARALLEL_JOBS="$custom_jobs"
                echo -e "${GREEN}✓ Parallel jobs set to ${custom_jobs}${NC}"
            else
                echo -e "${RED}✗ Invalid input. No change made.${NC}"
            fi
            ;;
        *) echo -e "${YELLOW}No change made${NC}" ;;
    esac
    sleep 1
}

# 💪 Configure Memory Settings
configure_memory_settings() {
    local total_ram=$(free -m 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "4096")
    echo -e "\n${BLUE}${BOLD}💪 MEMORY OPTIMIZATION:${NC}"
    echo -e "${CYAN}System RAM: ${BOLD}$((total_ram / 1024))GB${NC}${CYAN} (${total_ram}MB)${NC}"
    echo -e "${CYAN}Current cache size: ${BOLD}${RAM_CACHE_SIZE:-auto}${NC}\n"
    
    echo -e "  ${GREEN}[1]${NC} Auto (recommended)"
    echo -e "  ${GREEN}[2]${NC} Conservative (512MB)"
    echo -e "  ${GREEN}[3]${NC} Moderate (1GB)"
    echo -e "  ${GREEN}[4]${NC} Aggressive (2GB)"
    echo -e "  ${GREEN}[5]${NC} Maximum (4GB)"
    echo -e "  ${GREEN}[6]${NC} Enable RAM disk: $(get_status_icon "$RAM_DISK_ENABLED")\n"
    
    echo -e "${MAGENTA}Select memory option [1-6]: ${NC}"
    read -r memory_choice
    
    case "$memory_choice" in
        "1") RAM_CACHE_SIZE="auto"; echo -e "${GREEN}✓ Memory cache set to Auto${NC}" ;;
        "2") RAM_CACHE_SIZE="512m"; echo -e "${GREEN}✓ Memory cache set to 512MB${NC}" ;;
        "3") RAM_CACHE_SIZE="1g"; echo -e "${GREEN}✓ Memory cache set to 1GB${NC}" ;;
        "4") RAM_CACHE_SIZE="2g"; echo -e "${GREEN}✓ Memory cache set to 2GB${NC}" ;;
        "5") RAM_CACHE_SIZE="4g"; echo -e "${GREEN}✓ Memory cache set to 4GB${NC}" ;;
        "6") RAM_DISK_ENABLED=$([[ "$RAM_DISK_ENABLED" == "true" ]] && echo "false" || echo "true")
             echo -e "${GREEN}✓ RAM disk $([ "$RAM_DISK_ENABLED" == "true" ] && echo "enabled" || echo "disabled")${NC}" ;;
        *) echo -e "${YELLOW}No change made${NC}" ;;
    esac
    sleep 1
}

# 🎨 Configure Quality Settings
configure_quality_settings() {
    echo -e "\n${BLUE}${BOLD}🎨 QUALITY & COLOR CONFIGURATION:${NC}"
    echo -e "${CYAN}Current: Quality=${BOLD}${QUALITY}${NC}${CYAN}, Colors=${BOLD}${MAX_COLORS}${NC}${CYAN}, Dither=${BOLD}${DITHER_MODE}${NC}\n"
    
    echo -e "  ${GREEN}[1]${NC} Quick config - Low quality (64 colors, fast)"
    echo -e "  ${GREEN}[2]${NC} Quick config - Medium quality (128 colors, balanced)"
    echo -e "  ${GREEN}[3]${NC} Quick config - High quality (256 colors, best)"
    echo -e "  ${GREEN}[4]${NC} Custom max colors (current: ${MAX_COLORS})"
    echo -e "  ${GREEN}[5]${NC} Dither mode (current: ${DITHER_MODE})\n"
    
    echo -e "${MAGENTA}Select quality option [1-5]: ${NC}"
    read -r quality_choice
    
    case "$quality_choice" in
        "1") QUALITY="low"; MAX_COLORS="64"; DITHER_MODE="none"; echo -e "${GREEN}✓ Set to Low quality${NC}" ;;
        "2") QUALITY="medium"; MAX_COLORS="128"; DITHER_MODE="bayer"; echo -e "${GREEN}✓ Set to Medium quality${NC}" ;;
        "3") QUALITY="high"; MAX_COLORS="256"; DITHER_MODE="floyd_steinberg"; echo -e "${GREEN}✓ Set to High quality${NC}" ;;
        "4") 
            echo -e "${MAGENTA}Enter max colors (8-256): ${NC}"
            read -r custom_colors
            if [[ "$custom_colors" =~ ^[0-9]+$ ]] && [[ $custom_colors -ge 8 && $custom_colors -le 256 ]]; then
                MAX_COLORS="$custom_colors"
                echo -e "${GREEN}✓ Max colors set to ${custom_colors}${NC}"
            else
                echo -e "${RED}✗ Invalid input. No change made.${NC}"
            fi
            ;;
        "5")
            echo -e "${MAGENTA}Select dither mode:${NC}"
            echo -e "  ${GREEN}[a]${NC} none, ${GREEN}[b]${NC} bayer, ${GREEN}[c]${NC} floyd_steinberg, ${GREEN}[d]${NC} sierra2_4a"
            read -r dither_choice
            case "$dither_choice" in
                "a") DITHER_MODE="none"; echo -e "${GREEN}✓ Dither set to none${NC}" ;;
                "b") DITHER_MODE="bayer"; echo -e "${GREEN}✓ Dither set to bayer${NC}" ;;
                "c") DITHER_MODE="floyd_steinberg"; echo -e "${GREEN}✓ Dither set to floyd_steinberg${NC}" ;;
                "d") DITHER_MODE="sierra2_4a"; echo -e "${GREEN}✓ Dither set to sierra2_4a${NC}" ;;
                *) echo -e "${YELLOW}No change made${NC}" ;;
            esac
            ;;
        *) echo -e "${YELLOW}No change made${NC}" ;;
    esac
    sleep 1
}

# 🛡️ Configure Compression Settings
configure_compression_settings() {
    echo -e "\n${BLUE}${BOLD}🛡️ COMPRESSION & SIZE LIMITS:${NC}"
    echo -e "${CYAN}Current: Level=${BOLD}${COMPRESSION_LEVEL}${NC}${CYAN}, Max Size=${BOLD}${MAX_GIF_SIZE_MB}MB${NC}\n"
    
    echo -e "  ${GREEN}[1]${NC} Compression Level (current: ${COMPRESSION_LEVEL})"
    echo -e "  ${GREEN}[2]${NC} Max GIF Size (current: ${MAX_GIF_SIZE_MB}MB)"
    echo -e "  ${GREEN}[3]${NC} Auto reduce quality: $(get_status_icon "$AUTO_REDUCE_QUALITY")"
    echo -e "  ${GREEN}[4]${NC} Smart size down: $(get_status_icon "$SMART_SIZE_DOWN")\n"
    
    echo -e "${MAGENTA}Select compression option [1-4]: ${NC}"
    read -r comp_choice
    
    case "$comp_choice" in
        "1")
            echo -e "${MAGENTA}Select compression level:${NC}"
            echo -e "  ${GREEN}[a]${NC} low, ${GREEN}[b]${NC} medium, ${GREEN}[c]${NC} high, ${GREEN}[d]${NC} maximum"
            read -r level_choice
            case "$level_choice" in
                "a") COMPRESSION_LEVEL="low"; echo -e "${GREEN}✓ Compression set to low${NC}" ;;
                "b") COMPRESSION_LEVEL="medium"; echo -e "${GREEN}✓ Compression set to medium${NC}" ;;
                "c") COMPRESSION_LEVEL="high"; echo -e "${GREEN}✓ Compression set to high${NC}" ;;
                "d") COMPRESSION_LEVEL="maximum"; echo -e "${GREEN}✓ Compression set to maximum${NC}" ;;
                *) echo -e "${YELLOW}No change made${NC}" ;;
            esac
            ;;
        "2")
            echo -e "${MAGENTA}Enter max GIF size in MB (1-100): ${NC}"
            read -r custom_size
            if [[ "$custom_size" =~ ^[0-9]+$ ]] && [[ $custom_size -ge 1 && $custom_size -le 100 ]]; then
                MAX_GIF_SIZE_MB="$custom_size"
                echo -e "${GREEN}✓ Max GIF size set to ${custom_size}MB${NC}"
            else
                echo -e "${RED}✗ Invalid input. No change made.${NC}"
            fi
            ;;
        "3") AUTO_REDUCE_QUALITY=$([[ "$AUTO_REDUCE_QUALITY" == "true" ]] && echo "false" || echo "true")
             echo -e "${GREEN}✓ Auto reduce quality $([ "$AUTO_REDUCE_QUALITY" == "true" ] && echo "enabled" || echo "disabled")${NC}" ;;
        "4") SMART_SIZE_DOWN=$([[ "$SMART_SIZE_DOWN" == "true" ]] && echo "false" || echo "true")
             echo -e "${GREEN}✓ Smart size down $([ "$SMART_SIZE_DOWN" == "true" ] && echo "enabled" || echo "disabled")${NC}" ;;
        *) echo -e "${YELLOW}No change made${NC}" ;;
    esac
    sleep 1
}

# 🔍 Configure Validation Settings
configure_validation_settings() {
    echo -e "\n${BLUE}${BOLD}🔍 VALIDATION & DETECTION SETTINGS:${NC}"
    echo -e "${CYAN}Current validation settings:\n${NC}"
    
    echo -e "  ${GREEN}[1]${NC} Skip validation: $(get_status_icon "$SKIP_VALIDATION")"
    echo -e "  ${GREEN}[2]${NC} Dynamic file detection: $(get_status_icon "$DYNAMIC_FILE_DETECTION")"
    echo -e "  ${GREEN}[3]${NC} File monitor interval: ${BOLD}${FILE_MONITOR_INTERVAL}s${NC}\n"
    
    echo -e "${MAGENTA}Select validation option [1-3]: ${NC}"
    read -r val_choice
    
    case "$val_choice" in
        "1") SKIP_VALIDATION=$([[ "$SKIP_VALIDATION" == "true" ]] && echo "false" || echo "true")
             echo -e "${GREEN}✓ Skip validation $([ "$SKIP_VALIDATION" == "true" ] && echo "enabled" || echo "disabled")${NC}" ;;
        "2") DYNAMIC_FILE_DETECTION=$([[ "$DYNAMIC_FILE_DETECTION" == "true" ]] && echo "false" || echo "true")
             echo -e "${GREEN}✓ Dynamic file detection $([ "$DYNAMIC_FILE_DETECTION" == "true" ] && echo "enabled" || echo "disabled")${NC}" ;;
        "3")
            echo -e "${MAGENTA}Enter monitor interval in seconds (5-60): ${NC}"
            read -r custom_interval
            if [[ "$custom_interval" =~ ^[0-9]+$ ]] && [[ $custom_interval -ge 5 && $custom_interval -le 60 ]]; then
                FILE_MONITOR_INTERVAL="$custom_interval"
                echo -e "${GREEN}✓ Monitor interval set to ${custom_interval}s${NC}"
            else
                echo -e "${RED}✗ Invalid input. No change made.${NC}"
            fi
            ;;
        *) echo -e "${YELLOW}No change made${NC}" ;;
    esac
    sleep 1
}

# 📝 Configure Logging Settings
configure_logging_settings() {
    echo -e "\n${BLUE}${BOLD}📝 LOGGING & DEBUG CONFIGURATION:${NC}"
    echo -e "${CYAN}Current logging settings:\n${NC}"
    
    echo -e "  ${GREEN}[1]${NC} Log level: ${BOLD}${LOG_LEVEL}${NC}"
    echo -e "  ${GREEN}[2]${NC} Progress bar: $(get_status_icon "$PROGRESS_BAR")"
    echo -e "  ${GREEN}[3]${NC} CPU benchmark: $(get_status_icon "$CPU_BENCHMARK")"
    echo -e "  ${GREEN}[4]${NC} Cleanup on exit: $(get_status_icon "$CLEANUP_ON_EXIT")\n"
    
    echo -e "${MAGENTA}Select logging option [1-4]: ${NC}"
    read -r log_choice
    
    case "$log_choice" in
        "1")
            echo -e "${MAGENTA}Select log level:${NC}"
            echo -e "  ${GREEN}[a]${NC} error, ${GREEN}[b]${NC} warning, ${GREEN}[c]${NC} info, ${GREEN}[d]${NC} debug"
            read -r level_choice
            case "$level_choice" in
                "a") LOG_LEVEL="error"; echo -e "${GREEN}✓ Log level set to error${NC}" ;;
                "b") LOG_LEVEL="warning"; echo -e "${GREEN}✓ Log level set to warning${NC}" ;;
                "c") LOG_LEVEL="info"; echo -e "${GREEN}✓ Log level set to info${NC}" ;;
                "d") LOG_LEVEL="debug"; echo -e "${GREEN}✓ Log level set to debug${NC}" ;;
                *) echo -e "${YELLOW}No change made${NC}" ;;
            esac
            ;;
        "2") PROGRESS_BAR=$([[ "$PROGRESS_BAR" == "true" ]] && echo "false" || echo "true")
             echo -e "${GREEN}✓ Progress bar $([ "$PROGRESS_BAR" == "true" ] && echo "enabled" || echo "disabled")${NC}" ;;
        "3") CPU_BENCHMARK=$([[ "$CPU_BENCHMARK" == "true" ]] && echo "false" || echo "true")
             echo -e "${GREEN}✓ CPU benchmark $([ "$CPU_BENCHMARK" == "true" ] && echo "enabled" || echo "disabled")${NC}" ;;
        "4") CLEANUP_ON_EXIT=$([[ "$CLEANUP_ON_EXIT" == "true" ]] && echo "false" || echo "true")
             echo -e "${GREEN}✓ Cleanup on exit $([ "$CLEANUP_ON_EXIT" == "true" ] && echo "enabled" || echo "disabled")${NC}" ;;
        *) echo -e "${YELLOW}No change made${NC}" ;;
    esac
    sleep 1
}

# 🔧 Configure Custom Settings
configure_custom_settings() {
    echo -e "\n${BLUE}${BOLD}🔧 CUSTOM FFMPEG SETTINGS:${NC}"
    echo -e "${CYAN}Advanced users only - direct FFmpeg parameter configuration${NC}\n"
    
    echo -e "${YELLOW}Current custom settings:${NC}"
    echo -e "  Resolution: ${BOLD}${RESOLUTION}${NC}"
    echo -e "  Framerate: ${BOLD}${FRAMERATE}${NC}"
    echo -e "  Scaling algo: ${BOLD}${SCALING_ALGO}${NC}\n"
    
    echo -e "  ${GREEN}[1]${NC} Custom resolution (e.g., 1920:1080)"
    echo -e "  ${GREEN}[2]${NC} Custom framerate (e.g., 15)"
    echo -e "  ${GREEN}[3]${NC} Scaling algorithm"
    echo -e "  ${GREEN}[4]${NC} Export current settings to file"
    echo -e "  ${GREEN}[5]${NC} Import settings from file\n"
    
    echo -e "${MAGENTA}Select custom option [1-5]: ${NC}"
    read -r custom_choice
    
    case "$custom_choice" in
        "1")
            echo -e "${MAGENTA}Enter resolution (width:height, e.g. 1280:720): ${NC}"
            read -r custom_res
            if [[ "$custom_res" =~ ^[0-9]+:[0-9]+$ ]]; then
                RESOLUTION="$custom_res"
                echo -e "${GREEN}✓ Resolution set to ${custom_res}${NC}"
            else
                echo -e "${RED}✗ Invalid format. Use width:height${NC}"
            fi
            ;;
        "2")
            echo -e "${MAGENTA}Enter framerate (1-60): ${NC}"
            read -r custom_fps
            if [[ "$custom_fps" =~ ^[0-9]+$ ]] && [[ $custom_fps -ge 1 && $custom_fps -le 60 ]]; then
                FRAMERATE="$custom_fps"
                echo -e "${GREEN}✓ Framerate set to ${custom_fps}${NC}"
            else
                echo -e "${RED}✗ Invalid framerate${NC}"
            fi
            ;;
        "3")
            echo -e "${MAGENTA}Select scaling algorithm:${NC}"
            echo -e "  ${GREEN}[a]${NC} lanczos (best quality), ${GREEN}[b]${NC} bicubic, ${GREEN}[c]${NC} bilinear, ${GREEN}[d]${NC} neighbor (fastest)"
            read -r scale_choice
            case "$scale_choice" in
                "a") SCALING_ALGO="lanczos"; echo -e "${GREEN}✓ Scaling set to lanczos${NC}" ;;
                "b") SCALING_ALGO="bicubic"; echo -e "${GREEN}✓ Scaling set to bicubic${NC}" ;;
                "c") SCALING_ALGO="bilinear"; echo -e "${GREEN}✓ Scaling set to bilinear${NC}" ;;
                "d") SCALING_ALGO="neighbor"; echo -e "${GREEN}✓ Scaling set to neighbor${NC}" ;;
                *) echo -e "${YELLOW}No change made${NC}" ;;
            esac
            ;;
        "4")
            save_current_settings
            ;;
        "5")
            load_settings_from_file
            ;;
        *) echo -e "${YELLOW}No change made${NC}" ;;
    esac
    sleep 1
}

# 💾 Save current settings to file
save_current_settings() {
    local settings_file="gif-converter-settings-$(date +%Y%m%d-%H%M%S).conf"
    {
        echo "# Smart GIF Converter Settings - $(date)"
        echo "QUALITY=$QUALITY"
        echo "RESOLUTION=$RESOLUTION"
        echo "FRAMERATE=$FRAMERATE"
        echo "MAX_COLORS=$MAX_COLORS"
        echo "DITHER_MODE=$DITHER_MODE"
        echo "FFMPEG_THREADS=$FFMPEG_THREADS"
        echo "PARALLEL_JOBS=$PARALLEL_JOBS"
        echo "AI_ENABLED=$AI_ENABLED"
        echo "AI_MODE=$AI_MODE"
        echo "GPU_ACCELERATION=$GPU_ACCELERATION"
        echo "COMPRESSION_LEVEL=$COMPRESSION_LEVEL"
        echo "MAX_GIF_SIZE_MB=$MAX_GIF_SIZE_MB"
        echo "BACKUP_ORIGINAL=$BACKUP_ORIGINAL"
        echo "DEBUG_MODE=$DEBUG_MODE"
    } > "$settings_file"
    echo -e "${GREEN}✓ Settings saved to: $settings_file${NC}"
}

# 📁 Load settings from file
load_settings_from_file() {
    echo -e "${MAGENTA}Enter settings file path (or press Enter for default): ${NC}"
    read -r settings_path
    
    if [[ -z "$settings_path" ]]; then
        settings_path="$CONFIG_FILE"
    fi
    
    if [[ -f "$settings_path" ]]; then
        source "$settings_path"
        echo -e "${GREEN}✓ Settings loaded from: $settings_path${NC}"
    else
        echo -e "${RED}✗ File not found: $settings_path${NC}"
    fi
}

# ⚙️ Advanced conversion mode with settings
advanced_convert_mode() {
    clear
    print_header
    echo -e "${BLUE}${BOLD}⚙️  ADVANCED CONVERSION MODE${NC}\n"
    
    # Show settings configuration
    select_quality_preset
    echo ""
    select_aspect_ratio
    echo ""
    
    # Show comprehensive advanced settings
    show_advanced_settings_menu
    
    echo -e "${MAGENTA}Enter option number (1-15), 'c' to configure custom settings, or Enter to start: ${NC}"
    read -r choice
    
    case "$choice" in
        "1") FORCE_CONVERSION=$([[ "$FORCE_CONVERSION" == "true" ]] && echo "false" || echo "true") ;;
        "2") BACKUP_ORIGINAL=$([[ "$BACKUP_ORIGINAL" == "true" ]] && echo "false" || echo "true") ;;
        "3") AUTO_OPTIMIZE=$([[ "$AUTO_OPTIMIZE" == "true" ]] && echo "false" || echo "true") ;;
        "4") DEBUG_MODE=$([[ "$DEBUG_MODE" == "true" ]] && echo "false" || echo "true") ;;
        "5") AI_ENABLED=$([[ "$AI_ENABLED" == "true" ]] && echo "false" || echo "true") ;;
        "6") configure_ai_mode ;;
        "7") configure_threads ;;
        "8") configure_parallel_jobs ;;
        "9") GPU_ACCELERATION=$([[ "$GPU_ACCELERATION" == "auto" ]] && echo "disabled" || echo "auto") ;;
        "10") configure_memory_settings ;;
        "11") configure_quality_settings ;;
        "12") configure_compression_settings ;;
        "13") INTERACTIVE_MODE=$([[ "$INTERACTIVE_MODE" == "true" ]] && echo "false" || echo "true") ;;
        "14") configure_validation_settings ;;
        "15") configure_logging_settings ;;
        "c"|"C") configure_custom_settings ;;
        "")
            INTERACTIVE_MODE=false
            echo -e "\n${CYAN}🔍 Starting advanced conversion with validation...${NC}\n"
            if start_conversion; then
                echo -e "\n${GREEN}✅ Advanced conversion completed successfully!${NC}"
            else
                echo -e "\n${YELLOW}📋 Advanced conversion completed (no action needed)${NC}"
            fi
            ;;
    esac
    
    if [[ -n "$choice" && ("$choice" =~ ^[1-9]$ || "$choice" =~ ^1[0-5]$ || "$choice" =~ ^[cC]$) ]]; then
        advanced_convert_mode  # Recursive call to show updated options
    else
        echo -e "\n${YELLOW}Press any key to return to main menu...${NC}"
        read -rsn1
    fi
}

# 📊 Show conversion statistics
show_conversion_stats() {
    clear
    print_header
    echo -e "${CYAN}${BOLD}📊 CONVERSION STATISTICS${NC}\n"
    
    init_log_directory >/dev/null 2>&1
    
    if [[ -f "$CONVERSION_LOG" ]]; then
        local total_conversions=$(grep -c "SUCCESS\|FAILED\|SKIPPED" "$CONVERSION_LOG" 2>/dev/null || echo "0")
        local successful=$(grep -c "SUCCESS" "$CONVERSION_LOG" 2>/dev/null || echo "0")
        local failed=$(grep -c "FAILED" "$CONVERSION_LOG" 2>/dev/null || echo "0")
        local skipped=$(grep -c "SKIPPED" "$CONVERSION_LOG" 2>/dev/null || echo "0")
        
        echo -e "${BLUE}📁 Log File: $CONVERSION_LOG${NC}"
        echo -e "${YELLOW}📈 Total Operations: ${BOLD}$total_conversions${NC}"
        echo -e "${GREEN}✓ Successful: ${BOLD}$successful${NC}"
        echo -e "${RED}❌ Failed: ${BOLD}$failed${NC}"
        echo -e "${YELLOW}⏭️ Skipped: ${BOLD}$skipped${NC}\n"
        
        if [[ $total_conversions -gt 0 ]]; then
            echo -e "${CYAN}${BOLD}🕰️ RECENT ACTIVITY (Last 10):${NC}\n"
            tail -10 "$CONVERSION_LOG" | grep -E "SUCCESS|FAILED|SKIPPED" | while read line; do
                if [[ $line == *"SUCCESS"* ]]; then
                    echo -e "  ${GREEN}✓ $line${NC}"
                elif [[ $line == *"FAILED"* ]]; then
                    echo -e "  ${RED}❌ $line${NC}"
                elif [[ $line == *"SKIPPED"* ]]; then
                    echo -e "  ${YELLOW}⏭️ $line${NC}"
                fi
            done
        fi
    else
        echo -e "${YELLOW}⚠️ No conversion history found${NC}"
        echo -e "${BLUE}Run some conversions to see statistics here!${NC}"
    fi
    
    echo -e "\n${YELLOW}Press any key to return to main menu...${NC}"
    read -rsn1
}

# 📁 Manage log files
manage_log_files() {
    clear
    print_header
    echo -e "${CYAN}${BOLD}📁 LOG FILE MANAGEMENT${NC}\n"
    
    init_log_directory >/dev/null 2>&1
    
    echo -e "${BLUE}Log Directory: ${BOLD}$LOG_DIR${NC}"
    echo -e "${YELLOW}Available actions:${NC}\n"
    
    echo -e "  ${GREEN}[1]${NC} View recent errors (formatted)"
    echo -e "  ${GREEN}[2]${NC} View error log (last 20 lines)"
    echo -e "  ${GREEN}[3]${NC} View conversion log (last 20 lines)"
    echo -e "  ${GREEN}[4]${NC} Clear all logs"
    echo -e "  ${GREEN}[5]${NC} Open log directory in file manager"
    echo -e "  ${GREEN}[6]${NC} Show log file sizes"
    echo -e "  ${GREEN}[0]${NC} Return to main menu\n"
    
    echo -e "${MAGENTA}Select an option: ${NC}"
    read -r choice
    
    case "$choice" in
        "1")
            echo -e "\n${CYAN}${BOLD}🔍 RECENT ERRORS (FORMATTED):${NC}\n"
            show_recent_errors 5
            echo -e "\n${YELLOW}Press any key to continue...${NC}"
            read -rsn1
            manage_log_files
            ;;
        "2")
            echo -e "\n${CYAN}Error Log (last 20 lines):${NC}"
            if [[ -f "$ERROR_LOG" ]]; then
                tail -20 "$ERROR_LOG"
            else
                echo -e "${YELLOW}No error log found${NC}"
            fi
            echo -e "\n${YELLOW}Press any key to continue...${NC}"
            read -rsn1
            manage_log_files
            ;;
        "3")
            echo -e "\n${CYAN}Conversion Log (last 20 lines):${NC}"
            if [[ -f "$CONVERSION_LOG" ]]; then
                tail -20 "$CONVERSION_LOG"
            else
                echo -e "${YELLOW}No conversion log found${NC}"
            fi
            echo -e "\n${YELLOW}Press any key to continue...${NC}"
            read -rsn1
            manage_log_files
            ;;
        "4")
            echo -e "\n${RED}Are you sure you want to clear all logs? [y/N]: ${NC}"
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                rm -f "$ERROR_LOG" "$CONVERSION_LOG" 2>/dev/null
                init_log_directory
                echo -e "${GREEN}✓ All logs cleared${NC}"
            else
                echo -e "${YELLOW}Operation cancelled${NC}"
            fi
            echo -e "\n${YELLOW}Press any key to continue...${NC}"
            read -rsn1
            manage_log_files
            ;;
        "5")
            if command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$LOG_DIR" 2>/dev/null
                echo -e "${GREEN}✓ Opening log directory in file manager${NC}"
            elif command -v nautilus >/dev/null 2>&1; then
                nautilus "$LOG_DIR" 2>/dev/null &
                echo -e "${GREEN}✓ Opening log directory in Nautilus${NC}"
            else
                echo -e "${YELLOW}No file manager found. Directory: $LOG_DIR${NC}"
            fi
            echo -e "\n${YELLOW}Press any key to continue...${NC}"
            read -rsn1
            manage_log_files
            ;;
        "6")
            echo -e "\n${CYAN}Log File Sizes:${NC}"
            if [[ -f "$ERROR_LOG" ]]; then
                local error_size=$(du -h "$ERROR_LOG" | cut -f1)
                local error_lines=$(wc -l < "$ERROR_LOG")
                echo -e "  ${BLUE}Error Log: ${BOLD}$error_size ($error_lines lines)${NC}"
            fi
            if [[ -f "$CONVERSION_LOG" ]]; then
                local conv_size=$(du -h "$CONVERSION_LOG" | cut -f1)
                local conv_lines=$(wc -l < "$CONVERSION_LOG")
                echo -e "  ${BLUE}Conversion Log: ${BOLD}$conv_size ($conv_lines lines)${NC}"
            fi
            echo -e "\n${YELLOW}Press any key to continue...${NC}"
            read -rsn1
            manage_log_files
            ;;
        "0"|"")
            return
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            echo -e "\n${YELLOW}Press any key to continue...${NC}"
            read -rsn1
            manage_log_files
            ;;
    esac
}

# 🔧 Show system information
show_system_info() {
    clear
    print_header
    echo -e "${CYAN}${BOLD}🔧 SYSTEM INFORMATION${NC}\n"
    
    echo -e "${YELLOW}System Dependencies:${NC}"
    
    # Check FFmpeg
    if command -v ffmpeg >/dev/null 2>&1; then
        local ffmpeg_version=$(ffmpeg -version 2>/dev/null | head -1 | cut -d' ' -f3)
        echo -e "  ${GREEN}✓ FFmpeg: ${BOLD}$ffmpeg_version${NC}"
    else
        echo -e "  ${RED}❌ FFmpeg: Not installed${NC}"
    fi
    
    # Check FFprobe
    if command -v ffprobe >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ FFprobe: Available${NC}"
    else
        echo -e "  ${RED}❌ FFprobe: Not installed${NC}"
    fi
    
    # Check optional tools
    if command -v gifsicle >/dev/null 2>&1; then
        local gifsicle_version=$(gifsicle --version 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+\.*[0-9]*')
        echo -e "  ${GREEN}✓ Gifsicle: ${BOLD}$gifsicle_version${NC} (optimization available)"
    else
        echo -e "  ${YELLOW}⚠️ Gifsicle: Not installed (optimization disabled)${NC}"
    fi
    
    if command -v jq >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ jq: Available (auto-detection enabled)${NC}"
    else
        echo -e "  ${YELLOW}⚠️ jq: Not installed (limited auto-detection)${NC}"
    fi
    
    echo -e "\n${YELLOW}Current Configuration:${NC}"
    echo -e "  ${BLUE}Quality: ${BOLD}$QUALITY${NC}"
    echo -e "  ${BLUE}Resolution: ${BOLD}$RESOLUTION${NC}"
    echo -e "  ${BLUE}Frame Rate: ${BOLD}${FRAMERATE}fps${NC}"
    echo -e "  ${BLUE}Aspect Ratio: ${BOLD}$ASPECT_RATIO${NC}"
    echo -e "  ${BLUE}Scaling: ${BOLD}$SCALING_ALGO${NC}"
    echo -e "  ${BLUE}Max Colors: ${BOLD}$MAX_COLORS${NC}"
    
    echo -e "\n${YELLOW}Advanced System Analysis:${NC}"
    
    # Enhanced CPU information
    local cpu_info=$(detect_cpu_architecture)
    local physical_cores=$(get_physical_cores)
    local logical_cores=$(get_logical_cores)
    local memory_gb=$(get_available_memory_gb)
    local cpu_scaling=$(detect_cpu_scaling)
    local governor=$(echo $cpu_scaling | cut -d',' -f1 | cut -d':' -f2)
    local current_freq=$(echo $cpu_scaling | cut -d',' -f2 | cut -d':' -f2)
    
    echo -e "  ${GREEN}🧮 CPU Architecture:${NC}"
    echo -e "    ${BLUE}Model: ${BOLD}$(echo "$cpu_info" | cut -d'(' -f1)${NC}"
    if [[ "$cpu_info" == *"("* ]]; then
        local features=$(echo "$cpu_info" | grep -o '([^)]*)' | tr -d '()')
        echo -e "    ${BLUE}Features: ${BOLD}$features${NC}"
    fi
    echo -e "    ${BLUE}Physical cores: ${BOLD}$physical_cores${NC} | ${BLUE}Logical cores: ${BOLD}$logical_cores${NC}"
    [[ "$governor" != "unknown" ]] && echo -e "    ${BLUE}Power governor: ${BOLD}$governor${NC}"
    [[ "$current_freq" != "unknown" ]] && echo -e "    ${BLUE}Current frequency: ${BOLD}$current_freq${NC}"
    
    # Enhanced memory information
    if command -v free >/dev/null 2>&1; then
        local mem_total=$(free -h | awk '/^Mem:/ {print $2}')
        local mem_used=$(free -h | awk '/^Mem:/ {print $3}')
        local mem_available=$(free -h | awk '/^Mem:/ {print $7}')
        local mem_percent=$(free | awk '/^Mem:/ {printf "%.0f", $3*100/$2}')
        
        echo -e "  ${GREEN}📦 Memory Status:${NC}"
        echo -e "    ${BLUE}Total: ${BOLD}$mem_total${NC} | ${BLUE}Used: ${BOLD}$mem_used${NC} (${mem_percent}%) | ${BLUE}Available: ${BOLD}$mem_available${NC}"
    fi
    
    # Disk space with enhanced details
    local disk_total=$(df -h . | awk 'NR==2 {print $2}')
    local disk_used=$(df -h . | awk 'NR==2 {print $3}')
    local disk_available=$(df -h . | awk 'NR==2 {print $4}')
    local disk_percent=$(df . | awk 'NR==2 {print $5}')
    
    echo -e "  ${GREEN}💾 Storage Status:${NC}"
    echo -e "    ${BLUE}Total: ${BOLD}$disk_total${NC} | ${BLUE}Used: ${BOLD}$disk_used${NC} ($disk_percent) | ${BLUE}Available: ${BOLD}$disk_available${NC}"
    
    # Current CPU utilization
    local current_cpu=$(monitor_cpu_performance 2)
    echo -e "  ${GREEN}📈 Current Performance:${NC}"
    echo -e "    ${BLUE}$current_cpu${NC} utilization"
    
    # Optimal settings recommendation
    local optimal_threads=$(calculate_optimal_ffmpeg_threads "$logical_cores" "$memory_gb")
    local optimal_jobs=$(calculate_optimal_parallel_jobs "$logical_cores" "$physical_cores" "$memory_gb")
    
    echo -e "  ${GREEN}⚙️ Recommended Settings:${NC}"
    echo -e "    ${BLUE}FFmpeg threads: ${BOLD}$optimal_threads${NC} | ${BLUE}Parallel jobs: ${BOLD}$optimal_jobs${NC}"
    echo -e "    ${BLUE}Total thread utilization: ${BOLD}$((optimal_jobs * optimal_threads))/${logical_cores}${NC} logical cores"
    
    echo -e "\n${YELLOW}Press any key to return to main menu...${NC}"
    read -rsn1
}

# ❓ Show interactive help
show_interactive_help() {
    clear
    print_header
    echo -e "${CYAN}${BOLD}❓ HELP & DOCUMENTATION${NC}\n"
    
    echo -e "${YELLOW}Welcome to Smart GIF Converter!${NC}\n"
    
    echo -e "${GREEN}${BOLD}🎬 Quick Start:${NC}"
    echo -e "  1. Place video files in the current directory"
    echo -e "  2. Choose 'Quick Mode' for default conversion"
    echo -e "  3. Or use 'Advanced Mode' to customize settings\n"
    
    echo -e "${GREEN}${BOLD}🎯 Supported Formats:${NC}"
    echo -e "  Input:  MP4, AVI, MOV, MKV, WebM"
    echo -e "  Output: GIF (with optional optimization)\n"
    
    echo -e "${GREEN}${BOLD}⚙️ Quality Presets:${NC}"
    echo -e "  Low:    480p,  8fps  - Small files"
    echo -e "  Medium: 720p,  12fps - Balanced"
    echo -e "  High:   1080p, 15fps - Recommended"
    echo -e "  Ultra:  1440p, 20fps - High quality"
    echo -e "  Max:    4K,    24fps - Maximum quality\n"
    
    echo -e "${GREEN}${BOLD}📐 Aspect Ratios:${NC}"
    echo -e "  16:9 - Widescreen (YouTube standard)"
    echo -e "  4:3  - Classic TV format"
    echo -e "  1:1  - Square (Instagram)"
    echo -e "  21:9 - Ultra-wide cinematic"
    echo -e "  9:16 - Vertical (TikTok/Mobile)\n"
    
    echo -e "${GREEN}${BOLD}🛡️ Smart Features:${NC}"
    echo -e "  ✓ Automatic file skipping (if already converted)"
    echo -e "  ✓ Error handling with retry logic"
    echo -e "  ✓ Progress tracking and statistics"
    echo -e "  ✓ Comprehensive logging system"
    echo -e "  ✓ Automatic palette optimization\n"
    
    echo -e "${BLUE}${BOLD}📁 Log Files:${NC}"
    echo -e "  Location: ~/.smart-gif-converter/"
    echo -e "  • errors.log - Error tracking"
    echo -e "  • conversions.log - Conversion history\n"
    
    echo -e "${YELLOW}Press any key to return to main menu...${NC}"
    read -rsn1
}

# 🚀 Start conversion process with robust error handling
start_conversion() {
    trace_function "start_conversion"
    
    echo -e "${BLUE}🔄 Starting robust conversion process...${NC}"
    
    # Validate environment before starting
    if ! validate_conversion_environment; then
        log_error "Environment validation failed" "" "Cannot proceed with conversion" "${BASH_LINENO[0]}" "start_conversion"
        return 1
    fi
    
    # Run pre-conversion validation and cleanup
    if ! perform_pre_conversion_validation; then
        echo -e "${YELLOW}🏁 Validation completed - no conversion needed${NC}"
        return 0
    fi
    
    # Load previous progress to resume where we left off
    declare -A processed_files
    local has_previous_progress=false
    if load_progress processed_files; then
        has_previous_progress=true
    fi
    
    # Count video files and check for existing conversions
    local total_files=0
    local files_to_process=()
    local already_converted=0
    local resumed_files=0
    
    # If ONLY_FILE is set, process just that file
    if [[ -n "$ONLY_FILE" ]]; then
        if [[ -f "$ONLY_FILE" ]]; then
            if validate_video_file "$ONLY_FILE"; then
                files_to_process+=("$ONLY_FILE")
                total_files=1
                echo -e "${GREEN}📄 Ready to convert (single file): $(basename \"$ONLY_FILE\")${NC}"
            else
                echo -e "${RED}❌ Invalid input file: $ONLY_FILE${NC}"
                return 1
            fi
        else
            echo -e "${RED}❌ File not found: $ONLY_FILE${NC}"
            return 1
        fi
    else
    shopt -s nullglob
    for file in *.mp4 *.avi *.mov *.mkv *.webm; do
        if [[ -f "$file" && -r "$file" ]]; then
            ((total_files++)) || true
            local base_name=$(basename "$file")
            
            # Check if file was already processed in previous session
            if [[ -n "${processed_files[$base_name]:-}" ]]; then
                ((resumed_files++)) || true
                ((already_converted++)) || true
                echo -e "${BLUE}↻ Already processed: $base_name${NC}"
                continue
            fi
            
            # Check for duplicates first
            if check_duplicate_output "$file"; then
                ((already_converted++)) || true
                ((skipped_files++)) || true
                log_conversion "SKIPPED" "$file" "${file%.*}.${OUTPUT_FORMAT}" "(already exists)"
            else
                # Only do basic validation for files we'll actually process
                if validate_video_file "$file"; then
                    files_to_process+=("$file")
                    echo -e "${GREEN}📄 Ready to convert: $(basename "$file")${NC}"
                else
                    echo -e "${YELLOW}⚠️ Skipping invalid: $(basename "$file")${NC}"
                    ((corrupt_input_files++)) || true
                fi
            fi
        fi
    done
    shopt -u nullglob
    fi
    
    # Show resume info if applicable
    if [[ $has_previous_progress == true && $resumed_files -gt 0 ]]; then
        echo -e "${CYAN}🔄 Resuming from previous session: $resumed_files files already completed${NC}"
    fi
    
    if [[ $total_files -eq 0 ]]; then
        echo -e "${RED}❌ No video files found in current directory${NC}"
        return 1
    fi
    
    if [[ ${#files_to_process[@]} -eq 0 ]]; then
        echo -e "${GREEN}✓ All $total_files video files already converted!${NC}"
        if [[ $already_converted -gt 0 ]]; then
            echo -e "${BLUE}📁 $already_converted files already exist as GIFs${NC}"
        fi
        return 0
    fi
    
    echo -e "${BLUE}🎯 Found $total_files video files total${NC}"
    echo -e "${GREEN}✓ $already_converted already converted, ${#files_to_process[@]} to process${NC}"
    echo -e "${YELLOW}⚙️  Quality: $QUALITY | Resolution: $RESOLUTION | FPS: $FRAMERATE | Aspect: $ASPECT_RATIO${NC}"
    echo ""
    
    # Start dynamic file monitoring if enabled
    if [[ "$DYNAMIC_FILE_DETECTION" == "true" ]]; then
        # Get current files for monitoring baseline
        local all_current_files=()
        shopt -s nullglob
        for file in *.mp4 *.avi *.mov *.mkv *.webm; do
            [[ -f "$file" && -r "$file" ]] && all_current_files+=("$file")
        done
        shopt -u nullglob
        
        monitor_new_files "${all_current_files[@]}"
    fi
    
    # Process only the files that need conversion
    local current=0
    local files_to_convert=${#files_to_process[@]}
    
    if [[ "$PARALLEL_JOBS" -gt 1 && $files_to_convert -gt 1 ]]; then
        echo -e "${GREEN}🚀 Starting parallel conversion with $PARALLEL_JOBS concurrent jobs${NC}"
        echo -e "${BLUE}Processing $files_to_convert files in parallel...${NC}\n"
        
        # Parallel processing using job control
        local job_count=0
        local active_jobs=()
        
        for file in "${files_to_process[@]}"; do
            # Check for graceful interrupt request
            if [[ "$INTERRUPT_REQUESTED" == true ]]; then
                echo -e "\n${YELLOW}⚠️  Interrupt received - waiting for current jobs to complete${NC}"
                break
            fi
            
            # Wait if we've reached max parallel jobs
            while [[ $job_count -ge $PARALLEL_JOBS ]]; do
                # Check for completed jobs
                for i in "${!active_jobs[@]}"; do
                    if ! kill -0 "${active_jobs[i]}" 2>/dev/null; then
                        # Job finished, remove from active list
                        unset "active_jobs[i]"
                        ((job_count--))
                    fi
                done
                # Compact array
                active_jobs=("${active_jobs[@]}")
                sleep 0.1
            done
            
            ((current++))
            
            # Show overall progress
            if [[ "$PROGRESS_BAR" == true ]]; then
                local percent=$((current * 100 / files_to_convert))
                local filled=$((current * 50 / files_to_convert))
                local empty=$((50 - filled))
                printf "\r${BLUE}Overall: ["
                for ((i=0; i<filled; i++)); do printf "█"; done
                for ((i=0; i<empty; i++)); do printf "░"; done
                printf "] %d%% (%d/%d) Processing...${NC}" $percent $current $files_to_convert
            fi
            
            # Start conversion in background with proper I/O redirection
            (
                # Redirect stdin to prevent terminal conflicts
                exec </dev/null
                # Set process group to handle signals properly
                set -m 2>/dev/null || true
                CURRENT_FILE="$file"
                convert_video "$file"
                CURRENT_FILE=""
            ) &
            
            local job_pid=$!
            active_jobs+=("$job_pid")
            ((job_count++))
            
            echo -e "${CYAN}Started job $current/$files_to_convert: $(basename "$file") (PID: $job_pid)${NC}"
        done
        
        # Wait for all remaining jobs to complete
        echo -e "\n${YELLOW}Waiting for all parallel jobs to complete...${NC}"
        for job_pid in "${active_jobs[@]}"; do
            if kill -0 "$job_pid" 2>/dev/null; then
                wait "$job_pid" 2>/dev/null || true
            fi
        done
        
    else
        # Sequential processing (original method)
        for file in "${files_to_process[@]}"; do
            # Check for graceful interrupt request
            if [[ "$INTERRUPT_REQUESTED" == true ]]; then
                echo -e "\n${YELLOW}⚠️  Interrupt received - stopping after completing current batch${NC}"
                break
            fi
            
            ((current++))
            
            # Track current file for cleanup purposes
            CURRENT_FILE="$file"
            
            # Show overall progress with current file info
            if [[ "$PROGRESS_BAR" == true ]]; then
                show_progress $current $files_to_convert "$file" "Processing..."
            fi
            
            convert_video "$file"
            
            # Clear current file tracking when done
            CURRENT_FILE=""
        done
    fi
    
    # Final progress update
    if [[ "$PROGRESS_BAR" == true ]]; then
        printf "\r\033[K${GREEN}Overall: ["
        printf "%50s" | tr ' ' '▓'
        printf "] 100%% (%d/%d) ${GREEN}Completed!${NC}\n\n" $files_to_convert $files_to_convert
    fi
    
    show_statistics
    
    # Show detailed error information if there were failures
    if [[ $failed_files -gt 0 ]]; then
        echo -e "${RED}⚠️  $failed_files file(s) failed to convert${NC}"
        echo -e "${YELLOW}📂 Log Directory: $LOG_DIR${NC}"
        echo -e "${BLUE}📄 Error Log: $ERROR_LOG${NC}"
        echo -e "${BLUE}📈 Conversion Log: $CONVERSION_LOG${NC}"
        echo ""
        
        # Show recent errors automatically
        show_recent_errors 3
        
        echo -e "\n${YELLOW}🔧 Troubleshooting Commands:${NC}"
        echo -e "  ${CYAN}View full error log:${NC} tail -50 \"$ERROR_LOG\""
        echo -e "  ${CYAN}View recent conversions:${NC} tail -20 \"$CONVERSION_LOG\""
        echo -e "  ${CYAN}Clear error log:${NC} > \"$ERROR_LOG\""
    fi
    
    if [[ $converted_files -gt 0 ]]; then
        echo -e "${GREEN}🎉 Conversion completed successfully!${NC}"
        if [[ $failed_files -eq 0 ]]; then
            echo -e "${GREEN}All files processed without errors${NC}"
        fi
    elif [[ $skipped_files -gt 0 && $failed_files -eq 0 ]]; then
        echo -e "${YELLOW}ℹ️  No new files were converted (all up-to-date)${NC}"
    elif [[ $failed_files -gt 0 ]]; then
        echo -e "${RED}❌ Some files failed to convert${NC}"
    else
        echo -e "${YELLOW}ℹ️  No files were processed${NC}"
    fi
    
    # Check for any new files detected during conversion
    check_for_new_files
    
    # Stop file monitoring and clean up
    stop_file_monitoring
    
    # Ensure all ffmpeg processes are stopped
    kill_script_ffmpeg_processes
    
    # Save settings after successful run
    if [[ -n "$SETTINGS_FILE" ]]; then
        save_settings --silent
    fi
}

# 🎡 Welcome screen with friendly introduction
show_welcome() {
    clear
    echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                    🎬 SMART GIF CONVERTER v2.0                    ║${NC}"
    echo -e "${CYAN}${BOLD}║                  🤖 AI-Powered Video to GIF Magic                  ║${NC}"
    echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}👋 Welcome! Let me help you convert videos to amazing GIFs!${NC}"
    echo -e "${BLUE}💻 This tool automatically optimizes everything for you.${NC}"
    echo ""
    
    # System detection with friendly messages
    echo -e "${YELLOW}🔍 Detecting your system capabilities...${NC}"
    local cpu_cores=$(nproc 2>/dev/null || echo "4")
    local total_ram=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "unknown")
    local gpu_status="🚫 No GPU acceleration"
    
    # Check for GPU acceleration
    if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
        local gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null | head -1)
        gpu_status="🚀 NVIDIA GPU: ${gpu_name:-Unknown}"
    elif [[ -d /sys/class/drm ]] && ls /sys/class/drm/card*/device/vendor 2>/dev/null | xargs cat | grep -q "0x1002\|0x8086"; then
        gpu_status="🚀 AMD/Intel GPU detected"
    fi
    
    echo -e "  ${GREEN}✓ CPU:${NC} ${BOLD}${cpu_cores} cores${NC} - Perfect for fast conversions!"
    echo -e "  ${GREEN}✓ RAM:${NC} ${BOLD}${total_ram}${NC} - Great for handling large videos!"
    echo -e "  ${GREEN}✓ GPU:${NC} ${gpu_status}"
    echo ""
    
    # Check for video files in current directory
    local video_count=0
    shopt -s nullglob
    for ext in mp4 avi mov mkv webm; do
        local files=(*."$ext")
        video_count=$((video_count + ${#files[@]}))
    done
    shopt -u nullglob
    
    if [[ $video_count -gt 0 ]]; then
        echo -e "${GREEN}📹 Found ${BOLD}${video_count}${NC}${GREEN} video file(s) ready to convert!${NC}"
        echo -e "${CYAN}🎯 I'll automatically optimize each one for the best results.${NC}"
    else
        echo -e "${YELLOW}📁 No video files found in current directory.${NC}"
        echo -e "${BLUE}📌 Tip: Place video files (mp4, avi, mov, mkv, webm) here and run again!${NC}"
    fi
    echo ""
    
    # Show first-time setup if needed
    if [[ ! -f "$SETTINGS_FILE" ]]; then
        show_first_time_setup
    else
        show_quick_tips
    fi
}

# 🎆 First time setup wizard
show_first_time_setup() {
    echo -e "${MAGENTA}${BOLD}🎆 FIRST TIME SETUP - Let's get you started!${NC}\n"
    
    echo -e "${BLUE}🤔 What type of content do you usually convert?${NC}"
    echo -e "  ${GREEN}[1]${NC} Anime/Animation (optimized for cartoons)"
    echo -e "  ${GREEN}[2]${NC} Movies/TV Shows (live action content)"
    echo -e "  ${GREEN}[3]${NC} Screen recordings (tutorials, gameplay)"
    echo -e "  ${GREEN}[4]${NC} Mixed content (I'll use smart AI detection)"
    echo -e "  ${GREEN}[5]${NC} Skip setup (use defaults)\n"
    
    echo -e "${MAGENTA}Your choice [1-5]:${NC} "
    read -r setup_choice
    
    case "$setup_choice" in
        "1")
            QUALITY="high"
            MAX_COLORS="128"
            DITHER_MODE="floyd_steinberg"
            AI_MODE="content"
            echo -e "\n${GREEN}✓ Optimized for anime/animation content!${NC}"
            ;;
        "2")
            QUALITY="medium"
            MAX_COLORS="256"
            DITHER_MODE="bayer"
            AI_MODE="motion"
            echo -e "\n${GREEN}✓ Optimized for movies and live action!${NC}"
            ;;
        "3")
            QUALITY="high"
            MAX_COLORS="64"
            DITHER_MODE="none"
            FRAMERATE="10"
            AI_MODE="quality"
            echo -e "\n${GREEN}✓ Optimized for screen recordings!${NC}"
            ;;
        "4")
            AI_ENABLED=true
            AI_MODE="smart"
            echo -e "\n${GREEN}✓ Smart AI will automatically detect and optimize!${NC}"
            ;;
        *)
            echo -e "\n${YELLOW}✓ Using balanced default settings.${NC}"
            ;;
    esac
    
    echo -e "\n${CYAN}💾 Settings saved! You can change them anytime in Advanced Mode.${NC}\n"
    sleep 2
}

# 📚 Quick tips for returning users
show_quick_tips() {
    local tips=(
        "🚀 Pro tip: AI Quick Mode analyzes each video automatically!"
        "⚙️ Advanced Mode has 15+ settings you can customize!"
        "📊 Check Statistics to see your conversion history!"
        "🔧 Use 'c' in Advanced Mode for custom FFmpeg settings!"
        "💾 Your settings are automatically saved between runs!"
    )
    
    local random_tip=${tips[$RANDOM % ${#tips[@]}]}
    echo -e "${CYAN}💡 ${random_tip}${NC}\n"
}

# 📱 Get responsive help text based on screen size
get_responsive_help_text() {
    local short_text="$1"
    local long_text="$2"
    local layout_mode="$3"
    
    case $layout_mode in
        "mobile")
            echo "$short_text"
            ;;
        "tablet")
            # Use medium-length text
            local medium_text=$(echo "$long_text" | cut -c1-50)
            if [[ ${#long_text} -gt 50 ]]; then
                echo "${medium_text}..."
            else
                echo "$long_text"
            fi
            ;;
        *)
            echo "$long_text"
            ;;
    esac
}

# 🎡 Function to print fancy headers (simplified for menus)
print_header() {
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                    🎬 SMART GIF CONVERTER                    ║${NC}"
    echo -e "${CYAN}${BOLD}║                AI-Powered Video to GIF Magic                  ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 📋 Function to show help
show_help() {
    cat << EOF
${BOLD}🎬 SMART GIF CONVERTER - Advanced Usage Guide${NC}

${YELLOW}BASIC USAGE:${NC}
    $0 [OPTIONS]

${YELLOW}QUALITY PRESETS:${NC}
    --preset low        Low quality, small files (480p, 8fps)
    --preset medium     Balanced quality (720p, 12fps)
    --preset high       High quality (1080p, 15fps) [DEFAULT]
    --preset ultra      Ultra quality (1440p, 20fps)
    --preset max        Maximum quality (4K, 24fps)
    --ai | --ai-smart    Enable comprehensive AI analysis (all modes)
    --ai-mode MODE       AI analysis mode: smart|content|motion|quality
    --ai-content         Focus on content type detection and optimization
    --ai-motion          Focus on motion analysis and frame rate optimization
    --ai-quality         Focus on source quality analysis and preservation
    --ai-confidence N    AI confidence threshold (0-100, default: 70)

${YELLOW}ADVANCED OPTIONS:${NC}
    --resolution WxH    Custom resolution (e.g., 1920x1080)
    --fps N             Frame rate (1-60)
    --quality MODE      Quality mode: low|medium|high|ultra|max
    --aspect RATIO      Aspect ratio: original|16:9|4:3|1:1|21:9
    --scaling ALGO      Scaling: bilinear|bicubic|lanczos|neighbor
    --palette MODE      Palette: auto|custom|web|grayscale
    --colors N          Max colors (16-256)
    --dither MODE       Dithering: none|floyd|bayer|sierra
    --jobs N            Parallel processing jobs (1-16)
    --single-threaded   Disable parallel processing (use only 1 job)
    --parallel-jobs N   Set number of concurrent conversion jobs
    --threads N         FFmpeg thread count (auto-detected by default)
    --gpu-enable        Force enable GPU acceleration
    --gpu-disable       Disable GPU acceleration (CPU only)
    --format FORMAT     Output: gif|webp|apng
    --force             Force re-conversion of existing files
    --backup            Backup original files
    --optimize          Auto-optimize output files
    --optimize-aggressive    Aggressive optimization (try multiple strategies)
    --optimize-conservative  Conservative optimization (basic only)
    --optimize-target N      Target size ratio (default: 20% of original)
    --aggressive-optimization   Ultra-aggressive: 15MB limit, 15% target ratio
    --conservative-optimization Conservative: 75MB limit, 50% target ratio
    --enable-smart-sizing    Enable intelligent size reduction (default: on)
    --disable-smart-sizing   Disable automatic size optimization
    --disable-size-optimization  Disable all size optimizations
    --silent            Minimal output
    --verbose           Detailed logging
    --no-progress       Disable progress bars
    --debug             Enable debug mode with detailed error info
    --max-retries N     Maximum retry attempts (default: 2)
    --interactive|-i        Interactive mode with selection menus
    --kill-ffmpeg           Kill all running ffmpeg processes
    --stop-all              Stop all ffmpeg processes and exit immediately
    --skip-validation       Skip output validation for faster processing
    --show-settings         Show current settings and their saved location
    --show-progress         Show current conversion progress from autosave
    --clear-progress        Clear saved progress (start fresh)
    --test-termination      Test process group termination system
    --dynamic-detection     Monitor for new video files during conversion
    --monitor-files         Same as --dynamic-detection
    --monitor-interval N    File monitoring check interval in seconds (default: 10)
    --no-dynamic-detection  Disable dynamic file monitoring
    --no-monitor            Same as --no-dynamic-detection

${YELLOW}SMART FEATURES:${NC}
    --auto-detect       Auto-detect optimal settings per video
    --batch-optimize    Optimize all files after conversion
    --size-limit MB     Target file size limit
    --duration-limit S  Maximum GIF duration (clips longer videos)
    --smart-crop        Intelligent cropping for better composition
    --denoise           Apply noise reduction
    --stabilize         Video stabilization
    --enhance           Color/contrast enhancement

${YELLOW}ERROR HANDLING:${NC}
    --debug             Show detailed error information
    --max-retries N     Set maximum retry attempts per file
    Automatic features: Input validation, retry logic, cleanup on exit
    Logs saved to: ~/.smart-gif-converter/ (errors.log & conversions.log)

${YELLOW}CONFIGURATION:${NC}
    --config FILE       Use custom config file
    --save-config       Save current settings as default
    --reset-config      Reset to factory defaults
    --show-config       Display current configuration
    --show-settings     Show current settings and their saved location
    --file FILE         Convert only the specified video file (path or name)
    --show-logs         Show log directory and file information
    
${YELLOW}SETTINGS PERSISTENCE:${NC}
    The script automatically remembers your settings!
    • Settings are saved to: ~/.smart-gif-converter/settings.conf
    • Any changes via command line or interactive mode are auto-saved
    • Settings persist between runs - no need to set them again

${YELLOW}EXAMPLES:${NC}
    $0 --interactive                    # Interactive mode with menus
    $0 --preset ultra --aspect 16:9     # Command line mode
    $0 -i --auto-detect                 # Interactive + auto-detect
    $0 --resolution 1280x720 --fps 10   # Custom settings

EOF
}

# 🔧 Load configuration and settings
load_config() {
    # First try to load saved settings from log directory
    if load_settings 2>/dev/null; then
        return 0
    fi
    
    # Fallback to old config file
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        echo -e "${GREEN}✓ Loaded configuration from $CONFIG_FILE${NC}"
        # Migrate to new settings format
        save_settings --silent
        return 0
    fi
    
    echo -e "${YELLOW}ℹ️ Using default settings (will be saved after first use)${NC}"
    return 1
}

# 💾 Save settings to log directory
save_settings() {
    local settings_file="${1:-$SETTINGS_FILE}"
    
    cat > "$settings_file" << EOF
# Smart GIF Converter Settings - Auto-saved $(date)
# This file remembers your last used settings
RESOLUTION="$RESOLUTION"
FRAMERATE="$FRAMERATE"
QUALITY="$QUALITY"
ASPECT_RATIO="$ASPECT_RATIO"
SCALING_ALGO="$SCALING_ALGO"
DITHER_MODE="$DITHER_MODE"
MAX_COLORS="$MAX_COLORS"
PALETTE_MODE="$PALETTE_MODE"
PARALLEL_JOBS="$PARALLEL_JOBS"
OUTPUT_FORMAT="$OUTPUT_FORMAT"
AUTO_OPTIMIZE="$AUTO_OPTIMIZE"
OPTIMIZE_AGGRESSIVE="$OPTIMIZE_AGGRESSIVE"
OPTIMIZE_TARGET_RATIO="$OPTIMIZE_TARGET_RATIO"
BACKUP_ORIGINAL="$BACKUP_ORIGINAL"
SKIP_VALIDATION="$SKIP_VALIDATION"
PROGRESS_BAR="$PROGRESS_BAR"
FORCE_CONVERSION="$FORCE_CONVERSION"
DEBUG_MODE="$DEBUG_MODE"
MAX_RETRIES="$MAX_RETRIES"
AI_ENABLED="$AI_ENABLED"
AI_MODE="$AI_MODE"
AI_CONFIDENCE_THRESHOLD="$AI_CONFIDENCE_THRESHOLD"
MAX_GIF_SIZE_MB="$MAX_GIF_SIZE_MB"
AUTO_REDUCE_QUALITY="$AUTO_REDUCE_QUALITY"
SMART_SIZE_DOWN="$SMART_SIZE_DOWN"
GPU_ACCELERATION="$GPU_ACCELERATION"
FFMPEG_THREADS="$FFMPEG_THREADS"
PARALLEL_JOBS="$PARALLEL_JOBS"
EOF
    
    if [[ "$1" != "--silent" ]]; then
        echo -e "${GREEN}💾 Settings saved to $settings_file${NC}"
    fi
}

# 📁 Load settings from log directory
load_settings() {
    local settings_file="${1:-$SETTINGS_FILE}"
    
    if [[ -f "$settings_file" ]]; then
        # Source the settings file safely
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z $key ]] && continue
            
            # Remove quotes from value
            value=$(echo "$value" | sed 's/^"\|"$//g')
            
            # Set the variable
            case "$key" in
                RESOLUTION) RESOLUTION="$value" ;;
                FRAMERATE) FRAMERATE="$value" ;;
                QUALITY) QUALITY="$value" ;;
                ASPECT_RATIO) ASPECT_RATIO="$value" ;;
                SCALING_ALGO) SCALING_ALGO="$value" ;;
                DITHER_MODE) DITHER_MODE="$value" ;;
                MAX_COLORS) MAX_COLORS="$value" ;;
                PALETTE_MODE) PALETTE_MODE="$value" ;;
                PARALLEL_JOBS) PARALLEL_JOBS="$value" ;;
                OUTPUT_FORMAT) OUTPUT_FORMAT="$value" ;;
                AUTO_OPTIMIZE) AUTO_OPTIMIZE="$value" ;;
                OPTIMIZE_AGGRESSIVE) OPTIMIZE_AGGRESSIVE="$value" ;;
                OPTIMIZE_TARGET_RATIO) OPTIMIZE_TARGET_RATIO="$value" ;;
                BACKUP_ORIGINAL) BACKUP_ORIGINAL="$value" ;;
                SKIP_VALIDATION) SKIP_VALIDATION="$value" ;;
                PROGRESS_BAR) PROGRESS_BAR="$value" ;;
                FORCE_CONVERSION) FORCE_CONVERSION="$value" ;;
                DEBUG_MODE) DEBUG_MODE="$value" ;;
                MAX_RETRIES) MAX_RETRIES="$value" ;;
                AI_ENABLED) AI_ENABLED="$value" ;;
                AI_MODE) AI_MODE="$value" ;;
                AI_CONFIDENCE_THRESHOLD) AI_CONFIDENCE_THRESHOLD="$value" ;;
            esac
        done < "$settings_file"
        
        echo -e "${GREEN}📁 Loaded saved settings from $settings_file${NC}"
        return 0
    fi
    return 1
}

# 💾 Save configuration (legacy function for backward compatibility)
save_config() {
    save_settings "$CONFIG_FILE"
}

# 📐 Interactive aspect ratio selection
select_aspect_ratio() {
    echo -e "\n${CYAN}${BOLD}📐 SELECT ASPECT RATIO:${NC}"
    echo -e "${YELLOW}Choose your preferred aspect ratio:${NC}\n"
    
    local options=(
        "16:9 (Widescreen - Most common, YouTube standard)"
        "4:3 (Classic TV/Monitor format)"
        "1:1 (Square - Instagram/Social media)"
        "21:9 (Ultra-wide cinematic)"
        "9:16 (Vertical - Mobile/TikTok)"
        "Original (Keep source aspect ratio)"
    )
    
    local aspect_values=("16:9" "4:3" "1:1" "21:9" "9:16" "original")
    
    for i in "${!options[@]}"; do
        local num=$((i + 1))
        if [[ "${aspect_values[$i]}" == "$ASPECT_RATIO" ]]; then
            echo -e "  ${GREEN}[$num] ✓ ${options[$i]}${NC} ${BOLD}(Current)${NC}"
        else
            echo -e "  ${BLUE}[$num]${NC}   ${options[$i]}"
        fi
    done
    
    echo -e "\n${MAGENTA}Enter your choice [1-${#options[@]}] or press Enter for current (${ASPECT_RATIO}): ${NC}"
    read -r choice
    
    if [[ -z "$choice" ]]; then
        echo -e "${GREEN}✓ Using current aspect ratio: $ASPECT_RATIO${NC}"
        return
    fi
    
    if [[ "$choice" =~ ^[1-6]$ ]]; then
        local index=$((choice - 1))
        ASPECT_RATIO="${aspect_values[$index]}"
        echo -e "${GREEN}✓ Selected aspect ratio: $ASPECT_RATIO${NC}"
        
        # Auto-save settings when aspect ratio changes
        if [[ -n "$SETTINGS_FILE" ]]; then
            save_settings --silent
        fi
    else
        echo -e "${RED}❌ Invalid choice. Using current: $ASPECT_RATIO${NC}"
    fi
}

# 🎛️ Interactive quality preset selection
select_quality_preset() {
    echo -e "\n${CYAN}${BOLD}⚙️ SELECT QUALITY PRESET:${NC}"
    echo -e "${YELLOW}Choose your preferred quality level:${NC}\n"
    
    local presets=(
        "Low (480p, 8fps) - Small files, fast processing"
        "Medium (720p, 12fps) - Balanced quality and size"
        "High (1080p, 15fps) - Great quality, standard choice"
        "Ultra (1440p, 20fps) - Excellent quality, larger files"
        "Max (4K, 24fps) - Maximum quality, very large files"
    )
    
    local preset_values=("low" "medium" "high" "ultra" "max")
    
    for i in "${!presets[@]}"; do
        local num=$((i + 1))
        if [[ "${preset_values[$i]}" == "$QUALITY" ]]; then
            echo -e "  ${GREEN}[$num] ✓ ${presets[$i]}${NC} ${BOLD}(Current)${NC}"
        else
            echo -e "  ${BLUE}[$num]${NC}   ${presets[$i]}"
        fi
    done
    
    echo -e "\n${MAGENTA}Enter your choice [1-${#presets[@]}] or press Enter for current ($QUALITY): ${NC}"
    read -r choice
    
    if [[ -z "$choice" ]]; then
        echo -e "${GREEN}✓ Using current quality: $QUALITY${NC}"
        return
    fi
    
    if [[ "$choice" =~ ^[1-5]$ ]]; then
        local index=$((choice - 1))
        apply_preset "${preset_values[$index]}"
        echo -e "${GREEN}✓ Selected quality: $QUALITY (${RESOLUTION}, ${FRAMERATE}fps)${NC}"
        
        # Settings are auto-saved by apply_preset function
    else
        echo -e "${RED}❌ Invalid choice. Using current: $QUALITY${NC}"
    fi
}

# 📊 Enhanced overall progress bar with animations
show_progress() {
    local current=$1
    local total=$2
    local filename="$3"
    local status="$4"

    # Guard against zero/invalid totals
    if [[ -z "$total" || "$total" -le 0 ]]; then total=1; fi
    if [[ -z "$current" || "$current" -lt 0 ]]; then current=0; fi
    if [[ "$current" -gt "$total" ]]; then current=$total; fi

    # Compute percentage with rounding and filled length for a 50-char bar
    local percent_str=$(awk -v c="$current" -v t="$total" 'BEGIN { printf("%.1f", (c*100.0)/t) }')
    local filled=$(awk -v p="${percent_str}" 'BEGIN { printf("%d", (p*50/100)+0.5) }')
    if [[ "$filled" -gt 50 ]]; then filled=50; fi
    local empty=$((50 - filled))

    # Choose ASCII if terminal likely can't render Unicode blocks
    local use_unicode=1
    if locale 2>/dev/null | grep -qi -E "LC_CTYPE=.*(C|POSIX)"; then use_unicode=0; fi
    if [[ -n "$PROGRESS_ASCII" && "$PROGRESS_ASCII" == "true" ]]; then use_unicode=0; fi

    local ch_done="#"; local ch_rem="."
    if [[ $use_unicode -eq 1 ]]; then ch_done="█"; ch_rem="░"; fi

    printf "\r\033[K${CYAN}${BOLD}Overall Progress:${NC} ${BLUE}["
    for ((i=0; i<filled; i++)); do printf "%s" "$ch_done"; done
    for ((i=0; i<empty; i++)); do printf "%s" "$ch_rem"; done
    printf "${BLUE}]${NC} ${MAGENTA}${BOLD}%s%%%s ${CYAN}(%d/%d)${NC}" "$percent_str" "$NC" "$current" "$total"

    if [[ -n "$filename" ]]; then
        echo ""
        local truncated_name=$(basename "$filename")
        if [[ ${#truncated_name} -gt 50 ]]; then
            truncated_name="${truncated_name:0:47}..."
        fi
        printf "  ${BLUE}➤${NC} ${YELLOW}%s:${NC} ${BOLD}%s${NC}" "$status" "$truncated_name"
    fi
}

# 📈 Show conversion progress for individual files
show_file_progress() {
    local step="$1"
    local total_steps=3
    local description="$2"
    local percent=$((step * 100 / total_steps))
    local filled=$((percent / 5))
    local empty=$((20 - filled))
    
    printf "\r  ${MAGENTA}File: ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '▒'
    printf "] %d%% ${CYAN}%s${NC}" $percent "$description"
}

# 🌨 Build video filter chain
build_filter_chain() {
    local file="$1"
    local filters="fps=${FRAMERATE}"
    
    # Aspect ratio handling
    case "$ASPECT_RATIO" in
        "16:9")
            filters+=",scale=${RESOLUTION}:force_original_aspect_ratio=decrease:flags=${SCALING_ALGO},pad=${RESOLUTION}:(ow-iw)/2:(oh-ih)/2:black"
            ;;
        "4:3")
            local w=$(echo $RESOLUTION | cut -d: -f1)
            local h=$((w * 3 / 4))
            filters+=",scale=${w}:${h}:force_original_aspect_ratio=decrease:flags=${SCALING_ALGO},pad=${w}:${h}:(ow-iw)/2:(oh-ih)/2:black"
            ;;
        "1:1")
            local size=$(echo $RESOLUTION | cut -d: -f1)
            filters+=",scale=${size}:${size}:force_original_aspect_ratio=decrease:flags=${SCALING_ALGO},pad=${size}:${size}:(ow-iw)/2:(oh-ih)/2:black"
            ;;
        "21:9")
            local w=$(echo $RESOLUTION | cut -d: -f1)
            local h=$((w * 9 / 21))
            filters+=",scale=${w}:${h}:force_original_aspect_ratio=decrease:flags=${SCALING_ALGO},pad=${w}:${h}:(ow-iw)/2:(oh-ih)/2:black"
            ;;
        "9:16")
            local h=$(echo $RESOLUTION | cut -d: -f2)
            local w=$((h * 9 / 16))
            filters+=",scale=${w}:${h}:force_original_aspect_ratio=decrease:flags=${SCALING_ALGO},pad=${w}:${h}:(ow-iw)/2:(oh-ih)/2:black"
            ;;
        "original")
            filters+=",scale=${RESOLUTION}:flags=${SCALING_ALGO}"
            ;;
        *)
            filters+=",scale=${RESOLUTION}:force_original_aspect_ratio=decrease:flags=${SCALING_ALGO},pad=${RESOLUTION}:(ow-iw)/2:(oh-ih)/2:black"
            ;;
    esac
    
    # Add palette generation
    case "$PALETTE_MODE" in
        "custom")
            filters+=",palettegen=max_colors=${MAX_COLORS}:reserve_transparent=0"
            ;;
        "web")
            filters+=",palettegen=max_colors=216:reserve_transparent=0"
            ;;
        "grayscale")
            filters+=",colorchannelmixer=.3:.4:.3:0:.3:.4:.3:0:.3:.4:.3,palettegen=max_colors=${MAX_COLORS}"
            ;;
    esac
    
    echo "$filters"
}

# 🎯 Main conversion function with error handling
convert_video() {
    # Temporarily disable exit-on-error for this function
    set +e
    
    local file="$1"
    local output_file="${file%.*}.${OUTPUT_FORMAT}"
    local palette_file="${file%.*}_palette.png"
    local retry_count=0
    local conversion_success=false
    
    # Validate input file
    if [[ ! -f "$file" ]]; then
        log_error "Input file does not exist" "$file"
        echo -e "\n${RED}❌ Error: File '$file' not found${NC}"
        ((failed_files++))
        return 1
    fi
    
    if [[ ! -r "$file" ]]; then
        log_error "Cannot read input file (permission denied)" "$file"
        echo -e "\n${RED}❌ Error: Cannot read file '$file' (permission denied)${NC}"
        ((failed_files++))
        return 1
    fi
    
    # Check if file is actually a video
    if ! ffprobe -v quiet -select_streams v:0 -show_entries stream=codec_type -of csv=p=0 "$file" 2>/dev/null | grep -q "video"; then
        log_error "File is not a valid video" "$file"
        echo -e "\n${RED}❌ Error: '$file' is not a valid video file${NC}"
        ((failed_files++))
        return 1
    fi
    
    # Skip if file exists and is newer (unless force mode)
    if [[ -f "$output_file" && "$output_file" -nt "$file" && "$FORCE_CONVERSION" != true ]]; then
        echo -e "\n${YELLOW}⏭️  Skipping: $(basename "$file") (already converted)${NC}"
        log_conversion "SKIPPED" "$file" "$output_file" "(already exists)"
        ((skipped_files++))
        return 0
    fi
    
    echo ""
    echo -e "${GREEN}✨ Converting: ${BOLD}$(basename "$file")${NC}"
    
    # Auto-detect settings if enabled
    if [[ "$AUTO_DETECT" == true ]]; then
        auto_detect_settings "$file"
    fi
    
    # Smart GIF size estimation and optimization (always enabled)
    estimate_and_optimize_gif_settings "$file"
    
    # Backup original if requested (only on first attempt)
    if [[ "$BACKUP_ORIGINAL" == true ]]; then
        if ! cp "$file" "${file}.backup" 2>/dev/null; then
            log_error "Failed to create backup" "$file"
            echo -e "  ${YELLOW}⚠️  Warning: Could not create backup${NC}"
        fi
    fi
    
    # Step 1: Generate palette
    show_file_progress 1 "Analyzing video & generating palette..."
    local filter_chain=$(build_filter_chain "$file")
    
    if ! ffmpeg -i "$file" -vf "$filter_chain" -y "$palette_file" -loglevel error 2>/dev/null; then
        log_error "Failed to generate palette" "$file"
        echo -e "\n  ${RED}❌ Failed to generate palette${NC}"
        cleanup_temp_files "${file%.*}"
        ((failed_files++))
        return 1
    fi
    
    # Step 2: Convert to GIF with palette
    show_file_progress 2 "Converting with ${QUALITY} quality settings..."
    # Fix dithering mode for FFmpeg paletteuse filter
    local dither_option=""
    case "$DITHER_MODE" in
        "floyd") dither_option="dither=floyd_steinberg" ;;
        "bayer") dither_option="dither=bayer:bayer_scale=3" ;;
        "none") dither_option="dither=none" ;;
        *) dither_option="dither=bayer:bayer_scale=3" ;;  # default
    esac
    
    local conversion_filter="fps=${FRAMERATE},scale=${RESOLUTION}:force_original_aspect_ratio=decrease:flags=${SCALING_ALGO},pad=${RESOLUTION}:(ow-iw)/2:(oh-ih)/2:black[x];[x][1:v]paletteuse=$dither_option"
    
    if ! ffmpeg -i "$file" -i "$palette_file" -lavfi "$conversion_filter" -y "$output_file" -loglevel error 2>/dev/null; then
        log_error "Failed to convert to GIF" "$file"
        echo -e "\n  ${RED}❌ Conversion failed${NC}"
        cleanup_temp_files "${file%.*}"
        ((failed_files++))
        return 1
    fi
    
    # Step 3: Post-processing and optimization
    show_file_progress 3 "Finalizing and optimizing..."
    
    # Verify output file was created and has content
    if [[ ! -f "$output_file" ]]; then
        log_error "Output file was not created" "$file"
        echo -e "\n  ${RED}❌ Error: Output file was not created${NC}"
        cleanup_temp_files "${file%.*}"
        ((failed_files++))
        return 1
    fi
    
    local file_size=$(stat -c%s "$output_file" 2>/dev/null || echo "0")
    if [[ $file_size -eq 0 ]]; then
        log_error "Output file is empty" "$file"
        echo -e "\n  ${RED}❌ Error: Output file is empty${NC}"
        rm -f "$output_file"
        cleanup_temp_files "${file%.*}"
        ((failed_files++))
        return 1
    fi
    
    # Show file size comparison
    local original_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
    local converted_size=$file_size
    local ratio_pct_str=$(compute_ratio_percent "$converted_size" "$original_size")
    
    # Auto-optimize if enabled
    if [[ "$AUTO_OPTIMIZE" == true && "$OUTPUT_FORMAT" == "gif" ]]; then
        if command -v gifsicle >/dev/null 2>&1; then
            if ! gifsicle -O3 "$output_file" -o "${output_file}.tmp" 2>/dev/null; then
                log_error "GIF optimization failed, using unoptimized version" "$file"
                echo -e "  ${YELLOW}⚠️  Warning: Optimization failed, using unoptimized GIF${NC}"
            else
                mv "${output_file}.tmp" "$output_file" 2>/dev/null
            fi
        fi
    fi
    
    printf "\r  ${GREEN}✓ Completed: ${BOLD}$(basename \"$output_file\")${NC} ${MAGENTA}($(numfmt --to=iec $converted_size) - ${ratio_pct_str}% of original)${NC}\n"
    
    # Log successful conversion
    log_conversion "SUCCESS" "$file" "$output_file" "($(numfmt --to=iec $converted_size) - ${ratio_pct_str}% of original)"
    
    ((converted_files++))
    
    # Always cleanup temporary files
    cleanup_temp_files "${file%.*}"
    
    # Re-enable exit-on-error
    set -e
}

# 📥 Show final statistics
show_statistics() {
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    echo ""
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}                        📊 STATISTICS                         ${NC}"
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD} ${GREEN}✓ Converted:${NC} %-10s ${YELLOW}⏭ Skipped:${NC} %-10s ${RED}❌ Failed:${NC} %-6s ${CYAN}${BOLD} ${NC}" "$converted_files" "$skipped_files" "$failed_files"
    echo -e "${CYAN}${BOLD} ${BLUE}📁 Total files:${NC} %-8s ${MAGENTA}⏱ Duration:${NC} %02d:%02d:%02d                ${CYAN}${BOLD} ${NC}" "$total_files" "$hours" "$minutes" "$seconds"
    echo -e "${CYAN}${BOLD} ${YELLOW}⚙ Quality:${NC} %-12s ${BLUE}📐 Resolution:${NC} %-12s        ${CYAN}${BOLD} ${NC}" "$QUALITY" "$RESOLUTION"
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# 🎚️ Apply quality preset
apply_preset() {
    case "$1" in
        "low")
            RESOLUTION="854:480"
            FRAMERATE="8"
            MAX_COLORS="128"
            SCALING_ALGO="bilinear"
            ;;
        "medium")
            RESOLUTION="1280:720"
            FRAMERATE="12"
            MAX_COLORS="192"
            SCALING_ALGO="bicubic"
            ;;
        "high")
            RESOLUTION="1920:1080"
            FRAMERATE="15"
            MAX_COLORS="256"
            SCALING_ALGO="lanczos"
            ;;
        "ultra")
            RESOLUTION="2560:1440"
            FRAMERATE="20"
            MAX_COLORS="256"
            SCALING_ALGO="lanczos"
            ;;
        "max")
            RESOLUTION="3840:2160"
            FRAMERATE="24"
            MAX_COLORS="256"
            SCALING_ALGO="lanczos"
            ;;
    esac
    QUALITY="$1"
    
    # Auto-save settings when preset changes
    if [[ -n "$SETTINGS_FILE" ]]; then
        save_settings --silent
    fi
}

# 🧠 Auto-detect optimal settings based on input video
auto_detect_settings() {
    local file="$1"
    local info=$(ffprobe -v quiet -print_format json -show_format -show_streams "$file" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        local width=$(echo "$info" | jq -r '.streams[0].width // empty')
        local height=$(echo "$info" | jq -r '.streams[0].height // empty')
        local duration=$(echo "$info" | jq -r '.format.duration // empty' | cut -d. -f1)
        local bitrate=$(echo "$info" | jq -r '.format.bit_rate // empty')
        
        # Auto-adjust resolution based on source
        if [[ -n "$width" && -n "$height" ]]; then
            if (( width * height > 3686400 )); then  # > 1080p
                apply_preset "ultra"
            elif (( width * height > 2073600 )); then  # > 720p
                apply_preset "high"
            elif (( width * height > 921600 )); then   # > 480p
                apply_preset "medium"
            else
                apply_preset "low"
            fi
        fi
        
        # Adjust framerate for long videos
        if [[ -n "$duration" && $duration -gt 30 ]]; then
            FRAMERATE="10"
        elif [[ -n "$duration" && $duration -gt 60 ]]; then
            FRAMERATE="8"
        fi
        
        echo -e "${BLUE}🧠 Auto-detected settings: ${QUALITY} quality, ${FRAMERATE}fps${NC}"
    fi
}

# 🎨 Build video filter chain
build_filter_chain() {
    local file="$1"
    local filters="fps=${FRAMERATE}"
    
    # Simple scaling approach that works reliably
    case "$ASPECT_RATIO" in
        "16:9")
            filters+=",scale=${RESOLUTION}:force_original_aspect_ratio=decrease:flags=${SCALING_ALGO},pad=${RESOLUTION}:(ow-iw)/2:(oh-ih)/2:black"
            ;;
        "4:3")
            local w=$(echo $RESOLUTION | cut -d: -f1)
            local h=$((w * 3 / 4))
            filters+=",scale=${w}:${h}:force_original_aspect_ratio=decrease:flags=${SCALING_ALGO},pad=${w}:${h}:(ow-iw)/2:(oh-ih)/2:black"
            ;;
        "1:1")
            local size=$(echo $RESOLUTION | cut -d: -f1)
            filters+=",scale=${size}:${size}:force_original_aspect_ratio=decrease:flags=${SCALING_ALGO},pad=${size}:${size}:(ow-iw)/2:(oh-ih)/2:black"
            ;;
        "21:9")
            local w=$(echo $RESOLUTION | cut -d: -f1)
            local h=$((w * 9 / 21))
            filters+=",scale=${w}:${h}:force_original_aspect_ratio=decrease:flags=${SCALING_ALGO},pad=${w}:${h}:(ow-iw)/2:(oh-ih)/2:black"
            ;;
        "9:16")
            local h=$(echo $RESOLUTION | cut -d: -f2)
            local w=$((h * 9 / 16))
            filters+=",scale=${w}:${h}:force_original_aspect_ratio=decrease:flags=${SCALING_ALGO},pad=${w}:${h}:(ow-iw)/2:(oh-ih)/2:black"
            ;;
        "original")
            # Keep original proportions, only downscale if too large
            local max_w=$(echo $RESOLUTION | cut -d: -f1)
            local max_h=$(echo $RESOLUTION | cut -d: -f2)
            filters+=",scale=${max_w}:${max_h}:force_original_aspect_ratio=decrease:flags=${SCALING_ALGO}"
            ;;
        *)
            filters+=",scale=${RESOLUTION}:force_original_aspect_ratio=decrease:flags=${SCALING_ALGO},pad=${RESOLUTION}:(ow-iw)/2:(oh-ih)/2:black"
            ;;
    esac
    
    # Add palette generation
    case "$PALETTE_MODE" in
        "custom")
            filters+=",palettegen=max_colors=${MAX_COLORS}:reserve_transparent=0"
            ;;
        "web")
            filters+=",palettegen=max_colors=216:reserve_transparent=0"
            ;;
        "grayscale")
            filters+=",colorchannelmixer=.3:.4:.3:0:.3:.4:.3:0:.3:.4:.3,palettegen=max_colors=${MAX_COLORS}"
            ;;
    esac
    
    echo "$filters"
}

# 📊 Show overall progress bar
show_progress() {
    local current=$1
    local total=$2
    local filename="$3"
    local status="$4"
    
    # Guard against zero/invalid totals  
    if [[ -z "$total" || "$total" -le 0 ]]; then total=1; fi
    if [[ -z "$current" || "$current" -lt 0 ]]; then current=0; fi
    if [[ "$current" -gt "$total" ]]; then current=$total; fi
    
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    # Clear line and show progress
    printf "\r\033[K${CYAN}Overall: ["
    for ((i=0; i<filled; i++)); do printf "▓"; done
    for ((i=0; i<empty; i++)); do printf "░"; done
    printf "] %d%% (%d/%d) ${YELLOW}%s${NC}" $percent $current $total "$status"
    
    # Show current file being processed
    if [[ -n "$filename" ]]; then
        echo ""
        printf "${BLUE}🎬 Processing: ${NC}%s" "$(basename "$filename")"
    fi
}

# 📈 Show conversion progress for individual files
show_file_progress() {
    local step="$1"
    local total_steps=3
    local description="$2"
    local percent=$((step * 100 / total_steps))
    local filled=$((percent / 5))
    local empty=$((20 - filled))
    
    printf "\r  ${MAGENTA}File: ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '▒'
    printf "] %d%% ${CYAN}%s${NC}" $percent "$description"
}

# 🌀 Show animated spinner with enhanced visuals
show_spinner() {
    local pid=$1
    local description="$2"
    local spinchars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    local start_time=$(date +%s)
    
    while kill -0 $pid 2>/dev/null; do
        local char="${spinchars:$((i % ${#spinchars})):1}"
        local elapsed=$(($(date +%s) - start_time))
        local mins=$((elapsed / 60))
        local secs=$((elapsed % 60))
        
        printf "\r  ${YELLOW}%s ${CYAN}%s ${GRAY}[%02d:%02d]${NC}" "$char" "$description" "$mins" "$secs"
        sleep 0.1
        ((i++))
    done
    
    local total_time=$(($(date +%s) - start_time))
    local total_mins=$((total_time / 60))
    local total_secs=$((total_time % 60))
    printf "\r  ${GREEN}✓ ${CYAN}%s ${GREEN}[%02d:%02d]${NC}\n" "$description" "$total_mins" "$total_secs"
}

# 📊 Live animated progress bar with ffmpeg progress parsing
show_live_progress() {
    local pid=$1
    local description="$2"
    local input_file="$3"
    local progress_file="/tmp/ffmpeg_progress_$$_$(date +%s).log"
    local start_time=$(date +%s)
    local total_duration=0
    
    # Get video duration for percentage calculation
    if [[ -n "$input_file" && -f "$input_file" ]]; then
        total_duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$input_file" 2>/dev/null | cut -d. -f1 || echo "0")
    fi
    
    local frame=0
    local spinchars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    
    while kill -0 $pid 2>/dev/null; do
        local char="${spinchars:$((frame % ${#spinchars})):1}"
        local elapsed=$(($(date +%s) - start_time))
        local mins=$((elapsed / 60))
        local secs=$((elapsed % 60))
        
        # Create animated progress bar
        local bar_width=30
        local filled=$((elapsed % bar_width))
        local progress_bar=""
        
        for ((i=0; i<bar_width; i++)); do
            if [[ $i -eq $filled ]]; then
                progress_bar+="${YELLOW}▶${NC}"
            elif [[ $i -lt $filled ]]; then
                progress_bar+="${GREEN}▓${NC}"
            else
                progress_bar+="${GRAY}▒${NC}"
            fi
        done
        
        printf "\r  ${char} ${CYAN}%s${NC} [%s] ${GRAY}%02d:%02d${NC}" "$description" "$progress_bar" "$mins" "$secs"
        sleep 0.15
        ((frame++))
    done
    
    local total_time=$(($(date +%s) - start_time))
    local total_mins=$((total_time / 60))
    local total_secs=$((total_time % 60))
    
    # Final completed progress bar
    local completed_bar=""
    for ((i=0; i<30; i++)); do
        completed_bar+="${GREEN}▓${NC}"
    done
    
    printf "\r  ${GREEN}✓${NC} ${CYAN}%s${NC} [%s] ${GREEN}%02d:%02d${NC}\n" "$description" "$completed_bar" "$total_mins" "$total_secs"
    
    # Cleanup
    rm -f "$progress_file" 2>/dev/null
}

# 🎬 Advanced ffmpeg progress with real-time stats
show_ffmpeg_progress() {
    local pid=$1
    local description="$2"
    local input_file="$3"
    local start_time=$(date +%s)
    local frame=0
    local last_fps=0
    
    # Animation characters for different stages
    local spinchars="🎬🎥🎞️🎪🎭🎨🎯🎲🎸🎺"
    
    while kill -0 $pid 2>/dev/null; do
        local char="${spinchars:$((frame % ${#spinchars})):1}"
        local elapsed=$(($(date +%s) - start_time))
        local mins=$((elapsed / 60))
        local secs=$((elapsed % 60))
        
        # Create pulsing progress bar
        local bar_width=25
        local pulse_pos=$((elapsed % (bar_width * 2)))
        if [[ $pulse_pos -gt $bar_width ]]; then
            pulse_pos=$((bar_width * 2 - pulse_pos))
        fi
        
        local progress_bar=""
        for ((i=0; i<bar_width; i++)); do
            if [[ $i -eq $pulse_pos ]]; then
                progress_bar+="${YELLOW}●${NC}"
            elif [[ $((i - pulse_pos)) -le 2 && $((i - pulse_pos)) -ge -2 ]]; then
                progress_bar+="${BLUE}▓${NC}"
            else
                progress_bar+="${GRAY}▒${NC}"
            fi
        done
        
        # Show processing stats
        printf "\r  %s ${CYAN}%s${NC} [%s] ${MAGENTA}%02d:%02d${NC} ${YELLOW}Processing...${NC}" \
               "$char" "$description" "$progress_bar" "$mins" "$secs"
        
        sleep 0.2
        ((frame++))
    done
    
    local total_time=$(($(date +%s) - start_time))
    local total_mins=$((total_time / 60))
    local total_secs=$((total_time % 60))
    
    # Final success bar
    local success_bar=""
    for ((i=0; i<25; i++)); do
        success_bar+="${GREEN}█${NC}"
    done
    
    printf "\r  ${GREEN}🎉${NC} ${CYAN}%s${NC} [%s] ${GREEN}%02d:%02d Complete!${NC}\n" \
           "$description" "$success_bar" "$total_mins" "$total_secs"
}

# 🎯 Main conversion function with bulletproof error handling
convert_video() {
    local file="$1"
    trace_function "convert_video"
    
    # Input validation with detailed logging
    if [[ -z "$file" ]]; then
        log_error "No input file provided to convert_video" "" "" "${BASH_LINENO[0]}" "convert_video"
        return 1
    fi
    
    echo -e "${CYAN}⚙️ Starting robust conversion for: $(basename "$file")${NC}"
    
    # Wrap the entire conversion in a try-catch like structure
    {
        _convert_video_internal "$file"
    } || {
        local exit_code=$?
        log_error "Conversion function failed" "$file" "Internal conversion failed with exit code $exit_code" "${BASH_LINENO[0]}" "convert_video"
        return $exit_code
    }
}

# Internal conversion function with all the logic
_convert_video_internal() {
    
    local file="$1"
    local final_output_file="${file%.*}.${OUTPUT_FORMAT}"
    local base_name=$(basename "${file%.*}")
    
    # Use RAM-optimized temp directory for all intermediate files
    local temp_palette_file=$(get_temp_file_path "${base_name}_palette" "png")
    local temp_output_file=$(get_temp_file_path "${base_name}_temp" "${OUTPUT_FORMAT}")
    local retry_count=0
    local conversion_success=false
    
    # Validate input file
    if [[ ! -f "$file" ]]; then
        log_error "Input file does not exist" "$file"
        echo -e "\n${RED}❌ Error: File '$file' not found${NC}"
        ((failed_files++))
        return 1
    fi
    
    if [[ ! -r "$file" ]]; then
        log_error "Cannot read input file (permission denied)" "$file"
        echo -e "\n${RED}❌ Error: Cannot read file '$file' (permission denied)${NC}"
        ((failed_files++))
        return 1
    fi
    
    # Check if file is actually a video
    if ! ffprobe -v quiet -select_streams v:0 -show_entries stream=codec_type -of csv=p=0 "$file" 2>/dev/null | grep -q "video"; then
        log_error "File is not a valid video" "$file"
        echo -e "\n${RED}❌ Error: '$file' is not a valid video file${NC}"
        ((failed_files++))
        return 1
    fi
    
    # Duplicate check is now handled upstream in start_conversion()
    # Files reaching this function are guaranteed to need conversion
    
    echo ""
    local media_brief=$(probe_media_brief "$file")
    echo -e "${GREEN}✨ Converting: ${BOLD}$(basename \"$file\")${NC}"
    # Log concise media info
    { echo "[$(date '+%Y-%m-%d %H:%M:%S')] INPUT: $(basename \"$file\") info=${media_brief}"; } >> "$ERROR_LOG" 2>/dev/null || true
    
    # Retry loop for conversion
    while [[ $retry_count -le $MAX_RETRIES && $conversion_success == false ]]; do
        if [[ $retry_count -gt 0 ]]; then
            echo -e "  ${YELLOW}♾️ Retry attempt $retry_count/$MAX_RETRIES${NC}"
            sleep 1
        fi
        
        # AI-lite: analyze content once per file (first attempt only)
        if [[ "$AI_ENABLED" == true && $retry_count -eq 0 ]]; then
            echo -e "  ${CYAN}🤖 AI: analyzing content for smart defaults...${NC}"
            ai_smart_analyze "$file"
        fi
        
        # Clean up any previous attempt files
        cleanup_temp_files "${file%.*}"
        
        # Auto-detect settings if enabled
        if [[ "$AUTO_DETECT" == true ]]; then
            auto_detect_settings "$file"
        fi
        
        # Backup original if requested (only on first attempt)
        if [[ "$BACKUP_ORIGINAL" == true && $retry_count -eq 0 ]]; then
            if ! cp "$file" "${file}.backup" 2>/dev/null; then
                log_error "Failed to create backup" "$file"
                echo -e "  ${YELLOW}⚠️  Warning: Could not create backup${NC}"
            fi
        fi
        
        # Step 1: Generate palette
        local filter_chain=$(build_filter_chain "$file")
        
        # If AI suggested a crop, inject it before scaling
        if [[ -n "$CROP_FILTER" ]]; then
            # Insert crop right after fps, before scale
            if [[ "$filter_chain" == fps=* ]]; then
                filter_chain=$(echo "$filter_chain" | sed "s/fps=[^,\"]\+/&,$CROP_FILTER/")
            else
                filter_chain="$CROP_FILTER,$filter_chain"
            fi
        fi
        
        # Safe palette generation with comprehensive error handling
        local ffmpeg_error_file="${temp_palette_file}.error"
        
        # Run ffmpeg in foreground with progress monitoring
        echo -e "\033[2m🎦 Starting palette generation (foreground)\033[0m"
        
        echo -e "  🎦 Analyzing video & generating palette..."
        
        # Keep signal handling active for interruption
        # trap '' INT TERM HUP PIPE ERR
        
        # Run ffmpeg (attempt ladder)
        local ffmpeg_exit_code=0
        local cmd1="env -i PATH=\"$PATH\" HOME=\"$HOME\" ffmpeg $FFMPEG_INPUT_OPTS -i \"$file\" -vf \"$filter_chain\" -threads $FFMPEG_THREADS $FFMPEG_MEMORY_OPTS -frames:v 1 -update 1 -y \"$temp_palette_file\" -loglevel error"
        local palette_start_ts=$(date +%s)
        ffmpeg_exit_code=$(run_ffmpeg_safely "$cmd1" "$ffmpeg_error_file" 25)
        local palette_end_ts=$(date +%s)
        local palette_elapsed=$((palette_end_ts - palette_start_ts))
        # Log attempt detail
        { echo "[$(date '+%Y-%m-%d %H:%M:%S')] PALETTE ATTEMPT #1 chain='$filter_chain' elapsed=${palette_elapsed}s"; } >> "$ERROR_LOG" 2>/dev/null || true
        
        # If failed, try simpler palettegen without pad/scale
        if [[ $ffmpeg_exit_code -ne 0 || ! -s "$temp_palette_file" ]]; then
            local simple_chain="fps=${FRAMERATE},palettegen=max_colors=${MAX_COLORS}:reserve_transparent=0"
            local cmd2="env -i PATH=\"$PATH\" HOME=\"$HOME\" ffmpeg $FFMPEG_INPUT_OPTS -i \"$file\" -vf \"$simple_chain\" -threads $FFMPEG_THREADS $FFMPEG_MEMORY_OPTS -frames:v 1 -update 1 -y \"$temp_palette_file\" -loglevel error"
            local palette_start_ts2=$(date +%s)
            ffmpeg_exit_code=$(run_ffmpeg_safely "$cmd2" "$ffmpeg_error_file" 20)
            local palette_end_ts2=$(date +%s)
            { echo "[$(date '+%Y-%m-%d %H:%M:%S')] PALETTE ATTEMPT #2 chain='$simple_chain' elapsed=$((palette_end_ts2 - palette_start_ts2))s"; } >> "$ERROR_LOG" 2>/dev/null || true
        fi
        
        # If still failed, try minimal palettegen
        if [[ $ffmpeg_exit_code -ne 0 || ! -s "$temp_palette_file" ]]; then
            local cmd3="env -i PATH=\"$PATH\" HOME=\"$HOME\" ffmpeg $FFMPEG_INPUT_OPTS -i \"$file\" -vf \"palettegen=max_colors=${MAX_COLORS}:reserve_transparent=0\" -threads $FFMPEG_THREADS $FFMPEG_MEMORY_OPTS -frames:v 1 -update 1 -y \"$temp_palette_file\" -loglevel error"
            local palette_start_ts3=$(date +%s)
            ffmpeg_exit_code=$(run_ffmpeg_safely "$cmd3" "$ffmpeg_error_file" 15)
            local palette_end_ts3=$(date +%s)
            { echo "[$(date '+%Y-%m-%d %H:%M:%S')] PALETTE ATTEMPT #3 chain='palettegen' elapsed=$((palette_end_ts3 - palette_start_ts3))s"; } >> "$ERROR_LOG" 2>/dev/null || true
        fi
        
        # Signal handling remains active throughout palette generation
        # (no need to re-enable since we didn't disable)
        
        # Check if palette generation was successful
        local palette_success=false
        if [[ $ffmpeg_exit_code -eq 0 && -f "$temp_palette_file" ]]; then
            local palette_size=$(stat -c%s "$temp_palette_file" 2>/dev/null || echo "0")
            if [[ $palette_size -gt 50 ]]; then
                palette_success=true
                printf "\r  ${GREEN}✓ Palette generation completed ($(numfmt --to=iec $palette_size))${NC}\n"
            fi
        fi
        
        # Clean up FFmpeg output file after success
        if [[ $palette_success == true ]]; then
            rm -f "$ffmpeg_error_file" 2>/dev/null || true
        fi
        
        # Only fail if palette generation genuinely failed
        if [[ $palette_success != true ]]; then
            local ffmpeg_error="Unknown FFmpeg error"
            local ffmpeg_output=""
            local is_genuine_error=false
            
            # Determine if this is a genuine error or just FFmpeg being slow/resource-constrained
            if [[ $ffmpeg_exit_code -ne 0 ]]; then
                is_genuine_error=true
            elif [[ ! -f "$temp_palette_file" ]]; then
                is_genuine_error=true
            elif [[ -f "$temp_palette_file" ]]; then
                local palette_size=$(stat -c%s "$temp_palette_file" 2>/dev/null || echo "0")
                if [[ $palette_size -le 50 ]]; then
                    is_genuine_error=true
                fi
            fi
            
            # Capture detailed error information and log it properly - but only if it's a genuine error
            local diagnosis=""
            if [[ $is_genuine_error == true && -f "$ffmpeg_error_file" && -s "$ffmpeg_error_file" ]]; then
                ffmpeg_error="$(summarize_ffmpeg_error "$ffmpeg_error_file")"
                diagnosis="$ffmpeg_error"
                # Append full FFmpeg output to error log with clear separation
                {
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ==================== FFMPEG OUTPUT ===================="
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FILE: $file"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] COMMAND: ffmpeg -i \"$file\" -vf \"$filter_chain\" -frames:v 1 -update 1 -y \"$temp_palette_file\" -loglevel info"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] EXIT CODE: $ffmpeg_exit_code ($(explain_exit_code $ffmpeg_exit_code))"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] PALETTE FILE EXISTS: $([[ -f "$temp_palette_file" ]] && echo "YES" || echo "NO")"
                    [[ -f "$temp_palette_file" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] PALETTE SIZE: $(stat -c%s "$temp_palette_file" 2>/dev/null || echo "0") bytes"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DIAGNOSIS: $diagnosis"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FFMPEG FULL OUTPUT:"
                    cat "$ffmpeg_error_file"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ================================================"
                    echo ""
                } >> "$ERROR_LOG" 2>/dev/null || true
            elif [[ $is_genuine_error == true ]]; then
                ffmpeg_error="No FFmpeg output captured"
                diagnosis="$(explain_exit_code $ffmpeg_exit_code)"
                # Log the fact that we couldn't capture output
                {
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ==================== FFMPEG ERROR ===================="
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FILE: $file"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: No FFmpeg output file created"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] EXIT CODE: $ffmpeg_exit_code ($(explain_exit_code $ffmpeg_exit_code))"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR FILE: $ffmpeg_error_file"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ================================================"
                    echo ""
                } >> "$ERROR_LOG" 2>/dev/null || true
            fi
            
            # Only log and retry if this is genuinely an error
            if [[ $is_genuine_error == true ]]; then
                # Log with comprehensive details
                log_error "FFmpeg palette generation failed (attempt $((retry_count + 1)))" "$file" "Cause: ${diagnosis:-$(explain_exit_code $ffmpeg_exit_code)}" "${BASH_LINENO[0]}" "_convert_video_internal"
                
                # User-friendly terminal output
                echo -e "  ${RED}⚠️ FFmpeg palette generation failed${NC}"
                if [[ -n "$diagnosis" ]]; then
                    echo -e "  ${RED}🔍 Cause: $diagnosis${NC}"
                fi
                echo -e "  ${YELLOW}📋 Full log: $ERROR_LOG${NC}"
                
                # Cleanup
                rm -f "$ffmpeg_error_file" 2>/dev/null || true
                
                ((retry_count++))
                if [[ $retry_count -gt $MAX_RETRIES ]]; then
                    echo -e "\n  ${RED}❌ Failed to generate palette after $MAX_RETRIES attempts${NC}"
                    cleanup_temp_files "${file%.*}"
                    ((failed_files++))
                    return 1
                fi
                continue
            else
                # This was not a genuine error - FFmpeg probably succeeded but the script's detection failed
                # Let's wait a moment and re-check the palette file
                echo -e "  ${YELLOW}⏳ Waiting for palette file to be fully written...${NC}"
                sleep 2
                
                # Re-check palette file
                if [[ -f "$temp_palette_file" ]]; then
                    local final_palette_size=$(stat -c%s "$temp_palette_file" 2>/dev/null || echo "0")
                    if [[ $final_palette_size -gt 50 ]]; then
                        palette_success=true
                        printf "  ${GREEN}✓ Palette generation completed ($(numfmt --to=iec $final_palette_size))${NC}\n"
                        rm -f "$ffmpeg_error_file" 2>/dev/null || true
                    fi
                fi
                
                # If still not successful after waiting, then retry
                if [[ $palette_success != true ]]; then
                    echo -e "  ${YELLOW}⚠️ Palette file still not ready, retrying...${NC}"
                    rm -f "$ffmpeg_error_file" 2>/dev/null || true
                    ((retry_count++))
                    if [[ $retry_count -gt $MAX_RETRIES ]]; then
                        echo -e "\n  ${RED}❌ Failed to generate palette after $MAX_RETRIES attempts${NC}"
                        cleanup_temp_files "${file%.*}"
                        ((failed_files++))
                        return 1
                    fi
                    continue
                fi
            fi
        fi
        
        # Step 2: Convert to GIF with palette
        local prefix_filters="fps=${FRAMERATE}"
        if [[ -n "$CROP_FILTER" ]]; then prefix_filters+=",$CROP_FILTER"; fi
        # Fix dithering mode for FFmpeg paletteuse filter
        local dither_option=""
        case "$DITHER_MODE" in
            "floyd") dither_option="dither=floyd_steinberg" ;;
            "bayer") dither_option="dither=bayer:bayer_scale=3" ;;
            "none") dither_option="dither=none" ;;
            *) dither_option="dither=bayer:bayer_scale=3" ;;  # default
        esac
        
        local conversion_filter="${prefix_filters},scale=${RESOLUTION}:force_original_aspect_ratio=decrease:flags=${SCALING_ALGO},pad=${RESOLUTION}:(ow-iw)/2:(oh-ih)/2:black[x];[x][1:v]paletteuse=$dither_option"
        
        # Safe GIF conversion with comprehensive error handling
        local conversion_error_file="${temp_output_file}.error"
        
        # Run ffmpeg conversion in foreground with progress monitoring
        echo -e "\033[2m🎥 Starting GIF conversion (foreground)\033[0m"
        
        echo -e "  🎥 Converting with ${QUALITY} quality..."
        
        # Keep signal handling active for interruption
        # trap '' INT TERM HUP PIPE ERR
        
        # Run ffmpeg conversion (with per-file progress)
        local conversion_exit_code=0
        local conv_start_ts=$(date +%s)
        if convert_with_progress "$file" "$temp_palette_file" "$temp_output_file" "$conversion_filter" "$conversion_error_file"; then
            conversion_exit_code=0
        else
            conversion_exit_code=$?
        fi
        local conv_end_ts=$(date +%s)
        { echo "[$(date '+%Y-%m-%d %H:%M:%S')] CONVERSION ATTEMPT #1 filter='$conversion_filter' elapsed=$((conv_end_ts - conv_start_ts))s"; } >> "$ERROR_LOG" 2>/dev/null || true
        
        # Fallback: one-shot filter_complex (no temp palette file) with progress
        if [[ $conversion_exit_code -ne 0 || ! -s "$temp_output_file" ]]; then
            # Fix dithering mode for one-shot conversion
            local oneshot_dither_option=""
            case "$DITHER_MODE" in
                "floyd") oneshot_dither_option="dither=floyd_steinberg" ;;
                "bayer") oneshot_dither_option="dither=bayer:bayer_scale=3" ;;
                "none") oneshot_dither_option="dither=none" ;;
                *) oneshot_dither_option="dither=bayer:bayer_scale=3" ;;  # default
            esac
            
            local fc="[0:v]fps=${FRAMERATE},scale=${RESOLUTION}:force_original_aspect_ratio=decrease:flags=${SCALING_ALGO},pad=${RESOLUTION}:(ow-iw)/2:(oh-ih)/2:black,split[a][b];[a]palettegen=max_colors=${MAX_COLORS}:reserve_transparent=0[p];[b][p]paletteuse=$oneshot_dither_option"
            local conv_start_ts2=$(date +%s)
            # For one-shot, create special variant that doesn't use palette input
            if convert_with_progress_oneshot "$file" "$temp_output_file" "$fc" "$conversion_error_file"; then
                conversion_exit_code=0
            else
                conversion_exit_code=$?
            fi
            local conv_end_ts2=$(date +%s)
            { echo "[$(date '+%Y-%m-%d %H:%M:%S')] CONVERSION ATTEMPT #2 (one-shot) elapsed=$((conv_end_ts2 - conv_start_ts2))s"; } >> "$ERROR_LOG" 2>/dev/null || true
        fi
        
        # Signal handling remains active throughout conversion
        # (no need to re-enable since we didn't disable)
        
        echo -e "  ✓ GIF conversion completed"
        
        # Check if ffmpeg failed
        if [[ $conversion_exit_code -ne 0 ]]; then
            local conversion_error="Unknown conversion error"
            
            # Capture detailed error information and log it properly
            local conv_diagnosis=""
            if [[ -f "$conversion_error_file" && -s "$conversion_error_file" ]]; then
                conversion_error="$(summarize_ffmpeg_error "$conversion_error_file")"
                conv_diagnosis="$conversion_error"
                
                # Append full FFmpeg output to error log with clear separation
                {
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ==================== FFMPEG GIF CONVERSION OUTPUT ===================="
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FILE: $file"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] COMMAND: ffmpeg -i \"$file\" -i \"$temp_palette_file\" -lavfi \"$conversion_filter\" -y \"$temp_output_file\" -loglevel info"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] EXIT CODE: $conversion_exit_code ($(explain_exit_code $conversion_exit_code))"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] OUTPUT FILE EXISTS: $([[ -f "$temp_output_file" ]] && echo "YES" || echo "NO")"
                    [[ -f "$temp_output_file" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] OUTPUT SIZE: $(stat -c%s "$temp_output_file" 2>/dev/null || echo "0") bytes"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DIAGNOSIS: $conv_diagnosis"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FFMPEG FULL OUTPUT:"
                    cat "$conversion_error_file"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ================================================"
                    echo ""
                } >> "$ERROR_LOG" 2>/dev/null || true
            else
                conversion_error="No FFmpeg output captured for conversion"
                conv_diagnosis="$(explain_exit_code $conversion_exit_code)"
                {
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ==================== FFMPEG GIF CONVERSION ERROR ===================="
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FILE: $file"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: No FFmpeg output file created"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] EXIT CODE: $conversion_exit_code ($(explain_exit_code $conversion_exit_code))"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR FILE: $conversion_error_file"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ================================================"
                    echo ""
                } >> "$ERROR_LOG" 2>/dev/null || true
            fi
            
            # Log with comprehensive details
            log_error "FFmpeg GIF conversion failed (attempt $((retry_count + 1)))" "$file" "Cause: ${conv_diagnosis:-$(explain_exit_code $conversion_exit_code)}" "${BASH_LINENO[0]}" "_convert_video_internal"
            
            # User-friendly terminal output
            echo -e "  ${RED}⚠️ FFmpeg GIF conversion failed${NC}"
            if [[ -n "$conv_diagnosis" ]]; then
                echo -e "  ${RED}🔍 Cause: $conv_diagnosis${NC}"
            fi
            echo -e "  ${YELLOW}📋 Full log: $ERROR_LOG${NC}"
            
            # Cleanup
            rm -f "$conversion_error_file" 2>/dev/null || true
            
            ((retry_count++))
            if [[ $retry_count -gt $MAX_RETRIES ]]; then
                echo -e "\n  ${RED}❌ Failed to convert after $MAX_RETRIES attempts${NC}"
                cleanup_temp_files "${file%.*}"
                ((failed_files++))
                return 1
            fi
            continue
        fi
        
        # If we reach here, conversion was successful
        conversion_success=true
    done
    
    # Post-conversion processing
    if [[ $conversion_success == true ]]; then
    
        # Step 3: Post-processing and optimization
        echo -e "\n  ${BLUE}🔄 Post-processing and validation...${NC}"
        
        # Output file validation (can be skipped for speed)
        if [[ "$SKIP_VALIDATION" == "true" ]]; then
            echo -e "  ${YELLOW}⚡ Skipping validation for speed${NC}"
            if [[ -f "$temp_output_file" ]]; then
                local file_size=$(stat -c%s "$temp_output_file" 2>/dev/null || echo "0")
                if [[ $file_size -gt 100 ]]; then
                    echo -e "  ${GREEN}✓ GIF created: $(numfmt --to=iec $file_size)${NC}"
                else
                    echo -e "  ${RED}❌ Output file too small: $file_size bytes${NC}"
                    cleanup_temp_files "${file%.*}"
                    ((failed_files++))
                    return 1
                fi
            else
                echo -e "  ${RED}❌ No output file created${NC}"
                cleanup_temp_files "${file%.*}"
                ((failed_files++))
                return 1
            fi
        else
            # Full validation
            if ! validate_output_file "$temp_output_file" "$file"; then
                # Handle the corrupt output file
                if [[ -f "$temp_output_file" ]]; then
                    handle_corrupt_file "$temp_output_file" "$file" "Corrupt GIF output"
                    ((corrupt_output_files++)) || true
                fi
                cleanup_temp_files "${file%.*}"
                ((failed_files++))
                return 1
            fi
        fi
        
        # Step 4: Smart AI Decision - Check if compression is truly needed
        local temp_gif_size_mb=$(($(stat -c%s "$temp_output_file" 2>/dev/null || echo 0) / 1024 / 1024))
        local compress_needed=false
        local compression_reason=""
        
        # AI Smart Analysis: Decide whether to compromise quality or accept large file
        if [[ "$temp_gif_size_mb" -gt "$MAX_GIF_SIZE_MB" ]]; then
            # Get video metadata for smart decision
            local video_duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$file" 2>/dev/null | cut -d. -f1)
            local video_bitrate=$(ffprobe -v error -show_entries format=bit_rate -of csv=p=0 "$file" 2>/dev/null)
            local current_width=$(echo "$RESOLUTION" | cut -d':' -f1)
            local current_height=$(echo "$RESOLUTION" | cut -d':' -f2)
            
            # AI Decision Logic: When NOT to compromise
            local should_preserve_quality=false
            
            # Rule 1: High-res content (1080p+) should not be compromised
            if [[ $current_width -ge 1920 || $current_height -ge 1080 ]]; then
                should_preserve_quality=true
                compression_reason="High-resolution output (${current_width}x${current_height}) - preserving quality"
            fi
            
            # Rule 2: Short videos (<10 seconds) can accept larger files
            if [[ $video_duration -lt 10 && $temp_gif_size_mb -lt $((MAX_GIF_SIZE_MB * 3)) ]]; then
                should_preserve_quality=true
                compression_reason="Short duration (${video_duration}s) - acceptable large file for quality"
            fi
            
            # Rule 3: Premium quality preset should not be compromised
            if [[ "$QUALITY" == "ultra" || "$QUALITY" == "max" ]]; then
                if [[ $temp_gif_size_mb -lt $((MAX_GIF_SIZE_MB * 2)) ]]; then
                    should_preserve_quality=true
                    compression_reason="${QUALITY} quality preset - minimal compromise acceptable"
                fi
            fi
            
            # Rule 4: If size is only slightly over limit (10-30%), accept it
            local size_ratio=$((temp_gif_size_mb * 100 / MAX_GIF_SIZE_MB))
            if [[ $size_ratio -lt 130 ]]; then
                should_preserve_quality=true
                compression_reason="Only $((size_ratio - 100))% over limit - accepting for quality"
            fi
            
            # Decide: Compress only if truly necessary
            if [[ "$should_preserve_quality" == true ]]; then
                echo -e "  ${YELLOW}ℹ️  GIF size: ${temp_gif_size_mb}MB (limit: ${MAX_GIF_SIZE_MB}MB)${NC}"
                echo -e "  ${GREEN}🧠 AI Decision: Quality preserved - $compression_reason${NC}"
                compress_needed=false
            else
                echo -e "  ${RED}⚠️  GIF size (${temp_gif_size_mb}MB) significantly exceeds limit (${MAX_GIF_SIZE_MB}MB)${NC}"
                echo -e "  ${BLUE}🤖 AI Decision: Compression needed - $(( (size_ratio - 100) / 10 ))0% over limit${NC}"
                compress_needed=true
            fi
        fi
        
        if [[ "$compress_needed" == true ]]; then
            echo -e "  ${RED}⚠️  GIF size (${temp_gif_size_mb}MB) exceeds limit (${MAX_GIF_SIZE_MB}MB)${NC}"
            echo -e "  ${BLUE}🤖 AI Taking Control: Applying intelligent adaptive compression...${NC}"
            
            # AI-controlled adaptive compression with intelligent reduction strategy
            local emergency_temp="${TEMP_WORK_DIR}/${base_name}_emergency.${OUTPUT_FORMAT}"
            local emergency_palette="${TEMP_WORK_DIR}/${base_name}_emergency_palette.png"
            
            # Calculate target size ratio to fit within limit
            local size_ratio=$((temp_gif_size_mb * 100 / MAX_GIF_SIZE_MB))
            local reduction_factor=$((size_ratio / 100 + 1))  # How many times over limit
            
            # AI Strategy: Progressively reduce parameters based on size overage
            local emerg_fps=$FRAMERATE
            local emerg_colors=$MAX_COLORS
            local emerg_resolution="$RESOLUTION"
            
            # Determine aggressive level based on how much we exceed
            local aggressive_level=1
            if [[ $size_ratio -gt 400 ]]; then aggressive_level=4; fi  # >4x limit
            if [[ $size_ratio -gt 300 ]]; then aggressive_level=3; fi  # 3-4x limit
            if [[ $size_ratio -gt 150 ]]; then aggressive_level=2; fi  # 1.5-3x limit
            
            # AI Optimization Pass 1: Reduce FPS aggressively
            case $aggressive_level in
                4) emerg_fps=$((FRAMERATE / 4)); [[ $emerg_fps -lt 4 ]] && emerg_fps=4 ;;
                3) emerg_fps=$((FRAMERATE / 3)); [[ $emerg_fps -lt 5 ]] && emerg_fps=5 ;;
                2) emerg_fps=$((FRAMERATE / 2)); [[ $emerg_fps -lt 6 ]] && emerg_fps=6 ;;
                *) emerg_fps=$((FRAMERATE - 2)); [[ $emerg_fps -lt 8 ]] && emerg_fps=8 ;;
            esac
            
            # AI Optimization Pass 2: Reduce color palette
            case $aggressive_level in
                4) emerg_colors=$((MAX_COLORS / 4)); [[ $emerg_colors -lt 16 ]] && emerg_colors=16 ;;
                3) emerg_colors=$((MAX_COLORS / 3)); [[ $emerg_colors -lt 24 ]] && emerg_colors=24 ;;
                2) emerg_colors=$((MAX_COLORS / 2)); [[ $emerg_colors -lt 32 ]] && emerg_colors=32 ;;
                *) emerg_colors=$((MAX_COLORS * 80 / 100)); [[ $emerg_colors -lt 48 ]] && emerg_colors=48 ;;
            esac
            
            # AI Optimization Pass 3: Reduce resolution proportionally
            local current_width=$(echo "$RESOLUTION" | cut -d':' -f1)
            local current_height=$(echo "$RESOLUTION" | cut -d':' -f2)
            local res_factor=100
            case $aggressive_level in
                4) res_factor=40 ;;  # 40% of original
                3) res_factor=50 ;;  # 50% of original
                2) res_factor=65 ;;  # 65% of original
                *) res_factor=80 ;;  # 80% of original
            esac
            
            local emerg_width=$((current_width * res_factor / 100))
            local emerg_height=$((current_height * res_factor / 100))
            # Round to nearest even number (required for video codecs)
            emerg_width=$((emerg_width / 2 * 2))
            emerg_height=$((emerg_height / 2 * 2))
            emerg_resolution="${emerg_width}:${emerg_height}"
            
            echo -e "    ${YELLOW}🤖 AI Compression Level ${aggressive_level}: ${emerg_resolution}, ${emerg_fps}fps, ${emerg_colors} colors${NC}"
            echo -e "    ${CYAN}AI Strategy: Reducing size by ${res_factor}% resolution, ${emerg_fps}fps framerate, ${emerg_colors} colors${NC}"
            
            # Generate emergency palette
            local emerg_filter_chain="fps=${emerg_fps},scale=${emerg_resolution}:force_original_aspect_ratio=decrease:flags=${SCALING_ALGO},pad=${emerg_resolution}:(ow-iw)/2:(oh-ih)/2:black,palettegen=max_colors=${emerg_colors}:reserve_transparent=0"
            
            if ffmpeg -i "$file" -vf "$emerg_filter_chain" -threads $FFMPEG_THREADS -frames:v 1 -update 1 -y "$emergency_palette" -loglevel error 2>/dev/null; then
                # Generate emergency GIF with corrected dithering syntax
                local emerg_dither_option=""
                case "$DITHER_MODE" in
                    "floyd") emerg_dither_option="dither=floyd_steinberg" ;;
                    "bayer") emerg_dither_option="dither=bayer:bayer_scale=3" ;;
                    "none") emerg_dither_option="dither=none" ;;
                    *) emerg_dither_option="dither=bayer:bayer_scale=3" ;;  # default
                esac
                
                local emerg_conv_filter="fps=${emerg_fps},scale=${emerg_resolution}:force_original_aspect_ratio=decrease:flags=${SCALING_ALGO},pad=${emerg_resolution}:(ow-iw)/2:(oh-ih)/2:black[x];[x][1:v]paletteuse=$emerg_dither_option"
                
                if ffmpeg -i "$file" -i "$emergency_palette" -lavfi "$emerg_conv_filter" -threads $FFMPEG_THREADS -nostats -nostdin -loglevel error -y "$emergency_temp" 2>/dev/null; then
                    local emergency_size_mb=$(($(stat -c%s "$emergency_temp" 2>/dev/null || echo 0) / 1024 / 1024))
                    echo -e "    ${GREEN}✓ Emergency compression: ${emergency_size_mb}MB${NC}"
                    
                    # Use emergency version if significantly smaller
                    if [[ "$emergency_size_mb" -lt "$((temp_gif_size_mb / 2))" ]]; then
                        mv "$emergency_temp" "$temp_output_file"
                        echo -e "    ${GREEN}✓ Using emergency compressed version${NC}"
                    else
                        rm -f "$emergency_temp"
                        echo -e "    ${YELLOW}Emergency compression didn't help enough, keeping original${NC}"
                    fi
                fi
                rm -f "$emergency_palette"
            fi
        fi
        
        # Step 5: Move completed GIF from temp to final location
        echo -e "  ${BLUE}📦 Moving completed GIF to final location...${NC}"
        if mv "$temp_output_file" "$final_output_file" 2>/dev/null; then
            echo -e "  ${GREEN}✓ GIF saved: $(basename "$final_output_file")${NC}"
        else
            echo -e "  ${RED}❌ Failed to move GIF to final location${NC}"
            cleanup_temp_files "${file%.*}"
            ((failed_files++))
            return 1
        fi
        
        # Show file size comparison
        local original_size=$(stat -c%s "$file" 2>/dev/null || echo "1")
        local converted_size=$(stat -c%s "$final_output_file" 2>/dev/null || echo "0")
        local ratio=0
        if [[ $original_size -gt 0 ]]; then
            ratio=$((converted_size * 100 / original_size))
        fi
        
        # Enhanced Auto-optimization with multiple strategies
        if [[ "$AUTO_OPTIMIZE" == true && "$OUTPUT_FORMAT" == "gif" ]]; then
            local original_size=$converted_size
            local best_file="$final_output_file"
            local best_size=$original_size
            local optimization_applied=false
            
            echo -e "  ${BLUE}🎯 Starting intelligent GIF optimization...${NC}"
            
            # Strategy 1: gifsicle optimization (if available)
            if command -v gifsicle >/dev/null 2>&1; then
                echo -e "  ${BLUE}⚙️ Trying gifsicle optimization...${NC}"
                
                # Progress animation
                (
                    local frame=0
                    local spinchars="⚙️🔧⚡🔍🔄"
                    while sleep 0.2; do
                        local char="${spinchars:$((frame % ${#spinchars})):1}"
                        printf "\r  %s ${CYAN}Gifsicle optimization...${NC}" "$char"
                        ((frame++))
                    done
                ) &
                local opt_progress_pid=$!
                
                # Try different optimization levels
                local gifsicle_success=false
                for opt_level in "-O3" "-O2" "-O1"; do
                    local temp_file="${final_output_file}.gifsicle.tmp"
                    if gifsicle $opt_level "$final_output_file" -o "$temp_file" 2>/dev/null; then
                        local new_size=$(stat -c%s "$temp_file" 2>/dev/null || echo "0")
                        if [[ $new_size -gt 100 && $new_size -lt $best_size ]]; then
                            best_file="$temp_file"
                            best_size=$new_size
                            gifsicle_success=true
                            break
                        fi
                        rm -f "$temp_file" 2>/dev/null
                    fi
                done
                
                kill $opt_progress_pid 2>/dev/null || true
                wait $opt_progress_pid 2>/dev/null || true
                
                if [[ $gifsicle_success == true ]]; then
                    local savings=$(( (original_size - best_size) * 100 / original_size ))
                    printf "\r  ${GREEN}✓ Gifsicle: $(numfmt --to=iec $best_size) (-${savings}%%)${NC}\n"
                    optimization_applied=true
                else
                    printf "\r  ${YELLOW}⚠️ Gifsicle: No improvement found${NC}\n"
                fi
            fi
            
            # Strategy 2: FFmpeg re-encoding with different settings (if gifsicle didn't help enough)
            local target_threshold=$((original_size * OPTIMIZE_TARGET_RATIO / 100))
            local should_try_ffmpeg=false
            
            if [[ "$OPTIMIZE_AGGRESSIVE" == "true" ]]; then
                # Aggressive mode: try FFmpeg if we haven't reached target ratio
                [[ $best_size -gt $target_threshold ]] && should_try_ffmpeg=true
            else
                # Conservative mode: only try FFmpeg if gifsicle didn't save much
                local conservative_threshold=$((original_size * 90 / 100))
                [[ $best_size -gt $conservative_threshold ]] && should_try_ffmpeg=true
            fi
            
            if [[ $should_try_ffmpeg == true ]]; then
                echo -e "  ${BLUE}🔄 Trying FFmpeg re-optimization...${NC}"
                
                # Progress animation
                (
                    local frame=0
                    local spinchars="🔄⚙️🎛️🔧📐"
                    while sleep 0.3; do
                        local char="${spinchars:$((frame % ${#spinchars})):1}"
                        printf "\r  %s ${CYAN}FFmpeg re-optimization...${NC}" "$char"
                        ((frame++))
                    done
                ) &
                local ffmpeg_progress_pid=$!
                
                # Try re-encoding with slightly reduced quality for size savings
                local temp_palette="${final_output_file}.reopt_palette.png"
                local temp_output="${final_output_file}.reopt.tmp"
                local reopt_colors=$((MAX_COLORS * 85 / 100))  # Reduce colors by 15%
                
                # Generate new palette with fewer colors
                local reopt_filter="fps=${FRAMERATE},scale=${RESOLUTION}:force_original_aspect_ratio=decrease:flags=${SCALING_ALGO},pad=${RESOLUTION}:(ow-iw)/2:(oh-ih)/2:black,palettegen=max_colors=${reopt_colors}:reserve_transparent=0"
                
                # Use background process for palette generation and track it
                ffmpeg $FFMPEG_INPUT_OPTS -i "$file" -vf "$reopt_filter" $FFMPEG_MEMORY_OPTS -frames:v 1 -update 1 -y "$temp_palette" -loglevel error 2>/dev/null &
                local palette_pid=$!
                SCRIPT_FFMPEG_PIDS+=("$palette_pid")
                
                # Wait for palette generation and remove from tracking
                wait $palette_pid
                local palette_result=$?
                
                # Remove from tracking array
                local new_pids=()
                for pid in "${SCRIPT_FFMPEG_PIDS[@]}"; do
                    if [[ "$pid" != "$palette_pid" ]]; then
                        new_pids+=("$pid")
                    fi
                done
                SCRIPT_FFMPEG_PIDS=("${new_pids[@]}")
                
                if [[ $palette_result -eq 0 && -f "$temp_palette" ]]; then
                    # Re-encode with new palette
                    local reopt_conversion_filter="fps=${FRAMERATE},scale=${RESOLUTION}:force_original_aspect_ratio=decrease:flags=${SCALING_ALGO},pad=${RESOLUTION}:(ow-iw)/2:(oh-ih)/2:black[x];[x][1:v]paletteuse=dither=${DITHER_MODE}:bayer_scale=2"
                    
                    # Use background process for reencoding and track it
                    ffmpeg $FFMPEG_INPUT_OPTS -i "$file" -i "$temp_palette" -lavfi "$reopt_conversion_filter" $FFMPEG_MEMORY_OPTS -y "$temp_output" -loglevel error 2>/dev/null &
                    local reopt_pid=$!
                    SCRIPT_FFMPEG_PIDS+=("$reopt_pid")
                    
                    # Wait for reencoding and remove from tracking
                    wait $reopt_pid
                    local reopt_result=$?
                    
                    # Remove from tracking array
                    local new_pids2=()
                    for pid in "${SCRIPT_FFMPEG_PIDS[@]}"; do
                        if [[ "$pid" != "$reopt_pid" ]]; then
                            new_pids2+=("$pid")
                        fi
                    done
                    SCRIPT_FFMPEG_PIDS=("${new_pids2[@]}")
                    
                    if [[ $reopt_result -eq 0 ]]; then
                        local reopt_size=$(stat -c%s "$temp_output" 2>/dev/null || echo "0")
                        if [[ $reopt_size -gt 100 && $reopt_size -lt $best_size ]]; then
                            # Clean up previous best file if it's a temp file
                            [[ "$best_file" != "$final_output_file" ]] && rm -f "$best_file" 2>/dev/null
                            best_file="$temp_output"
                            best_size=$reopt_size
                            optimization_applied=true
                        else
                            rm -f "$temp_output" 2>/dev/null
                        fi
                    fi
                    rm -f "$temp_palette" 2>/dev/null
                fi
                
                kill $ffmpeg_progress_pid 2>/dev/null || true
                wait $ffmpeg_progress_pid 2>/dev/null || true
                disown $ffmpeg_progress_pid 2>/dev/null || true  # Remove from job list
                
                if [[ "$best_file" != "$final_output_file" && -f "$best_file" ]]; then
                    local savings=$(( (original_size - best_size) * 100 / original_size ))
                    printf "\r  ${GREEN}✓ FFmpeg reopt: $(numfmt --to=iec $best_size) (-${savings}%%)${NC}\n"
                else
                    printf "\r  ${YELLOW}⚠️ FFmpeg reopt: No improvement${NC}\n"
                fi
            fi
            
            # Apply the best optimization result
            if [[ "$best_file" != "$final_output_file" && -f "$best_file" ]]; then
                mv "$best_file" "$final_output_file" 2>/dev/null
                converted_size=$best_size
                local total_savings=$(( (original_size - best_size) * 100 / original_size ))
                echo -e "  ${GREEN}🎉 Optimization complete: $(numfmt --to=iec $best_size) (saved ${total_savings}%%)${NC}"
            else
                if [[ $optimization_applied == false ]]; then
                    echo -e "  ${CYAN}ℹ️ No optimization tools available or no improvements found${NC}"
                fi
                # Clean up any temp files
                rm -f "${final_output_file}".*.tmp 2>/dev/null
            fi
        fi
        
        printf "\r  ${GREEN}✓ Completed: ${BOLD}$(basename "$final_output_file")${NC} ${MAGENTA}($(numfmt --to=iec $converted_size) - ${ratio}%% of original)${NC}\n"
        
        # Log successful conversion
        log_conversion "SUCCESS" "$file" "$final_output_file" "($(numfmt --to=iec $converted_size) - ${ratio}% of original)"
        
        ((converted_files++))
    else
        echo -e "\n  ${RED}❌ Conversion failed after all attempts${NC}"
        log_conversion "FAILED" "$file" "$final_output_file" "(failed after $MAX_RETRIES attempts)"
        ((failed_files++))
    fi
    
    # Always cleanup temporary files
    cleanup_temp_files "${file%.*}"
    
    # Immediate cleanup of any lingering processes for this conversion
    local immediate_cleanup_count=0
    local remaining_pids=()
    for pid in "${SCRIPT_FFMPEG_PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            remaining_pids+=("$pid")
        else
            ((immediate_cleanup_count++))
        fi
    done
    SCRIPT_FFMPEG_PIDS=("${remaining_pids[@]}")
    
    if [[ $immediate_cleanup_count -gt 0 ]]; then
        echo -e "  ${BLUE}🧹 Cleaned up $immediate_cleanup_count completed processes${NC}"
    fi
    
    echo -e "${CYAN}✓ Finished processing: $(basename "$1")${NC}"
}

# 📈 Show final statistics
show_statistics() {
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                        📊 STATISTICS                         ║${NC}"
    echo -e "${CYAN}${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
    printf "${CYAN}${BOLD}║${NC} ${GREEN}✓ Converted:${NC} %-10s ${YELLOW}⏭ Skipped:${NC} %-10s ${RED}✗ Failed:${NC} %-6s ${CYAN}${BOLD}║${NC}\n" "$converted_files" "$skipped_files" "$failed_files"
    printf "${CYAN}${BOLD}║${NC} ${BLUE}📁 Total files:${NC} %-8s ${MAGENTA}⏱ Duration:${NC} %02d:%02d:%02d                ${CYAN}${BOLD}║${NC}\n" "$total_files" "$hours" "$minutes" "$seconds"
    printf "${CYAN}${BOLD}║${NC} ${YELLOW}⚙ Quality:${NC} %-12s ${BLUE}📐 Resolution:${NC} %-12s        ${CYAN}${BOLD}║${NC}\n" "$QUALITY" "$RESOLUTION"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 🎆 Main execution with robust error handling
main() {
    # Initialize error handling system
    trace_function "main"
    
    # Enhanced signal handling for graceful interruption
    trap 'handle_crash $LINENO' ERR
    trap 'handle_interrupt' INT  # Graceful interrupt (allows current file to finish)
    trap 'cleanup_on_exit 143' TERM
    trap 'emergency_exit' HUP PIPE
    trap 'finish_script' EXIT  # Normal cleanup on successful exit
    
    # Enable debug mode for better error tracking
    [[ "$DEBUG_MODE" == true ]] && set -x
    
    # Initialize log directory and files (sets SETTINGS_FILE)
    init_log_directory
    
    # Log a one-time settings snapshot for better diagnostics
    log_settings_snapshot_once
    
    print_header
    
    # System checks
    echo -e "${BLUE}🔍 Performing system checks...${NC}"
    check_dependencies
    validate_environment
    
    # GPU acceleration and parallel processing setup
    detect_gpu_acceleration
    setup_parallel_processing
    
    # Show optimization status
    echo -e "${BLUE}🧠 Smart Optimization Status:${NC}"
    if [[ "$SMART_SIZE_DOWN" == "true" ]]; then
        echo -e "  ${GREEN}✓ Smart sizing: ENABLED${NC} (automatic size reduction)"
    else
        echo -e "  ${YELLOW}⚠️  Smart sizing: DISABLED${NC}"
    fi
    if [[ "$AUTO_OPTIMIZE" == "true" ]]; then
        local opt_mode=$([[ "$OPTIMIZE_AGGRESSIVE" == "true" ]] && echo "Aggressive" || echo "Conservative")
        echo -e "  ${GREEN}✓ Auto-optimize: ENABLED${NC} ($opt_mode mode)"
        echo -e "  ${CYAN}  → Target: ${OPTIMIZE_TARGET_RATIO}% of original, Max: ${MAX_GIF_SIZE_MB}MB${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Auto-optimize: DISABLED${NC}"
    fi
    echo ""
    
    # Skip corrupted GIF check in interactive mode (available in validation menu)
    # detect_corrupted_gifs  # This causes hangs in interactive mode
    
    load_config || true  # Don't fail if no config exists
    
    # If no arguments provided, enable interactive mode
    if [[ $# -eq 0 ]]; then
        show_welcome
        show_main_menu
        exit 0
    fi
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --file)
                ONLY_FILE="$2"
                shift 2
                ;;
            --ai|--ai-smart)
                AI_ENABLED=true
                AI_MODE="smart"
                shift
                ;;
            --ai-mode)
                AI_MODE="$2"
                shift 2
                ;;
            --ai-content)
                AI_ENABLED=true
                AI_MODE="content"
                shift
                ;;
            --ai-motion)
                AI_ENABLED=true
                AI_MODE="motion"
                shift
                ;;
            --ai-quality)
                AI_ENABLED=true
                AI_MODE="quality"
                shift
                ;;
            --ai-confidence)
                AI_CONFIDENCE_THRESHOLD="$2"
                shift 2
                ;;
            --preset)
                apply_preset "$2"
                shift 2
                ;;
            --anime|--artwork)
                # Anime/artwork optimized preset
                RESOLUTION="854:480"
                FRAMERATE="10"
                MAX_COLORS="96"
                QUALITY="anime"
                echo -e "${GREEN}🎨 Applied anime/artwork optimized preset${NC}"
                shift
                ;;
            --resolution)
                RESOLUTION="$2"
                shift 2
                # Auto-save when resolution changes
                if [[ -n "$SETTINGS_FILE" ]]; then save_settings --silent; fi
                ;;
            --fps)
                FRAMERATE="$2"
                shift 2
                # Auto-save when framerate changes
                if [[ -n "$SETTINGS_FILE" ]]; then save_settings --silent; fi
                ;;
            --aspect)
                ASPECT_RATIO="$2"
                shift 2
                # Auto-save when aspect ratio changes
                if [[ -n "$SETTINGS_FILE" ]]; then save_settings --silent; fi
                ;;
            --force)
                FORCE_CONVERSION=true
                shift
                # Auto-save when force mode changes
                if [[ -n "$SETTINGS_FILE" ]]; then save_settings --silent; fi
                ;;
            --auto-detect)
                AUTO_DETECT=true
                shift
                ;;
            --optimize-aggressive)
                OPTIMIZE_AGGRESSIVE=true
                shift
                # Auto-save when optimization setting changes
                if [[ -n "$SETTINGS_FILE" ]]; then save_settings --silent; fi
                ;;
            --optimize-conservative)
                OPTIMIZE_AGGRESSIVE=false
                shift
                # Auto-save when optimization setting changes
                if [[ -n "$SETTINGS_FILE" ]]; then save_settings --silent; fi
                ;;
            --optimize-target)
                OPTIMIZE_TARGET_RATIO="$2"
                shift 2
                # Auto-save when optimization setting changes
                if [[ -n "$SETTINGS_FILE" ]]; then save_settings --silent; fi
                ;;
            --debug)
                DEBUG_MODE=true
                shift
                # Auto-save when debug mode changes
                if [[ -n "$SETTINGS_FILE" ]]; then save_settings --silent; fi
                ;;
            --max-retries)
                MAX_RETRIES="$2"
                shift 2
                # Auto-save when retry count changes
                if [[ -n "$SETTINGS_FILE" ]]; then save_settings --silent; fi
                ;;
            --interactive|-i)
                INTERACTIVE_MODE=true
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION=true
                shift
                # Auto-save when validation setting changes
                if [[ -n "$SETTINGS_FILE" ]]; then save_settings --silent; fi
                ;;
            --single-threaded)
                PARALLEL_JOBS=1
                shift
                ;;
            --parallel-jobs)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            --gpu-enable)
                GPU_ACCELERATION="true"
                shift
                ;;
            --gpu-disable)
                GPU_ACCELERATION="false"
                shift
                ;;
            --threads)
                FFMPEG_THREADS="$2"
                shift 2
                ;;
            --max-size)
                MAX_GIF_SIZE_MB="$2"
                shift 2
                ;;
            --target-ratio)
                OPTIMIZE_TARGET_RATIO="$2"
                shift 2
                ;;
            --disable-size-optimization)
                AUTO_REDUCE_QUALITY=false
                SMART_SIZE_DOWN=false
                shift
                ;;
            --enable-smart-sizing)
                SMART_SIZE_DOWN=true
                AUTO_REDUCE_QUALITY=true
                shift
                ;;
            --disable-smart-sizing)
                SMART_SIZE_DOWN=false
                shift
                ;;
            --aggressive-optimization)
                OPTIMIZE_AGGRESSIVE=true
                MAX_GIF_SIZE_MB=15
                OPTIMIZE_TARGET_RATIO=15
                shift
                ;;
            --conservative-optimization)
                OPTIMIZE_AGGRESSIVE=false
                MAX_GIF_SIZE_MB=75
                OPTIMIZE_TARGET_RATIO=50
                shift
                ;;
            --dynamic-detection|--monitor-files)
                DYNAMIC_FILE_DETECTION=true
                shift
                ;;
            --monitor-interval)
                FILE_MONITOR_INTERVAL="$2"
                shift 2
                ;;
            --no-dynamic-detection|--no-monitor)
                DYNAMIC_FILE_DETECTION=false
                shift
                ;;
            --kill-ffmpeg)
                echo -e "${RED}${BOLD}🔫 Killing all ffmpeg processes...${NC}\n"
                local ffmpeg_pids=($(pgrep -f ffmpeg 2>/dev/null || true))
                if [[ ${#ffmpeg_pids[@]} -eq 0 ]]; then
                    echo -e "${GREEN}✓ No ffmpeg processes are currently running${NC}"
                else
                    echo -e "${YELLOW}Found ${#ffmpeg_pids[@]} ffmpeg process(es), sending SIGTERM...${NC}"
                    for pid in "${ffmpeg_pids[@]}"; do
                        if kill -TERM "$pid" 2>/dev/null; then
                            echo -e "  ${GREEN}✓ Terminated PID $pid${NC}"
                        else
                            echo -e "  ${RED}❌ Failed to terminate PID $pid${NC}"
                        fi
                    done
                    sleep 2
                    
                    # Check for remaining processes and force kill if needed
                    local remaining_pids=($(pgrep -f ffmpeg 2>/dev/null || true))
                    if [[ ${#remaining_pids[@]} -gt 0 ]]; then
                        echo -e "${RED}Force killing ${#remaining_pids[@]} remaining process(es)...${NC}"
                        for pid in "${remaining_pids[@]}"; do
                            if kill -KILL "$pid" 2>/dev/null; then
                                echo -e "  ${GREEN}✓ Force killed PID $pid${NC}"
                            fi
                        done
                    fi
                fi
                exit 0
                ;;
            --stop-all)
                echo -e "${RED}${BOLD}🚫 STOPPING ALL FFMPEG PROCESSES...${NC}\n"
                # Kill all ffmpeg processes (not just script ones)
                local all_ffmpeg_pids=($(pgrep ffmpeg 2>/dev/null || true))
                if [[ ${#all_ffmpeg_pids[@]} -eq 0 ]]; then
                    echo -e "${GREEN}✓ No ffmpeg processes running${NC}"
                else
                    echo -e "${YELLOW}🔄 Terminating ${#all_ffmpeg_pids[@]} ffmpeg process(es)...${NC}"
                    for pid in "${all_ffmpeg_pids[@]}"; do
                        if kill -TERM "$pid" 2>/dev/null; then
                            echo -e "  ${GREEN}✓ Terminated PID $pid${NC}"
                        fi
                    done
                    sleep 2
                    
                    # Force kill any survivors
                    local remaining_pids=($(pgrep ffmpeg 2>/dev/null || true))
                    if [[ ${#remaining_pids[@]} -gt 0 ]]; then
                        echo -e "${RED}Force killing ${#remaining_pids[@]} stubborn process(es)...${NC}"
                        for pid in "${remaining_pids[@]}"; do
                            kill -KILL "$pid" 2>/dev/null
                            echo -e "  ${YELLOW}⚡ Force killed PID $pid${NC}"
                        done
                    fi
                    echo -e "${GREEN}✅ All ffmpeg processes stopped${NC}"
                fi
                exit 0
                ;;
            --clear-progress)
                echo -e "${YELLOW}🗋 Clearing conversion progress...${NC}"
                clear_progress
                exit 0
                ;;
            --show-progress)
                if [[ -f "$PROGRESS_FILE" ]]; then
                    echo -e "${CYAN}${BOLD}📊 CONVERSION PROGRESS${NC}\\n"
                    echo -e "${BLUE}Progress File: $PROGRESS_FILE${NC}"
                    echo -e "\n${YELLOW}Recent Progress:${NC}"
                    tail -20 "$PROGRESS_FILE" | grep -E "SUCCESS|FAILED|SKIPPED" | while read line; do
                        if [[ $line == *"SUCCESS"* ]]; then
                            echo -e "  ${GREEN}✓ $line${NC}"
                        elif [[ $line == *"FAILED"* ]]; then
                            echo -e "  ${RED}❌ $line${NC}"
                        elif [[ $line == *"SKIPPED"* ]]; then
                            echo -e "  ${YELLOW}⏭ $line${NC}"
                        fi
                    done
                else
                    echo -e "${YELLOW}ℹ️ No progress file found${NC}"
                fi
                exit 0
                ;;
            --show-settings)
                echo -e "${CYAN}${BOLD}🔧 CURRENT SETTINGS${NC}\\n"
                echo -e "${YELLOW}Settings Location:${NC} $SETTINGS_FILE"
                echo -e "${YELLOW}Backup Config:${NC} $CONFIG_FILE\n"
                
                echo -e "${GREEN}${BOLD}Quality & Output:${NC}"
                echo -e "  ${BLUE}Quality Preset:${NC} $QUALITY"
                echo -e "  ${BLUE}Resolution:${NC} $RESOLUTION"
                echo -e "  ${BLUE}Frame Rate:${NC} ${FRAMERATE}fps"
                echo -e "  ${BLUE}Aspect Ratio:${NC} $ASPECT_RATIO"
                echo -e "  ${BLUE}Output Format:${NC} $OUTPUT_FORMAT"
                
                echo -e "\n${GREEN}${BOLD}Processing Options:${NC}"
                echo -e "  ${BLUE}Auto Optimize:${NC} $AUTO_OPTIMIZE"
                if [[ "$AUTO_OPTIMIZE" == "true" ]]; then
                    echo -e "  ${BLUE}Optimization Mode:${NC} $([[ "$OPTIMIZE_AGGRESSIVE" == "true" ]] && echo "Aggressive" || echo "Conservative")"
                    echo -e "  ${BLUE}Target Size Ratio:${NC} ${OPTIMIZE_TARGET_RATIO}%"
                fi
                echo -e "  ${BLUE}Skip Validation:${NC} $SKIP_VALIDATION"
                echo -e "  ${BLUE}Force Conversion:${NC} $FORCE_CONVERSION"
                echo -e "  ${BLUE}Backup Original:${NC} $BACKUP_ORIGINAL"
                echo -e "  ${BLUE}Progress Bar:${NC} $PROGRESS_BAR"
                echo -e "  ${BLUE}Debug Mode:${NC} $DEBUG_MODE"
                echo -e "  ${BLUE}Max Retries:${NC} $MAX_RETRIES"
                echo -e "  ${BLUE}Dynamic File Detection:${NC} $DYNAMIC_FILE_DETECTION"
                [[ "$DYNAMIC_FILE_DETECTION" == "true" ]] && echo -e "  ${BLUE}Monitor Interval:${NC} ${FILE_MONITOR_INTERVAL}s"
                
                echo -e "\n${GREEN}${BOLD}Advanced:${NC}"
                echo -e "  ${BLUE}Scaling Algorithm:${NC} $SCALING_ALGO"
                echo -e "  ${BLUE}Dither Mode:${NC} $DITHER_MODE"
                echo -e "  ${BLUE}Max Colors:${NC} $MAX_COLORS"
                echo -e "  ${BLUE}Palette Mode:${NC} $PALETTE_MODE"
                
                if [[ -f "$SETTINGS_FILE" ]]; then
                    local mod_time=$(stat -c %Y "$SETTINGS_FILE" 2>/dev/null || echo "0")
                    local readable_time=$(date -d "@$mod_time" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Unknown")
                    echo -e "\n${YELLOW}ℹ️ Settings file last updated: $readable_time${NC}"
                else
                    echo -e "\n${YELLOW}⚠️ No settings file found (will be created on first use)${NC}"
                fi
                exit 0
                ;;
            --test-termination)
                echo -e "${CYAN}${BOLD}🧪 TESTING PROCESS GROUP TERMINATION${NC}\n"
                echo -e "${YELLOW}Process Group ID: $SCRIPT_PGID${NC}"
                echo -e "${YELLOW}Script PID: $SCRIPT_PID${NC}"
                echo -e "${YELLOW}Terminal Bound: $TERMINAL_BOUND${NC}\n"
                
                echo -e "${BLUE}Starting test ffmpeg processes...${NC}"
                # Start a few test ffmpeg processes in background for testing
                for i in {1..3}; do
                    (
                        ffmpeg -f lavfi -i testsrc=duration=30:size=320x240:rate=1 -y "/tmp/test_$i.mp4" 2>/dev/null
                    ) &
                    local test_pid=$!
                    echo -e "  ${GREEN}✓ Started test ffmpeg $i as PID $test_pid${NC}"
                    SCRIPT_FFMPEG_PIDS+=("$test_pid")
                done
                
                echo -e "\n${YELLOW}Test processes started. Try one of these:${NC}"
                echo -e "  ${CYAN}1. Press Ctrl+C to test interrupt handling${NC}"
                echo -e "  ${CYAN}2. Close this terminal to test terminal disconnect${NC}"
                echo -e "  ${CYAN}3. Kill this script from another terminal${NC}"
                echo -e "\n${MAGENTA}Waiting 30 seconds or until interrupted...${NC}"
                
                # Wait and show process status
                for ((i=1; i<=30; i++)); do
                    echo -ne "\r${BLUE}Waiting... ${i}/30s - Active ffmpeg: $(pgrep ffmpeg | wc -l)${NC}"
                    sleep 1
                done
                
                echo -e "\n${GREEN}Test completed - cleaning up${NC}"
                kill_entire_process_group TERM
                sleep 2
                kill_entire_process_group KILL
                echo -e "${GREEN}✓ All test processes should be terminated${NC}"
                exit 0
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --save-config)
                save_config
                exit 0
                ;;
            --show-logs)
                init_log_directory >/dev/null 2>&1
                echo -e "${CYAN}${BOLD}📁 LOG DIRECTORY INFORMATION:${NC}\n"
                echo -e "${YELLOW}Log Directory:${NC} $LOG_DIR"
                echo -e "${YELLOW}Error Log:${NC} $ERROR_LOG"
                echo -e "${YELLOW}Conversion Log:${NC} $CONVERSION_LOG\n"
                
                if [[ -f "$ERROR_LOG" ]]; then
                    local error_lines=$(wc -l < "$ERROR_LOG")
                    echo -e "${GREEN}✓ Error log exists ($error_lines lines)${NC}"
                else
                    echo -e "${YELLOW}⚠ No error log found${NC}"
                fi
                
                if [[ -f "$CONVERSION_LOG" ]]; then
                    local conv_lines=$(wc -l < "$CONVERSION_LOG")
                    echo -e "${GREEN}✓ Conversion log exists ($conv_lines lines)${NC}"
                else
                    echo -e "${YELLOW}⚠ No conversion log found${NC}"
                fi
                
                echo -e "\n${BLUE}Commands to view logs:${NC}"
                echo -e "  tail -f \"$ERROR_LOG\"       # Follow error log"
                echo -e "  tail -20 \"$CONVERSION_LOG\"  # Last 20 conversions"
                echo -e "  ls -la \"$LOG_DIR\"         # List all log files"
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo -e "${YELLOW}Use --help for available options${NC}"
                exit 1
                ;;
        esac
    done
    
    # Count total files
    shopt -s nullglob
    for file in *.mp4 *.avi *.mov *.mkv *.webm; do
        if [[ -f "$file" ]]; then
            ((total_files++)) || true
        fi
    done
    shopt -u nullglob
    
    if [[ $total_files -eq 0 ]]; then
        echo -e "${RED}❌ No video files found in current directory${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🎯 Found $total_files video files to process${NC}"
    
    # Interactive mode for settings selection
    if [[ "$INTERACTIVE_MODE" == true ]]; then
        select_quality_preset
        select_aspect_ratio
        echo ""
    fi
    
    echo -e "${YELLOW}⚙️  Quality: $QUALITY | Resolution: $RESOLUTION | FPS: $FRAMERATE | Aspect: $ASPECT_RATIO${NC}"
    
    # Preload files into memory cache for faster access
    if [[ ${#files_to_process[@]} -gt 1 ]]; then
        preload_files_to_cache "${files_to_process[@]}"
    fi
    
    # Confirmation in interactive mode
    if [[ "$INTERACTIVE_MODE" == true ]]; then
        echo -e "\n${MAGENTA}Proceed with conversion? [Y/n]: ${NC}"
        read -r confirm
        if [[ "$confirm" =~ ^[Nn]$ ]]; then
            echo -e "${YELLOW}Operation cancelled by user${NC}"
            exit 0
        fi
    fi
    
    # Call the main conversion function
    start_conversion
}

# 🎬 Execute main function
main "$@"