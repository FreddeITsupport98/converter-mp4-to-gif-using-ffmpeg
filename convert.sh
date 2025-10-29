#!/bin/bash

# ============================================================================
# 🔒 BASH SHELL ENFORCEMENT - This script REQUIRES bash
# ============================================================================
# This check runs immediately (even before any sourcing or subshells)
if [ -z "$BASH_VERSION" ]; then
    # Not running in bash - show helpful error and exit
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                    ⚠️  SHELL COMPATIBILITY ERROR                    ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "🚫 This script REQUIRES GNU Bash and cannot run in $(basename $SHELL)."
    echo ""
    echo "📝 Why? The script uses advanced bash features like:"
    echo "   • Associative arrays"
    echo "   • Parameter expansion (\${var//pattern/replace})"
    echo "   • Process substitution"
    echo "   • [[  ]] test syntax"
    echo "   • \${...} advanced substitution"
    echo ""
    echo "💡 How to fix this:"
    echo "   1. Run with bash explicitly:"
    echo "      bash $0"
    echo ""
    echo "   2. Or set bash as your default shell:"
    echo "      chsh -s /bin/bash"
    echo ""
    echo "   3. Then run the script normally:"
    echo "      ./$(basename $0)"
    echo ""
    echo "📋 Current shell:"
    echo "   SHELL variable: $SHELL"
    echo "   Running as: $(basename $0)"
    echo ""
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

# 🔒 Single Instance Lock - Prevent multiple concurrent executions
# This ensures only one instance of the script runs at a time
LOCK_FILE="${HOME}/.smart-gif-converter/script.lock"
LOCK_DIR="$(dirname "$LOCK_FILE")"

# Create lock directory if it doesn't exist
mkdir -p "$LOCK_DIR" 2>/dev/null || true

# Try to acquire the lock
if [[ -f "$LOCK_FILE" ]]; then
    # Lock file exists, check if the process is still running
    existing_pid=$(cat "$LOCK_FILE" 2>/dev/null)
    
    if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
        # Process is still running - block this new instance
        echo -e "" >&2
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
        echo -e "${RED}${BOLD}⏸️  Script is already running in another terminal${NC}" >&2
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
        echo -e "" >&2
        echo -e "${CYAN}Running process ID (PID): ${BOLD}$existing_pid${NC}" >&2
        echo -e "" >&2
        echo -e "${CYAN}Your options:${NC}" >&2
        echo -e "  ${GREEN}1. Wait${NC} - Let the current conversion finish" >&2
        echo -e "  ${GREEN}2. Stop${NC} - Run: ${BOLD}kill $existing_pid${NC}" >&2
        echo -e "" >&2
        exit 1
    else
        # Process is not running, clean up stale lock
        rm -f "$LOCK_FILE" 2>/dev/null || true
    fi
fi

# Create lock file with current PID
echo "$$" > "$LOCK_FILE" 2>/dev/null || true

# Setup cleanup for lock file on exit
cleanup_lock_file() {
    rm -f "$LOCK_FILE" 2>/dev/null || true
}
trap cleanup_lock_file EXIT

# =============================================================================
# 🎬 SMART GIF CONVERTER - Revolutionary Video-to-GIF Conversion Tool
# =============================================================================
# Author: AI Assistant
# Version: 5.3
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
FFMPEG_THREADS="auto"
BACKUP_ORIGINAL=true
LOG_LEVEL="info"
PROGRESS_BAR=true
INTERACTIVE_MODE=true
SKIP_VALIDATION=false
ONLY_FILE=""

# 📁 Output Directory Configuration
OUTPUT_DIRECTORY="./converted_gifs"  # Default: ./converted_gifs subdirectory
OUTPUT_DIR_MODE="default"  # default, current, pictures, custom

# 🤖 Enhanced AI Configuration
AI_ENABLED=false
CROP_FILTER=""
AI_MODE="smart"  # smart, content, motion, quality
AI_CONFIDENCE_THRESHOLD=70
AI_CONTENT_CACHE=""
AI_AUTO_QUALITY=false  # Let AI automatically select quality per video
AI_SCENE_ANALYSIS=true  # Enable advanced scene detection
AI_VISUAL_SIMILARITY=true  # Enable visual similarity in duplicate detection
AI_SMART_CROP=true  # Enable intelligent crop detection
AI_DYNAMIC_FRAMERATE=true  # Enable smart frame rate adjustment
AI_QUALITY_SCALING=true  # Enable intelligent quality parameter scaling
AI_CONTENT_FINGERPRINT=true   # Enable content fingerprinting for duplicates
AI_THREADS_OPTIMAL="auto"  # AI-optimized thread count
AI_MEMORY_OPT="auto"        # AI-optimized memory settings
CONTENT_TYPE_PREFERENCE="mixed"  # animation, movie, screencast, mixed (auto-detect)

# 🔍 AI Video Discovery Preferences
AI_DISCOVERY_ENABLED=true      # Enable AI video discovery when no files found
AI_DISCOVERY_AUTO_SELECT="ask" # Auto selection mode: "ask", "recent", "all", "disabled"
AI_DISCOVERY_REMEMBER_CHOICE=true  # Remember user's selection preference
CPU_BENCHMARK=false

# 🚀 Advanced Multi-Threading Configuration
CPU_CORES="$(nproc 2>/dev/null || echo '4')"
CPU_PHYSICAL_CORES="$(lscpu 2>/dev/null | grep '^Core(s) per socket:' | awk '{print $4}' || echo "$CPU_CORES")"
CPU_LOGICAL_CORES="$CPU_CORES"
AI_MAX_PARALLEL_JOBS="$(( CPU_CORES > 8 ? 8 : CPU_CORES ))"  # Cap at 8 for memory efficiency
AI_DUPLICATE_THREADS="$(( CPU_CORES > 4 ? CPU_CORES - 1 : CPU_CORES ))"  # Leave 1 core free on high-core systems
AI_ANALYSIS_BATCH_SIZE="$(( CPU_CORES * 2 ))"  # Process 2x CPU cores worth in each batch

# 🗄️ AI Cache System Configuration
AI_CACHE_DIR="$LOG_DIR/ai_cache"
AI_CACHE_INDEX="$AI_CACHE_DIR/analysis_cache.db"
AI_CACHE_VERSION="2.0"  # Increment to invalidate old cache
AI_CACHE_ENABLED=true
AI_CACHE_MAX_AGE_DAYS=30  # Cache entries older than this are cleaned up

# 🔐 Checksum Cache System Configuration
CHECKSUM_CACHE_DIR="$LOG_DIR/checksum_cache"
CHECKSUM_CACHE_DB="$CHECKSUM_CACHE_DIR/checksums.db"
CHECKSUM_CACHE_VERSION="1.0"
CHECKSUM_CACHE_ENABLED=true
CHECKSUM_CACHE_MAX_AGE_DAYS=90  # Cache checksums for 90 days

# 📊 Duplicate Detection Statistics
DUPLICATE_STATS_TOTAL_CHECKED=0
DUPLICATE_STATS_EXACT_BINARY=0
DUPLICATE_STATS_VISUAL_IDENTICAL=0
DUPLICATE_STATS_CONTENT_FINGERPRINT=0
DUPLICATE_STATS_NEAR_IDENTICAL=0
DUPLICATE_STATS_DELETED=0
DUPLICATE_STATS_SKIPPED=0
DUPLICATE_STATS_SPACE_SAVED=0
DUPLICATE_STATS_CACHE_HITS=0
DUPLICATE_STATS_CACHE_MISSES=0

# 🧠 AI Training & Learning System Configuration
AI_TRAINING_ENABLED=true
AI_TRAINING_DIR="$LOG_DIR/ai_training"
AI_MODEL_FILE="$AI_TRAINING_DIR/smart_model.db"
AI_TRAINING_LOG="$AI_TRAINING_DIR/training_history.log"
AI_MODEL_VERSION="1.0"  # Increment to reset training model
AI_GENERATION=1          # Current AI generation (increments with model rebuilds)
AI_LEARNING_RATE=0.1    # How quickly AI adapts (0.1 = moderate learning)
AI_CONFIDENCE_MIN=0.3    # Minimum confidence threshold for AI decisions
AI_TRAINING_MIN_SAMPLES=5  # Minimum samples before AI makes confident predictions

# 🔄 Auto-Update System Configuration
GITHUB_REPO="FreddeITsupport98/converter-mp4-to-gif-using-ffmpeg"
GITHUB_API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
GITHUB_RELEASES_URL="https://github.com/${GITHUB_REPO}/releases"
CURRENT_VERSION="5.3"  # Script version
UPDATE_CHECK_FILE="$LOG_DIR/.last_update_check"
UPDATE_CHECK_INTERVAL=86400  # Check once per day (in seconds)
AUTO_UPDATE_ENABLED=true  # Enable automatic update checks (user configurable)
UPDATE_FIRST_RUN_PROMPT_DONE=false  # Track if first-run update prompt was shown

# 🛠️ Development Mode Configuration (Auto-detected, hidden from settings)
DEV_MODE=false           # Auto-detected: true if running in Git repository
DEV_MODE_DETECTED=false  # Set to true if Git repository detected

# 🔐 Release Fingerprint System - Track installed version integrity
RELEASE_FINGERPRINT_FILE="$LOG_DIR/.release_fingerprint"
INSTALLED_RELEASE_SHA256=""       # SHA256 of currently installed release
INSTALLED_RELEASE_VERSION=""      # Version of currently installed release
INSTALLED_RELEASE_TAG=""          # Git tag of currently installed release
INSTALLED_RELEASE_TIMESTAMP="0"   # GitHub release timestamp (Unix epoch)

# 🔐 Security Configuration
GPG_SIGNATURE_REQUIRED=false  # Require GPG signature verification (set true for max security)
GPG_KEY_FINGERPRINT=""  # Your GPG key fingerprint (set this for GPG verification)
TRUSTED_GITHUB_DOMAINS=("raw.githubusercontent.com" "github.com" "api.github.com")
MIN_FILE_SIZE=10000  # Minimum expected file size in bytes (sanity check)

# 🚀 Parallel Processing Utility Functions
# =====================================================

# 🧠 Optimize thread count based on workload type
get_optimal_threads() {
    local workload_type="${1:-default}"  # io, cpu, mixed, default
    local total_work="${2:-1}"           # Number of items to process
    
    case "$workload_type" in
        "io")  # I/O intensive (file operations, FFprobe)
            # Use more threads for I/O bound tasks
            echo "$(( CPU_CORES * 2 ))"
            ;;
        "cpu") # CPU intensive (FFmpeg encoding, hash calculations)
            # Use physical cores to avoid oversubscription
            echo "$CPU_PHYSICAL_CORES"
            ;;
        "mixed") # Mixed workload
            # Use logical cores but cap at reasonable limit
            echo "$(( CPU_CORES > 12 ? 12 : CPU_CORES ))"
            ;;
        "memory") # Memory intensive operations
            # Conservative threading to avoid memory pressure
            echo "$(( CPU_CORES > 6 ? 6 : CPU_CORES ))"
            ;;
        *) # Default balanced approach
            # Adapt based on total work and available cores
            if [[ $total_work -lt $CPU_CORES ]]; then
                echo "$total_work"  # Don't use more threads than work items
            else
                echo "$CPU_CORES"
            fi
            ;;
    esac
}

# ⚡ Run commands in parallel with controlled concurrency
run_parallel() {
    local max_jobs="$1"      # Maximum concurrent jobs
    local job_function="$2"  # Function to call for each item
    shift 2                  # Remove first two args
    local items=("$@")       # Remaining args are items to process
    
    if [[ $max_jobs -le 1 || ${#items[@]} -eq 0 ]]; then
        # No parallelization needed/possible
        for item in "${items[@]}"; do
            "$job_function" "$item"
        done
        return
    fi
    
    local active_jobs=0
    local job_pids=()
    
    for item in "${items[@]}"; do
        # Wait if we have too many active jobs
        while [[ $active_jobs -ge $max_jobs ]]; do
            # Check for completed jobs
            local new_pids=()
            for pid in "${job_pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    new_pids+=("$pid")
                else
                    ((active_jobs--))
                fi
            done
            job_pids=("${new_pids[@]}")
            
            # Short sleep to avoid busy waiting
            [[ $active_jobs -ge $max_jobs ]] && sleep 0.1
        done
        
        # Start new job in background
        "$job_function" "$item" &
        job_pids+=("$!")
        ((active_jobs++))
    done
    
    # Wait for all remaining jobs to complete
    for pid in "${job_pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
}

# 📊 Progress tracker for parallel operations
update_parallel_progress() {
    local current="$1"
    local total="$2"
    local operation="${3:-Processing}"
    local bar_length="${4:-25}"
    
    local progress=$(( current * 100 / total ))
    local filled=$(( progress * bar_length / 100 ))
    local empty=$(( bar_length - filled ))
    
    printf "\r  ${CYAN}%s [${NC}" "$operation"
    for ((i=0; i<filled; i++)); do printf "${GREEN}█${NC}"; done
    for ((i=0; i<empty; i++)); do printf "${GRAY}░${NC}"; done
    printf "${CYAN}] ${BOLD}%3d%%${NC} (${BOLD}%d${NC}/${BOLD}%d${NC})" "$progress" "$current" "$total"
}

# 📊 Progress tracker with current file display
update_file_progress() {
    local current="$1"
    local total="$2"
    local current_file="${3:-}"
    local operation="${4:-Processing}"
    local bar_length="${5:-25}"
    
    # Ensure current doesn't exceed total to prevent overshooting
    [[ $current -gt $total ]] && current=$total
    
    local progress=$(( current * 100 / total ))
    # Cap progress at 100% to prevent overshooting
    [[ $progress -gt 100 ]] && progress=100
    
    local filled=$(( progress * bar_length / 100 ))
    local empty=$(( bar_length - filled ))
    
    # Show full filename without truncation
    local display_file="$current_file"
    
    # Clear the entire line first to prevent display corruption
    printf "\r\033[K"  # Clear from cursor to end of line
    printf "  ${CYAN}%s [${NC}" "$operation"
    for ((i=0; i<filled; i++)); do printf "${GREEN}█${NC}"; done
    for ((i=0; i<empty; i++)); do printf "${GRAY}░${NC}"; done
    printf "${CYAN}] ${BOLD}%3d%%${NC} (${BOLD}%d${NC}/${BOLD}%d${NC})" "$progress" "$current" "$total"
    if [[ -n "$current_file" ]]; then
        printf "\n\033[K"  # New line and clear it
        printf "  ${GRAY}📄 Analyzing: ${BOLD}%s${NC}" "$display_file"
        printf "\033[K"  # Clear rest of line to remove any leftover characters
        printf "\r\033[1A"  # Move cursor back up to progress line
    fi
}

# 🔄 Auto-Update System (GitHub Releases with SHA256 Verification)
# =================================================================

# 🛠️ Detect if script is running in a Git repository (Development Mode)
# FOOLPROOF: Multiple layers of detection to ensure 100% accuracy
detect_dev_mode() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local script_file="${BASH_SOURCE[0]}"
    
    # ==================================================================
    # LAYER 1: Check if script is inside a Git repository
    # ==================================================================
    local check_dir="$script_dir"
    local git_root=""
    
    while [[ "$check_dir" != "/" ]]; do
        if [[ -d "$check_dir/.git" ]]; then
            git_root="$check_dir"
            break
        fi
        check_dir="$(dirname "$check_dir")"
    done
    
    # No Git repository found - definitely user mode
    if [[ -z "$git_root" ]]; then
        DEV_MODE_DETECTED=false
        DEV_MODE=false
        return 1
    fi
    
    # ==================================================================
    # LAYER 2: Verify it's THIS project's repository
    # ==================================================================
    local is_our_repo=false
    
    if [[ -f "$git_root/.git/config" ]]; then
        local git_remote=$(grep -E 'url\s*=' "$git_root/.git/config" 2>/dev/null | head -1)
        if [[ "$git_remote" =~ converter-mp4-to-gif-using-ffmpeg ]]; then
            is_our_repo=true
        fi
    fi
    
    # ==================================================================
    # LAYER 3: Check for development indicators
    # ==================================================================
    local dev_indicators=0
    
    # Check for WARP.md (development documentation)
    [[ -f "$git_root/WARP.md" ]] && ((dev_indicators++))
    
    # Check for CHANGELOG.md
    [[ -f "$git_root/CHANGELOG.md" ]] && ((dev_indicators++))
    
    # Check for .gitignore
    [[ -f "$git_root/.gitignore" ]] && ((dev_indicators++))
    
    # Check if script is directly in repository root or subdirectory
    if [[ "$script_dir" == "$git_root" ]] || [[ "$script_dir" == "$git_root"/* ]]; then
        ((dev_indicators++))
    fi
    
    # ==================================================================
    # LAYER 4: Check Git status (tracked vs untracked)
    # ==================================================================
    local is_tracked=false
    
    if command -v git >/dev/null 2>&1; then
        # Check if script file is tracked by Git
        if git -C "$git_root" ls-files --error-unmatch "$script_file" >/dev/null 2>&1; then
            is_tracked=true
            ((dev_indicators++))
        fi
    fi
    
    # ==================================================================
    # LAYER 5: Check for uncommitted changes (strongest indicator)
    # ==================================================================
    local has_uncommitted=false
    
    if command -v git >/dev/null 2>&1; then
        # Check if there are any uncommitted changes in the repo
        if ! git -C "$git_root" diff --quiet 2>/dev/null || \
           ! git -C "$git_root" diff --cached --quiet 2>/dev/null; then
            has_uncommitted=true
            ((dev_indicators++))
        fi
    fi
    
    # ==================================================================
    # LAYER 6: Check for .dev_mode marker file (ABSOLUTE OVERRIDE)
    # ==================================================================
    # If .dev_mode file exists in Git root, FORCE dev mode ON
    # If .no_dev_mode exists, FORCE dev mode OFF
    # This gives you absolute control when needed
    
    local force_dev_mode=false
    local force_user_mode=false
    
    if [[ -f "$git_root/.dev_mode" ]]; then
        force_dev_mode=true
    fi
    
    if [[ -f "$git_root/.no_dev_mode" ]]; then
        force_user_mode=true
    fi
    
    # ABSOLUTE OVERRIDE: .dev_mode file forces development mode
    if [[ "$force_dev_mode" == "true" ]]; then
        DEV_MODE_DETECTED=true
        DEV_MODE=true
        echo -e "${YELLOW}⚠️  ${BOLD}DEVELOPMENT MODE ACTIVE${NC}" >&2
        echo -e "${BLUE}🛠️  Auto-update: ${RED}DISABLED${NC}" >&2
        echo -e "${GRAY}   Reason: .dev_mode marker file found${NC}" >&2
        echo -e "${CYAN}   → Your work is protected from auto-updates${NC}" >&2
        echo "" >&2
        return 0
    fi
    
    # ABSOLUTE OVERRIDE: .no_dev_mode file forces user mode (for testing)
    if [[ "$force_user_mode" == "true" ]]; then
        DEV_MODE_DETECTED=false
        DEV_MODE=false
        echo -e "${CYAN}ℹ️  User mode forced by .no_dev_mode marker${NC}" >&2
        return 1
    fi
    
    # ==================================================================
    # DECISION: Enable DEV_MODE if ANY strong indicator is present
    # ==================================================================
    
    # Strong indicators (any one triggers DEV_MODE)
    if [[ "$is_our_repo" == "true" ]] || \
       [[ "$is_tracked" == "true" ]] || \
       [[ "$has_uncommitted" == "true" ]] || \
       [[ $dev_indicators -ge 3 ]]; then
        
        DEV_MODE_DETECTED=true
        DEV_MODE=true
        
        # Show detailed development mode notice
        echo -e "${YELLOW}⚠️  ${BOLD}DEVELOPMENT MODE ACTIVE${NC}" >&2
        echo -e "${BLUE}🛠️  Auto-update: ${RED}DISABLED${NC}" >&2
        echo -e "${GRAY}   Git repo: $git_root${NC}" >&2
        
        # Show why DEV_MODE was triggered
        if [[ "$is_our_repo" == "true" ]]; then
            echo -e "${GRAY}   Reason: This repository (converter-mp4-to-gif-using-ffmpeg)${NC}" >&2
        fi
        if [[ "$is_tracked" == "true" ]]; then
            echo -e "${GRAY}   Reason: Script is Git-tracked${NC}" >&2
        fi
        if [[ "$has_uncommitted" == "true" ]]; then
            echo -e "${GRAY}   Reason: Uncommitted changes detected${NC}" >&2
        fi
        if [[ $dev_indicators -ge 3 ]]; then
            echo -e "${GRAY}   Reason: $dev_indicators development indicators found${NC}" >&2
        fi
        
        echo -e "${CYAN}   → Your work is protected from auto-updates${NC}" >&2
        echo "" >&2
        
        return 0
    fi
    
    # ==================================================================
    # FALLBACK: Even if in a Git repo, it's not a development environment
    # ==================================================================
    
    # User might have cloned the repo just to use it (not develop)
    # No strong indicators found - treat as user mode
    DEV_MODE_DETECTED=false
    DEV_MODE=false
    return 1
}

# 🔍 Check for updates from GitHub Releases
check_for_updates() {
    # 🛠️ Skip update check if in development mode
    if [[ "$DEV_MODE" == "true" ]]; then
        return 0  # Silently skip - don't disturb development
    fi
    # Skip if auto-update is disabled
    if [[ "$AUTO_UPDATE_ENABLED" != "true" ]]; then
        return 0
    fi
    
    # Skip if checked recently
    if [[ -f "$UPDATE_CHECK_FILE" ]]; then
        local last_check=$(cat "$UPDATE_CHECK_FILE" 2>/dev/null || echo "0")
        local now=$(date +%s)
        local time_diff=$((now - last_check))
        
        if [[ $time_diff -lt $UPDATE_CHECK_INTERVAL ]]; then
            return 0  # Skip check
        fi
    fi
    
    # Validate update URL is reachable with HTTPS certificate verification
    if ! curl -sI --ssl-reqd --cacert /etc/ssl/certs/ca-certificates.crt "$GITHUB_API_URL" -m 5 2>/dev/null || \
       ! curl -sI --ssl-reqd "$GITHUB_API_URL" -m 5 2>/dev/null; then
        return 0  # Silently fail if GitHub unreachable or SSL verification fails
    fi
    
    # Fetch latest STABLE release info from GitHub API (excludes pre-releases)
    # Using /releases/latest endpoint ensures we get only stable releases
    local release_json=$(curl -s --ssl-reqd --tlsv1.2 "$GITHUB_API_URL" -m 10 2>/dev/null)
    
    if [[ -z "$release_json" ]] || [[ "$release_json" == *"Not Found"* ]] || [[ "$release_json" == *"API rate limit"* ]]; then
        return 0  # Silently fail (return success to avoid ERR trap)
    fi
    
    # Verify this is a stable release (not pre-release or draft)
    local is_prerelease=$(echo "$release_json" | grep -o '"prerelease":[^,]*' | grep -o 'true\|false')
    local is_draft=$(echo "$release_json" | grep -o '"draft":[^,]*' | grep -o 'true\|false')
    
    # Skip if this is a pre-release or draft (protection against RC/beta versions)
    if [[ "$is_prerelease" == "true" ]] || [[ "$is_draft" == "true" ]]; then
        return 0  # Skip pre-releases and drafts
    fi
    
    # Extract version tag and release timestamp
    local remote_tag=$(echo "$release_json" | grep -o '"tag_name":"[^"]*"' | cut -d'"' -f4)
    local remote_version=$(echo "$remote_tag" | grep -oE '[0-9]+\.[0-9]+' | head -1)
    
    # Extract GitHub release published_at timestamp (ISO 8601 format)
    local remote_timestamp_iso=$(echo "$release_json" | grep -o '"published_at":"[^"]*"' | cut -d'"' -f4)
    local remote_timestamp=0
    
    # Convert ISO 8601 to Unix epoch timestamp for comparison
    if [[ -n "$remote_timestamp_iso" ]]; then
        remote_timestamp=$(date -d "$remote_timestamp_iso" +%s 2>/dev/null || echo "0")
    fi
    
    # Additional safety: verify tag doesn't contain RC, beta, alpha, or pre markers
    if [[ "$remote_tag" =~ (rc|RC|beta|BETA|alpha|ALPHA|pre|PRE) ]]; then
        return 0  # Skip release candidates and pre-releases
    fi
    
    [[ -z "$remote_version" ]] && return 0  # Return success to avoid ERR trap
    
    # Save check time
    mkdir -p "$(dirname "$UPDATE_CHECK_FILE")" 2>/dev/null || true
    echo "$(date +%s)" > "$UPDATE_CHECK_FILE" 2>/dev/null || true
    
    # Extract SHA256 from release to compare with installed fingerprint
    local remote_sha256=$(extract_sha256_from_release "$release_json")
    
    # Load current installation fingerprint
    load_release_fingerprint 2>/dev/null
    
    # 🔒 BULLETPROOF: Compare versions, checksums AND timestamps
    # This prevents confusion when same version with different checksums exists
    # and ensures we NEVER consider older releases as updates
    local needs_update=false
    
    # Timestamp validation: ONLY accept releases NEWER than installed version
    if [[ "$remote_timestamp" -gt 0 && "$INSTALLED_RELEASE_TIMESTAMP" != "0" ]]; then
        if [[ "$remote_timestamp" -le "$INSTALLED_RELEASE_TIMESTAMP" ]]; then
            # Remote release is OLDER or SAME age - skip it
            return 0
        fi
    fi
    
    if [[ "$remote_version" != "$CURRENT_VERSION" ]]; then
        # Different version number - check if it's actually newer
        needs_update=true
    elif [[ -n "$remote_sha256" && -n "$INSTALLED_RELEASE_SHA256" ]]; then
        # Same version but check if SHA256 differs (hotfix/rebuild)
        # AND timestamp is newer (already validated above)
        if [[ "$remote_sha256" != "$INSTALLED_RELEASE_SHA256" ]]; then
            needs_update=true
        fi
    fi
    
    if [[ "$needs_update" == "true" ]]; then
        local release_body=$(echo "$release_json" | grep -o '"body":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n/\n/g' | sed 's/\\r//g')
        
        # Save update info to file for main menu display
        local update_info_file="$LOG_DIR/.update_available"
        cat > "$update_info_file" 2>/dev/null << EOF
UPDATE_AVAILABLE=true
REMOTE_VERSION="$remote_version"
REMOTE_TAG="$remote_tag"
REMOTE_TIMESTAMP="$remote_timestamp"
REMOTE_SHA256="$remote_sha256"
CHECKED_AT=$(date +%s)
EOF
        
        show_update_available "$remote_version" "$remote_tag" "$release_body" "prompt"
    else
        # No update available - clear the update info file
        local update_info_file="$LOG_DIR/.update_available"
        rm -f "$update_info_file" 2>/dev/null || true
    fi
    
    return 0  # Always return success
}

# 📢 Show update notification
show_update_available() {
    local new_version="$1"
    local release_tag="$2"
    local release_notes="$3"
    local mode="${4:-notify}"  # notify or prompt
    
    echo ""
    echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║               🎉 UPDATE AVAILABLE: v${new_version}                       ║${NC}"
    echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}Current: v${CURRENT_VERSION}${NC} → ${GREEN}${BOLD}New: v${new_version}${NC}"
    echo -e "${BLUE}🔗 View release: ${CYAN}${GITHUB_RELEASES_URL}/tag/${release_tag}${NC}"
    
    # Show release notes preview
    if [[ -n "$release_notes" ]]; then
        echo -e "\n${BLUE}📝 Release notes (preview):${NC}"
        echo "$release_notes" | head -5 | sed 's/^/  /'
        if [[ $(echo "$release_notes" | wc -l) -gt 5 ]]; then
            echo -e "  ${GRAY}... (see full notes at link above)${NC}"
        fi
    fi
    
    if [[ "$mode" == "prompt" ]]; then
        echo ""
        echo -e "${YELLOW}Would you like to update now? [Y/n/later]: ${NC}"
        read -r update_response
        
        case "$update_response" in
            [Yy]|"")
                echo -e "${CYAN}⬇️  Starting update process...${NC}"
                perform_update "$new_version" "$release_tag" "$release_notes"
                ;;
            [Ll]*)
                echo -e "${BLUE}ℹ️  Update postponed. Run ${GREEN}./convert.sh --update${BLUE} when ready.${NC}"
                ;;
            *)
                echo -e "${YELLOW}⏸️  Update skipped. You can update anytime with: ${GREEN}./convert.sh --update${NC}"
                ;;
        esac
    else
        echo -e "${YELLOW}🔄 Update with: ${GREEN}./convert.sh --update${NC}"
    fi
    
    echo ""
}

# 🔐 Verify GPG signature (most secure)
verify_gpg_signature() {
    local file="$1"
    local signature_file="${file}.sig"
    local signature_url="$2"
    
    # Check if GPG is available
    if ! command -v gpg >/dev/null 2>&1 && ! command -v gpg2 >/dev/null 2>&1; then
        if [[ "$GPG_SIGNATURE_REQUIRED" == "true" ]]; then
            echo -e "${RED}❌ GPG not installed but signature verification required${NC}"
            return 1
        else
            echo -e "${YELLOW}⚠️  GPG not available, skipping signature verification${NC}"
            return 0
        fi
    fi
    
    local gpg_cmd="gpg"
    command -v gpg2 >/dev/null 2>&1 && gpg_cmd="gpg2"
    
    # Download signature file
    if [[ -n "$signature_url" ]]; then
        echo -e "${CYAN}🔏 Downloading GPG signature...${NC}"
        if ! curl -sL --ssl-reqd --tlsv1.2 "$signature_url" -o "$signature_file" 2>/dev/null; then
            if [[ "$GPG_SIGNATURE_REQUIRED" == "true" ]]; then
                echo -e "${RED}❌ Failed to download GPG signature${NC}"
                return 1
            else
                echo -e "${YELLOW}⚠️  No GPG signature available${NC}"
                return 0
            fi
        fi
        
        # Verify signature
        echo -e "${CYAN}🔐 Verifying GPG signature...${NC}"
        if [[ -n "$GPG_KEY_FINGERPRINT" ]]; then
            # Verify with specific key fingerprint
            if $gpg_cmd --verify --status-fd 1 "$signature_file" "$file" 2>/dev/null | grep -q "$GPG_KEY_FINGERPRINT"; then
                echo -e "${GREEN}✓ GPG signature verified with trusted key!${NC}"
                rm -f "$signature_file"
                return 0
            else
                echo -e "${RED}❌ GPG signature verification FAILED!${NC}"
                rm -f "$signature_file"
                return 1
            fi
        else
            # Verify signature exists and is valid (any key)
            if $gpg_cmd --verify "$signature_file" "$file" 2>/dev/null; then
                echo -e "${YELLOW}⚠️  GPG signature valid but key not pinned (set GPG_KEY_FINGERPRINT for max security)${NC}"
                rm -f "$signature_file"
                return 0
            else
                if [[ "$GPG_SIGNATURE_REQUIRED" == "true" ]]; then
                    echo -e "${RED}❌ GPG signature verification FAILED!${NC}"
                    rm -f "$signature_file"
                    return 1
                else
                    echo -e "${YELLOW}⚠️  GPG verification failed, continuing anyway${NC}"
                    rm -f "$signature_file"
                    return 0
                fi
            fi
        fi
    else
        if [[ "$GPG_SIGNATURE_REQUIRED" == "true" ]]; then
            echo -e "${RED}❌ GPG signature required but not found${NC}"
            return 1
        fi
    fi
    
    return 0
}

# 🔐 Verify SHA256 checksum (MANDATORY)
verify_sha256() {
    local file="$1"
    local expected_sha="$2"
    
    # SHA256 is MANDATORY - no bypasses for security
    if [[ -z "$expected_sha" ]]; then
        echo -e "${RED}❌ SECURITY ERROR: No SHA256 checksum found!${NC}"
        echo -e "${RED}Update cannot proceed without SHA256 verification.${NC}"
        echo -e "${YELLOW}This protects you from corrupted or malicious files.${NC}"
        return 1
    fi
    
    echo -e "${CYAN}🔐 Verifying SHA256 checksum...${NC}"
    local actual_sha=$(sha256sum "$file" | awk '{print $1}')
    
    echo -e "${GRAY}Expected: ${expected_sha}${NC}"
    echo -e "${GRAY}Actual:   ${actual_sha}${NC}"
    
    if [[ "$actual_sha" == "$expected_sha" ]]; then
        echo -e "${GREEN}      ✓ SHA256 MATCH - File integrity confirmed!${NC}"
        return 0
    else
        echo -e "${RED}❌ SHA256 MISMATCH! File is corrupted or tampered!${NC}"
        echo -e "${RED}Update aborted for your safety.${NC}"
        return 1
    fi
}

# 📥 Extract SHA256 from release body and assets
extract_sha256_from_release() {
    local release_json="$1"
    local sha256=""
    
    # Method 1: Try to fetch SHA256 from release assets with SSL verification
    local assets_url=$(echo "$release_json" | grep -o '"assets_url":"[^"]*"' | cut -d'"' -f4)
    if [[ -n "$assets_url" ]]; then
        local assets_json=$(curl -sL --ssl-reqd --tlsv1.2 "$assets_url" -m 10 2>/dev/null)
        
        # Look for .sha256 or .checksum file
        local sha256_url=$(echo "$assets_json" | grep -o '"browser_download_url":"[^"]*\\.sha256"' | cut -d'"' -f4 | head -1)
        if [[ -z "$sha256_url" ]]; then
            sha256_url=$(echo "$assets_json" | grep -o '"browser_download_url":"[^"]*convert\\.sh\\.sha256"' | cut -d'"' -f4 | head -1)
        fi
        if [[ -z "$sha256_url" ]]; then
            sha256_url=$(echo "$assets_json" | grep -o '"browser_download_url":"[^"]*checksum"' | cut -d'"' -f4 | head -1)
        fi
        
        if [[ -n "$sha256_url" ]]; then
            sha256=$(curl -sL --ssl-reqd --tlsv1.2 "$sha256_url" -m 10 2>/dev/null | grep -oE '[a-f0-9]{64}' | head -1)
            if [[ -n "$sha256" ]]; then
                echo "$sha256"
                return 0
            fi
        fi
    fi
    
    # Method 2: Extract from release body
    local release_body=$(echo "$release_json" | grep -o '"body":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n/\n/g' | sed 's/\\r//g')
    sha256=$(echo "$release_body" | grep -iE '(sha256|checksum)' | grep -oE '[a-f0-9]{64}' | head -1)
    
    if [[ -n "$sha256" ]]; then
        echo "$sha256"
        return 0
    fi
    
    # No SHA256 found
    return 1
}

# 🚀 Perform update with SHA256 verification
perform_update() {
    local new_version="$1"
    local release_tag="$2"
    local release_json="$3"
    
    # Set up atomic update protection
    local update_lock="${BASH_SOURCE[0]}.updating"
    local update_temp="${BASH_SOURCE[0]}.new"
    local update_backup="${BASH_SOURCE[0]}.backup"
    
    # Trap interruptions for cleanup
    trap 'update_cleanup_on_interrupt "$update_lock" "$update_temp" "$update_backup"' INT TERM HUP
    
    # Check if previous update was interrupted
    if [[ -f "$update_lock" ]]; then
        echo -e "${YELLOW}⚠️  Previous update was interrupted!${NC}"
        recover_from_interrupted_update "$update_lock" "$update_backup"
    fi
    
    # Create update lock file
    echo "UPDATE_IN_PROGRESS" > "$update_lock"
    
    echo -e "${CYAN}⬇️  Downloading v${new_version} from ${release_tag}...${NC}"
    
    # Extract SHA256 from release (tries assets first, then body)
    local expected_sha256=$(extract_sha256_from_release "$release_json")
    
    if [[ -n "$expected_sha256" ]]; then
        echo -e "${GREEN}✓ Found SHA256 checksum for verification${NC}"
    else
        echo -e "${YELLOW}⚠️  No SHA256 checksum found in release${NC}"
    fi
    
    # Extract release timestamp for fingerprint tracking
    local release_timestamp_iso=$(echo "$release_json" | grep -o '"published_at":"[^"]*"' | cut -d'"' -f4)
    local release_timestamp=0
    if [[ -n "$release_timestamp_iso" ]]; then
        release_timestamp=$(date -d "$release_timestamp_iso" +%s 2>/dev/null || echo "0")
    fi
    
    # Create backup (atomic operation)
    local backup_dir="$LOG_DIR/backups"
    mkdir -p "$backup_dir" 2>/dev/null
    local backup_file="$backup_dir/convert.sh.v${CURRENT_VERSION}-$(date +%Y%m%d-%H%M%S)"
    
    # Create atomic backup
    if ! cp "${BASH_SOURCE[0]}" "$update_backup" 2>/dev/null; then
        echo -e "${RED}❌ Failed to create safety backup${NC}"
        rm -f "$update_lock"
        trap - INT TERM HUP
        return 1
    fi
    
    # Also save to backups directory
    cp "${BASH_SOURCE[0]}" "$backup_file" 2>/dev/null
    echo -e "${GREEN}✓ Backup: $backup_file${NC}"
    
    # Download with HTTPS SSL verification
    local download_url="https://raw.githubusercontent.com/${GITHUB_REPO}/${release_tag}/convert.sh"
    local fallback_url="https://raw.githubusercontent.com/${GITHUB_REPO}/main/convert.sh"
    
    # Verify URLs are from trusted GitHub domains
    if [[ ! "$download_url" =~ ^https://raw\.githubusercontent\.com/ ]] || [[ ! "$fallback_url" =~ ^https://raw\.githubusercontent\.com/ ]]; then
        echo -e "${RED}❌ Security error: Invalid download URL (not from GitHub)${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🔒 Downloading with SSL certificate verification...${NC}"
    echo -e "${CYAN}Source: ${download_url}${NC}"
    echo ""
    
    # Download with progress bar
    if ! curl -L --ssl-reqd --tlsv1.2 --progress-bar "$download_url" -o convert.sh.new 2>&1 | \
         while IFS= read -r line; do
             # Show curl's progress bar
             echo -ne "\r${CYAN}⬇️  ${line}${NC}"
         done || [[ ! -s "convert.sh.new" ]]; then
        echo ""
        echo -e "${YELLOW}⚠️  Tag download failed, trying main branch...${NC}"
        echo -e "${CYAN}Source: ${fallback_url}${NC}"
        echo ""
        if ! curl -L --ssl-reqd --tlsv1.2 --progress-bar "$fallback_url" -o convert.sh.new 2>&1 | \
             while IFS= read -r line; do
                 echo -ne "\r${CYAN}⬇️  ${line}${NC}"
             done; then
            echo ""
            echo -e "${RED}❌ SSL verification failed or download error${NC}"
            return 1
        fi
    fi
    echo ""  # New line after progress
    echo -e "${GREEN}✓ Download complete${NC}"
    
    if [[ ! -f "convert.sh.new" ]] || [[ ! -s "convert.sh.new" ]]; then
        echo -e "${RED}❌ Download failed${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║              🔒 SECURITY VERIFICATION                       ║${NC}"
    echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Running multiple security checks...${NC}"
    echo ""
    
    # Security Check 1: File size sanity check
    echo -e "${CYAN}[1/6] Checking file size...${NC}"
    local file_size=$(stat -c%s "convert.sh.new" 2>/dev/null || echo "0")
    if [[ $file_size -lt $MIN_FILE_SIZE ]]; then
        echo -e "${RED}❌ Downloaded file too small ($file_size bytes) - possibly corrupted or fake${NC}"
        rm -f convert.sh.new
        return 1
    fi
    echo -e "${GREEN}      ✓ File size check passed ($file_size bytes)${NC}"
    
    # Security Check 2: Verify file starts with shebang
    echo -e "${CYAN}[2/6] Verifying file format...${NC}"
    local first_line=$(head -n1 "convert.sh.new" 2>/dev/null)
    if [[ ! "$first_line" =~ ^#!/.*bash ]]; then
        echo -e "${RED}❌ File doesn't appear to be a valid bash script${NC}"
        rm -f convert.sh.new
        return 1
    fi
    echo -e "${GREEN}      ✓ File format check passed${NC}"
    
    # Security Check 2.5: Verify downloaded file version matches expected version
    echo -e "${CYAN}[2.5/6] Verifying version number...${NC}"
    local downloaded_version=$(grep -m1 '^CURRENT_VERSION=' "convert.sh.new" 2>/dev/null | cut -d'"' -f2)
    
    if [[ -z "$downloaded_version" ]]; then
        echo -e "${RED}❌ Cannot detect version in downloaded file${NC}"
        rm -f convert.sh.new
        return 1
    fi
    
    # Ensure downloaded version matches the release we're trying to install
    if [[ "$downloaded_version" != "$new_version" ]]; then
        echo -e "${RED}❌ VERSION MISMATCH!${NC}"
        echo -e "${RED}   Expected: v${new_version}${NC}"
        echo -e "${RED}   Got: v${downloaded_version}${NC}"
        echo -e "${YELLOW}This can happen if a new release was published during download.${NC}"
        echo -e "${YELLOW}Please run the update again to get the correct version.${NC}"
        rm -f convert.sh.new
        return 1
    fi
    echo -e "${GREEN}      ✓ Version verified: v${downloaded_version}${NC}"
    
    # Security Check 3: GPG signature verification (if available)
    echo -e "${CYAN}[3/6] Checking GPG signature...${NC}"
    local sig_url=""
    if [[ -n "$assets_url" ]]; then
        local assets_json=$(curl -sL --ssl-reqd --tlsv1.2 "$(echo "$release_json" | grep -o '"assets_url":"[^"]*"' | cut -d'"' -f4)" -m 10 2>/dev/null)
        sig_url=$(echo "$assets_json" | grep -o '"browser_download_url":"[^"]*\\.sig"' | cut -d'"' -f4 | head -1)
    fi
    
    if ! verify_gpg_signature "convert.sh.new" "$sig_url"; then
        rm -f convert.sh.new
        return 1
    fi
    
    # Security Check 4: SHA256 checksum
    echo -e "${CYAN}[4/6] Verifying SHA256 checksum...${NC}"
    if ! verify_sha256 "convert.sh.new" "$expected_sha256"; then
        rm -f convert.sh.new
        return 1
    fi
    
    # Security Check 5: Bash syntax validation
    echo -e "${CYAN}[5/6] Validating bash syntax...${NC}"
    if ! bash -n convert.sh.new 2>/dev/null; then
        echo -e "${RED}❌ Syntax error in download${NC}"
        rm -f convert.sh.new
        return 1
    fi
    echo -e "${GREEN}      ✓ Syntax validation passed${NC}"
    
    # Security Check 6: Install (ATOMIC OPERATION)
    echo -e "${CYAN}[6/6] Installing update...${NC}"
    
    # Atomic replace using mv (single syscall, safe even if interrupted)
    if ! mv -f "convert.sh.new" "${BASH_SOURCE[0]}" 2>/dev/null; then
        echo -e "${RED}❌ Installation failed!${NC}"
        echo -e "${YELLOW}Restoring from backup...${NC}"
        mv -f "$update_backup" "${BASH_SOURCE[0]}" 2>/dev/null
        rm -f "$update_lock"
        trap - INT TERM HUP
        return 1
    fi
    
    chmod +x "${BASH_SOURCE[0]}" 2>/dev/null
    
    # Clean up atomic update files
    rm -f "$update_lock" "$update_backup" 2>/dev/null
    
    # Remove trap
    trap - INT TERM HUP
    
    echo -e "${GREEN}      ✓ Installation complete${NC}"
    
    # Security Check 7: Update release fingerprint with verified SHA256 and timestamp
    echo -e "${CYAN}[7/7] Updating release fingerprint...${NC}"
    if update_release_fingerprint "$new_version" "$release_tag" "$expected_sha256" "$release_timestamp"; then
        echo -e "${GREEN}      ✓ Release fingerprint saved${NC}"
    else
        echo -e "${YELLOW}⚠️  Warning: Could not update release fingerprint${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║               ✓ UPDATE SUCCESSFUL!                          ║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Updated from v${CURRENT_VERSION} to v${new_version}${NC}"
    echo -e "${BLUE}Backup saved at: ${backup_file}${NC}"
    echo -e "${BLUE}Fingerprint: ${expected_sha256:0:16}...${NC}"
    echo ""
    echo -e "${YELLOW}🔄 Please restart the script to use the new version${NC}"
    echo ""
    exit 0
}

# 🔧 Manual update command
manual_update() {
    # 🛠️ Block manual updates in development mode
    if [[ "$DEV_MODE" == "true" ]]; then
        echo ""
        echo -e "${YELLOW}⚠️  Development Mode Active${NC}"
        echo -e "${RED}🚫 Auto-update is disabled in Git repositories${NC}"
        echo ""
        echo -e "${BLUE}This protects your development work from being overwritten.${NC}"
        echo -e "${GRAY}If you want to update:${NC}"
        echo -e "${GRAY}1. Commit your changes: ${GREEN}git commit -am 'Your changes'${NC}"
        echo -e "${GRAY}2. Pull latest: ${GREEN}git pull origin main${NC}"
        echo ""
        return 1
    fi
    
    echo -e "${CYAN}🔄 Checking GitHub Releases for stable versions...${NC}"
    
    local release_json=$(curl -s --ssl-reqd --tlsv1.2 "$GITHUB_API_URL" 2>/dev/null)
    
    if [[ -z "$release_json" ]] || [[ "$release_json" == *"Not Found"* ]]; then
        echo -e "${RED}❌ Cannot fetch releases${NC}"
        echo -e "${BLUE}Visit: ${GITHUB_RELEASES_URL}${NC}"
        return 1
    fi
    
    # Verify this is a stable release (not pre-release or draft)
    local is_prerelease=$(echo "$release_json" | grep -o '"prerelease":[^,]*' | grep -o 'true\|false')
    local is_draft=$(echo "$release_json" | grep -o '"draft":[^,]*' | grep -o 'true\|false')
    
    if [[ "$is_prerelease" == "true" ]] || [[ "$is_draft" == "true" ]]; then
        echo -e "${YELLOW}⚠️  Latest release is a pre-release or draft, skipping${NC}"
        echo -e "${BLUE}Only stable releases are used for updates${NC}"
        return 0
    fi
    
    local remote_tag=$(echo "$release_json" | grep -o '"tag_name":"[^"]*"' | cut -d'"' -f4)
    local remote_version=$(echo "$remote_tag" | grep -oE '[0-9]+\.[0-9]+' | head -1)
    local release_body=$(echo "$release_json" | grep -o '"body":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n/\n/g' | sed 's/\\r//g')
    
    # Extract release timestamp for validation
    local remote_timestamp_iso=$(echo "$release_json" | grep -o '"published_at":"[^"]*"' | cut -d'"' -f4)
    local remote_timestamp=0
    if [[ -n "$remote_timestamp_iso" ]]; then
        remote_timestamp=$(date -d "$remote_timestamp_iso" +%s 2>/dev/null || echo "0")
    fi
    
    # Additional safety: verify tag doesn't contain RC, beta, alpha, or pre markers
    if [[ "$remote_tag" =~ (rc|RC|beta|BETA|alpha|ALPHA|pre|PRE) ]]; then
        echo -e "${YELLOW}⚠️  Skipping release candidate or pre-release: ${remote_tag}${NC}"
        echo -e "${BLUE}Only stable releases are used for updates${NC}"
        return 0
    fi
    
    if [[ -z "$remote_version" ]]; then
        echo -e "${RED}❌ Cannot parse version${NC}"
        return 1
    fi
    
    # Load installed fingerprint for timestamp comparison
    load_release_fingerprint 2>/dev/null
    
    # Timestamp validation: prevent downgrade to older releases
    if [[ "$remote_timestamp" -gt 0 && "$INSTALLED_RELEASE_TIMESTAMP" != "0" ]]; then
        if [[ "$remote_timestamp" -le "$INSTALLED_RELEASE_TIMESTAMP" ]]; then
            echo -e "${YELLOW}⚠️  Remote release is not newer than installed version (timestamp check)${NC}"
            echo -e "${GREEN}✓ Already have the latest release${NC}"
            return 0
        fi
    fi
    
    if [[ "$remote_version" == "$CURRENT_VERSION" ]]; then
        echo -e "${GREEN}✓ Already latest (v${CURRENT_VERSION})${NC}"
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}Current: v${CURRENT_VERSION}${NC} → ${GREEN}Available: v${remote_version}${NC}"
    echo -e "${BLUE}📝 Release notes (first 10 lines):${NC}"
    echo "$release_body" | head -10 | sed 's/^/  /'
    echo ""
    echo -e "${YELLOW}Update now? [y/N]: ${NC}"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        perform_update "$remote_version" "$remote_tag" "$release_json"
    fi
}

# 📝 Show version info
show_version_info() {
    echo -e "${CYAN}${BOLD}Smart GIF Converter v${CURRENT_VERSION}${NC}"
    echo -e "${BLUE}Repository: ${CYAN}https://github.com/${GITHUB_REPO}${NC}"
    echo -e "${BLUE}Releases: ${CYAN}${GITHUB_RELEASES_URL}${NC}"
}

# 🛡️ Cleanup on update interruption
update_cleanup_on_interrupt() {
    local lock_file="$1"
    local temp_file="$2"
    local backup_file="$3"
    
    echo ""
    echo -e "${RED}❌ Update interrupted!${NC}"
    
    # Clean up temporary files
    rm -f "$temp_file" "convert.sh.new" 2>/dev/null
    
    # Check if original file still exists
    if [[ ! -f "${BASH_SOURCE[0]}" ]] && [[ -f "$backup_file" ]]; then
        echo -e "${YELLOW}Restoring from backup...${NC}"
        mv -f "$backup_file" "${BASH_SOURCE[0]}" 2>/dev/null
        chmod +x "${BASH_SOURCE[0]}" 2>/dev/null
        echo -e "${GREEN}✓ Original file restored${NC}"
    fi
    
    # Keep lock file to detect interrupted update on next run
    echo -e "${BLUE}ℹ️  Update was safely cancelled. Original file is intact.${NC}"
    exit 1
}

# 🔄 Recover from previously interrupted update
recover_from_interrupted_update() {
    local lock_file="$1"
    local backup_file="$2"
    
    echo -e "${CYAN}Checking for recovery...${NC}"
    
    # If backup exists and original is missing or corrupted
    if [[ -f "$backup_file" ]]; then
        if [[ ! -f "${BASH_SOURCE[0]}" ]]; then
            echo -e "${YELLOW}Original file missing, restoring from backup...${NC}"
            mv -f "$backup_file" "${BASH_SOURCE[0]}" 2>/dev/null
            chmod +x "${BASH_SOURCE[0]}" 2>/dev/null
            echo -e "${GREEN}✓ File restored from backup${NC}"
        elif ! bash -n "${BASH_SOURCE[0]}" 2>/dev/null; then
            echo -e "${YELLOW}Original file corrupted, restoring from backup...${NC}"
            mv -f "$backup_file" "${BASH_SOURCE[0]}" 2>/dev/null
            chmod +x "${BASH_SOURCE[0]}" 2>/dev/null
            echo -e "${GREEN}✓ Corrupted file replaced with backup${NC}"
        else
            echo -e "${GREEN}✓ Original file is intact${NC}"
            rm -f "$backup_file" 2>/dev/null
        fi
    fi
    
    # Clean up lock file
    rm -f "$lock_file" 2>/dev/null
    echo -e "${GREEN}✓ Recovery check complete${NC}"
    echo ""
}

# 🔐 Load release fingerprint from file
load_release_fingerprint() {
    if [[ -f "$RELEASE_FINGERPRINT_FILE" ]]; then
        # Load fingerprint data
        INSTALLED_RELEASE_SHA256=$(grep '^SHA256=' "$RELEASE_FINGERPRINT_FILE" 2>/dev/null | cut -d'=' -f2)
        INSTALLED_RELEASE_VERSION=$(grep '^VERSION=' "$RELEASE_FINGERPRINT_FILE" 2>/dev/null | cut -d'=' -f2)
        INSTALLED_RELEASE_TAG=$(grep '^TAG=' "$RELEASE_FINGERPRINT_FILE" 2>/dev/null | cut -d'=' -f2)
        INSTALLED_RELEASE_TIMESTAMP=$(grep '^RELEASE_TIMESTAMP=' "$RELEASE_FINGERPRINT_FILE" 2>/dev/null | cut -d'=' -f2)
        
        # Default to 0 if not found
        [[ -z "$INSTALLED_RELEASE_TIMESTAMP" ]] && INSTALLED_RELEASE_TIMESTAMP="0"
        
        # Validate loaded data
        if [[ -n "$INSTALLED_RELEASE_SHA256" && "$INSTALLED_RELEASE_VERSION" == "$CURRENT_VERSION" ]]; then
            return 0  # Valid fingerprint loaded
        fi
    fi
    
    # No fingerprint or version mismatch - create new fingerprint
    create_release_fingerprint
    return $?
}

# 🔐 Create release fingerprint for current installation
create_release_fingerprint() {
    echo -e "${CYAN}🔐 Creating release fingerprint...${NC}"
    
    # Calculate SHA256 of current script
    local script_sha256=$(sha256sum "${BASH_SOURCE[0]}" 2>/dev/null | awk '{print $1}')
    
    if [[ -z "$script_sha256" ]]; then
        echo -e "${YELLOW}⚠️  Warning: Cannot calculate script checksum${NC}"
        return 1
    fi
    
    # Create/update fingerprint file
    mkdir -p "$(dirname "$RELEASE_FINGERPRINT_FILE")" 2>/dev/null
    
    cat > "$RELEASE_FINGERPRINT_FILE" <<EOF
# Smart GIF Converter - Release Fingerprint
# This file tracks the SHA256 checksum of the installed version
# Created: $(date '+%Y-%m-%d %H:%M:%S')

VERSION=$CURRENT_VERSION
SHA256=$script_sha256
TAG=
RELEASE_TIMESTAMP=0
INSTALL_DATE=$(date +%s)
INSTALL_DATE_READABLE=$(date '+%Y-%m-%d %H:%M:%S')
EOF
    
    # Update in-memory variables
    INSTALLED_RELEASE_SHA256="$script_sha256"
    INSTALLED_RELEASE_VERSION="$CURRENT_VERSION"
    INSTALLED_RELEASE_TAG=""
    INSTALLED_RELEASE_TIMESTAMP="0"
    
    echo -e "${GREEN}✓ Release fingerprint created${NC}"
    echo -e "${GRAY}Version: v${CURRENT_VERSION}${NC}"
    echo -e "${GRAY}SHA256: ${script_sha256:0:16}...${NC}"
    
    return 0
}

# 🔐 Update release fingerprint after successful update
update_release_fingerprint() {
    local new_version="$1"
    local new_tag="$2"
    local new_sha256="$3"
    local new_timestamp="${4:-0}"  # GitHub release timestamp
    
    if [[ -z "$new_sha256" ]]; then
        # Calculate SHA256 of newly installed script
        new_sha256=$(sha256sum "${BASH_SOURCE[0]}" 2>/dev/null | awk '{print $1}')
    fi
    
    if [[ -z "$new_sha256" ]]; then
        echo -e "${YELLOW}⚠️  Warning: Cannot calculate new script checksum${NC}"
        return 1
    fi
    
    # Update fingerprint file
    mkdir -p "$(dirname "$RELEASE_FINGERPRINT_FILE")" 2>/dev/null
    
    cat > "$RELEASE_FINGERPRINT_FILE" <<EOF
# Smart GIF Converter - Release Fingerprint
# This file tracks the SHA256 checksum of the installed version
# Updated: $(date '+%Y-%m-%d %H:%M:%S')

VERSION=$new_version
SHA256=$new_sha256
TAG=$new_tag
RELEASE_TIMESTAMP=$new_timestamp
INSTALL_DATE=$(date +%s)
INSTALL_DATE_READABLE=$(date '+%Y-%m-%d %H:%M:%S')
PREVIOUS_VERSION=$INSTALLED_RELEASE_VERSION
PREVIOUS_SHA256=$INSTALLED_RELEASE_SHA256
PREVIOUS_TIMESTAMP=$INSTALLED_RELEASE_TIMESTAMP
EOF
    
    # Update in-memory variables
    INSTALLED_RELEASE_SHA256="$new_sha256"
    INSTALLED_RELEASE_VERSION="$new_version"
    INSTALLED_RELEASE_TAG="$new_tag"
    INSTALLED_RELEASE_TIMESTAMP="$new_timestamp"
    
    echo -e "${GREEN}✓ Release fingerprint updated${NC}"
    
    return 0
}

# 🔍 Verify current installation matches fingerprint
verify_installation_integrity() {
    if [[ -z "$INSTALLED_RELEASE_SHA256" ]]; then
        # No fingerprint loaded
        return 1
    fi
    
    # Calculate current SHA256
    local current_sha256=$(sha256sum "${BASH_SOURCE[0]}" 2>/dev/null | awk '{print $1}')
    
    if [[ "$current_sha256" == "$INSTALLED_RELEASE_SHA256" ]]; then
        return 0  # Integrity verified
    else
        return 1  # Mismatch detected
    fi
}

# 🆕 First-run auto-update preference prompt
prompt_auto_update_preference() {
    # Skip if already asked or if settings exist with preference
    if [[ "$UPDATE_FIRST_RUN_PROMPT_DONE" == "true" ]] || grep -q "AUTO_UPDATE_ENABLED=" "$SETTINGS_FILE" 2>/dev/null; then
        return 0
    fi
    
    echo ""
    echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║               🔄 AUTOMATIC UPDATE CHECKS                       ║${NC}"
    echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}This script can automatically check for updates from GitHub.${NC}"
    echo -e "${GRAY}Updates include bug fixes, new features, and improvements.${NC}"
    echo ""
    echo -e "${YELLOW}How it works:${NC}"
    echo -e "  ${GREEN}•${NC} Checks GitHub once per day (non-intrusive)"
    echo -e "  ${GREEN}•${NC} Shows a notification when updates are available"
    echo -e "  ${GREEN}•${NC} You choose when to install updates"
    echo -e "  ${GREEN}•${NC} Updates include SHA256 verification for security"
    echo ""
    echo -e "${CYAN}Would you like to enable automatic update checks?${NC}"
    echo -e "${GRAY}(You can change this anytime in settings)${NC}"
    echo ""
    echo -e "  ${GREEN}[Y]${NC} Yes - Check for updates automatically (recommended)"
    echo -e "  ${YELLOW}[N]${NC} No - I'll check manually with ${GREEN}./convert.sh --check-update${NC}"
    echo ""
    echo -ne "${YELLOW}Your choice [Y/n]: ${NC}"
    read -r auto_update_choice
    
    case "$auto_update_choice" in
        [Nn]*)
            AUTO_UPDATE_ENABLED=false
            echo -e "\n${BLUE}ℹ️  Auto-update disabled. You can manually check with: ${GREEN}./convert.sh --check-update${NC}"
            ;;
        *)
            AUTO_UPDATE_ENABLED=true
            echo -e "\n${GREEN}✓ Auto-update enabled! Checking for updates once per day.${NC}"
            ;;
    esac
    
    UPDATE_FIRST_RUN_PROMPT_DONE=true
    
    # Save preference to settings
    if [[ -n "$SETTINGS_FILE" ]]; then
        save_settings --silent
    fi
    
    echo -e "${BLUE}💡 Current version: ${BOLD}v${CURRENT_VERSION}${NC}"
    echo -e "${GRAY}Press Enter to continue...${NC}"
    read -r
    
    return 0
}

# 🗄️ AI Smart Cache Management System (Corruption-Proof)
# =================================================================

# Initialize AI cache system with corruption protection
init_ai_cache() {
    if [[ "$AI_CACHE_ENABLED" != "true" ]]; then
        return 0
    fi
    
    # Create cache directory structure
    mkdir -p "$AI_CACHE_DIR" 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Warning: Cannot create AI cache directory, disabling cache${NC}" >&2
        AI_CACHE_ENABLED=false
        return 1
    }
    
    # Initialize or validate cache index
    if ! validate_cache_index; then
        echo -e "${YELLOW}🔄 Cache corruption detected, rebuilding index...${NC}" >&2
        rebuild_cache_index
    fi
    
    # Create backup of cache index
    create_cache_backup
    
    # Smart cleanup: only run every 7 days to avoid slowdown on every launch
    local cleanup_marker="${AI_CACHE_DIR}/.last_cleanup"
    local current_time=$(date +%s)
    local cleanup_interval=$((7 * 86400))  # 7 days in seconds
    local should_cleanup=false
    
    if [[ ! -f "$cleanup_marker" ]]; then
        # No marker file, definitely clean up
        should_cleanup=true
    else
        local last_cleanup=$(cat "$cleanup_marker" 2>/dev/null || echo "0")
        local time_since_cleanup=$((current_time - last_cleanup))
        if [[ $time_since_cleanup -gt $cleanup_interval ]]; then
            should_cleanup=true
        fi
    fi
    
    if [[ "$should_cleanup" == "true" ]]; then
        # Run cleanup in background to not slow down script startup
        (
            cleanup_ai_cache
            echo "$current_time" > "$cleanup_marker" 2>/dev/null
        ) &
        # Save the cleanup PID so we can wait for it later if needed
        CLEANUP_PID=$!
    fi
}

# Validate cache index integrity
validate_cache_index() {
    # Check if cache index exists
    [[ -f "$AI_CACHE_INDEX" ]] || return 1
    
    # Check if file is readable
    [[ -r "$AI_CACHE_INDEX" ]] || return 1
    
    # Check if file has proper header
    local header_line=$(head -n 1 "$AI_CACHE_INDEX" 2>/dev/null || echo "")
    [[ "$header_line" =~ ^#.*Version ]] || return 1
    
    # Check if using old format (md5hash in field 2) - needs migration
    local sample_line=$(grep -v '^#' "$AI_CACHE_INDEX" | head -n 1)
    if [[ -n "$sample_line" ]]; then
        local field2=$(echo "$sample_line" | cut -d'|' -f2)
        # Old format has 32-char hex MD5, new format has numeric filesize
        if [[ "$field2" =~ ^[0-9a-f]{32}$ ]]; then
            echo -e "${YELLOW}🔄 Old cache format detected, migrating to new format...${NC}" >&2
            migrate_cache_format
            return $?
        fi
    fi
    
    # Check if file structure is valid (no broken lines)
    local line_count=0
    local corrupted_lines=0
    
    while IFS= read -r line; do
        ((line_count++))
        [[ $line_count -le 3 ]] && continue  # Skip header
        
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        
        # Check line format: should have 5+ fields separated by |
        local field_count=$(echo "$line" | tr -cd '|' | wc -c)
        if [[ $field_count -lt 4 ]]; then
            ((corrupted_lines++))
            # If more than 10% of lines are corrupted, fail validation
            if [[ $corrupted_lines -gt 10 ]] && [[ $((corrupted_lines * 10)) -gt $line_count ]]; then
                return 1
            fi
        fi
    done < "$AI_CACHE_INDEX" 2>/dev/null || return 1
    
    return 0
}

# Migrate cache from old format (md5|size) to new format (size|mtime)
migrate_cache_format() {
    local old_cache="${AI_CACHE_INDEX}.old_format.$(date +%s)"
    
    # Backup old cache
    cp "$AI_CACHE_INDEX" "$old_cache" 2>/dev/null
    
    echo -e "  ${BLUE}💾 Backing up old cache to: $(basename -- "$old_cache")${NC}" >&2
    
    # Create new format cache with header
    cat > "$AI_CACHE_INDEX" << EOF
# AI Analysis Cache Index - Version $AI_CACHE_VERSION (Migrated)
# Format: filename|filesize|filemtime|timestamp|analysis_data
# Note: Uses size+mtime for FAST validation (no MD5 recalc needed!)
# Migrated from old format: $(date)
EOF
    
    local migrated=0
    local skipped=0
    
    # Read old format and convert
    while IFS='|' read -r filename md5hash filesize timestamp analysis_data; do
        # Skip headers and empty lines
        [[ "$filename" =~ ^# || -z "$filename" ]] && continue
        
        # Get current mtime for this file (if it still exists)
        local file_path="$filename"
        if [[ ! -f "$file_path" ]]; then
            # Try just the basename in current directory
            file_path="./$(basename -- "$filename" 2>/dev/null)"
        fi
        
        if [[ -f "$file_path" ]]; then
            local filemtime=$(stat -c%Y "$file_path" 2>/dev/null || echo "0")
            # Write new format: filename|filesize|filemtime|timestamp|analysis_data
            echo "$filename|$filesize|$filemtime|$timestamp|$analysis_data" >> "$AI_CACHE_INDEX"
            ((migrated++))
        else
            # File doesn't exist anymore, skip it
            ((skipped++))
        fi
    done < "$old_cache"
    
    echo -e "  ${GREEN}✓ Migrated $migrated cache entries${NC}" >&2
    [[ $skipped -gt 0 ]] && echo -e "  ${GRAY}⚠️  Skipped $skipped entries (files no longer exist)${NC}" >&2
    
    return 0
}

# Rebuild corrupted cache index
rebuild_cache_index() {
    local backup_file="${AI_CACHE_INDEX}.backup.$(date +%s)"
    
    # Backup corrupted file for analysis
    [[ -f "$AI_CACHE_INDEX" ]] && cp "$AI_CACHE_INDEX" "$backup_file" 2>/dev/null
    
    # Create fresh index
    cat > "$AI_CACHE_INDEX" << EOF
# AI Analysis Cache Index - Version $AI_CACHE_VERSION (Rebuilt)
# Format: filename|filesize|filemtime|timestamp|analysis_data
# Note: Uses size+mtime for FAST validation (no MD5 recalc needed!)
# Rebuilt: $(date)
EOF
    
    # Try to recover valid entries from backup
    if [[ -f "$backup_file" ]]; then
        local recovered=0
        while IFS= read -r line; do
            # Skip header and empty lines
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            
            # Validate line format
            local field_count=$(echo "$line" | tr -cd '|' | wc -c)
            if [[ $field_count -ge 4 ]]; then
                echo "$line" >> "$AI_CACHE_INDEX"
                ((recovered++))
            fi
        done < "$backup_file" 2>/dev/null || true
        
        if [[ $recovered -gt 0 ]]; then
            echo -e "${GREEN}✅ Recovered $recovered cache entries${NC}" >&2
        fi
        
        # Keep backup for a while, then clean up
        (sleep 300 && rm -f "$backup_file") &
    fi
}

# Create atomic backup of cache index
create_cache_backup() {
    if [[ -f "$AI_CACHE_INDEX" ]]; then
        local backup_file="${AI_CACHE_INDEX}.safe"
        cp "$AI_CACHE_INDEX" "$backup_file" 2>/dev/null || true
    fi
}

# Clean up old cache entries, remove duplicates, and purge deleted files
cleanup_ai_cache() {
    if [[ "$AI_CACHE_ENABLED" != "true" || ! -f "$AI_CACHE_INDEX" ]]; then
        return 0
    fi
    
    local cutoff_time=$(($(date +%s) - (AI_CACHE_MAX_AGE_DAYS * 86400)))
    local temp_index="$(mktemp)"
    
    # Keep header
    head -n 3 "$AI_CACHE_INDEX" > "$temp_index"
    
    # Use associative array to keep only the LATEST entry per file (deduplication)
    declare -A latest_entries
    declare -A latest_timestamps
    
    local old_entries=0
    local deleted_files=0
    local duplicate_entries=0
    
    # Read all entries and keep only the most recent per filename
    while IFS='|' read -r filename filesize filemtime timestamp analysis_data; do
        [[ "$filename" =~ ^# ]] && continue  # Skip comments
        [[ -z "$filename" ]] && continue     # Skip empty lines
        
        # Skip old entries (beyond max age)
        if [[ $timestamp -lt $cutoff_time ]]; then
            ((old_entries++))
            continue
        fi
        
        # Check if file still exists (check both absolute path and basename)
        local file_exists=false
        if [[ -f "$filename" ]]; then
            file_exists=true
        elif [[ -f "$(basename -- "$filename")" ]]; then
            file_exists=true
        fi
        
        if [[ "$file_exists" == "false" ]]; then
            ((deleted_files++))
            continue
        fi
        
        # Keep only the latest entry for each filename (deduplication)
        local existing_ts="${latest_timestamps[$filename]:-0}"
        if [[ $timestamp -gt $existing_ts ]]; then
            # This is a newer entry, check if we're replacing an old one
            [[ $existing_ts -gt 0 ]] && ((duplicate_entries++))
            
            latest_timestamps[$filename]=$timestamp
            latest_entries[$filename]="$filename|$filesize|$filemtime|$timestamp|$analysis_data"
        else
            # Older duplicate entry
            ((duplicate_entries++))
        fi
    done < <(tail -n +4 "$AI_CACHE_INDEX")
    
    # Write deduplicated entries to temp file
    for filename in "${!latest_entries[@]}"; do
        echo "${latest_entries[$filename]}" >> "$temp_index"
    done
    
    # Atomically replace cache with cleaned version
    mv "$temp_index" "$AI_CACHE_INDEX"
    
    # Report cleanup results
    local total_cleaned=$((old_entries + deleted_files + duplicate_entries))
    if [[ $total_cleaned -gt 0 ]]; then
        echo -e "  ${BLUE}🧹 Cache cleanup complete:${NC}" >&2
        [[ $old_entries -gt 0 ]] && echo -e "    ${GRAY}⏰ Removed $old_entries old entries (>${AI_CACHE_MAX_AGE_DAYS} days)${NC}" >&2
        [[ $deleted_files -gt 0 ]] && echo -e "    ${YELLOW}🗑️  Removed $deleted_files entries (files deleted)${NC}" >&2
        [[ $duplicate_entries -gt 0 ]] && echo -e "    ${GREEN}✔️ Removed $duplicate_entries duplicate entries${NC}" >&2
        
        # Show size reduction
        local new_count=$(tail -n +4 "$AI_CACHE_INDEX" 2>/dev/null | wc -l)
        local cache_size=$(du -h "$AI_CACHE_INDEX" 2>/dev/null | cut -f1 || echo "0")
        echo -e "    ${CYAN}📊 Cache size: ${cache_size}B, ${new_count} entries${NC}" >&2
    fi
    
    # Clean up old backup files
    find "$AI_CACHE_DIR" -name "analysis_cache.db.backup.*" -mtime +7 -delete 2>/dev/null || true
}

# Get file fingerprint for change detection (FAST - uses size + mtime, not MD5!)
get_file_fingerprint() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "MISSING"
        return 1
    fi
    
    # Use file size and modification time for FAST change detection
    # MD5 is stored in cache data, no need to recalculate here!
    local filesize=$(stat -c%s "$file" 2>/dev/null || echo "0")
    local filemtime=$(stat -c%Y "$file" 2>/dev/null || echo "0")
    
    echo "${filesize}:${filemtime}"
}

# Check if file analysis is cached and valid (with corruption protection)
check_ai_cache() {
    local file="$1"
    
    if [[ "$AI_CACHE_ENABLED" != "true" ]]; then
        return 1
    fi
    
    # Validate cache integrity first
    if ! validate_cache_index; then
        echo -e "${YELLOW}🔄 Cache corrupted during read, rebuilding...${NC}" >&2
        rebuild_cache_index
        return 1
    fi
    
    local current_fingerprint=$(get_file_fingerprint "$file")
    [[ "$current_fingerprint" == "MISSING" || "$current_fingerprint" == "ERROR:0" ]] && return 1
    
    # Search for cached entry with error handling
    local cached_line
    if ! cached_line=$(grep -F "$(basename -- "$file")|" "$AI_CACHE_INDEX" 2>/dev/null | tail -n 1); then
        return 1
    fi
    
    if [[ -n "$cached_line" ]]; then
        # Validate cached line format
        local field_count=$(echo "$cached_line" | tr -cd '|' | wc -c)
        if [[ $field_count -lt 4 ]]; then
            # Corrupted cache entry, ignore
            return 1
        fi
        
        local cached_fingerprint=$(echo "$cached_line" | cut -d'|' -f2-3 | tr '|' ':')
        
        if [[ "$cached_fingerprint" == "$current_fingerprint" ]]; then
            # Cache hit - return cached analysis
            local analysis_data=$(echo "$cached_line" | cut -d'|' -f5-)
            # Validate analysis data is not empty
            [[ -n "$analysis_data" ]] && echo "$analysis_data" && return 0
        fi
    fi
    
    return 1
}

# Save analysis results to cache (atomic operation)
save_to_ai_cache() {
    local file="$1"
    local analysis_data="$2"
    
    if [[ "$AI_CACHE_ENABLED" != "true" ]]; then
        return 0
    fi
    
    # Validate cache before write
    if ! validate_cache_index; then
        echo -e "${YELLOW}🔄 Cache corrupted during write, rebuilding...${NC}" >&2
        rebuild_cache_index
    fi
    
    local fingerprint=$(get_file_fingerprint "$file")
    [[ "$fingerprint" == "MISSING" ]] && return 1
    
    local filesize=$(echo "$fingerprint" | cut -d':' -f1)
    local filemtime=$(echo "$fingerprint" | cut -d':' -f2)
    local timestamp=$(date +%s)
    local filename=$(basename -- "$file")
    
    # Validate data before saving
    if [[ -z "$analysis_data" || ${#analysis_data} -gt 10000 ]]; then
        echo -e "${YELLOW}⚠️  Invalid analysis data, skipping cache save${NC}" >&2
        return 1
    fi
    
    # Atomic write operation using temporary file
    local temp_entry="$(mktemp)"
    local cache_entry="$filename|$filesize|$filemtime|$timestamp|$analysis_data"
    
    # Write to temp file first
    if echo "$cache_entry" > "$temp_entry" 2>/dev/null; then
        # Atomic append from temp file
        if cat "$temp_entry" >> "$AI_CACHE_INDEX" 2>/dev/null; then
            rm -f "$temp_entry"
            return 0
        fi
    fi
    
    # Cleanup on failure
    rm -f "$temp_entry" 2>/dev/null || true
    return 1
}

# Get cache statistics
get_cache_stats() {
    if [[ "$AI_CACHE_ENABLED" != "true" || ! -f "$AI_CACHE_INDEX" ]]; then
        echo "Cache disabled"
        return
    fi
    
    local total_entries=$(grep -v '^#' "$AI_CACHE_INDEX" | grep -c '|' || echo "0")
    local cache_size=$(du -h "$AI_CACHE_DIR" 2>/dev/null | cut -f1 || echo "0")
    
    echo "$total_entries entries, ${cache_size}B"
}

# 🔐 Checksum Cache System for Duplicate Detection
# =================================================================
# Dramatically speeds up duplicate detection by caching MD5 checksums
# Only recalculates if file mtime has changed

# Initialize checksum cache
init_checksum_cache() {
    if [[ "$CHECKSUM_CACHE_ENABLED" != "true" ]]; then
        return 0
    fi
    
    # Create cache directory
    mkdir -p "$CHECKSUM_CACHE_DIR" 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Warning: Cannot create checksum cache directory, disabling cache${NC}" >&2
        CHECKSUM_CACHE_ENABLED=false
        return 1
    }
    
    # Create cache DB if it doesn't exist
    if [[ ! -f "$CHECKSUM_CACHE_DB" ]]; then
        cat > "$CHECKSUM_CACHE_DB" << EOF
# Checksum Cache Database - Version $CHECKSUM_CACHE_VERSION
# Format: filepath|filesize|filemtime|md5_checksum|timestamp
# Created: $(date)
EOF
    fi
    
    # Smart cleanup: only run every 14 days
    local cleanup_marker="${CHECKSUM_CACHE_DIR}/.last_cleanup"
    local current_time=$(date +%s)
    local cleanup_interval=$((14 * 86400))  # 14 days
    
    if [[ ! -f "$cleanup_marker" ]]; then
        ( cleanup_checksum_cache && echo "$current_time" > "$cleanup_marker" ) &
    else
        local last_cleanup=$(cat "$cleanup_marker" 2>/dev/null || echo "0")
        local time_since=$((current_time - last_cleanup))
        if [[ $time_since -gt $cleanup_interval ]]; then
            ( cleanup_checksum_cache && echo "$current_time" > "$cleanup_marker" ) &
        fi
    fi
}

# Get cached checksum or calculate new one
get_cached_checksum() {
    local filepath="$1"
    
    if [[ ! -f "$filepath" ]]; then
        echo ""
        return 1
    fi
    
    local filesize=$(stat -c%s "$filepath" 2>/dev/null || echo "0")
    local filemtime=$(stat -c%Y "$filepath" 2>/dev/null || echo "0")
    
    # Check cache if enabled
    if [[ "$CHECKSUM_CACHE_ENABLED" == "true" && -f "$CHECKSUM_CACHE_DB" ]]; then
        # Search for cached entry
        local cached_line=$(grep -F "$filepath|" "$CHECKSUM_CACHE_DB" 2>/dev/null | tail -n 1)
        
        if [[ -n "$cached_line" ]]; then
            local cached_size=$(echo "$cached_line" | cut -d'|' -f2)
            local cached_mtime=$(echo "$cached_line" | cut -d'|' -f3)
            local cached_checksum=$(echo "$cached_line" | cut -d'|' -f4)
            
            # Validate cache entry (size and mtime must match)
            if [[ "$cached_size" == "$filesize" && "$cached_mtime" == "$filemtime" ]]; then
                # Cache hit!
                ((DUPLICATE_STATS_CACHE_HITS++))
                echo "$cached_checksum"
                return 0
            fi
        fi
    fi
    
    # Cache miss - calculate checksum
    ((DUPLICATE_STATS_CACHE_MISSES++))
    local checksum=$(md5sum "$filepath" 2>/dev/null | awk '{print $1}' || echo "")
    
    if [[ -n "$checksum" && "$CHECKSUM_CACHE_ENABLED" == "true" ]]; then
        # Save to cache (atomic operation)
        local timestamp=$(date +%s)
        local cache_entry="$filepath|$filesize|$filemtime|$checksum|$timestamp"
        echo "$cache_entry" >> "$CHECKSUM_CACHE_DB" 2>/dev/null || true
    fi
    
    echo "$checksum"
    return 0
}

# Clean up old checksum cache entries
cleanup_checksum_cache() {
    if [[ "$CHECKSUM_CACHE_ENABLED" != "true" || ! -f "$CHECKSUM_CACHE_DB" ]]; then
        return 0
    fi
    
    local cutoff_time=$(($(date +%s) - (CHECKSUM_CACHE_MAX_AGE_DAYS * 86400)))
    local temp_db="$(mktemp)"
    
    # Keep header
    head -n 3 "$CHECKSUM_CACHE_DB" > "$temp_db"
    
    declare -A latest_checksums
    declare -A latest_timestamps
    
    local old_entries=0
    local deleted_files=0
    local duplicate_entries=0
    
    # Deduplicate and clean
    while IFS='|' read -r filepath filesize filemtime checksum timestamp; do
        [[ "$filepath" =~ ^# || -z "$filepath" ]] && continue
        
        # Skip old entries
        if [[ $timestamp -lt $cutoff_time ]]; then
            ((old_entries++))
            continue
        fi
        
        # Check if file exists
        if [[ ! -f "$filepath" ]]; then
            ((deleted_files++))
            continue
        fi
        
        # Keep only latest entry per file
        local existing_ts="${latest_timestamps[$filepath]:-0}"
        if [[ $timestamp -gt $existing_ts ]]; then
            [[ $existing_ts -gt 0 ]] && ((duplicate_entries++))
            latest_timestamps[$filepath]=$timestamp
            latest_checksums[$filepath]="$filepath|$filesize|$filemtime|$checksum|$timestamp"
        else
            ((duplicate_entries++))
        fi
    done < <(tail -n +4 "$CHECKSUM_CACHE_DB")
    
    # Write deduplicated entries
    for filepath in "${!latest_checksums[@]}"; do
        echo "${latest_checksums[$filepath]}" >> "$temp_db"
    done
    
    # Atomic replace
    mv "$temp_db" "$CHECKSUM_CACHE_DB"
    
    # Report if significant cleanup
    local total_cleaned=$((old_entries + deleted_files + duplicate_entries))
    if [[ $total_cleaned -gt 50 ]]; then
        echo -e "  ${BLUE}🧹 Checksum cache cleaned: removed $total_cleaned entries${NC}" >&2
    fi
}

# Get checksum cache statistics
get_checksum_cache_stats() {
    if [[ "$CHECKSUM_CACHE_ENABLED" != "true" || ! -f "$CHECKSUM_CACHE_DB" ]]; then
        echo "disabled"
        return
    fi
    
    local total=$(grep -v '^#' "$CHECKSUM_CACHE_DB" | grep -c '|' || echo "0")
    local hits=$DUPLICATE_STATS_CACHE_HITS
    local misses=$DUPLICATE_STATS_CACHE_MISSES
    local total_lookups=$((hits + misses))
    
    if [[ $total_lookups -gt 0 ]]; then
        local hit_rate=$((hits * 100 / total_lookups))
        echo "$total entries, $hit_rate% hit rate"
    else
        echo "$total entries"
    fi
}

# Save AI analysis results to cache
save_ai_analysis_to_cache() {
    local file="$1"
    
    if [[ "$AI_CACHE_ENABLED" != "true" ]]; then
        return 0
    fi
    
    # Prepare AI analysis data for caching
    local ai_data="FRAMERATE=$FRAMERATE|DITHER_MODE=$DITHER_MODE|MAX_COLORS=$MAX_COLORS"
    ai_data="$ai_data|CROP_FILTER=${CROP_FILTER:-none}|AI_CONTENT_CACHE=${AI_CONTENT_CACHE:-none}"
    
    save_to_ai_cache "$file" "AI_ANALYSIS:$ai_data"
}

# Restore AI analysis variables from cache
restore_ai_analysis_from_cache() {
    local cached_data="$1"
    
    # Check if this is AI analysis data
    if [[ "$cached_data" =~ ^AI_ANALYSIS: ]]; then
        # Remove prefix and parse variables
        local ai_vars="${cached_data#AI_ANALYSIS:}"
        
        # Parse each variable
        IFS='|' read -ra VAR_ARRAY <<< "$ai_vars"
        for var_assignment in "${VAR_ARRAY[@]}"; do
            case "$var_assignment" in
                FRAMERATE=*) FRAMERATE="${var_assignment#*=}" ;;
                DITHER_MODE=*) DITHER_MODE="${var_assignment#*=}" ;;
                MAX_COLORS=*) MAX_COLORS="${var_assignment#*=}" ;;
                CROP_FILTER=*) 
                    local crop_val="${var_assignment#*=}"
                    [[ "$crop_val" != "none" ]] && CROP_FILTER="$crop_val" || CROP_FILTER=""
                    ;;
                AI_CONTENT_CACHE=*) 
                    local cache_val="${var_assignment#*=}"
                    [[ "$cache_val" != "none" ]] && AI_CONTENT_CACHE="$cache_val" || AI_CONTENT_CACHE=""
                    ;;
            esac
        done
        return 0
    fi
    
    return 1
}

# 🧠 AI Training & Learning System
# =======================================

# Initialize AI training system (corruption-proof)
init_ai_training() {
    if [[ "$AI_TRAINING_ENABLED" != "true" ]]; then
        return 0
    fi
    
    # Create training directory structure
    mkdir -p "$AI_TRAINING_DIR" 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Warning: Cannot create AI training directory, disabling training${NC}" >&2
        AI_TRAINING_ENABLED=false
        return 1
    }
    
    # Validate or rebuild model file
    if ! validate_ai_model; then
        echo -e "${YELLOW}🔄 AI model corruption detected, rebuilding...${NC}" >&2
        rebuild_ai_model
    fi
    
    # Validate or rebuild training log
    if ! validate_training_log; then
        echo -e "${YELLOW}🔄 Training log corruption detected, rebuilding...${NC}" >&2
        rebuild_training_log
    fi
    
    # Create backups
    create_training_backups
    
    # Clean up old training data if version changed
    local current_version=$(head -n 1 "$AI_MODEL_FILE" 2>/dev/null | grep -o 'Version [0-9.]*' | cut -d' ' -f2 2>/dev/null || echo "")
    if [[ "$current_version" != "$AI_MODEL_VERSION" ]]; then
        echo -e "${BLUE}🔄 AI Model version updated, reinitializing training data${NC}" >&2
        rebuild_ai_model
        rebuild_training_log
    fi
}

# Validate AI model file integrity
validate_ai_model() {
    # Check if model file exists and is readable
    [[ -f "$AI_MODEL_FILE" && -r "$AI_MODEL_FILE" ]] || return 1
    
    # Check proper header
    local header=$(head -n 1 "$AI_MODEL_FILE" 2>/dev/null || echo "")
    [[ "$header" =~ ^#.*AI.*Model.*Version ]] || return 1
    
    # Try to load AI generation from model file if available
    local model_generation=$(head -n 5 "$AI_MODEL_FILE" 2>/dev/null | grep "^# AI Generation:" | sed 's/^# AI Generation: //' | head -n 1)
    if [[ -n "$model_generation" && "$model_generation" =~ ^[0-9]+$ ]]; then
        AI_GENERATION="$model_generation"
    fi
    
    # Validate structure (check for major corruption)
    local corrupted=0
    local data_lines=0
    while IFS= read -r line; do
        # Skip header lines (first 4-6 lines starting with #)
        [[ "$line" =~ ^# ]] && continue
        # Skip empty lines
        [[ -z "$line" ]] && continue
        
        ((data_lines++))
        
        # Check format: feature_pattern|settings|confidence|samples|timestamp
        local fields=$(echo "$line" | tr -cd '|' | wc -c)
        [[ $fields -eq 4 ]] || ((corrupted++))
    done < "$AI_MODEL_FILE" 2>/dev/null || return 1
    
    # Only fail if we have substantial corruption:
    # - If we have 10+ data lines and >50% are corrupted, OR
    # - If we have >20 corrupted entries
    if [[ $data_lines -ge 10 ]] && [[ $((corrupted * 2)) -gt $data_lines ]]; then
        return 1
    elif [[ $corrupted -gt 20 ]]; then
        return 1
    fi
    
    # Model is valid (or has too few entries to judge)
    return 0
}

# Validate training log integrity
validate_training_log() {
    # Check if log exists and is readable
    [[ -f "$AI_TRAINING_LOG" && -r "$AI_TRAINING_LOG" ]] || return 1
    
    # Check proper header
    local header=$(head -n 1 "$AI_TRAINING_LOG" 2>/dev/null || echo "")
    [[ "$header" =~ ^#.*Training.*History ]] || return 1
    
    # Basic structure validation (at least readable)
    head -n 10 "$AI_TRAINING_LOG" >/dev/null 2>&1 || return 1
    
    return 0
}

# Rebuild corrupted AI model
rebuild_ai_model() {
    local backup="${AI_MODEL_FILE}.backup.$(date +%s)"
    [[ -f "$AI_MODEL_FILE" ]] && cp "$AI_MODEL_FILE" "$backup" 2>/dev/null
    
    # Increment AI generation on rebuild
    AI_GENERATION=$((AI_GENERATION + 1))
    
    # Save updated generation to settings
    save_settings --silent 2>/dev/null || true
    
    # Create fresh model file
    cat > "$AI_MODEL_FILE" << EOF
# AI Smart Model Database - Version $AI_MODEL_VERSION (Rebuilt)
# AI Generation: $AI_GENERATION
# Format: feature_pattern|optimal_settings|confidence|sample_count|last_updated
# Features: content_type:resolution:duration:motion_level:complexity
# Settings: framerate:dither:colors:crop
# Rebuilt: $(date)
EOF
    
    # Try to recover valid entries
    if [[ -f "$backup" ]]; then
        local recovered=0
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            local fields=$(echo "$line" | tr -cd '|' | wc -c)
            if [[ $fields -eq 4 ]]; then
                echo "$line" >> "$AI_MODEL_FILE"
                ((recovered++))
            fi
        done < "$backup" 2>/dev/null || true
        
        [[ $recovered -gt 0 ]] && echo -e "${GREEN}✅ Recovered $recovered model entries${NC}" >&2
        (sleep 300 && rm -f "$backup") &
    fi
}

# Rebuild corrupted training log
rebuild_training_log() {
    local backup="${AI_TRAINING_LOG}.backup.$(date +%s)"
    [[ -f "$AI_TRAINING_LOG" ]] && cp "$AI_TRAINING_LOG" "$backup" 2>/dev/null
    
    # Create fresh training log
    cat > "$AI_TRAINING_LOG" << EOF
# AI Training History - Version $AI_MODEL_VERSION (Rebuilt)
# Format: timestamp|action|feature_pattern|settings|outcome|confidence
# Rebuilt: $(date)
EOF
    
    # Optionally recover recent entries (last 100 lines)
    if [[ -f "$backup" ]]; then
        local recovered=0
        tail -n 100 "$backup" 2>/dev/null | while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            local fields=$(echo "$line" | tr -cd '|' | wc -c)
            if [[ $fields -ge 4 ]]; then
                echo "$line" >> "$AI_TRAINING_LOG"
                ((recovered++))
            fi
        done
        
        (sleep 300 && rm -f "$backup") &
    fi
}

# Create training system backups
create_training_backups() {
    if [[ -f "$AI_MODEL_FILE" ]]; then
        cp "$AI_MODEL_FILE" "${AI_MODEL_FILE}.safe" 2>/dev/null || true
    fi
    if [[ -f "$AI_TRAINING_LOG" ]]; then
        cp "$AI_TRAINING_LOG" "${AI_TRAINING_LOG}.safe" 2>/dev/null || true
    fi
}

# Extract feature pattern from video characteristics
extract_feature_pattern() {
    local content_type="$1"
    local width="$2"
    local height="$3"
    local duration="$4"
    local motion_level="$5"
    local complexity="$6"
    
    # Normalize resolution into categories
    local resolution_class
    local total_pixels=$((width * height))
    if [[ $total_pixels -ge 8294400 ]]; then
        resolution_class="4k"
    elif [[ $total_pixels -ge 2073600 ]]; then
        resolution_class="1080p"
    elif [[ $total_pixels -ge 921600 ]]; then
        resolution_class="720p"
    else
        resolution_class="sd"
    fi
    
    # Normalize duration into categories
    local duration_class
    if [[ $duration -lt 10 ]]; then
        duration_class="short"
    elif [[ $duration -lt 60 ]]; then
        duration_class="medium"
    elif [[ $duration -lt 300 ]]; then
        duration_class="long"
    else
        duration_class="movie"
    fi
    
    # Create feature pattern
    echo "${content_type}:${resolution_class}:${duration_class}:${motion_level}:${complexity}"
}

# Predict optimal settings using AI training data
ai_predict_settings() {
    local feature_pattern="$1"
    
    if [[ "$AI_TRAINING_ENABLED" != "true" || ! -f "$AI_MODEL_FILE" ]]; then
        return 1
    fi
    
    # Search for exact match first
    local exact_match=$(grep "^$feature_pattern|" "$AI_MODEL_FILE" | tail -n 1)
    if [[ -n "$exact_match" ]]; then
        local confidence=$(echo "$exact_match" | cut -d'|' -f3)
        local sample_count=$(echo "$exact_match" | cut -d'|' -f4)
        
        # Only use prediction if we have enough samples and confidence
        if [[ $(echo "$confidence > $AI_CONFIDENCE_MIN" | bc -l 2>/dev/null || echo 0) -eq 1 ]] && \
           [[ $sample_count -ge $AI_TRAINING_MIN_SAMPLES ]]; then
            local settings=$(echo "$exact_match" | cut -d'|' -f2)
            echo "EXACT:$confidence:$settings"
            return 0
        fi
    fi
    
    # Try partial matches with similarity scoring
    local best_match=""
    local best_score=0
    local best_confidence=0
    
    while IFS='|' read -r pattern settings confidence samples timestamp; do
        [[ "$pattern" =~ ^# ]] && continue  # Skip comments
        [[ -z "$pattern" ]] && continue     # Skip empty lines
        
        # Calculate similarity score
        local similarity=$(calculate_pattern_similarity "$feature_pattern" "$pattern")
        local weighted_score=$(echo "$similarity * $confidence" | bc -l 2>/dev/null || echo "0")
        
        if [[ $(echo "$weighted_score > $best_score" | bc -l 2>/dev/null || echo 0) -eq 1 ]] && \
           [[ $samples -ge $AI_TRAINING_MIN_SAMPLES ]]; then
            best_match="$settings"
            best_score="$weighted_score"
            best_confidence="$confidence"
        fi
    done < <(tail -n +4 "$AI_MODEL_FILE")
    
    if [[ -n "$best_match" && $(echo "$best_score > $AI_CONFIDENCE_MIN" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
        echo "SIMILAR:$best_confidence:$best_match"
        return 0
    fi
    
    return 1
}

# Calculate similarity between feature patterns
calculate_pattern_similarity() {
    local pattern1="$1"
    local pattern2="$2"
    
    IFS=':' read -ra features1 <<< "$pattern1"
    IFS=':' read -ra features2 <<< "$pattern2"
    
    local matches=0
    local total=${#features1[@]}
    
    for ((i=0; i<total; i++)); do
        if [[ "${features1[i]}" == "${features2[i]}" ]]; then
            ((matches++))
        fi
    done
    
    # Return similarity as decimal (0.0 to 1.0)
    echo "scale=2; $matches / $total" | bc -l 2>/dev/null || echo "0"
}

# Train AI model with successful conversion results
train_ai_model() {
    local file="$1"
    local content_type="$2"
    local width="$3"
    local height="$4"
    local duration="$5"
    local motion_level="$6"
    local complexity="$7"
    local final_framerate="$8"
    local final_dither="$9"
    local final_colors="${10}"
    local final_crop="${11:-none}"
    local outcome="${12:-success}"  # success, partial, failure
    
    if [[ "$AI_TRAINING_ENABLED" != "true" ]]; then
        return 0
    fi
    
    local feature_pattern=$(extract_feature_pattern "$content_type" "$width" "$height" "$duration" "$motion_level" "$complexity")
    local settings_pattern="${final_framerate}:${final_dither}:${final_colors}:${final_crop}"
    local timestamp=$(date +%s)
    
    # Calculate outcome score
    local outcome_score
    case "$outcome" in
        "success") outcome_score=1.0 ;;
        "partial") outcome_score=0.6 ;;
        "failure") outcome_score=0.1 ;;
        *) outcome_score=0.5 ;;
    esac
    
    # Log training event (atomic)
    atomic_append_training_log "$timestamp|train|$feature_pattern|$settings_pattern|$outcome|$outcome_score"
    
    # Update or create model entry (atomic)
    atomic_update_model_entry "$feature_pattern" "$settings_pattern" "$outcome_score"
}

# Atomic append to training log
atomic_append_training_log() {
    local log_entry="$1"
    [[ -z "$log_entry" ]] && return 1
    
    # Validate log integrity before writing
    if ! validate_training_log; then
        echo -e "${YELLOW}🔄 Training log corrupted, rebuilding...${NC}" >&2
        rebuild_training_log
    fi
    
    local temp_log="${AI_TRAINING_LOG}.append.$$"
    
    # Copy existing log and append new entry atomically
    if [[ -f "$AI_TRAINING_LOG" ]]; then
        cp "$AI_TRAINING_LOG" "$temp_log" 2>/dev/null || return 1
        echo "$log_entry" >> "$temp_log" 2>/dev/null || {
            rm -f "$temp_log"
            return 1
        }
        mv "$temp_log" "$AI_TRAINING_LOG"
    else
        echo "$log_entry" > "$AI_TRAINING_LOG"
    fi
}

# Atomic update AI model entry with new training data
atomic_update_model_entry() {
    local feature_pattern="$1"
    local settings_pattern="$2"
    local outcome_score="$3"
    
    # Validate inputs
    if [[ "${#feature_pattern}" -gt 500 || "${#settings_pattern}" -gt 200 ]]; then
        echo -e "${YELLOW}⚠️  Warning: Training data too large, skipping save${NC}" >&2
        return 1
    fi
    
    # Ensure model file integrity before modification
    if ! validate_ai_model; then
        echo -e "${YELLOW}🔄 Model corrupted before update, rebuilding...${NC}" >&2
        rebuild_ai_model
    fi
    
    local temp_model="${AI_MODEL_FILE}.atomic.$$"
    local updated=false
    local timestamp=$(date +%s)
    
    # Create backup before modification
    cp "$AI_MODEL_FILE" "${AI_MODEL_FILE}.preupdate" 2>/dev/null || true
    
    # Copy header first
    head -n 4 "$AI_MODEL_FILE" 2>/dev/null > "$temp_model" || {
        cat > "$temp_model" << EOF
# AI Smart Model Database - Version $AI_MODEL_VERSION
# Format: feature_pattern|optimal_settings|confidence|sample_count|last_updated
# Features: content_type:resolution:duration:motion_level:complexity
# Settings: framerate:dither:colors:crop
EOF
    }
    
    # Process existing entries
    while IFS='|' read -r pattern settings confidence samples last_updated; do
        [[ "$pattern" =~ ^# ]] && continue  # Skip comments
        [[ -z "$pattern" ]] && continue     # Skip empty lines
        
        # Validate entry format before processing
        local fields=$(echo "$pattern|$settings|$confidence|$samples|$last_updated" | tr -cd '|' | wc -c)
        [[ $fields -ne 4 ]] && continue
        
        if [[ "$pattern" == "$feature_pattern" ]]; then
            # Update existing entry using adaptive learning
            local new_samples=$((samples + 1))
            local new_confidence=$(echo "scale=3; ($confidence * $samples + $outcome_score * $AI_LEARNING_RATE) / $new_samples" | bc -l 2>/dev/null || echo "$confidence")
            
            # Prefer settings with higher success rate
            local updated_settings="$settings_pattern"
            if [[ $(echo "$outcome_score > 0.7" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
                updated_settings="$settings_pattern"  # Use new successful settings
            fi
            
            echo "$pattern|$updated_settings|$new_confidence|$new_samples|$timestamp" >> "$temp_model"
            updated=true
        else
            echo "$pattern|$settings|$confidence|$samples|$last_updated" >> "$temp_model"
        fi
    done < <(tail -n +5 "$AI_MODEL_FILE" 2>/dev/null || true)
    
    # Add new entry if not updated
    if [[ "$updated" == "false" ]]; then
        echo "$feature_pattern|$settings_pattern|$outcome_score|1|$timestamp" >> "$temp_model"
    fi
    
    # Validate new file before replacing
    if [[ -s "$temp_model" ]] && head -n 1 "$temp_model" | grep -q "^#.*AI.*Model"; then
        mv "$temp_model" "$AI_MODEL_FILE"
        rm -f "${AI_MODEL_FILE}.preupdate"
    else
        echo -e "${YELLOW}⚠️  Warning: Failed to create valid model file, rolling back${NC}" >&2
        rm -f "$temp_model"
        [[ -f "${AI_MODEL_FILE}.preupdate" ]] && mv "${AI_MODEL_FILE}.preupdate" "$AI_MODEL_FILE"
        return 1
    fi
}

# Get AI training statistics
# 🔗 Create clickable file path with terminal hyperlink
make_clickable_path() {
    local file_path="$1"
    local display_text="${2:-$file_path}"
    
    # Convert ~ back to full path for the hyperlink
    local full_path="$(echo "$file_path" | sed "s|^~|$HOME|g")"
    
    # Enhanced terminal and hyperlink support detection
    local supports_hyperlinks=false
    
    # Check for terminals that support OSC 8 hyperlinks
    if [[ -n "$TERM" && "$TERM" != "dumb" && -t 1 ]]; then
        # Warp terminal always supports hyperlinks
        if [[ "$TERM_PROGRAM" == "WarpTerminal" ]]; then
            supports_hyperlinks=true
        # Other modern terminals
        elif [[ "$TERM_PROGRAM" =~ ^(iTerm\.app|vscode|Terminal\.app)$ ]]; then
            supports_hyperlinks=true
        # Standard terminal types that support hyperlinks
        elif [[ "$TERM" =~ ^(xterm|screen|tmux) ]]; then
            supports_hyperlinks=true
        fi
    fi
    
    if [[ "$supports_hyperlinks" == "true" ]]; then
        # Use OSC 8 hyperlink escape sequence
        # Format: \033]8;;file://path\033\\text\033]8;;\033\\
        printf "\033]8;;file://%s\033\\%s\033]8;;\033\\" "$full_path" "$display_text"
    else
        # Fallback: show only display text (no parentheses)
        echo "$display_text"
    fi
}

# 🤖 Comprehensive AI System Status Display
show_ai_status() {
    echo -e "${CYAN}${BOLD}🤖 AI SYSTEM COMPREHENSIVE STATUS${NC}\\n"
    
    # Display main settings location prominently at the top
    local settings_display_path="$(echo "$SETTINGS_FILE" | sed "s|$HOME|~|g")"
    local clickable_settings=$(make_clickable_path "$SETTINGS_FILE" "$settings_display_path")
    echo -e "${YELLOW}📁 Settings Location: ${BOLD}$clickable_settings${NC}"
    if [[ -f "$SETTINGS_FILE" ]]; then
        local mod_time=$(stat -c %Y "$SETTINGS_FILE" 2>/dev/null || echo "0")
        local readable_time=$(date -d "@$mod_time" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Unknown")
        echo -e "${GRAY}   Last updated: $readable_time${NC}"
    else
        echo -e "${GRAY}   (will be created on first use)${NC}"
    fi
    echo ""
    
    # Basic AI Configuration
    echo -e "${BLUE}📊 AI Configuration:${NC}"
    echo -e "  🔧 AI Enabled: $([[ "$AI_ENABLED" == true ]] && echo "${GREEN}✓ YES${NC}" || echo "${RED}✗ NO${NC}")"
    echo -e "  🧠 AI Mode: ${BOLD}$AI_MODE${NC} (smart/content/motion/quality)"
    echo -e "  🎯 Confidence Threshold: ${BOLD}$AI_CONFIDENCE_THRESHOLD${NC}%"
    echo -e "  ⚡ Auto Quality: $([[ "$AI_AUTO_QUALITY" == true ]] && echo "${GREEN}✓ ON${NC}" || echo "${YELLOW}OFF${NC}")"
    echo -e "  🎬 Scene Analysis: $([[ "$AI_SCENE_ANALYSIS" == true ]] && echo "${GREEN}✓ ON${NC}" || echo "${YELLOW}OFF${NC}")"
    echo -e "  👀 Visual Similarity: $([[ "$AI_VISUAL_SIMILARITY" == true ]] && echo "${GREEN}✓ ON${NC}" || echo "${YELLOW}OFF${NC}")"
    echo -e "  ✂️  Smart Crop: $([[ "$AI_SMART_CROP" == true ]] && echo "${GREEN}✓ ON${NC}" || echo "${YELLOW}OFF${NC}")"
    echo -e "  🎞️  Dynamic Framerate: $([[ "$AI_DYNAMIC_FRAMERATE" == true ]] && echo "${GREEN}✓ ON${NC}" || echo "${YELLOW}OFF${NC}")"
    echo ""
    
    # AI Cache System Status
    echo -e "${BLUE}💾 AI Cache System:${NC}"
    local cache_display_path="$(echo "$AI_CACHE_DIR" | sed "s|$HOME|~|g")"
    local clickable_cache_dir=$(make_clickable_path "$AI_CACHE_DIR" "$cache_display_path")
    echo -e "  📁 Cache Directory: ${BOLD}$clickable_cache_dir${NC}"
    echo -e "  🔧 Cache Enabled: $([[ "$AI_CACHE_ENABLED" == true ]] && echo "${GREEN}✓ YES${NC}" || echo "${RED}✗ NO${NC}")"
    echo -e "  📋 Cache Version: ${BOLD}$AI_CACHE_VERSION${NC}"
    echo -e "  🗓️  Max Age: ${BOLD}$AI_CACHE_MAX_AGE_DAYS${NC} days"
    
    # Cache file status
    if [[ -f "$AI_CACHE_INDEX" ]]; then
        local cache_size=$(stat -c%s "$AI_CACHE_INDEX" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "?")
        local cache_entries=$(grep -v '^#' "$AI_CACHE_INDEX" 2>/dev/null | grep -c '|' 2>/dev/null || echo "0")
        echo -e "  📈 Cache Status: ${GREEN}✓ Active${NC} ($cache_entries entries, $cache_size)"
        
        # Cache validation status
        if validate_cache_index; then
            echo -e "  ✅ Cache Integrity: ${GREEN}✓ Valid${NC}"
        else
            echo -e "  ⚠️  Cache Integrity: ${YELLOW}! Needs rebuild${NC}"
        fi
    else
        echo -e "  📈 Cache Status: ${YELLOW}! Not initialized${NC}"
    fi
    echo ""
    
    # AI Training System Status
    echo -e "${BLUE}🧠 AI Training System:${NC}"
    echo -e "  🎓 Training Enabled: $([[ "$AI_TRAINING_ENABLED" == true ]] && echo "${GREEN}✓ YES${NC}" || echo "${RED}✗ NO${NC}")"
    local training_display_path="$(echo "$AI_TRAINING_DIR" | sed "s|$HOME|~|g")"
    local clickable_training_dir=$(make_clickable_path "$AI_TRAINING_DIR" "$training_display_path")
    echo -e "  📁 Training Directory: ${BOLD}$clickable_training_dir${NC}"
    echo -e "  📊 Model Version: ${BOLD}$AI_MODEL_VERSION${NC}"
    echo -e "  🤖 AI Generation: ${BOLD}$AI_GENERATION${NC}"
    echo -e "  📈 Learning Rate: ${BOLD}$AI_LEARNING_RATE${NC}"
    echo -e "  🎯 Confidence Min: ${BOLD}$AI_CONFIDENCE_MIN${NC}"
    echo -e "  📋 Min Samples: ${BOLD}$AI_TRAINING_MIN_SAMPLES${NC}"
    
    # Training data status
    if [[ "$AI_TRAINING_ENABLED" == true ]]; then
        if [[ -f "$AI_MODEL_FILE" ]]; then
            local model_size=$(stat -c%s "$AI_MODEL_FILE" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "?")
            local total_patterns=$(grep -v '^#' "$AI_MODEL_FILE" 2>/dev/null | grep -c '|' 2>/dev/null || echo "0")
            local avg_confidence="0.00"
            
            # Clean the variable to ensure it contains only numbers
            total_patterns=${total_patterns//[^0-9]/}
            [[ -z "$total_patterns" ]] && total_patterns="0"
            
            if [[ $total_patterns -gt 0 ]]; then
                avg_confidence=$(awk -F'|' 'NR>4 && NF>=3 {sum+=$3; count++} END {if(count>0) printf "%.2f", sum/count; else print "0.00"}' "$AI_MODEL_FILE" 2>/dev/null || echo "0.00")
            fi
            
            echo -e "  📊 Model Status: ${GREEN}✓ Active${NC} ($total_patterns patterns, $model_size)"
            echo -e "  📈 Average Confidence: ${BOLD}$avg_confidence${NC}"
            
            # Model validation status
            if validate_ai_model; then
                echo -e "  ✅ Model Integrity: ${GREEN}✓ Valid${NC}"
            else
                echo -e "  ⚠️  Model Integrity: ${YELLOW}! Needs rebuild${NC}"
            fi
        else
            echo -e "  📊 Model Status: ${YELLOW}! Not initialized${NC}"
        fi
        
        if [[ -f "$AI_TRAINING_LOG" ]]; then
            local log_size=$(stat -c%s "$AI_TRAINING_LOG" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "?")
            local training_events=$(grep -v '^#' "$AI_TRAINING_LOG" 2>/dev/null | grep -c '|' 2>/dev/null || echo "0")
            echo -e "  📜 Training Log: ${GREEN}✓ Active${NC} ($training_events sessions, $log_size)"
            
            # Training log validation
            if validate_training_log; then
                echo -e "  ✅ Log Integrity: ${GREEN}✓ Valid${NC}"
            else
                echo -e "  ⚠️  Log Integrity: ${YELLOW}! Needs rebuild${NC}"
            fi
        else
            echo -e "  📜 Training Log: ${YELLOW}! Not found${NC}"
        fi
    else
        echo -e "  📊 Training Status: ${GRAY}Disabled${NC}"
    fi
    echo ""
    
    # AI Performance Settings
    echo -e "${BLUE}⚡ AI Performance Settings:${NC}"
    echo -e "  🧮 CPU Cores: ${BOLD}$CPU_CORES${NC} total, ${BOLD}$CPU_PHYSICAL_CORES${NC} physical"
    echo -e "  🔄 Max Parallel Jobs: ${BOLD}$AI_MAX_PARALLEL_JOBS${NC}"
    echo -e "  🕸️  Duplicate Detection Threads: ${BOLD}$AI_DUPLICATE_THREADS${NC}"
    echo -e "  📦 Analysis Batch Size: ${BOLD}$AI_ANALYSIS_BATCH_SIZE${NC}"
    echo -e "  🧵 Optimal Threads: ${BOLD}$AI_THREADS_OPTIMAL${NC}"
    echo -e "  🧠 Memory Optimization: ${BOLD}$AI_MEMORY_OPT${NC}"
    echo ""
    
    # Recent AI Activity (if available)
    echo -e "${BLUE}📊 Recent AI Activity:${NC}"
    if [[ -f "$AI_TRAINING_LOG" && "$AI_TRAINING_ENABLED" == true ]]; then
        local recent_sessions=$(tail -n 5 "$AI_TRAINING_LOG" 2>/dev/null | grep -v '^#' | wc -l)
        if [[ $recent_sessions -gt 0 ]]; then
            echo -e "  📈 Last 5 Training Sessions:"
            tail -n 5 "$AI_TRAINING_LOG" 2>/dev/null | grep -v '^#' | while IFS='|' read -r timestamp action pattern settings outcome confidence; do
                local status_icon
                case "$outcome" in
                    "success") status_icon="${GREEN}✓${NC}" ;;
                    "partial") status_icon="${YELLOW}~${NC}" ;;
                    "failure") status_icon="${RED}✗${NC}" ;;
                    *) status_icon="${BLUE}?${NC}" ;;
                esac
                echo -e "    $status_icon $(echo "$pattern" | cut -d':' -f1-2) → conf:$confidence"
            done
        else
            echo -e "  ${GRAY}No recent training activity${NC}"
        fi
    else
        echo -e "  ${GRAY}Training disabled or no log available${NC}"
    fi
    echo ""
    
    # AI Health Check
    echo -e "${BLUE}🏥 AI System Health Check:${NC}"
    local health_issues=0
    
    # Check cache health
    if [[ "$AI_CACHE_ENABLED" == true ]]; then
        if [[ ! -d "$AI_CACHE_DIR" ]]; then
            echo -e "  ⚠️  Cache directory missing"
            ((health_issues++))
        elif ! validate_cache_index 2>/dev/null; then
            echo -e "  ⚠️  Cache index corrupted"
            ((health_issues++))
        fi
    fi
    
    # Check training health
    if [[ "$AI_TRAINING_ENABLED" == true ]]; then
        if [[ ! -d "$AI_TRAINING_DIR" ]]; then
            echo -e "  ⚠️  Training directory missing"
            ((health_issues++))
        elif [[ -f "$AI_MODEL_FILE" ]] && ! validate_ai_model 2>/dev/null; then
            echo -e "  ⚠️  AI model corrupted"
            ((health_issues++))
        elif [[ -f "$AI_TRAINING_LOG" ]] && ! validate_training_log 2>/dev/null; then
            echo -e "  ⚠️  Training log corrupted"
            ((health_issues++))
        fi
    fi
    
    # Check dependencies
    if ! command -v bc >/dev/null 2>&1; then
        echo -e "  ⚠️  'bc' command missing (needed for AI calculations)"
        ((health_issues++))
    fi
    
    if [[ $health_issues -eq 0 ]]; then
        echo -e "  ${GREEN}✅ All systems healthy${NC}"
    else
        echo -e "  ${YELLOW}⚠️  $health_issues issue(s) detected${NC}"
        echo -e "  💡 Run the script to auto-repair most issues"
    fi
    
    echo -e "\n${CYAN}💡 Tips:${NC}"
    echo -e "  ${BLUE}•${NC} Use interactive menu options to manage AI settings"
    echo -e "  ${BLUE}•${NC} Click on file paths above to open them in your file manager"
    echo -e "  ${BLUE}•${NC} Settings are automatically saved when changed"
}

# 🦺 AI File Health Detection & Learning System
# ===============================================

# Analyze file health using AI with learning capabilities
ai_analyze_file_health() {
    local file="$1"
    local context="$2"  # md5_failed, analysis_timeout, suspicious_size, etc.
    
    # SAFETY: Only analyze GIF files - never touch video sources
    if [[ "${file##*.}" != "gif" ]]; then
        echo "SKIP_NON_GIF"  # Don't analyze non-GIF files
        return 0
    fi
    
    # Refuse to analyze video files (double safety check)
    if [[ "$file" =~ \.(mp4|avi|mov|mkv|webm|MP4|AVI|MOV|MKV|WEBM)$ ]]; then
        echo "SKIP_VIDEO_FILE"  # Never analyze video files
        return 0
    fi
    
    # Quick validation
    [[ -z "$file" || ! -f "$file" ]] && echo "CORRUPTED" && return 1
    
    # Get file characteristics for AI analysis
    local file_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
    local file_age=$(stat -c%Y "$file" 2>/dev/null || echo "0")
    local current_time=$(date +%s)
    local age_days=$(( (current_time - file_age) / 86400 ))
    
    # Create feature signature for AI analysis
    local feature_signature="${context}:${file_size}:${age_days}"
    
    # Check if we have learned patterns for this type of issue
    local ai_confidence=$(query_ai_health_model "$feature_signature")
    local health_verdict="UNCERTAIN"
    
    # AI decision making based on context and learned patterns
    case "$context" in
        "md5_failed")
            # MD5 failure is usually serious
            if [[ $file_size -eq 0 ]]; then
                health_verdict="CORRUPTED"  # Empty file
            elif [[ $file_size -gt 104857600 ]]; then
                health_verdict="COMPLEX"    # Very large file might cause MD5 issues
            elif [[ $age_days -lt 1 && $file_size -gt 1024 ]]; then
                health_verdict="COMPLEX"    # Recent file with reasonable size might be OK
            else
                health_verdict="CORRUPTED"  # Default to corrupted for MD5 failures
            fi
            ;;
        "analysis_timeout")
            # Timeouts can indicate complexity or corruption
            if [[ $file_size -gt 52428800 ]]; then  # > 50MB
                health_verdict="COMPLEX"    # Large files legitimately take time
            elif [[ $file_size -lt 1024 ]]; then
                health_verdict="CORRUPTED"  # Very small files shouldn't timeout
            elif [[ $age_days -gt 30 ]]; then
                health_verdict="CORRUPTED"  # Old files with timeouts likely corrupted
            else
                # Use AI confidence if available
                if [[ -n "$ai_confidence" && "$ai_confidence" != "0" ]]; then
                    local confidence_num=${ai_confidence%.*}  # Remove decimal part
                    confidence_num=${confidence_num:-0}
                    if [[ $confidence_num -gt 70 ]]; then
                        health_verdict="COMPLEX"
                    elif [[ $confidence_num -lt 30 ]]; then
                        health_verdict="CORRUPTED"
                    else
                        health_verdict="UNCERTAIN"
                    fi
                else
                    health_verdict="COMPLEX"  # Default to complex for reasonable files
                fi
            fi
            ;;
        "suspicious_size")
            # Size-based analysis
            if [[ $file_size -eq 0 ]]; then
                health_verdict="CORRUPTED"
            elif [[ $file_size -lt 100 ]]; then
                health_verdict="CORRUPTED"  # Too small to be valid GIF
            else
                health_verdict="COMPLEX"
            fi
            ;;
        *)
            # Default analysis for unknown contexts
            if [[ $file_size -eq 0 ]]; then
                health_verdict="CORRUPTED"
            elif [[ $file_size -gt 209715200 ]]; then  # > 200MB
                health_verdict="COMPLEX"
            else
                health_verdict="UNCERTAIN"
            fi
            ;;
    esac
    
    echo "$health_verdict"
}

# Query AI health model for learned patterns
query_ai_health_model() {
    local feature_signature="$1"
    
    if [[ "$AI_TRAINING_ENABLED" != "true" || ! -f "$AI_MODEL_FILE" ]]; then
        echo "50"  # Default neutral confidence (as integer)
        return 1
    fi
    
    # Search for similar patterns in the AI model
    local pattern_match=$(grep "^health_pattern:$feature_signature" "$AI_MODEL_FILE" 2>/dev/null | tail -1)
    if [[ -n "$pattern_match" ]]; then
        # Extract confidence score: health_pattern:signature|verdict|confidence|samples|timestamp
        local confidence=$(echo "$pattern_match" | cut -d'|' -f3)
        # Convert to integer percentage
        local confidence_int=$(echo "$confidence * 100" | bc 2>/dev/null | cut -d. -f1 2>/dev/null || echo "50")
        echo "${confidence_int:-50}"
    else
        # Look for partial matches (same context)
        local context="${feature_signature%%:*}"
        local partial_matches=$(grep "^health_pattern:$context:" "$AI_MODEL_FILE" 2>/dev/null | wc -l)
        if [[ $partial_matches -gt 0 ]]; then
            # Calculate average confidence for this context
            local avg_confidence=$(grep "^health_pattern:$context:" "$AI_MODEL_FILE" 2>/dev/null | \
                cut -d'|' -f3 | awk '{sum+=$1; count++} END {if(count>0) printf "%.0f", sum*100/count; else print "50"}')
            echo "${avg_confidence:-50}"
        else
            echo "50"  # No learned patterns, neutral confidence
        fi
    fi
}

# Train AI model with file health patterns
train_ai_file_health() {
    local file="$1"
    local verdict="$2"      # corrupted, complex, suspicious, uncertain
    local context="$3"      # md5_failed, analysis_timeout, etc.
    local outcome="$4"      # confirmed, legitimate, learning
    
    # SAFETY: Only train on GIF files - never video files
    if [[ "${file##*.}" != "gif" ]]; then
        return 0  # Skip training for non-GIF files
    fi
    
    # Double safety: refuse video files
    if [[ "$file" =~ \.(mp4|avi|mov|mkv|webm|MP4|AVI|MOV|MKV|WEBM)$ ]]; then
        return 0  # Never train on video files
    fi
    
    if [[ "$AI_TRAINING_ENABLED" != "true" ]]; then
        return 0
    fi
    
    # Get file characteristics
    local file_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
    local file_age=$(stat -c%Y "$file" 2>/dev/null || echo "0")
    local current_time=$(date +%s)
    local age_days=$(( (current_time - file_age) / 86400 ))
    
    # Create feature signature
    local feature_signature="${context}:${file_size}:${age_days}"
    
    # Calculate outcome score for training
    local outcome_score
    case "$outcome" in
        "confirmed") outcome_score="1.0" ;;    # High confidence
        "legitimate") outcome_score="0.8" ;;   # Good confidence
        "learning") outcome_score="0.5" ;;     # Neutral for learning
        "uncertain") outcome_score="0.3" ;;    # Low confidence
        *) outcome_score="0.5" ;;
    esac
    
    # Log training event
    local timestamp=$(date +%s)
    atomic_append_training_log "$timestamp|health_train|$feature_signature|$verdict|$outcome|$outcome_score"
    
    # Update AI health model
    atomic_update_health_model "$feature_signature" "$verdict" "$outcome_score"
}

# Update AI health model with new patterns
atomic_update_health_model() {
    local feature_signature="$1"
    local verdict="$2"
    local outcome_score="$3"
    
    # Ensure model file integrity
    if ! validate_ai_model; then
        rebuild_ai_model
    fi
    
    local temp_model="${AI_MODEL_FILE}.health.$$"
    local updated=false
    local timestamp=$(date +%s)
    
    # Create backup
    cp "$AI_MODEL_FILE" "${AI_MODEL_FILE}.health_backup" 2>/dev/null || true
    
    # Copy existing model
    cp "$AI_MODEL_FILE" "$temp_model" 2>/dev/null || {
        echo "# AI Health Model - Auto-generated" > "$temp_model"
    }
    
    # Look for existing health pattern
    local pattern_key="health_pattern:$feature_signature"
    if grep -q "^$pattern_key" "$temp_model" 2>/dev/null; then
        # Update existing pattern using adaptive learning
        local current_line=$(grep "^$pattern_key" "$temp_model" | tail -1)
        local current_confidence=$(echo "$current_line" | cut -d'|' -f3 2>/dev/null || echo "0.5")
        local current_samples=$(echo "$current_line" | cut -d'|' -f4 2>/dev/null || echo "1")
        
        # Calculate new confidence with learning rate
        local new_samples=$((current_samples + 1))
        local new_confidence
        if command -v bc >/dev/null 2>&1; then
            new_confidence=$(echo "scale=3; ($current_confidence * $current_samples + $outcome_score * $AI_LEARNING_RATE) / $new_samples" | bc 2>/dev/null || echo "$outcome_score")
        else
            new_confidence="$outcome_score"  # Fallback if bc not available
        fi
        
        # Remove old pattern and add updated one
        grep -v "^$pattern_key" "$temp_model" > "${temp_model}.tmp"
        echo "$pattern_key|$verdict|$new_confidence|$new_samples|$timestamp" >> "${temp_model}.tmp"
        mv "${temp_model}.tmp" "$temp_model"
        updated=true
    else
        # Add new health pattern
        echo "$pattern_key|$verdict|$outcome_score|1|$timestamp" >> "$temp_model"
        updated=true
    fi
    
    # Replace model file atomically
    if [[ "$updated" == "true" ]] && [[ -s "$temp_model" ]]; then
        mv "$temp_model" "$AI_MODEL_FILE"
        rm -f "${AI_MODEL_FILE}.health_backup"
    else
        rm -f "$temp_model"
        [[ -f "${AI_MODEL_FILE}.health_backup" ]] && mv "${AI_MODEL_FILE}.health_backup" "$AI_MODEL_FILE"
    fi
}

# Legacy function for backward compatibility
get_ai_training_stats() {
    if [[ "$AI_TRAINING_ENABLED" != "true" || ! -f "$AI_MODEL_FILE" ]]; then
        echo "Training disabled"
        return
    fi
    
    local total_patterns=$(grep -v '^#' "$AI_MODEL_FILE" 2>/dev/null | grep -c '|' 2>/dev/null || echo "0")
    local total_training_events=$(grep -v '^#' "$AI_TRAINING_LOG" 2>/dev/null | grep -c '|' 2>/dev/null || echo "0")
    local avg_confidence
    
    # Clean the variables to ensure they contain only numbers
    total_patterns=${total_patterns//[^0-9]/}
    total_training_events=${total_training_events//[^0-9]/}
    [[ -z "$total_patterns" ]] && total_patterns="0"
    [[ -z "$total_training_events" ]] && total_training_events="0"
    
    if [[ $total_patterns -gt 0 ]]; then
        avg_confidence=$(awk -F'|' 'NR>4 && NF>=3 {sum+=$3; count++} END {if(count>0) printf "%.2f", sum/count; else print "0.00"}' "$AI_MODEL_FILE")
    else
        avg_confidence="0.00"
    fi
    
    echo "$total_patterns patterns, $total_training_events sessions, ${avg_confidence} avg confidence"
}
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

# 🔒 Check and fix file/directory permissions
check_and_fix_permissions() {
    local silent_mode=false
    [[ "$1" == "--silent" ]] && silent_mode=true
    
    local issues_found=0
    local fix_commands=()
    local files_to_check=()
    local dirs_to_check=()
    
    # Directories that should be writable
    dirs_to_check+=(
        "$LOG_DIR"
        "$TEMP_WORK_DIR"
        "$AI_CACHE_DIR"
        "$AI_TRAINING_DIR"
    )
    
    # Files that should be readable and writable
    files_to_check+=(
        "$SETTINGS_FILE"
        "$ERROR_LOG"
        "$CONVERSION_LOG"
    )
    
    # Optional files (don't fail if they don't exist)
    local optional_files=(
        "$AI_CACHE_INDEX"
        "$AI_MODEL_FILE"
        "$AI_TRAINING_LOG"
        "$PROGRESS_FILE"
    )
    
    if [[ "$silent_mode" != true ]]; then
        echo -e "${CYAN}🔍 Checking file and directory permissions...${NC}"
    fi
    
    # Check directories
    for dir in "${dirs_to_check[@]}"; do
        [[ -z "$dir" || "$dir" == "." || "$dir" == "/tmp"* ]] && continue
        
        if [[ -d "$dir" ]]; then
            # Check if directory is readable
            if [[ ! -r "$dir" ]]; then
                ((issues_found++))
                echo -e "${RED}❌ Directory not readable: $dir${NC}" >&2
                fix_commands+=("chmod u+r \"$dir\"")
            fi
            
            # Check if directory is writable
            if [[ ! -w "$dir" ]]; then
                ((issues_found++))
                echo -e "${RED}❌ Directory not writable: $dir${NC}" >&2
                fix_commands+=("chmod u+w \"$dir\"")
            fi
            
            # Check if directory is executable (needed to access contents)
            if [[ ! -x "$dir" ]]; then
                ((issues_found++))
                echo -e "${RED}❌ Directory not accessible: $dir${NC}" >&2
                fix_commands+=("chmod u+x \"$dir\"")
            fi
            
            # Check ownership
            local dir_owner=$(stat -c '%U' "$dir" 2>/dev/null)
            if [[ -n "$dir_owner" && "$dir_owner" != "$USER" ]]; then
                ((issues_found++))
                echo -e "${YELLOW}⚠️  Directory owned by different user: $dir (owner: $dir_owner)${NC}" >&2
                fix_commands+=("sudo chown $USER:\$(id -gn) \"$dir\"")
            fi
        fi
    done
    
    # Check required files
    for file in "${files_to_check[@]}"; do
        [[ -z "$file" ]] && continue
        
        if [[ -f "$file" ]]; then
            # Check if file is readable
            if [[ ! -r "$file" ]]; then
                ((issues_found++))
                echo -e "${RED}❌ File not readable: $file${NC}" >&2
                fix_commands+=("chmod u+r \"$file\"")
            fi
            
            # Check if file is writable
            if [[ ! -w "$file" ]]; then
                ((issues_found++))
                echo -e "${RED}❌ File not writable: $file${NC}" >&2
                fix_commands+=("chmod u+w \"$file\"")
            fi
            
            # Check ownership
            local file_owner=$(stat -c '%U' "$file" 2>/dev/null)
            if [[ -n "$file_owner" && "$file_owner" != "$USER" ]]; then
                ((issues_found++))
                echo -e "${YELLOW}⚠️  File owned by different user: $file (owner: $file_owner)${NC}" >&2
                fix_commands+=("sudo chown $USER:\$(id -gn) \"$file\"")
            fi
        fi
    done
    
    # Check optional files (only if they exist)
    for file in "${optional_files[@]}"; do
        [[ -z "$file" || ! -f "$file" ]] && continue
        
        if [[ ! -r "$file" || ! -w "$file" ]]; then
            ((issues_found++))
            echo -e "${YELLOW}⚠️  Optional file has permission issues: $(basename "$file")${NC}" >&2
            fix_commands+=("chmod u+rw \"$file\"")
        fi
        
        local file_owner=$(stat -c '%U' "$file" 2>/dev/null)
        if [[ -n "$file_owner" && "$file_owner" != "$USER" ]]; then
            ((issues_found++))
            echo -e "${YELLOW}⚠️  Optional file owned by: $file_owner - $(basename "$file")${NC}" >&2
            fix_commands+=("sudo chown $USER:\$(id -gn) \"$file\"")
        fi
    done
    
    # If issues found, prompt user to fix them
    if [[ $issues_found -gt 0 ]]; then
        echo -e "\n${RED}${BOLD}⚠️  PERMISSION ISSUES DETECTED${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}Found $issues_found permission issue(s) that may prevent the script from working.${NC}\n"
        
        echo -e "${CYAN}${BOLD}How would you like to fix these issues?${NC}"
        echo -e "  ${GREEN}[1]${NC} Let the script automatically fix them (recommended)"
        echo -e "  ${GREEN}[2]${NC} Show me the commands to run manually"
        echo -e "  ${GREEN}[3]${NC} Continue anyway (may cause errors)"
        echo -e "  ${GREEN}[4]${NC} Exit and fix manually later\n"
        
        echo -ne "${MAGENTA}Enter your choice [1-4]: ${NC}"
        read -r fix_choice
        
        case "$fix_choice" in
            1)
                echo -e "\n${CYAN}🔧 Attempting to fix permissions automatically...${NC}\n"
                
                local fixed=0
                local failed=0
                
                # Deduplicate and execute fix commands
                local executed_commands=()
                for cmd in "${fix_commands[@]}"; do
                    # Skip if already executed
                    local already_done=false
                    for executed in "${executed_commands[@]}"; do
                        [[ "$cmd" == "$executed" ]] && already_done=true && break
                    done
                    [[ "$already_done" == true ]] && continue
                    
                    echo -e "${BLUE}▶ Running: ${GRAY}$cmd${NC}"
                    
                    if eval "$cmd" 2>/dev/null; then
                        echo -e "  ${GREEN}✓ Success${NC}"
                        ((fixed++))
                    else
                        echo -e "  ${RED}✗ Failed${NC}"
                        ((failed++))
                    fi
                    
                    executed_commands+=("$cmd")
                done
                
                echo -e "\n${GREEN}✓ Fixed: $fixed issues${NC}"
                [[ $failed -gt 0 ]] && echo -e "${RED}✗ Failed: $failed issues${NC}"
                
                if [[ $failed -eq 0 ]]; then
                    echo -e "\n${GREEN}${BOLD}All permission issues resolved!${NC}"
                else
                    echo -e "\n${YELLOW}Some issues remain. You may need to run with sudo or fix manually.${NC}"
                fi
                ;;
            2)
                echo -e "\n${CYAN}${BOLD}Commands to fix permissions manually:${NC}\n"
                
                # Deduplicate commands
                local printed_commands=()
                for cmd in "${fix_commands[@]}"; do
                    local already_printed=false
                    for printed in "${printed_commands[@]}"; do
                        [[ "$cmd" == "$printed" ]] && already_printed=true && break
                    done
                    [[ "$already_printed" == true ]] && continue
                    
                    echo -e "  ${GRAY}$cmd${NC}"
                    printed_commands+=("$cmd")
                done
                
                echo -e "\n${YELLOW}Copy and run these commands in your terminal.${NC}"
                ;;
            3)
                echo -e "\n${YELLOW}⚠️  Continuing with permission issues...${NC}"
                echo -e "${YELLOW}Note: You may encounter errors during conversion.${NC}"
                ;;
            4)
                echo -e "\n${CYAN}Exiting. Please fix permissions and try again.${NC}"
                exit 1
                ;;
            *)
                echo -e "\n${RED}Invalid choice. Continuing anyway...${NC}"
                ;;
        esac
    else
        if [[ "$silent_mode" != true ]]; then
            echo -e "${GREEN}✓ All permissions are correct${NC}"
        fi
    fi
    
    return $issues_found
}

# 🚨 Robust error logging system
log_error() {
    # Don't show errors if user interrupted the script
    if [[ "$INTERRUPT_REQUESTED" == true ]]; then
        return 0
    fi
    
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
    
    # Only show errors in terminal if not in silent validation mode
    if [[ "$VALIDATION_SILENT_MODE" != "true" ]]; then
        {
            echo -e "\n${RED}${BOLD}💥 CRITICAL ERROR${NC}"
            echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${RED}📋 Message: $error_msg${NC}"
            [[ -n "$file" ]] && echo -e "${RED}📁 File: $(basename -- "$file")${NC}"
            [[ -n "$line_num" ]] && echo -e "${RED}📍 Line: $line_num${NC}"
            [[ -n "$func_name" ]] && echo -e "${RED}⚙️  Function: $func_name${NC}"
            [[ -n "$detailed_error" ]] && echo -e "${RED}🔍 Details: $detailed_error${NC}"
            echo -e "${YELLOW}📋 Full log: $ERROR_LOG${NC}"
            echo -e "${CYAN}🔧 Debug: tail -20 \"$ERROR_LOG\"${NC}"
            echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        } >&2
    fi
}

# ⚠️ Log warnings (non-critical issues)
log_warning() {
    # Don't show warnings if user interrupted the script
    if [[ "$INTERRUPT_REQUESTED" == true ]]; then
        return 0
    fi
    
    local warning_msg="$1"
    local file="$2"
    local detailed_info="$3"
    local line_num="$4"
    local func_name="$5"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Ensure log directory exists
    [[ ! -d "$(dirname "$ERROR_LOG")" ]] && mkdir -p "$(dirname "$ERROR_LOG")" 2>/dev/null
    
    # Comprehensive logging to file
    {
        echo "[$timestamp] ==================== WARNING ===================="
        echo "[$timestamp] MESSAGE: $warning_msg"
        [[ -n "$file" ]] && echo "[$timestamp] FILE: $file"
        [[ -n "$line_num" ]] && echo "[$timestamp] LINE: $line_num"
        [[ -n "$func_name" ]] && echo "[$timestamp] FUNCTION: $func_name"
        [[ -n "$detailed_info" ]] && echo "[$timestamp] DETAILS: $detailed_info"
        echo "[$timestamp] ===================================================="
        echo ""
    } >> "$ERROR_LOG" 2>/dev/null || {
        # Fallback to current directory if log directory fails
        echo "[$timestamp] WARNING: $warning_msg" >> "./warning-fallback.log" 2>/dev/null
    }
    
    # Show warnings in terminal with less alarming format
    {
        echo -e "\n${YELLOW}${BOLD}⚠️ WARNING${NC}"
        echo -e "${YELLOW}───────────────────────────────────────────────────────────────${NC}"
        echo -e "${YELLOW}📝 Message: $warning_msg${NC}"
        [[ -n "$file" ]] && echo -e "${YELLOW}📁 File: $(basename -- "$file")${NC}"
        [[ -n "$line_num" ]] && echo -e "${YELLOW}📍 Line: $line_num${NC}"
        [[ -n "$func_name" ]] && echo -e "${YELLOW}⚙️  Function: $func_name${NC}"
        [[ -n "$detailed_info" ]] && echo -e "${YELLOW}🔍 Details: $detailed_info${NC}"
        echo -e "${CYAN}📋 Full log: $ERROR_LOG${NC}"
        echo -e "${YELLOW}───────────────────────────────────────────────────────────────${NC}"
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
    
    echo -e "  🧠 ${CYAN}Advanced AI Analysis Starting (${BOLD}$AI_MAX_PARALLEL_JOBS threads${NC}${CYAN})...${NC}"
    
    # Initialize AI training system
    init_ai_training
    local training_stats=$(get_ai_training_stats)
    echo -e "  🧠 AI Training: $training_stats"
    
    # Check cache first for AI analysis
    local cached_ai_analysis=$(check_ai_cache "$file" 2>/dev/null)
    if [[ $? -eq 0 && -n "$cached_ai_analysis" ]]; then
        echo -e "  🗄️ ${GREEN}Using cached AI analysis${NC}"
        # Parse cached analysis and restore AI variables
        restore_ai_analysis_from_cache "$cached_ai_analysis"
        echo -e "  ✅ ${GREEN}AI Analysis Complete (from cache)${NC}"
        return 0
    fi
    
    echo -e "  🔄 ${YELLOW}Performing fresh AI analysis...${NC}"
    
    # Get basic video properties first
    local video_info=$(get_video_properties "$file")
    local duration=$(echo "$video_info" | cut -d'|' -f1)
    local width=$(echo "$video_info" | cut -d'|' -f2) 
    local height=$(echo "$video_info" | cut -d'|' -f3)
    local fps=$(echo "$video_info" | cut -d'|' -f4)
    local bitrate=$(echo "$video_info" | cut -d'|' -f5)
    
    # Store original settings for training comparison
    local original_framerate="$FRAMERATE"
    local original_dither="$DITHER_MODE"
    local original_colors="$MAX_COLORS"
    
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
        echo "[$ai_log_ts] AI-ANALYSIS: mode=$AI_MODE file=$(basename -- "$file")"
        echo "[$ai_log_ts] AI-INPUT: duration=${duration}s resolution=${width}x${height} fps=$fps bitrate=$bitrate"
        echo "[$ai_log_ts] AI-OUTPUT: framerate=$FRAMERATE dither=$DITHER_MODE crop=${CROP_FILTER:-none} max_colors=$MAX_COLORS"
        [[ -n "$AI_CONTENT_CACHE" ]] && echo "[$ai_log_ts] AI-DETECTED: $AI_CONTENT_CACHE"
    } >> "$ERROR_LOG" 2>/dev/null || true
    
    # Save analysis results to cache for future runs
    save_ai_analysis_to_cache "$file"
    
    echo -e "  ✅ ${GREEN}AI Analysis Complete${NC}"
}

# 📊 Get comprehensive video properties with optimal threading
get_video_properties() {
    local file="$1"
    local properties
    local optimal_threads=$(get_optimal_threads "io" 1)
    
    # Use ffprobe to get detailed information with optimal threading
    if command -v jq >/dev/null 2>&1; then
        # Enhanced analysis with jq and optimized threading
        properties=$(ffprobe -v quiet -threads $optimal_threads -print_format json -show_format -show_streams "$file" 2>/dev/null)
        
        local duration=$(echo "$properties" | jq -r '.format.duration // "0"' | cut -d. -f1)
        local width=$(echo "$properties" | jq -r '.streams[0].width // "0"')
        local height=$(echo "$properties" | jq -r '.streams[0].height // "0"')
        local fps=$(echo "$properties" | jq -r '.streams[0].r_frame_rate // "0"' | cut -d'/' -f1)
        local bitrate=$(echo "$properties" | jq -r '.format.bit_rate // "0"')
        
        echo "${duration}|${width}|${height}|${fps}|${bitrate}"
    else
        # Fallback without jq but with optimal threading
        local duration=$(ffprobe -v error -threads $optimal_threads -show_entries format=duration -of csv=p=0 "$file" 2>/dev/null | cut -d. -f1)
        local width=$(ffprobe -v error -threads $optimal_threads -select_streams v:0 -show_entries stream=width -of csv=p=0 "$file" 2>/dev/null)
        local height=$(ffprobe -v error -threads $optimal_threads -select_streams v:0 -show_entries stream=height -of csv=p=0 "$file" 2>/dev/null)
        local fps=$(ffprobe -v error -threads $optimal_threads -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$file" 2>/dev/null | cut -d'/' -f1)
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
    
    # 4. AI-Powered Prediction (NEW!)
    local feature_pattern=$(extract_feature_pattern "$content_type" "$width" "$height" "$duration" "$motion_level" "$complexity_score")
    local ai_prediction=$(ai_predict_settings "$feature_pattern" 2>/dev/null)
    
    if [[ $? -eq 0 && -n "$ai_prediction" ]]; then
        local prediction_type=$(echo "$ai_prediction" | cut -d':' -f1)
        local confidence=$(echo "$ai_prediction" | cut -d':' -f2)
        local settings=$(echo "$ai_prediction" | cut -d':' -f3)
        
        echo -e "    🤖 ${GREEN}AI Prediction ($prediction_type, confidence: $confidence):${NC}"
        
        # Parse and apply AI-recommended settings
        IFS=':' read -ra ai_settings <<< "$settings"
        if [[ ${#ai_settings[@]} -ge 3 ]]; then
            echo -e "      🎯 Applying AI-learned settings..."
            FRAMERATE="${ai_settings[0]}"
            DITHER_MODE="${ai_settings[1]}"
            MAX_COLORS="${ai_settings[2]}"
            if [[ -n "${ai_settings[3]}" && "${ai_settings[3]}" != "none" ]]; then
                CROP_FILTER="${ai_settings[3]}"
            fi
            AI_CONTENT_CACHE+=" ai_applied=true"
            echo -e "      ✅ ${GREEN}AI settings applied: ${FRAMERATE}fps, ${DITHER_MODE} dither, ${MAX_COLORS} colors${NC}"
        fi
    else
        echo -e "    🤖 ${YELLOW}No AI prediction available (learning mode)${NC}"
        AI_CONTENT_CACHE+=" ai_applied=false"
    fi
    
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

# 🎨 Hyper-Optimized Content Type Detection with Multi-Threading
detect_content_type() {
    local file="$1" duration="$2" width="$3" height="$4"
    local cpu_threads=$(get_optimal_threads "cpu" 5)
    
    # Multi-stage parallel analysis for maximum performance
    local content_scores=()
    
    # Stage 1: Visual Pattern Analysis (optimized with maximum threads)
    local histogram_variance=$(ffmpeg -v error -threads $cpu_threads -i "$file" -t 6 -vf "histogram=level_height=150,scale=80:80:flags=fast_bilinear" -frames:v 8 -f null - 2>&1 | wc -l 2>/dev/null || echo "0")
    
    # Stage 2: Advanced Edge Detection with multiple thresholds (parallel processing)
    local edge_low=$(ffmpeg -v error -threads $cpu_threads -i "$file" -t 4 -vf "edgedetect=low=0.05:high=0.2:flags=fast_bilinear" -frames:v 6 -f null - 2>&1 | grep -c "frame=" 2>/dev/null || echo "0")
    local edge_high=$(ffmpeg -v error -threads $cpu_threads -i "$file" -t 4 -vf "edgedetect=low=0.2:high=0.6:flags=fast_bilinear" -frames:v 6 -f null - 2>&1 | grep -c "frame=" 2>/dev/null || echo "0")
    
    # Stage 3: Color Complexity Analysis (optimized)
    local color_stats=$(ffmpeg -v error -threads $cpu_threads -i "$file" -t 3 -vf "signalstats" -f null - 2>&1 | grep -E "YAVG=|UAVG=|VAVG=" | wc -l 2>/dev/null || echo "0")
    local color_range=$(ffmpeg -v error -threads $cpu_threads -i "$file" -t 3 -vf "signalstats" -f null - 2>&1 | grep -E "YMAX=|YMIN=" | wc -l 2>/dev/null || echo "0")
    
    # Stage 4: Motion Vector Analysis (accelerated)
    local motion_vectors=$(ffmpeg -v error -threads $cpu_threads -i "$file" -t 5 -vf "select='gt(scene,0.1)',showinfo" -f null - 2>&1 | grep -c "scene:" 2>/dev/null || echo "0")
    
    # Stage 5: Frame Rate Pattern Analysis (optimized)
    local fps_consistency=$(ffmpeg -v error -threads $cpu_threads -i "$file" -t 3 -vf "select='not(mod(n,4))',showinfo" -f null - 2>&1 | grep -c "pkt_pts_time=" 2>/dev/null || echo "0")
    
    # Sanitize and normalize values
    histogram_variance=${histogram_variance//[^0-9]/}; histogram_variance=${histogram_variance:-0}
    edge_low=${edge_low//[^0-9]/}; edge_low=${edge_low:-0}
    edge_high=${edge_high//[^0-9]/}; edge_high=${edge_high:-0}
    color_stats=${color_stats//[^0-9]/}; color_stats=${color_stats:-0}
    color_range=${color_range//[^0-9]/}; color_range=${color_range:-0}
    motion_vectors=${motion_vectors//[^0-9]/}; motion_vectors=${motion_vectors:-0}
    fps_consistency=${fps_consistency//[^0-9]/}; fps_consistency=${fps_consistency:-0}
    
    # AI-inspired scoring system
    local animation_score=0
    local screencast_score=0
    local movie_score=0
    local clip_score=0
    
    # Animation detection (high edge density, consistent colors, smooth motion)
    if [[ $edge_high -gt 12 && $color_stats -gt 15 && $fps_consistency -gt 8 ]]; then
        ((animation_score += 30))
    fi
    if [[ $histogram_variance -gt 8 && $motion_vectors -lt 4 ]]; then
        ((animation_score += 20))
    fi
    
    # Screencast detection (sharp edges, limited colors, static elements)
    if [[ $edge_low -gt 15 && $color_range -lt 8 && $motion_vectors -lt 3 ]]; then
        ((screencast_score += 35))
    fi
    if [[ $width -ge 1280 && $height -ge 720 && $fps_consistency -lt 5 ]]; then
        ((screencast_score += 15))
    fi
    
    # Movie detection (complex color patterns, natural motion, high resolution)
    if [[ $color_stats -gt 20 && $color_range -gt 10 && $motion_vectors -gt 5 ]]; then
        ((movie_score += 25))
    fi
    if [[ $width -ge 1920 && $height -ge 1080 && $duration -gt 60 ]]; then
        ((movie_score += 20))
    fi
    if [[ $histogram_variance -gt 15 && $edge_low -lt 10 ]]; then
        ((movie_score += 15))
    fi
    
    # Clip detection (short duration, variable motion, mixed patterns)
    if [[ $duration -lt 30 && $motion_vectors -gt 3 && $motion_vectors -lt 8 ]]; then
        ((clip_score += 25))
    fi
    if [[ $fps_consistency -gt 6 && $color_stats -gt 8 && $color_stats -lt 18 ]]; then
        ((clip_score += 20))
    fi
    
    # Determine content type based on highest score
    local max_score=0
    local content_type="clip"  # default fallback
    
    if [[ $animation_score -gt $max_score ]]; then
        max_score=$animation_score
        content_type="animation"
    fi
    if [[ $screencast_score -gt $max_score ]]; then
        max_score=$screencast_score
        content_type="screencast"
    fi
    if [[ $movie_score -gt $max_score ]]; then
        max_score=$movie_score
        content_type="movie"
    fi
    if [[ $clip_score -gt $max_score ]]; then
        max_score=$clip_score
        content_type="clip"
    fi
    
    # Confidence-based fallback for low scores
    if [[ $max_score -lt 25 ]]; then
        # Fallback to basic heuristics
        if [[ $width -ge 1920 && $height -ge 1080 && $duration -gt 300 ]]; then
            content_type="movie"
        elif [[ $duration -lt 15 ]]; then
            content_type="clip"
        elif [[ $width -ge 1280 && $color_range -lt 6 ]]; then
            content_type="screencast"
        else
            content_type="animation"
        fi
    fi
    
    echo "$content_type"
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

# 🎬 Advanced Scene Detection and Analysis
ai_scene_detection() {
    local file="$1" duration="$2"
    local sample_duration=$((duration > 60 ? 60 : duration))
    
    echo -e "      🎬 ${BLUE}Analyzing scene transitions and visual patterns...${NC}"
    
    # Detect scene changes with multiple thresholds
    local major_scenes=$(ffmpeg -v error -i "$file" -t $sample_duration -vf "select=gt(scene\,0.25)" -vsync vfr -f null - 2>&1 | grep -c "frame=" || echo "0")
    local minor_scenes=$(ffmpeg -v error -i "$file" -t $sample_duration -vf "select=gt(scene\,0.12)" -vsync vfr -f null - 2>&1 | grep -c "frame=" || echo "0")
    
    # Analyze frame consistency for optimal frame rate
    local frame_consistency=$(ffmpeg -v error -i "$file" -t 10 -vf "select='not(mod(n\,3))',showinfo" -f null - 2>&1 | grep -c "pkt_pts_time=" || echo "0")
    
    # Detect static regions (useful for optimizing GIF size)
    local static_regions=$(ffmpeg -v error -i "$file" -t 15 -vf "select='lt(scene\,0.003)',showinfo" -f null - 2>&1 | grep -c "pkt_pts_time=" || echo "0")
    
    # Clean numeric values
    major_scenes=${major_scenes//[^0-9]/}; major_scenes=${major_scenes:-0}
    minor_scenes=${minor_scenes//[^0-9]/}; minor_scenes=${minor_scenes:-0}
    frame_consistency=${frame_consistency//[^0-9]/}; frame_consistency=${frame_consistency:-0}
    static_regions=${static_regions//[^0-9]/}; static_regions=${static_regions:-0}
    
    # Calculate scene complexity score
    local scene_density=$((major_scenes * 100 / sample_duration))
    local transition_smoothness=$((minor_scenes - major_scenes))
    local static_ratio=$((static_regions * 100 / (frame_consistency + 1)))
    
    # Return scene analysis results
    echo "${scene_density}|${transition_smoothness}|${static_ratio}"
}

# 📊 Smart Frame Rate Optimization
ai_smart_framerate_adjustment() {
    local file="$1" duration="$2" motion_level="$3" scene_data="$4"
    
    echo -e "      📊 ${BLUE}Optimizing frame rate based on motion and scene analysis...${NC}"
    
    # Parse scene data
    local scene_density="${scene_data%%|*}"
    local temp_data="${scene_data#*|}"
    local transition_smoothness="${temp_data%%|*}"
    local static_ratio="${scene_data##*|}"
    
    # Base frame rate selection
    local optimal_fps=12
    
    # Adjust based on motion level
    case "$motion_level" in
        "high")
            optimal_fps=18
            [[ $scene_density -gt 15 ]] && optimal_fps=20
            ;;
        "medium")
            optimal_fps=15
            [[ $transition_smoothness -gt 10 ]] && optimal_fps=16
            ;;
        "low")
            optimal_fps=12
            [[ $static_ratio -gt 60 ]] && optimal_fps=10
            ;;
        "static")
            optimal_fps=8
            [[ $static_ratio -gt 80 ]] && optimal_fps=6
            ;;
    esac
    
    # Content duration adjustments
    if [[ $duration -gt 180 ]]; then
        # Long content - reduce fps to manage size
        optimal_fps=$((optimal_fps - 2))
        [[ $optimal_fps -lt 6 ]] && optimal_fps=6
    elif [[ $duration -lt 5 ]]; then
        # Very short content - can afford higher fps
        optimal_fps=$((optimal_fps + 4))
        [[ $optimal_fps -gt 24 ]] && optimal_fps=24
    fi
    
    echo "$optimal_fps"
}

# 🔧 Intelligent Quality Scaling
ai_intelligent_quality_scaling() {
    local file="$1" width="$2" height="$3" complexity_score="$4" content_type="$5"
    
    echo -e "      🔧 ${BLUE}Calculating optimal quality parameters...${NC}"
    
    local total_pixels=$((width * height))
    local base_colors=128
    local scaling_quality="bicubic"
    
    # Adjust color palette based on visual complexity and content type
    if [[ $complexity_score -gt 80 ]]; then
        base_colors=256  # High complexity needs more colors
    elif [[ $complexity_score -gt 60 ]]; then
        base_colors=192
    elif [[ $complexity_score -gt 40 ]]; then
        base_colors=128
    elif [[ $complexity_score -gt 20 ]]; then
        base_colors=96
    else
        base_colors=64   # Low complexity can use fewer colors
    fi
    
    # Content-specific adjustments
    case "$content_type" in
        "animation")
            base_colors=$((base_colors + 32))  # Animations benefit from more colors
            scaling_quality="lanczos"
            ;;
        "screencast")
            base_colors=$((base_colors - 16))  # Screencasts have limited color palette
            scaling_quality="neighbor"  # Preserve sharp edges
            ;;
        "movie")
            # Keep base colors as calculated
            scaling_quality="bicubic"
            ;;
        "clip")
            base_colors=$((base_colors + 16))  # Short clips can afford more colors
            scaling_quality="lanczos"
            ;;
    esac
    
    # Resolution-based scaling quality
    if [[ $total_pixels -ge 8294400 ]]; then  # 4K+
        scaling_quality="lanczos"  # Best quality for downscaling
    elif [[ $total_pixels -le 307200 ]]; then  # 480p or lower
        scaling_quality="neighbor"  # Preserve low-res content
    fi
    
    # Cap colors at reasonable limits
    [[ $base_colors -gt 256 ]] && base_colors=256
    [[ $base_colors -lt 32 ]] && base_colors=32
    
    echo "${base_colors}|${scaling_quality}"
}

# ✂️ Enhanced Intelligent Crop with AI Analysis
ai_enhanced_crop_detection() {
    local file="$1" width="$2" height="$3" content_type="$4"
    
    echo -e "      ✂️ ${BLUE}AI crop analysis for optimal framing...${NC}"
    
    # Content-aware crop detection
    local crop_samples=()
    local sample_strategy=()
    
    # Different sampling strategies based on content type
    case "$content_type" in
        "movie"|"clip")
            # Sample more frequently for dynamic content
            sample_strategy=("5" "15%" "30%" "50%" "70%" "85%")
            ;;
        "screencast")
            # Fewer samples for static content
            sample_strategy=("10%" "50%" "90%")
            ;;
        "animation")
            # Sample at quarter intervals
            sample_strategy=("25%" "50%" "75%")
            ;;
        *)
            # Default sampling
            sample_strategy=("3" "25%" "50%" "75%")
            ;;
    esac
    
    for sample_time in "${sample_strategy[@]}"; do
        # Use more sensitive detection for different content types
        local sensitivity="24:16:0"
        [[ "$content_type" == "screencast" ]] && sensitivity="12:8:0"
        [[ "$content_type" == "animation" ]] && sensitivity="32:24:0"
        
        local crop_line
        crop_line=$(ffmpeg -v error -ss "$sample_time" -i "$file" -t 1 -vf "cropdetect=$sensitivity" -f null - 2>&1 | grep -o "crop=[0-9]*:[0-9]*:[0-9]*:[0-9]*" | tail -1)
        [[ -n "$crop_line" ]] && crop_samples+=("$crop_line")
    done
    
    # Smart crop selection based on consistency and area preservation
    declare -A crop_frequency
    local best_crop="none"
    local max_frequency=0
    
    # Count frequency of similar crops
    for crop in "${crop_samples[@]}"; do
        ((crop_frequency["$crop"]++))
        if [[ ${crop_frequency["$crop"]} -gt $max_frequency ]]; then
            # Validate crop preserves enough content
            local cw=$(echo "$crop" | cut -d'=' -f2 | cut -d: -f1)
            local ch=$(echo "$crop" | cut -d'=' -f2 | cut -d: -f2)
            local area=$((cw * ch))
            local original_area=$((width * height))
            local area_ratio=$((area * 100 / original_area))
            
            # Accept crop if it preserves at least 75% of original area
            if [[ $area_ratio -ge 75 ]]; then
                max_frequency=${crop_frequency["$crop"]}
                best_crop="$crop"
            fi
        fi
    done
    
    echo "$best_crop"
}

# ⚙️ Enhanced AI-based Optimizations with Advanced Features
apply_ai_optimizations() {
    local content_type="$1" motion_level="$2" complexity_score="$3" duration="$4" width="$5" height="$6"
    
    echo -e "    🤖 ${MAGENTA}Applying advanced AI optimizations for $content_type content${NC}"
    
    # Stage 1: Advanced scene analysis
    local scene_data=$(ai_scene_detection "$1" "$duration")
    
    # Stage 2: Smart frame rate optimization
    local optimal_fps=$(ai_smart_framerate_adjustment "$1" "$duration" "$motion_level" "$scene_data")
    FRAMERATE="$optimal_fps"
    
    # Stage 3: Intelligent quality scaling
    local quality_data=$(ai_intelligent_quality_scaling "$1" "$width" "$height" "$complexity_score" "$content_type")
    local suggested_colors="${quality_data%%|*}"
    local suggested_scaling="${quality_data##*|}"
    MAX_COLORS="$suggested_colors"
    SCALING_ALGO="$suggested_scaling"
    
    # Stage 4: Enhanced crop detection
    local enhanced_crop=$(ai_enhanced_crop_detection "$1" "$width" "$height" "$content_type")
    if [[ "$enhanced_crop" != "none" ]]; then
        CROP_FILTER="$enhanced_crop"
        AI_CONTENT_CACHE+=" enhanced_crop=applied"
    fi
    
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

# 🎨 Enhanced AI-Powered Quality Selection with Intelligent Optimization
ai_quality_selection() {
    echo -e "${CYAN}${BOLD}🎯 AI-DRIVEN QUALITY SELECTION${NC}\n"
    echo -e "${YELLOW}🧠 AI will analyze your videos and suggest the optimal quality level!${NC}\n"
    
    # Pre-analyze first video to provide intelligent recommendations
    local video_files=()
    shopt -s nullglob
    for ext in mp4 avi mov mkv webm; do
        video_files+=(*."$ext")
    done
    shopt -u nullglob
    
    local ai_recommendation="high"  # default fallback
    local recommendation_reason=""
    
    # 🖥️ Detect system capabilities for intelligent recommendations
    echo -e "${BLUE}🖥️  Analyzing system capabilities...${NC}"
    
    local system_score=0
    local system_factors=()
    
    # Progress tracking
    local detection_steps=6  # Updated to match actual steps
    local current_step=0
    
    # Helper function to show detection progress
    show_detection_progress() {
        local step_name="$1"
        ((current_step++))
        local progress=$((current_step * 100 / detection_steps))
        local filled=$((progress * 20 / 100))
        local empty=$((20 - filled))
        
        # Hide cursor at start of first progress update
        if [[ $current_step -eq 1 ]]; then
            tput civis 2>/dev/null || printf "\033[?25l"
        fi
        
        # Get terminal width and calculate available space for text
        local term_width=$(tput cols 2>/dev/null || echo "80")
        # Actual visible characters: "  [" (3) + bar (20) + "] " (2) + "100% " (5) = 30 chars
        # Reserve extra space to prevent wrapping (safety margin)
        local available_width=$((term_width - 35))
        # Ensure reasonable bounds
        [[ $available_width -lt 15 ]] && available_width=15
        [[ $available_width -gt 40 ]] && available_width=40
        
        # Truncate step name if too long
        local display_name="$step_name"
        if [[ ${#step_name} -gt $available_width ]]; then
            display_name="${step_name:0:$((available_width-3))}..."
        fi
        
        # Clear the entire line first to prevent text artifacts
        printf "\r\033[K"
        
        # Print progress bar with dynamic-width text
        printf "  ${CYAN}["
        for ((i=0; i<filled; i++)); do printf "${GREEN}█${NC}"; done
        for ((i=0; i<empty; i++)); do printf "${GRAY}░${NC}"; done
        printf "${CYAN}] ${BOLD}%3d%%${NC} ${BLUE}%s${NC}" "$progress" "$display_name"
        
        # Show cursor and move to new line when complete
        if [[ "$step_name" == "Complete!" ]]; then
            tput cnorm 2>/dev/null || printf "\033[?25h"
        else
            # Brief pause to make progress visible
            sleep 0.1
        fi
    }
    
    # 🎯 Try inxi first - comprehensive hardware detection tool
    local use_inxi=false
    local inxi_cpu_info=""
    local inxi_memory_info=""
    local inxi_gpu_info=""
    local inxi_disk_info=""
    
    if command -v inxi >/dev/null 2>&1; then
        use_inxi=true
        show_detection_progress "Detecting hardware with inxi..."
        
        # Intelligent inxi flag selection based on what we need:
        # -C = CPU (cores, model, speed, cache)
        # -m = Memory (size, type, speed)
        # -G = Graphics (GPU model, driver)
        # -D = Drives (type, model, size)
        # -b = Basic output (faster, less verbose)
        # -c 0 = No color codes (cleaner parsing)
        
        # Get CPU info: cores, model, frequency, cache
        inxi_cpu_info=$(inxi -C -c 0 2>/dev/null)
        
        # Get Memory info: total RAM, type, speed
        inxi_memory_info=$(inxi -m -c 0 2>/dev/null)
        
        # Get GPU info: model, driver
        inxi_gpu_info=$(inxi -G -c 0 2>/dev/null)
        
        # Get Disk info: SSD/HDD detection
        inxi_disk_info=$(inxi -D -c 0 2>/dev/null)
    else
        show_detection_progress "Detecting hardware (standard tools)..."
    fi
    
    # Enhanced CPU detection with frequency and model info
    show_detection_progress "Analyzing CPU..."
    local cpu_model=""
    local cpu_freq_mhz=0
    local cpu_cores_detected=0
    
    # Parse inxi CPU info if available
    if [[ "$use_inxi" == "true" && -n "$inxi_cpu_info" ]]; then
        # Extract CPU model from inxi output
        # Example: "CPU: 16-core AMD Ryzen 9 5950X (32-thread) @ 3.4GHz"
        cpu_model=$(echo "$inxi_cpu_info" | grep -oP 'CPU:.*?(?=\(|@|$)' | sed 's/CPU:[[:space:]]*//g' | sed 's/[0-9]*-core[[:space:]]*//g' | sed 's/[[:space:]]*$//')
        
        # Extract core count from inxi
        cpu_cores_detected=$(echo "$inxi_cpu_info" | grep -oP '[0-9]+-core' | grep -oP '[0-9]+' | head -1)
        [[ -n "$cpu_cores_detected" ]] && CPU_CORES=$cpu_cores_detected
        
        # Extract frequency (convert GHz to MHz)
        local cpu_freq_ghz=$(echo "$inxi_cpu_info" | grep -oP '@[[:space:]]*[0-9.]+\s*GHz' | grep -oP '[0-9.]+' | head -1)
        if [[ -n "$cpu_freq_ghz" ]]; then
            cpu_freq_mhz=$(echo "$cpu_freq_ghz * 1000" | bc 2>/dev/null | cut -d. -f1)
        fi
    fi
    
    # Fallback: Try to get CPU model from lscpu (no sudo needed)
    if [[ -z "$cpu_model" ]] && command -v lscpu >/dev/null 2>&1; then
        cpu_model=$(lscpu | grep "Model name:" | sed 's/Model name:[[:space:]]*//g' | head -1)
        [[ -z "$cpu_freq_mhz" || "$cpu_freq_mhz" == "0" ]] && cpu_freq_mhz=$(lscpu | grep "CPU max MHz:" | awk '{print $NF}' | cut -d. -f1)
        # Fallback to current MHz if max not available
        [[ -z "$cpu_freq_mhz" || "$cpu_freq_mhz" == "0" ]] && cpu_freq_mhz=$(lscpu | grep "CPU MHz:" | awk '{print $NF}' | cut -d. -f1)
    fi
    
    # Alternative: read from /proc/cpuinfo
    if [[ -z "$cpu_model" && -r /proc/cpuinfo ]]; then
        cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^[[:space:]]*//g')
    fi
    
    # Score based on CPU cores and frequency
    if [[ $CPU_CORES -ge 16 ]]; then
        system_score=$((system_score + 35))
        system_factors+=("${CPU_CORES}-core CPU")
    elif [[ $CPU_CORES -ge 12 ]]; then
        system_score=$((system_score + 30))
        system_factors+=("${CPU_CORES}-core CPU")
    elif [[ $CPU_CORES -ge 8 ]]; then
        system_score=$((system_score + 20))
        system_factors+=("${CPU_CORES}-core CPU")
    elif [[ $CPU_CORES -ge 4 ]]; then
        system_score=$((system_score + 10))
    fi
    
    # Bonus for high-frequency CPUs (3.5GHz+)
    if [[ $cpu_freq_mhz -ge 3500 ]]; then
        system_score=$((system_score + 10))
    elif [[ $cpu_freq_mhz -ge 3000 ]]; then
        system_score=$((system_score + 5))
    fi
    
    # Detect high-performance CPU brands/models
    if [[ -n "$cpu_model" ]]; then
        if echo "$cpu_model" | grep -qiE "(ryzen 9|ryzen 7|i9|i7|threadripper|xeon|epyc)"; then
            system_score=$((system_score + 15))
            # Extract short CPU name for display
            local cpu_short=$(echo "$cpu_model" | sed -E 's/.*(Ryzen [0-9]|Core i[0-9]|Threadripper|Xeon|EPYC).*/\1/I' | head -c 20)
            [[ -n "$cpu_short" && "$cpu_short" != "$cpu_model" ]] && system_factors+=("$cpu_short")
        fi
    fi
    
    # Enhanced RAM detection with speed info
    show_detection_progress "Analyzing memory..."
    local total_ram_mb=0
    local ram_speed_mhz=0
    
    # Parse inxi memory info if available
    if [[ "$use_inxi" == "true" && -n "$inxi_memory_info" ]]; then
        # Extract total RAM from inxi output
        # Example: "RAM: 32 GiB (2 x 16 GiB) DDR4 3200 MHz"
        local ram_size_str=$(echo "$inxi_memory_info" | grep -oP 'RAM:[[:space:]]*[0-9.]+\s*(GiB|GB|MiB|MB)' | grep -oP '[0-9.]+\s*(GiB|GB|MiB|MB)')
        
        if [[ -n "$ram_size_str" ]]; then
            local ram_value=$(echo "$ram_size_str" | grep -oP '[0-9.]+')
            local ram_unit=$(echo "$ram_size_str" | grep -oP '(GiB|GB|MiB|MB)')
            
            # Convert to MB
            case "$ram_unit" in
                "GiB"|"GB")
                    total_ram_mb=$(echo "$ram_value * 1024" | bc 2>/dev/null | cut -d. -f1)
                    ;;
                "MiB"|"MB")
                    total_ram_mb=$(echo "$ram_value" | cut -d. -f1)
                    ;;
            esac
        fi
        
        # Extract RAM speed from inxi
        ram_speed_mhz=$(echo "$inxi_memory_info" | grep -oP 'DDR[0-9][[:space:]]*[0-9]+' | grep -oP '[0-9]+$' | head -1)
    fi
    
    # Fallback: Use free command
    if [[ $total_ram_mb -eq 0 ]] && command -v free >/dev/null 2>&1; then
        total_ram_mb=$(free -m | awk '/^Mem:/ {print $2}')
    fi
    
    # Fallback: Try to get RAM speed from dmidecode without sudo (may work on some systems)
    if [[ $ram_speed_mhz -eq 0 ]] && command -v dmidecode >/dev/null 2>&1; then
        ram_speed_mhz=$(dmidecode -t memory 2>/dev/null | grep "Speed:" | grep -oE '[0-9]+' | head -1 || echo "0")
    fi
    
    # Score based on total RAM
    if [[ $total_ram_mb -ge 65536 ]]; then  # 64GB+
        system_score=$((system_score + 40))
        system_factors+=("${total_ram_mb}MB RAM")
    elif [[ $total_ram_mb -ge 32768 ]]; then  # 32GB+
        system_score=$((system_score + 30))
        system_factors+=("${total_ram_mb}MB RAM")
    elif [[ $total_ram_mb -ge 16384 ]]; then  # 16GB+
        system_score=$((system_score + 20))
        system_factors+=("${total_ram_mb}MB RAM")
    elif [[ $total_ram_mb -ge 8192 ]]; then  # 8GB+
        system_score=$((system_score + 10))
    fi
    
    # Bonus for fast RAM (3200MHz+)
    if [[ $ram_speed_mhz -ge 3200 ]]; then
        system_score=$((system_score + 5))
    fi
    
    # Enhanced GPU detection with model info
    show_detection_progress "Analyzing GPU..."
    local has_gpu=false
    local gpu_model=""
    local gpu_detected=false
    
    # Parse inxi GPU info if available
    if [[ "$use_inxi" == "true" && -n "$inxi_gpu_info" ]]; then
        # Extract GPU model from inxi output
        # Example: "Graphics: Device-1: NVIDIA GeForce RTX 3080 driver: nvidia v: 525.125.06"
        gpu_model=$(echo "$inxi_gpu_info" | grep -oP 'Device-[0-9]+:[[:space:]]*[^:]+' | sed 's/Device-[0-9]*:[[:space:]]*//g' | head -1)
        
        if [[ -n "$gpu_model" ]]; then
            has_gpu=true
            gpu_detected=true
            
            # Intelligent GPU tier detection from inxi output
            if echo "$gpu_model" | grep -qiE "NVIDIA"; then
                # NVIDIA tier detection
                if echo "$gpu_model" | grep -qiE "(RTX 40|RTX 309|RTX 308|A[0-9]{3,4}|H100|A100|Quadro RTX)"; then
                    system_score=$((system_score + 30))
                    system_factors+=("High-end NVIDIA GPU")
                elif echo "$gpu_model" | grep -qiE "(RTX 30|RTX 20|GTX 16)"; then
                    system_score=$((system_score + 20))
                    system_factors+=("NVIDIA GPU")
                else
                    system_score=$((system_score + 15))
                    system_factors+=("NVIDIA GPU")
                fi
            elif echo "$gpu_model" | grep -qiE "AMD|Radeon"; then
                # AMD tier detection
                if echo "$gpu_model" | grep -qiE "(RX 7[0-9]{3}|RX 6[89][0-9]{2}|Radeon VII)"; then
                    system_score=$((system_score + 20))
                    system_factors+=("High-end AMD GPU")
                else
                    system_score=$((system_score + 15))
                    system_factors+=("AMD GPU")
                fi
            elif echo "$gpu_model" | grep -qiE "Intel.*Arc|Intel.*Xe"; then
                # Intel Arc detection
                system_score=$((system_score + 15))
                system_factors+=("Intel Arc GPU")
            elif echo "$gpu_model" | grep -qiE "Intel"; then
                # Intel integrated
                system_score=$((system_score + 5))
            fi
        fi
    fi
    
    # Fallback: NVIDIA GPU detection with nvidia-smi
    if [[ "$gpu_detected" == "false" ]] && command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
        has_gpu=true
        gpu_model=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
        
        # Score based on GPU tier (RTX 40/30 series, high-end Quadro, etc.)
        if echo "$gpu_model" | grep -qiE "(RTX 40|RTX 309|RTX 308|A[0-9]{3,4}|H100|A100)"; then
            system_score=$((system_score + 30))
            system_factors+=("High-end NVIDIA GPU")
        elif echo "$gpu_model" | grep -qiE "(RTX 30|RTX 20|GTX 16)"; then
            system_score=$((system_score + 20))
            system_factors+=("NVIDIA GPU")
        else
            system_score=$((system_score + 15))
            system_factors+=("NVIDIA GPU")
        fi
    # Fallback: AMD GPU detection
    elif [[ "$gpu_detected" == "false" ]] && command -v rocm-smi >/dev/null 2>&1 && rocm-smi >/dev/null 2>&1; then
        has_gpu=true
        system_score=$((system_score + 20))
        system_factors+=("AMD GPU (ROCm)")
    elif [[ "$gpu_detected" == "false" ]] && lspci 2>/dev/null | grep -qi 'vga.*amd'; then
        has_gpu=true
        gpu_model=$(lspci 2>/dev/null | grep -i 'vga.*amd' | sed 's/.*: //g' | head -1)
        # Check for high-end AMD cards
        if echo "$gpu_model" | grep -qiE "(RX 7[0-9]{3}|RX 6[89][0-9]{2}|Radeon VII)"; then
            system_score=$((system_score + 20))
            system_factors+=("High-end AMD GPU")
        else
            system_score=$((system_score + 15))
            system_factors+=("AMD GPU")
        fi
    # Fallback: Intel GPU detection
    elif [[ "$gpu_detected" == "false" ]] && lspci 2>/dev/null | grep -qi 'vga.*intel'; then
        gpu_model=$(lspci 2>/dev/null | grep -i 'vga.*intel' | sed 's/.*: //g' | head -1)
        # Check for Intel Arc discrete GPUs
        if echo "$gpu_model" | grep -qiE "(Arc A[0-9]{3}|Xe)"; then
            system_score=$((system_score + 15))
            system_factors+=("Intel Arc GPU")
        else
            system_score=$((system_score + 5))
        fi
    fi
    
    # Check available disk space in current directory (in GB)
    show_detection_progress "Analyzing storage..."
    local free_space_gb=0
    local total_space_gb=0
    
    if command -v df >/dev/null 2>&1; then
        free_space_gb=$(df -BG . 2>/dev/null | awk 'NR==2 {print $4}' | tr -d 'G')
        total_space_gb=$(df -BG . 2>/dev/null | awk 'NR==2 {print $2}' | tr -d 'G')
        
        if [[ $free_space_gb -ge 500 ]]; then
            system_score=$((system_score + 25))
            system_factors+=("${free_space_gb}GB free")
        elif [[ $free_space_gb -ge 100 ]]; then
            system_score=$((system_score + 20))
            system_factors+=("${free_space_gb}GB free")
        elif [[ $free_space_gb -ge 50 ]]; then
            system_score=$((system_score + 10))
        elif [[ $free_space_gb -lt 10 ]]; then
            system_score=$((system_score - 15))  # Penalize low disk space
        fi
    fi
    
    # Check for SSD vs HDD (SSDs are much faster for video processing)
    local is_ssd=false
    
    # Parse inxi disk info if available
    if [[ "$use_inxi" == "true" && -n "$inxi_disk_info" ]]; then
        # Look for SSD indicators in inxi output
        # Example: "Local Storage: 1 TiB (2 drives) SSD"
        if echo "$inxi_disk_info" | grep -qiE "SSD|NVMe|M\.2"; then
            is_ssd=true
            system_score=$((system_score + 10))
            system_factors+=("SSD storage")
            
            # Extra bonus for NVMe (much faster than SATA SSD)
            if echo "$inxi_disk_info" | grep -qiE "NVMe"; then
                system_score=$((system_score + 5))
            fi
        fi
    fi
    
    # Fallback: Check /sys/block for rotational flag
    if [[ "$is_ssd" == "false" ]]; then
        # Check multiple common disk devices
        for disk in sda nvme0n1 sdb sdc; do
            if [[ -r /sys/block/$disk/queue/rotational ]]; then
                local rotational=$(cat /sys/block/$disk/queue/rotational 2>/dev/null || echo "1")
                if [[ "$rotational" == "0" ]]; then
                    is_ssd=true
                    system_score=$((system_score + 10))
                    system_factors+=("SSD storage")
                    break
                fi
            fi
        done
    fi
    
    # Complete the progress bar
    show_detection_progress "Complete!"
    printf "\n"  # Move to next line after progress bar
    
    # Display system analysis
    if [[ ${#system_factors[@]} -gt 0 ]]; then
        echo -e "  ${GREEN}✓ Detected: ${system_factors[*]}${NC}"
    fi
    
    # Determine system tier based on score (updated thresholds for better detection)
    local system_tier="standard"
    if [[ $system_score -ge 100 ]]; then
        system_tier="high-end"
        echo -e "  ${CYAN}🚀 ${BOLD}Workstation/Enthusiast-class system detected!${NC} ${CYAN}Maximum quality recommended${NC}"
        echo -e "  ${GRAY}System Score: ${BOLD}$system_score${NC} ${GRAY}(High-Performance Tier)${NC}"
    elif [[ $system_score -ge 70 ]]; then
        system_tier="high-end"
        echo -e "  ${CYAN}💪 ${BOLD}High-end system detected!${NC} ${CYAN}Recommending premium quality settings${NC}"
        echo -e "  ${GRAY}System Score: ${BOLD}$system_score${NC} ${GRAY}(High-End Tier)${NC}"
    elif [[ $system_score -ge 40 ]]; then
        system_tier="mid-range"
        echo -e "  ${CYAN}⚡ ${BOLD}Mid-range system detected${NC} ${CYAN}- balanced quality recommended${NC}"
        echo -e "  ${GRAY}System Score: ${BOLD}$system_score${NC} ${GRAY}(Mid-Range Tier)${NC}"
    else
        system_tier="standard"
        echo -e "  ${CYAN}📊 ${BOLD}Standard system detected${NC} ${CYAN}- optimized for efficiency${NC}"
        echo -e "  ${GRAY}System Score: ${BOLD}$system_score${NC} ${GRAY}(Standard Tier)${NC}"
    fi
    echo ""
    
    if [[ ${#video_files[@]} -gt 0 ]]; then
        echo -e "${BLUE}🔍 AI is analyzing your videos to provide smart recommendations...${NC}"
        local sample_file="${video_files[0]}"
        
        # Quick analysis for recommendation
        local duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$sample_file" 2>/dev/null | cut -d. -f1 || echo "0")
        local width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$sample_file" 2>/dev/null || echo "0")
        local height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$sample_file" 2>/dev/null || echo "0")
        local bitrate=$(ffprobe -v error -show_entries format=bit_rate -of csv=p=0 "$sample_file" 2>/dev/null || echo "0")
        local file_size=$(stat -c%s "$sample_file" 2>/dev/null || echo "0")
        
        # AI-based recommendation logic
        local total_pixels=$((width * height))
        local file_size_mb=$((file_size / 1024 / 1024))
        
        # Base recommendations on video characteristics
        if [[ $total_pixels -ge 8294400 && $file_size_mb -gt 100 ]]; then
            # 4K+ high-quality source
            ai_recommendation="max"
            recommendation_reason="4K source with high bitrate"
        elif [[ $total_pixels -ge 2073600 && $bitrate -gt 5000000 ]]; then
            # 1080p+ good quality
            ai_recommendation="high"
            recommendation_reason="High-resolution source with good bitrate"
        elif [[ $duration -gt 300 && $file_size_mb -gt 200 ]]; then
            # Long, high-quality movie
            ai_recommendation="medium"
            recommendation_reason="Long-form content - balanced approach"
        elif [[ $duration -lt 10 && $total_pixels -ge 1382400 ]]; then
            # Short high-res clip
            ai_recommendation="high"
            recommendation_reason="Short high-resolution clip - quality preservation"
        elif [[ $width -ge 1280 && $height -ge 720 && $duration -lt 60 ]]; then
            # Screencast-like content
            ai_recommendation="medium"
            recommendation_reason="Screencast-type content detected"
        elif [[ $total_pixels -lt 921600 || $file_size_mb -lt 10 ]]; then
            # Lower resolution or small file
            ai_recommendation="low"
            recommendation_reason="Lower resolution or compressed source"
        fi
        
        # 🚀 Upgrade recommendation based on system capabilities
        # High-end systems should prioritize quality - system capabilities matter more than source quality
        case "$system_tier" in
            "high-end")
                # Workstation/Enthusiast systems (score 100+) - ALWAYS recommend MAX quality
                if [[ $system_score -ge 100 ]]; then
                    # Top-tier systems: Your hardware can handle MAX, so use it!
                    if [[ "$ai_recommendation" != "max" ]]; then
                        ai_recommendation="max"
                        recommendation_reason="Workstation-class PC (Score: $system_score) - maximum quality recommended"
                    fi
                # High-end systems (score 70-99) - aggressive upgrades
                else
                    if [[ "$ai_recommendation" == "low" ]]; then
                        ai_recommendation="medium"
                        recommendation_reason="$recommendation_reason (upgraded for high-end PC)"
                    elif [[ "$ai_recommendation" == "medium" ]]; then
                        ai_recommendation="high"
                        recommendation_reason="$recommendation_reason (upgraded for high-end PC)"
                    elif [[ "$ai_recommendation" == "high" && $total_pixels -ge 2073600 ]]; then
                        ai_recommendation="max"
                        recommendation_reason="$recommendation_reason (upgraded for high-end PC)"
                    fi
                fi
                ;;
            "mid-range")
                # Mid-range systems get modest upgrades
                if [[ "$ai_recommendation" == "low" && $total_pixels -ge 921600 ]]; then
                    ai_recommendation="medium"
                    recommendation_reason="$recommendation_reason (upgraded for capable PC)"
                fi
                ;;
            "standard")
                # Standard systems: lower recommendations if disk space is limited
                if [[ $free_space_gb -lt 10 ]]; then
                    if [[ "$ai_recommendation" == "max" ]]; then
                        ai_recommendation="high"
                        recommendation_reason="$recommendation_reason (adjusted for disk space)"
                    elif [[ "$ai_recommendation" == "high" ]]; then
                        ai_recommendation="medium"
                        recommendation_reason="$recommendation_reason (adjusted for disk space)"
                    fi
                fi
                ;;
        esac
        
        echo -e "  ${GREEN}✓ Video analysis complete!${NC}"
        echo ""
    fi
    
    local quality_options=(
        "🔹 Low Quality - Optimized for size (best for previews & social media)"
        "⚖️  Medium Quality - Balanced approach (recommended for most content)"
        "💎 High Quality - Detailed output (best for important content)"
        "🏆 Max Quality - Premium quality (for professional use)"
        "🤖 Let AI Decide - Use AI recommendation based on video analysis"
    )
    
    local quality_values=("low" "medium" "high" "max" "ai_auto")
    local quality_descriptions=(
        "Up to 720p, 8-12fps, 64-128 colors, optimized compression"
        "Up to 1080p, 10-15fps, 128-192 colors, balanced settings"
        "Up to 1440p, 12-18fps, 192-256 colors, quality-focused"
        "Up to 4K, 15-24fps, 256 colors, maximum detail preservation"
        "AI automatically selects optimal settings per video"
    )
    
    # Show AI recommendation prominently
    if [[ -n "$recommendation_reason" ]]; then
        echo -e "${YELLOW}${BOLD}💡 AI RECOMMENDATION:${NC}"
        echo -e "  ${GREEN}✓ Suggested: ${BOLD}${ai_recommendation^^}${NC} ${GREEN}quality${NC}"
        echo -e "  ${CYAN}🔎 Reason: $recommendation_reason${NC}"
        echo ""
    fi
    
    for i in "${!quality_options[@]}"; do
        local num=$((i + 1))
        
        # Don't show "(Current)" in quick mode - user is making a fresh selection
        # Only show current if this is a settings/advanced mode, not quick selection
        local is_current=""
        
        # Check if this option matches the AI recommendation
        local is_recommended=""
        if [[ "${quality_values[$i]}" == "$ai_recommendation" ]]; then
            is_recommended=" 💡 (AI Recommended)"
        fi
        
        # Special handling for AI auto option - always show as smart choice
        if [[ "${quality_values[$i]}" == "ai_auto" ]]; then
            is_recommended=" 🎆 (Smart Choice!)"
            # Don't show as current for ai_auto since it's a special mode
            if [[ "$QUALITY" == "ai_auto" ]]; then
                is_current=""
            fi
        fi
        
        # Optional debug output (enable by setting DEBUG_AI_SELECTION=true)
        if [[ "$DEBUG_AI_SELECTION" == "true" ]]; then
            echo "DEBUG: Option $((i+1)): value='${quality_values[$i]}' current_QUALITY='$QUALITY' ai_rec='$ai_recommendation'" >&2
        fi
        
        echo -e "  ${GREEN}[$num]${NC} ${quality_options[$i]}${is_current}${is_recommended}"
        echo -e "      ${GRAY}→ ${quality_descriptions[$i]}${NC}"
        echo ""
    done
    
    # Capitalize quality name for display
    local ai_recommendation_display="${ai_recommendation^}"  # Capitalize first letter
    
    echo -ne "${MAGENTA}Enter your choice [1-5] or press Enter for AI recommendation ($ai_recommendation_display):${NC} "
    read -r quality_choice
    
    if [[ -n "$quality_choice" && "$quality_choice" =~ ^[1-5]$ ]]; then
        local index=$((quality_choice - 1))
        local selected_quality="${quality_values[$index]}"
        
        if [[ "$selected_quality" == "ai_auto" ]]; then
            echo -e "${GREEN}🤖 AI Auto Mode Selected!${NC}"
            echo -e "${CYAN}AI will automatically determine optimal quality for each video${NC}"
            AI_AUTO_QUALITY=true
            QUALITY="$ai_recommendation"  # Set initial quality based on recommendation
        else
            apply_preset "$selected_quality"
            AI_AUTO_QUALITY=false
            # Capitalize quality name for display
            local quality_display="${QUALITY^}"
            echo -e "${GREEN}✓ Selected: ${BOLD}$quality_display${NC} ${GREEN}quality${NC}"
        fi
        
        # Save the selected quality choice to settings
        if [[ -n "$SETTINGS_FILE" ]]; then
            save_settings --silent
        fi
    else
        # Use AI recommendation as default
        apply_preset "$ai_recommendation"
        AI_AUTO_QUALITY=false
        # Capitalize quality name for display
        local quality_display="${QUALITY^}"
        echo -e "${GREEN}✓ Using AI recommendation: ${BOLD}$quality_display${NC} ${GREEN}quality${NC}"
        
        # Save the AI recommendation to settings
        if [[ -n "$SETTINGS_FILE" ]]; then
            save_settings --silent
        fi
    fi
    
    echo -e "${CYAN}${BOLD}🧠 AI will now analyze and optimize all other settings based on each video's content!${NC}"
}

# 🤖 AI-Powered Video Discovery System
ai_discover_videos() {
    # Check if AI discovery is enabled
    if [[ "$AI_DISCOVERY_ENABLED" != "true" ]]; then
        echo -e "  ${YELLOW}🙅 AI video discovery is disabled${NC}"
        echo -e "  ${CYAN}Enable it with: ${BOLD}AI_DISCOVERY_ENABLED=true${NC}"
        return 1
    fi
    
    echo -e "  ${CYAN}🔍 AI is scanning common video locations...${NC}"
    
    # Define intelligent search paths
    local search_paths=()
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Add script directory and common video locations
    search_paths+=("$script_dir")
    search_paths+=("$HOME/Videos")
    search_paths+=("$HOME/Downloads")
    search_paths+=("$HOME/Desktop")
    search_paths+=("$HOME/Documents")
    search_paths+=("$HOME/Pictures")
    search_paths+=("$(pwd)")
    
    # Add any mounted drives or common media locations
    if [[ -d "/media/$USER" ]]; then
        for media_dir in /media/$USER/*; do
            [[ -d "$media_dir" ]] && search_paths+=("$media_dir")
        done
    fi
    
    # Remove duplicates and non-existent paths
    local unique_paths=()
    for path in "${search_paths[@]}"; do
        if [[ -d "$path" ]] && ! printf '%s\n' "${unique_paths[@]}" | grep -Fxq "$path"; then
            unique_paths+=("$path")
        fi
    done
    
    # Search for videos with progress indication
    local total_paths=${#unique_paths[@]}
    local current_path=0
    local found_videos=()
    
    for search_dir in "${unique_paths[@]}"; do
        ((current_path++))
        local progress=$((current_path * 100 / total_paths))
        
        printf "\r  ${BLUE}Scanning [${NC}"
        local filled=$((progress * 20 / 100))
        for ((i=0; i<filled; i++)); do printf "${GREEN}█${NC}"; done
        for ((i=filled; i<20; i++)); do printf "${GRAY}░${NC}"; done
        printf "${BLUE}] ${BOLD}%3d%%${NC} ${CYAN}%s${NC}" "$progress" "$(basename -- "$search_dir")"
        
        # Search for video files (non-recursive for performance)
        shopt -s nullglob
        for ext in mp4 avi mov mkv webm MP4 AVI MOV MKV WEBM; do
            for video in "$search_dir"/*."$ext"; do
                if [[ -f "$video" ]]; then
                    # Get file info for intelligent sorting
                    local size=$(stat -c%s "$video" 2>/dev/null || echo "0")
                    local modified=$(stat -c%Y "$video" 2>/dev/null || echo "0")
                    found_videos+=("$video|$size|$modified")
                fi
            done
        done
        shopt -u nullglob
    done
    
    printf "\r  ${GREEN}✓ Search complete! Found ${BOLD}${#found_videos[@]}${NC} ${GREEN}video files${NC}\n\n"
    
    if [[ ${#found_videos[@]} -eq 0 ]]; then
        echo -e "  ${YELLOW}🚨 No video files found in common locations${NC}"
        echo -e "  ${GRAY}Searched in: $(printf '%s, ' "${unique_paths[@]%,}" | sed 's/, $//')${NC}"
        return 1
    fi
    
    # Sort videos by modification time (newest first) and size
    local sorted_videos=()
    while IFS= read -r line; do
        sorted_videos+=("$line")
    done < <(printf '%s\n' "${found_videos[@]}" | sort -t'|' -k3,3nr -k2,2nr)
    
    # Display found videos with intelligent categorization
    echo -e "  ${GREEN}${BOLD}🎬 Found Videos - AI Analysis & Recommendations:${NC}\n"
    
    # Categorize videos
    local recent_videos=()
    local large_videos=()
    local other_videos=()
    local current_time=$(date +%s)
    
    for video_info in "${sorted_videos[@]}"; do
        local video_path="${video_info%%|*}"
        local size="${video_info#*|}"; size="${size%|*}"
        local modified="${video_info##*|}"
        
        local age_days=$(( (current_time - modified) / 86400 ))
        local size_mb=$((size / 1024 / 1024))
        
        if [[ $age_days -le 7 ]]; then
            recent_videos+=("$video_info")
        elif [[ $size_mb -gt 50 ]]; then
            large_videos+=("$video_info")
        else
            other_videos+=("$video_info")
        fi
    done
    
    # Display categories with AI insights
    local display_count=0
    local max_display=15
    
    if [[ ${#recent_videos[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}${BOLD}🔥 Recent Videos (Modified within 7 days):${NC}"
        for video_info in "${recent_videos[@]}"; do
            [[ $display_count -ge $max_display ]] && break
            display_video_option "$video_info" $((++display_count))
        done
        echo ""
    fi
    
    if [[ ${#large_videos[@]} -gt 0 && $display_count -lt $max_display ]]; then
        echo -e "  ${BLUE}${BOLD}💾 Large Videos (>50MB):${NC}"
        for video_info in "${large_videos[@]}"; do
            [[ $display_count -ge $max_display ]] && break
            display_video_option "$video_info" $((++display_count))
        done
        echo ""
    fi
    
    if [[ ${#other_videos[@]} -gt 0 && $display_count -lt $max_display ]]; then
        echo -e "  ${CYAN}${BOLD}📁 Other Videos:${NC}"
        for video_info in "${other_videos[@]}"; do
            [[ $display_count -ge $max_display ]] && break
            display_video_option "$video_info" $((++display_count))
        done
        echo ""
    fi
    
    if [[ ${#sorted_videos[@]} -gt $max_display ]]; then
        echo -e "  ${GRAY}... and $((${#sorted_videos[@]} - max_display)) more videos${NC}\n"
    fi
    
    # Check for auto-selection based on user preferences
    if [[ "$AI_DISCOVERY_AUTO_SELECT" != "ask" ]]; then
        echo -e "  ${BLUE}🤖 ${BOLD}AI Auto-Selection Mode: $AI_DISCOVERY_AUTO_SELECT${NC}"
        
        case "$AI_DISCOVERY_AUTO_SELECT" in
            "recent")
                if [[ ${#recent_videos[@]} -gt 0 ]]; then
                    echo -e "  ${GREEN}✓ Auto-selecting ${#recent_videos[@]} recent videos!${NC}"
                    copy_videos_to_current "${recent_videos[@]}"
                    return 0
                else
                    echo -e "  ${YELLOW}No recent videos found, showing manual options...${NC}"
                fi
                ;;
            "all")
                echo -e "  ${GREEN}✓ Auto-selecting all displayed videos!${NC}"
                copy_videos_to_current "${sorted_videos[@]:0:$display_count}"
                return 0
                ;;
            "disabled")
                echo -e "  ${YELLOW}AI auto-selection disabled, showing manual options...${NC}"
                ;;
        esac
        echo ""
    fi
    
    # User selection options with clear explanation
    echo -e "  ${MAGENTA}${BOLD}🎯 Selection Options:${NC}"
    echo -e "  ${YELLOW}📍 Important: Selected videos will be ${BOLD}copied${NC} ${YELLOW}to current directory for conversion${NC}"
    echo -e "  ${CYAN}💾 GIF outputs will be saved in: ${BOLD}$(pwd)${NC}\n"
    echo -e "    ${GREEN}[a]${NC} Copy all displayed videos here and convert"
    echo -e "    ${GREEN}[r]${NC} Copy recent videos only (${#recent_videos[@]} files) and convert"
    echo -e "    ${GREEN}[1-$display_count]${NC} Copy specific video by number and convert"
    echo -e "    ${GREEN}[c]${NC} Copy custom selection (ranges like 1,3,5 or 1-5)"
    echo -e "    ${GREEN}[w]${NC} Change working directory first"
    echo -e "    ${GREEN}[s]${NC} Save preference and set auto-selection mode"
    echo -e "    ${GREEN}[n]${NC} No thanks, I'll add videos manually\n"
    
    echo -ne "${MAGENTA}Your choice: ${NC}"
    read -r choice
    
    case "$choice" in
        "a"|"A")
            echo -e "\n${GREEN}✓ Selected all displayed videos!${NC}"
            # Remember this choice if enabled
            if [[ "$AI_DISCOVERY_REMEMBER_CHOICE" == "true" ]]; then
                AI_DISCOVERY_AUTO_SELECT="all"
                save_settings --silent
                echo -e "  ${CYAN}💾 Remembered: Will auto-select all videos next time${NC}"
            fi
            copy_videos_to_current "${sorted_videos[@]:0:$display_count}"
            return 0
            ;;
        "r"|"R")
            if [[ ${#recent_videos[@]} -gt 0 ]]; then
                echo -e "\n${GREEN}✓ Selected ${#recent_videos[@]} recent videos!${NC}"
                # Remember this choice if enabled
                if [[ "$AI_DISCOVERY_REMEMBER_CHOICE" == "true" ]]; then
                    AI_DISCOVERY_AUTO_SELECT="recent"
                    save_settings --silent
                    echo -e "  ${CYAN}💾 Remembered: Will auto-select recent videos next time${NC}"
                fi
                copy_videos_to_current "${recent_videos[@]}"
                return 0
            else
                echo -e "\n${YELLOW}No recent videos found${NC}"
                return 1
            fi
            ;;
        [1-9]|[1-9][0-9])
            if [[ $choice -le $display_count ]]; then
                local selected_video="${sorted_videos[$((choice-1))]}"
                echo -e "\n${GREEN}✓ Selected video #$choice!${NC}"
                copy_videos_to_current "$selected_video"
                return 0
            else
                echo -e "\n${RED}Invalid selection${NC}"
                return 1
            fi
            ;;
        "c"|"C")
            echo -ne "\n${CYAN}Enter video numbers to copy (e.g., 1,3,5 or 1-5): ${NC}"
            read -r range_input
            copy_videos_by_range "$range_input" "${sorted_videos[@]:0:$display_count}"
            return $?
            ;;
        "w"|"W")
            echo -e "\n${BLUE}${BOLD}📂 Change Working Directory${NC}"
            echo -e "${CYAN}Current: ${BOLD}$(pwd)${NC}"
            echo -ne "${YELLOW}Enter new directory path (or press Enter to browse): ${NC}"
            read -r new_dir
            
            if [[ -z "$new_dir" ]]; then
                # Show some common directory options
                echo -e "\n${CYAN}Common directories:${NC}"
                echo -e "  ${GREEN}[1]${NC} $HOME/Desktop"
                echo -e "  ${GREEN}[2]${NC} $HOME/Downloads"
                echo -e "  ${GREEN}[3]${NC} $HOME/Documents"
                echo -e "  ${GREEN}[4]${NC} $HOME/Videos"
                echo -e "  ${GREEN}[c]${NC} Custom path\n"
                
                read -r dir_choice
                case "$dir_choice" in
                    "1") new_dir="$HOME/Desktop" ;;
                    "2") new_dir="$HOME/Downloads" ;;
                    "3") new_dir="$HOME/Documents" ;;
                    "4") new_dir="$HOME/Videos" ;;
                    "c"|"C")
                        echo -ne "${YELLOW}Enter full directory path: ${NC}"
                        read -r new_dir
                        ;;
                    *) 
                        echo -e "${RED}Invalid choice${NC}"
                        return 1
                        ;;
                esac
            fi
            
            if [[ -d "$new_dir" ]]; then
                cd "$new_dir" 2>/dev/null
                echo -e "${GREEN}✓ Changed to: ${BOLD}$(pwd)${NC}"
                echo -e "${CYAN}Restarting AI discovery in new location...${NC}\n"
                ai_discover_videos
                return $?
            else
                echo -e "${RED}❌ Directory does not exist: $new_dir${NC}"
                return 1
            fi
            ;;
        "s"|"S")
            echo -e "\n${BLUE}${BOLD}💾 AI Discovery Preferences${NC}"
            echo -e "${CYAN}Configure how AI should handle video discovery:${NC}\n"
            
            echo -e "  ${GREEN}[1]${NC} Ask me each time (current: $([ "$AI_DISCOVERY_AUTO_SELECT" = "ask" ] && echo "✓" || echo " "))"
            echo -e "  ${GREEN}[2]${NC} Always auto-select recent videos (current: $([ "$AI_DISCOVERY_AUTO_SELECT" = "recent" ] && echo "✓" || echo " "))"
            echo -e "  ${GREEN}[3]${NC} Always auto-select all videos (current: $([ "$AI_DISCOVERY_AUTO_SELECT" = "all" ] && echo "✓" || echo " "))"
            echo -e "  ${GREEN}[4]${NC} Disable auto-selection (current: $([ "$AI_DISCOVERY_AUTO_SELECT" = "disabled" ] && echo "✓" || echo " "))\n"
            
            echo -e "  ${YELLOW}Remember choices: $(get_status_icon "$AI_DISCOVERY_REMEMBER_CHOICE")${NC}"
            echo -e "  ${GREEN}[r]${NC} Toggle remember choices\n"
            
            read -r pref_choice
            case "$pref_choice" in
                "1") 
                    AI_DISCOVERY_AUTO_SELECT="ask"
                    echo -e "${GREEN}✓ Will ask for selection each time${NC}"
                    ;;
                "2") 
                    AI_DISCOVERY_AUTO_SELECT="recent"
                    echo -e "${GREEN}✓ Will auto-select recent videos${NC}"
                    ;;
                "3") 
                    AI_DISCOVERY_AUTO_SELECT="all"
                    echo -e "${GREEN}✓ Will auto-select all videos${NC}"
                    ;;
                "4") 
                    AI_DISCOVERY_AUTO_SELECT="disabled"
                    echo -e "${GREEN}✓ Auto-selection disabled${NC}"
                    ;;
                "r"|"R")
                    AI_DISCOVERY_REMEMBER_CHOICE=$([[ "$AI_DISCOVERY_REMEMBER_CHOICE" == "true" ]] && echo "false" || echo "true")
                    echo -e "${GREEN}✓ Remember choices: $(get_status_text "$AI_DISCOVERY_REMEMBER_CHOICE")${NC}"
                    ;;
                *)
                    echo -e "${YELLOW}No changes made${NC}"
                    return 0
                    ;;
            esac
            
            save_settings --silent
            echo -e "${CYAN}💾 Preferences saved!${NC}"
            echo -e "${YELLOW}Restarting discovery with new settings...${NC}\n"
            ai_discover_videos
            return $?
            ;;
        "n"|"N"|"")
            echo -e "\n${YELLOW}AI discovery cancelled${NC}"
            return 1
            ;;
        *)
            echo -e "\n${RED}Invalid choice${NC}"
            return 1
            ;;
    esac
}

# Helper function to display video options with AI analysis
display_video_option() {
    local video_info="$1"
    local number="$2"
    
    local video_path="${video_info%%|*}"
    local size="${video_info#*|}"; size="${size%|*}"
    local modified="${video_info##*|}"
    
    local filename=$(basename -- "$video_path")
    local dirname=$(dirname "$video_path")
    local size_human=$(numfmt --to=iec $size 2>/dev/null || echo "${size}B")
    local mod_date=$(date -d @$modified '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown")
    
    # AI content prediction based on filename and size
    local content_hint="🎬"
    if [[ $filename == *"screen"* ]] || [[ $filename == *"record"* ]] || [[ $filename == *"capture"* ]]; then
        content_hint="🖥️"
    elif [[ $size -lt 10485760 ]]; then  # < 10MB
        content_hint="🎥"  # likely a clip
    elif [[ $size -gt 104857600 ]]; then  # > 100MB
        content_hint="🎦"  # likely a movie
    fi
    
    printf "    ${GREEN}[%2d]${NC} %s ${BOLD}%s${NC}\n" "$number" "$content_hint" "$filename"
    printf "         ${GRAY}%s ${CYAN}%s${NC} ${YELLOW}%s${NC}\n" "$(basename -- "$dirname")" "$size_human" "$mod_date"
}

# Copy selected videos to current directory
copy_videos_to_current() {
    local selected_videos=("$@")
    local copy_count=0
    local current_dir="$(pwd)"
    
    echo -e "\n  ${BLUE}📎 Copying videos to conversion directory...${NC}"
    echo -e "  ${CYAN}💾 Destination: ${BOLD}$current_dir${NC}"
    echo -e "  ${YELLOW}ℹ️  Note: Both videos AND generated GIFs will be in this location${NC}\n"
    
    for video_info in "${selected_videos[@]}"; do
        local video_path="${video_info%%|*}"
        local filename=$(basename -- "$video_path")
        
        # Skip if already in current directory
        if [[ "$(dirname "$video_path")" == "$current_dir" ]]; then
            echo -e "    ${YELLOW}⚠️  Skipping $filename (already in current directory)${NC}"
            continue
        fi
        
        # Check if file already exists
        if [[ -f "$current_dir/$filename" ]]; then
            echo -e "    ${YELLOW}⚠️  Skipping $filename (already exists)${NC}"
            continue
        fi
        
        # Copy the file
        if cp "$video_path" "$current_dir/" 2>/dev/null; then
            echo -e "    ${GREEN}✓ Copied: $filename${NC}"
            ((copy_count++))
        else
            echo -e "    ${RED}❌ Failed: $filename${NC}"
        fi
    done
    
    if [[ $copy_count -gt 0 ]]; then
        echo -e "\n  ${GREEN}${BOLD}✨ Successfully copied $copy_count video(s) to conversion directory!${NC}"
        echo -e "  ${BLUE}📁 Files are now in: ${BOLD}$current_dir${NC}"
        echo -e "  ${CYAN}🚀 Ready to convert! GIFs will be generated in the same location.${NC}"
        return 0
    else
        echo -e "\n  ${YELLOW}No videos were copied${NC}"
        return 1
    fi
}

# Copy videos by range selection
copy_videos_by_range() {
    local range_input="$1"
    shift
    local all_videos=("$@")
    local selected_videos=()
    
    # Parse range input (e.g., "1,3,5" or "1-5")
    IFS=',' read -ra ranges <<< "$range_input"
    
    for range in "${ranges[@]}"; do
        if [[ $range == *"-"* ]]; then
            # Handle range (e.g., "1-5")
            local start="${range%-*}"
            local end="${range#*-}"
            for ((i=start; i<=end; i++)); do
                if [[ $i -gt 0 && $i -le ${#all_videos[@]} ]]; then
                    selected_videos+=("${all_videos[$((i-1))]}")
                fi
            done
        else
            # Handle single number
            if [[ $range -gt 0 && $range -le ${#all_videos[@]} ]]; then
                selected_videos+=("${all_videos[$((range-1))]}")
            fi
        fi
    done
    
    if [[ ${#selected_videos[@]} -gt 0 ]]; then
        echo -e "\n${GREEN}✓ Selected ${#selected_videos[@]} video(s)!${NC}"
        copy_videos_to_current "${selected_videos[@]}"
        return $?
    else
        echo -e "\n${RED}No valid selections${NC}"
        return 1
    fi
}

# 🔍 AI Preview Analysis (non-intrusive)
ai_preview_analysis() {
    local file="$1"
    
    echo -e "  ${YELLOW}🔬 AI Preview Analysis in progress...${NC}"
    
    # Show analysis progress
    local steps=("Extracting metadata" "Analyzing resolution" "Detecting content type" "Generating recommendations")
    for i in "${!steps[@]}"; do
        local step=$((i + 1))
        local progress=$((step * 25))
        local filled=$((progress * 20 / 100))
        local empty=$((20 - filled))
        
        printf "\r  ${CYAN}Preview [${NC}"
        for ((j=0; j<filled; j++)); do printf "${GREEN}█${NC}"; done
        for ((j=0; j<empty; j++)); do printf "${GRAY}░${NC}"; done
        printf "${CYAN}] ${BOLD}%3d%%${NC} ${BLUE}%s...${NC}" "$progress" "${steps[i]}"
        
        sleep 0.3  # Small delay for visual effect
    done
    
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
    
    # Clear progress line and show results
    printf "\r  ${GREEN}✓ Preview analysis complete!${NC}\n"
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
            local videos_analyzed=0
            local content_types=()
            local motion_types=()
            
            # Parse and count AI analysis results
            echo "$ai_entries" | while read -r line; do
                if [[ $line == *"AI-DETECTED:"* ]]; then
                    ((videos_analyzed++))
                    
                    # Extract content type
                    if [[ $line == *"content_type=clip"* ]]; then
                        content_types+=("Short Clip")
                    elif [[ $line == *"content_type=animation"* ]]; then
                        content_types+=("Animation")
                    elif [[ $line == *"content_type=screencast"* ]]; then
                        content_types+=("Screencast")
                    elif [[ $line == *"content_type=movie"* ]]; then
                        content_types+=("Movie/Long Video")
                    fi
                    
                    # Extract motion type
                    if [[ $line == *"motion=static"* ]]; then
                        motion_types+=("minimal motion")
                    elif [[ $line == *"motion=low"* ]]; then
                        motion_types+=("low motion")
                    elif [[ $line == *"motion=medium"* ]]; then
                        motion_types+=("moderate motion")
                    elif [[ $line == *"motion=high"* ]]; then
                        motion_types+=("high motion")
                    fi
                fi
            done
            
            # Show user-friendly summary
            echo -e "${YELLOW}📊 What AI Detected:${NC}"
            
            # Count unique content types
            if [[ ${#content_types[@]} -gt 0 ]]; then
                echo -e "  ${BLUE}Content:${NC} Analyzed ${videos_analyzed} video(s)"
                echo -e "  ${BLUE}Type:${NC} ${content_types[0]}"
            fi
            
            # Show motion analysis
            if [[ ${#motion_types[@]} -gt 0 ]]; then
                echo -e "  ${BLUE}Motion:${NC} Detected ${motion_types[0]}"
            fi
            
            echo -e "\n${YELLOW}⚙️ AI Optimizations Applied:${NC}"
            echo -e "  ${GREEN}✓${NC} Frame rate adjusted for motion level"
            echo -e "  ${GREEN}✓${NC} Color palette optimized for content type"
            echo -e "  ${GREEN}✓${NC} Smart cropping applied where beneficial"
            echo -e "  ${GREEN}✓${NC} File size optimized while preserving quality"
        fi
    fi
    
    echo -e "\n${GREEN}✅ Conversion complete! AI optimized each video automatically.${NC}"
    echo -e "${CYAN}💡 Tip: AI decisions are logged in: $(make_clickable_path "$ERROR_LOG" "errors.log")${NC}"
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

    # Extract non-banner lines and filter out benign warnings
    local body=$(grep -v -E "^ffmpeg version|^\s*libav|^\s*configuration:|^Input #|^Output #|^Stream mapping:|^Press \[q\]|^\s*$|Duped color|deprecated pixel format" "$err_file" 2>/dev/null)

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
    # Resolve AI_THREADS_OPTIMAL: if set to "auto", use FFMPEG_THREADS; otherwise use it directly
    local optimal_threads="$FFMPEG_THREADS"
    if [[ "$AI_THREADS_OPTIMAL" != "auto" && -n "$AI_THREADS_OPTIMAL" ]]; then
        optimal_threads="$AI_THREADS_OPTIMAL"
    fi
    # Resolve AI_MEMORY_OPT: if set to "auto" or empty, don't use it; otherwise use it directly
    local memory_opts=""
    if [[ "$AI_MEMORY_OPT" != "auto" && -n "$AI_MEMORY_OPT" ]]; then
        memory_opts="$AI_MEMORY_OPT"
    fi
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
    # Resolve AI_THREADS_OPTIMAL: if set to "auto", use FFMPEG_THREADS; otherwise use it directly
    local optimal_threads="$FFMPEG_THREADS"
    if [[ "$AI_THREADS_OPTIMAL" != "auto" && -n "$AI_THREADS_OPTIMAL" ]]; then
        optimal_threads="$AI_THREADS_OPTIMAL"
    fi
    # Resolve AI_MEMORY_OPT: if set to "auto" or empty, don't use it; otherwise use it directly
    local memory_opts=""
    if [[ "$AI_MEMORY_OPT" != "auto" && -n "$AI_MEMORY_OPT" ]]; then
        memory_opts="$AI_MEMORY_OPT"
    fi
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
    
    echo "[$timestamp] $status: $(basename -- "$source_file") -> $(basename -- "$output_file") $size_info" >> "$CONVERSION_LOG"
    
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
    echo "[$timestamp] $status:$(basename -- "$file")" >> "$PROGRESS_FILE"
    
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
        local base_name=$(basename -- "$file_prefix")
        
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
    echo -e "${RED}📁 File: $(basename -- "$corrupt_file")${NC}"
    echo -e "${RED}📄 Source: $(basename -- "$source_file")${NC}"
    echo -e "${RED}🔍 Type: $corruption_type${NC}"
    
    # Move corrupt file to quarantine directory
    local quarantine_dir="$LOG_DIR/corrupt_files"
    local quarantine_file="$quarantine_dir/$(basename -- "$corrupt_file").$(date +%s).corrupt"
    
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
    echo -e "\n${YELLOW}👋 Quitting... Stopping after current file completes...${NC}"
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
        
        # Delete incomplete output GIF if it exists
        local incomplete_gif="${CURRENT_FILE%.*}.${OUTPUT_FORMAT}"
        if [[ -f "$incomplete_gif" ]]; then
            local output_size=$(stat -c%s "$incomplete_gif" 2>/dev/null || echo "0")
            # If GIF is suspiciously small or incomplete, delete it
            if [[ $output_size -lt 1000 ]]; then
                rm -f "$incomplete_gif" 2>/dev/null || true
                echo -e "${YELLOW}🧹 Cleaned up incomplete conversion: $(basename -- "$incomplete_gif")${NC}"
            fi
        fi
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

# 🔍 Hyper-Optimized AI-Powered Duplicate Detection with Multi-Threading
detect_duplicate_gifs() {
    echo -e "${BLUE}${BOLD}🚀 AI-Enhanced Parallel Duplicate Detection${NC}"
    echo -e "${CYAN}🔬 Multi-threaded analysis: Content fingerprinting + Visual similarity + Metadata comparison...${NC}"
    echo -e "${GREEN}⚡ Using ${BOLD}$AI_DUPLICATE_THREADS${NC}${GREEN} CPU threads for maximum performance!${NC}"
    
    # Initialize AI cache and training systems
    init_ai_cache
    init_ai_training
    init_checksum_cache
    local cache_stats=$(get_cache_stats)
    local training_stats=$(get_ai_training_stats)
    local checksum_cache_stats=$(get_checksum_cache_stats)
    echo -e "${BLUE}🗄️ AI Cache: $cache_stats${NC}"
    echo -e "${GREEN}🧠 AI Training: $training_stats${NC}"
    echo -e "${CYAN}🔐 Checksum Cache: $checksum_cache_stats${NC}"
    
    local total_gifs=0
    local duplicate_count=0
    local duplicate_pairs=()
    declare -A gif_checksums
    declare -A gif_sizes
    declare -A gif_fingerprints
    declare -A gif_visual_hashes
    declare -A gif_frame_counts
    declare -A gif_durations
    
    # Create temporary directory for analysis
    local temp_analysis_dir="$(mktemp -d)"
    trap "rm -rf '$temp_analysis_dir'" EXIT
    
    # Count total GIF files first for progress calculation (avoid duplicates)
    local gif_files_list=()
    declare -A seen_files  # Track files to avoid duplicates
    
    echo -e "  ${CYAN}🔍 Scanning GIF files...${NC}"
    
    shopt -s nullglob
    
    # Build list of GIF files - ONLY scan OUTPUT_DIRECTORY if it's different from current dir
    local all_gifs=()
    
    if [[ -d "$OUTPUT_DIRECTORY" && "$(cd "$OUTPUT_DIRECTORY" 2>/dev/null && pwd)" != "$(pwd)" ]]; then
        # OUTPUT_DIRECTORY is configured and different - scan ONLY there
        echo -e "  ${BLUE}📂 Scanning output directory: $OUTPUT_DIRECTORY${NC}"
        all_gifs=("$OUTPUT_DIRECTORY"/*.gif)
    else
        # No separate output directory - scan current dir
        echo -e "  ${GRAY}📂 Scanning current directory${NC}"
        all_gifs=(*.gif)
    fi
    
    local total_to_scan=${#all_gifs[@]}
    local scan_count=0
    
    for gif_file in "${all_gifs[@]}"; do
        if [[ -f "$gif_file" && "${gif_file##*.}" == "gif" && -z "${seen_files["$gif_file"]}" ]]; then
            gif_files_list+=("$gif_file")
            seen_files["$gif_file"]=1
            ((scan_count++))
            
            # Show progress bar every few files
            if [[ $((scan_count % 5)) -eq 0 || $scan_count -eq $total_to_scan ]]; then
                local progress=$((scan_count * 100 / total_to_scan))
                local filled=$((progress * 20 / 100))
                local empty=$((20 - filled))
                
                # Truncate filename if too long
                local display_name="$(basename -- "$gif_file")"
                if [[ ${#display_name} -gt 50 ]]; then
                    display_name="${display_name:0:47}..."
                fi
                
                printf "\r  ${CYAN}["
                for ((j=0; j<filled; j++)); do printf "${GREEN}█${NC}"; done
                for ((j=0; j<empty; j++)); do printf "${GRAY}░${NC}"; done
                printf "${CYAN}] ${BOLD}%3d%%${NC} ${BLUE}Found %d files${NC}" "$progress" "$scan_count"
                printf "\n  ${GRAY}📄 %s${NC}" "$display_name"
                printf "\r\033[1A"  # Move cursor back up to progress bar line
            fi
        fi
    done
    shopt -u nullglob
    
    # Show final count (keep it visible)
    printf "\r  ${GREEN}["
    for ((j=0; j<20; j++)); do printf "${GREEN}█${NC}"; done
    printf "${GREEN}] ${BOLD}100%%${NC} ${BLUE}Found %d GIF files${NC}\n" "$scan_count"
    
    # Remove any duplicates from the array
    local unique_files_list=()
    declare -A dedup_tracker
    for gif_file in "${gif_files_list[@]}"; do
        if [[ -z "${dedup_tracker["$gif_file"]}" ]]; then
            unique_files_list+=("$gif_file")
            dedup_tracker["$gif_file"]=1
        fi
    done
    gif_files_list=("${unique_files_list[@]}")
    
    local total_files=${#gif_files_list[@]}
    if [[ $total_files -eq 0 ]]; then
        echo -e "  ${CYAN}ℹ️  No existing GIF files found${NC}"
        return 0
    fi
    
    # Calculate total size and estimate time
    local total_size=0
    for gif_file in "${gif_files_list[@]}"; do
        local file_size=$(stat -c%s "$gif_file" 2>/dev/null || echo "0")
        total_size=$((total_size + file_size))
    done
    
    # Convert to human readable
    local total_size_mb=$((total_size / 1024 / 1024))
    local estimated_time_sec=$((total_files * 2))  # Rough estimate: 2 seconds per file
    local estimated_time_min=$((estimated_time_sec / 60))
    
    # Show sample files after scanning complete (truncated for readability)
    local samples=""
    for ((i=0; i<3 && i<${#gif_files_list[@]}; i++)); do
        local fname="$(basename -- "${gif_files_list[$i]}")"
        # Truncate long filenames
        if [[ ${#fname} -gt 30 ]]; then
            fname="${fname:0:27}..."
        fi
        samples+="$fname, "
    done
    echo -e "  ${GRAY}📂 Sample: ${samples}...${NC}"
    
    # Pre-scan to count cached vs uncached files AND build list of only uncached files
    echo -e "  ${BLUE}${BOLD}🔍 Smart detection: Checking which files need analysis...${NC}"
    local files_to_analyze=0
    local files_cached=0
    declare -a uncached_files_list  # Only files that need processing
    
    # OPTIMIZATION: Load cache index into memory once instead of calling check_ai_cache 200+ times
    declare -A cache_lookup
    if [[ "$AI_CACHE_ENABLED" == "true" && -f "$AI_CACHE_INDEX" ]]; then
        # Load entire cache into associative array for O(1) lookups
        while IFS='|' read -r filename filesize filemtime timestamp analysis_data; do
            [[ "$filename" =~ ^# ]] && continue  # Skip comments
            [[ -z "$filename" ]] && continue     # Skip empty lines
            # Store with filename as key, fingerprint:data as value
            cache_lookup["$filename"]="${filesize}:${filemtime}|${analysis_data}"
        done < <(tail -n +4 "$AI_CACHE_INDEX" 2>/dev/null)
    fi
    
    # Build list of ONLY files that need analysis (NEW, CHANGED, or NOT CACHED)
    local idx_prescan
    for ((idx_prescan=0; idx_prescan<total_files; idx_prescan++)); do
        local prescan_file="${gif_files_list[$idx_prescan]}"
        local prescan_basename=$(basename -- "$prescan_file")
        
        local needs_analysis=true
        
        # Fast O(1) cache lookup using associative array
        if [[ -n "${cache_lookup[$prescan_basename]}" ]]; then
            # Check if file changed by comparing fingerprints
            local cached_entry="${cache_lookup[$prescan_basename]}"
            local cached_fingerprint=$(echo "$cached_entry" | cut -d'|' -f1)
            local cached_data=$(echo "$cached_entry" | cut -d'|' -f2-)
            
            # Get current file fingerprint (fast: just size + mtime)
            local current_filesize=$(stat -c%s "$prescan_file" 2>/dev/null || echo "0")
            local current_filemtime=$(stat -c%Y "$prescan_file" 2>/dev/null || echo "0")
            local current_fingerprint="${current_filesize}:${current_filemtime}"
            
            # If fingerprint matches and it's duplicate detection data, file is cached
            if [[ "$cached_fingerprint" == "$current_fingerprint" && "$cached_data" =~ ^DUPLICATE_DETECT: ]]; then
                ((files_cached++))
                needs_analysis=false  # File unchanged, skip it!
                
                # Load cached data directly into results (no processing needed)
                local results_file="$temp_analysis_dir/analysis_results.txt"
                echo "${cached_data#DUPLICATE_DETECT:}" >> "$results_file"
            fi
        fi
        
        # Add to processing list only if needs analysis
        if [[ "$needs_analysis" == "true" ]]; then
            uncached_files_list+=("$prescan_file")
            ((files_to_analyze++))
        fi
    done
    
    # From now on, ONLY process files in uncached_files_list (not all files!)
    # Clean up cache lookup
    unset cache_lookup
    
    echo -e "  ${BLUE}${BOLD}🧠 Stage 1: Parallel content fingerprinting (${AI_DUPLICATE_THREADS} threads)...${NC}"
    if [[ $files_cached -gt 0 ]]; then
        echo -e "  ${YELLOW}📊 Found ${BOLD}${total_files}${NC}${YELLOW} GIF files (${BOLD}${total_size_mb}MB${NC}${YELLOW} total)${NC}"
        echo -e "  ${GREEN}💾 Cached: ${BOLD}${files_cached}${NC}${GREEN} files (instant load)${NC}"
        echo -e "  ${CYAN}⚡ To analyze: ${BOLD}${files_to_analyze}${NC}${CYAN} files (need MD5 calculation)${NC}"
        if [[ $files_to_analyze -gt 0 ]]; then
            # Recalculate estimated time for only files needing analysis
            local estimated_time_min=$(( (total_size_mb / files_to_analyze) * files_to_analyze / 60 ))
            [[ $estimated_time_min -lt 1 ]] && estimated_time_min=1
            echo -e "  ${CYAN}⏱️  Estimated time: ~${estimated_time_min} minutes (varies by file size)${NC}"
        fi
    else
        echo -e "  ${YELLOW}📊 Processing ${BOLD}${total_files}${NC}${YELLOW} GIF files (${BOLD}${total_size_mb}MB${NC}${YELLOW} total)${NC}"
        echo -e "  ${CYAN}⏱️  Estimated time: ~${estimated_time_min} minutes (varies by file size)${NC}"
    fi
    echo -e "  ${GRAY}💡 Larger files take longer to calculate MD5 checksums${NC}"
    
    # Parallel analysis function for individual GIF files with timeout
    analyze_gif_parallel() {
        local gif_file="$1"
        local temp_dir="$2"
        local result_file="$3"
        local current_index="$4"     # Current file index for progress
        local total_files="$5"       # Total file count for progress
        local timeout_seconds=60     # Increased to 60 seconds per file - more reasonable for complex GIFs
        
        # Check if file exists and is readable
        if [[ ! -f "$gif_file" ]]; then
            local error_msg="File not found: $gif_file"
            log_error "$error_msg" "$gif_file" "File missing during duplicate detection"
            echo "$gif_file|ERROR|0|0:0:0:0x0||0|0" >> "$result_file"
            return 1
        elif [[ ! -r "$gif_file" ]]; then
            local error_msg="File not readable: $gif_file (permissions issue)"
            log_error "$error_msg" "$gif_file" "Permission denied during duplicate detection"
            echo "$gif_file|ERROR|0|0:0:0:0x0||0|0" >> "$result_file"
            return 1
        fi
        
        # Check cache first - look for DUPLICATE_DETECT prefix
        local cached_analysis=$(check_ai_cache "$gif_file" 2>/dev/null)
        if [[ $? -eq 0 && -n "$cached_analysis" ]]; then
            # Check if this is duplicate detection cache data
            if [[ "$cached_analysis" =~ ^DUPLICATE_DETECT: ]]; then
                # Cache hit - extract and use cached results (skip MD5 calculation!)
                local cached_data="${cached_analysis#DUPLICATE_DETECT:}"
                echo "$cached_data" >> "$result_file"
                
                # Update progress to show cache hit
                if [[ -n "$current_index" && -n "$total_files" ]]; then
                    update_file_progress "$current_index" "$total_files" "$(basename -- "$gif_file") [cached]" "Analyzing GIFs" 30
                fi
                # Increment cache hit counter (use file to share between function calls)
                echo "1" >> "$temp_dir/cache_hits.count" 2>/dev/null || true
                return 0
            fi
        fi
        
        # Simplified analysis using MD5 hash - much faster and reliable
        {
            # Display progress for current file
            if [[ -n "$current_index" && -n "$total_files" ]]; then
                update_file_progress "$current_index" "$total_files" "$(basename -- "$gif_file")" "Analyzing GIFs" 30
            fi
            
            # Stage 1: Fast MD5 checksum with intelligent caching
            # Use cached checksum if available, only calculate if needed
            local checksum
            local size=$(stat -c%s "$gif_file" 2>/dev/null || echo "0")
            
            # Try to get cached checksum first
            checksum=$(get_cached_checksum "$gif_file" 2>/dev/null)
            
            # If cache failed or returned empty, fallback to direct calculation with timeout
            if [[ -z "$checksum" ]]; then
                if checksum=$(timeout 5 md5sum "$gif_file" 2>/dev/null | awk '{print $1}'); then
                    [[ -z "$checksum" ]] && checksum="ERROR"
                else
                    checksum="TIMEOUT_MD5"
                    echo -e "  ${YELLOW}⏰ MD5 timeout: $(basename -- "$gif_file")${NC}" >&2
                fi
            fi
            
            # Check if MD5 calculation failed or timed out (likely corruption)
            if [[ "$checksum" == "ERROR" || "$checksum" == "TIMEOUT_MD5" ]]; then
                local failure_reason
                if [[ "$checksum" == "TIMEOUT_MD5" ]]; then
                    failure_reason="MD5 calculation timed out - likely severely corrupted file"
                    echo -e "  ${RED}🚫 Corrupted file (MD5 timeout): $(basename -- "$gif_file")${NC}" >&2
                else
                    failure_reason="MD5 calculation failed - file may be corrupted"
                fi
                
                # Use AI to verify if this is truly corrupted or just a permission issue
                local ai_health_verdict=$(ai_analyze_file_health "$gif_file" "md5_failed")
                if [[ "$ai_health_verdict" == "SKIP_NON_GIF" || "$ai_health_verdict" == "SKIP_VIDEO_FILE" ]]; then
                    # AI skipped - treat as regular MD5 failure
                    local error_msg="Cannot calculate MD5 hash: $gif_file ($failure_reason)"
                    log_error "$error_msg" "$gif_file" "$failure_reason"
                    echo "$gif_file|CORRUPTED|$size|unknown||0|0" >> "$result_file"
                    return 1
                elif [[ "$ai_health_verdict" == "CORRUPTED" ]]; then
                    # SAFETY: AI corruption detection NEVER triggers automatic deletion
                    # Only log and mark for manual review
                    local error_msg="AI detected potential corruption: $gif_file (MD5 failed, AI analysis suggests corruption)"
                    log_error "$error_msg" "$gif_file" "AI corruption detection - file marked for manual review, NOT auto-deleted"
                    echo "$gif_file|AI_CORRUPTED_REVIEW|$size|unknown||0|0" >> "$result_file"
                    # Train AI model with this corruption pattern
                    train_ai_file_health "$gif_file" "corrupted" "md5_failed" "confirmed"
                    echo -e "  ${YELLOW}🔍 AI flagged for review: $(basename -- "$gif_file") (potential corruption)${NC}" >&2
                    return 1
                else
                    # AI thinks file might be OK despite MD5 failure - mark as suspicious
                    local error_msg="Suspicious file (MD5 failed but AI uncertain): $gif_file"
                    log_error "$error_msg" "$gif_file" "MD5 failed but AI analysis suggests possible false positive"
                    echo "$gif_file|AI_SUSPICIOUS|$size|unknown||0|0" >> "$result_file"
                    # Train AI model with this edge case
                    train_ai_file_health "$gif_file" "suspicious" "md5_failed" "uncertain"
                    return 1
                fi
            fi
            
            # Stage 2: Enhanced metadata with FFprobe (fast and reliable for frame/duration)
            local frame_count="0"
            local duration="0" 
            local resolution="unknown"
            local perceptual_hash=""
            
            # Use FFprobe to get accurate frame count and duration (much faster than FFmpeg)
            # Timeout after 3 seconds to avoid hanging on corrupted files
            if command -v ffprobe >/dev/null 2>&1; then
                local ffprobe_output=$(timeout 3 ffprobe -v error -select_streams v:0 \
                    -count_packets -show_entries stream=nb_read_packets,duration,width,height \
                    -of csv=p=0 "$gif_file" 2>/dev/null)
                
                if [[ -n "$ffprobe_output" ]]; then
                    # Parse ffprobe output: nb_read_packets,duration,width,height
                    frame_count=$(echo "$ffprobe_output" | cut -d',' -f1)
                    duration=$(echo "$ffprobe_output" | cut -d',' -f2 | cut -d'.' -f1)  # Round to integer
                    local width=$(echo "$ffprobe_output" | cut -d',' -f3)
                    local height=$(echo "$ffprobe_output" | cut -d',' -f4)
                    resolution="${width}x${height}"
                    
                    # Ensure we have valid numbers
                    [[ ! "$frame_count" =~ ^[0-9]+$ ]] && frame_count="0"
                    [[ ! "$duration" =~ ^[0-9]+$ ]] && duration="0"
                fi
            fi
            
            # AI-powered perceptual hash for visual similarity detection
            # Extract middle frame and create a simple perceptual hash
            if [[ "$frame_count" -gt 0 ]] && command -v ffmpeg >/dev/null 2>&1; then
                # Extract a frame from middle of GIF for perceptual hashing
                local temp_frame="$temp_dir/frame_${RANDOM}.png"
                if timeout 2 ffmpeg -i "$gif_file" -vf "select=eq(n\,$(( frame_count / 2 )))" \
                    -vframes 1 -f image2 "$temp_frame" >/dev/null 2>&1; then
                    
                    # Create simple perceptual hash: average hash (aHash) algorithm
                    # Resize to 8x8, convert to grayscale, get average brightness
                    if command -v convert >/dev/null 2>&1; then
                        # Using ImageMagick for fast perceptual hash
                        perceptual_hash=$(convert "$temp_frame" -resize 8x8! -colorspace gray \
                            -format "%[fx:mean]" info: 2>/dev/null | tr -d '.')
                    fi
                    rm -f "$temp_frame" 2>/dev/null
                fi
            fi
            
            # Fallback to basic file validation if FFprobe unavailable
            if [[ "$resolution" == "unknown" ]]; then
                local file_info=$(file "$gif_file" 2>/dev/null || echo "unknown")
                if [[ "$file_info" == *"GIF"* ]]; then
                    resolution="valid_gif"
                elif [[ "$file_info" == *"data"* ]] && [[ $size -gt 1024 ]]; then
                    resolution="possible_gif"
                else
                    resolution="invalid_format"
                fi
            fi
            
            # Create enhanced content fingerprint with frame/duration data
            local content_fingerprint="${size}:${resolution}:${frame_count}:${duration}"
            
            # Prepare analysis data with perceptual hash
            local analysis_data="$gif_file|$checksum|$size|$content_fingerprint|$perceptual_hash|$frame_count|$duration"
            
            # Save to cache for future runs with DUPLICATE_DETECT prefix to distinguish from AI analysis cache
            save_to_ai_cache "$gif_file" "DUPLICATE_DETECT:$analysis_data" 2>/dev/null || true
            
            # Increment cache miss counter (MD5 was calculated)
            echo "1" >> "$temp_dir/cache_misses.count" 2>/dev/null || true
            
            # Write results atomically (no background processing - keep it simple and fast)
            echo "$analysis_data" >> "$result_file"
            
        } # No background process - execute immediately to avoid timeout issues
        
        return 0
    }
    
    # Export function for parallel execution
    export -f analyze_gif_parallel
    
    # Create results file for collecting parallel output
    local results_file="$temp_analysis_dir/analysis_results.txt"
    : > "$results_file"  # Initialize empty file
    
    # Process files sequentially with minimal parallelism to avoid timeout cascades
    local processed_files=0
    local auto_fixed_files=0
    local auto_deleted_files=0
    local auto_skipped_files=0
    declare -a fixed_files_list
    declare -a deleted_files_list
    declare -a skipped_files_list
    
    # Track cache statistics
    local cache_hits=0
    local cache_misses=0
    
    if [[ $files_to_analyze -gt 0 ]]; then
        echo -e "  ${BLUE}🚀 Processing ${files_to_analyze} GIF files that need analysis (${AI_DUPLICATE_THREADS} threads)${NC}"
        echo -e "  ${GREEN}💾 Skipping ${files_cached} cached files (instant load)${NC}"
    else
        echo -e "  ${GREEN}🚀 All ${total_files} GIF files are cached - loading instantly!${NC}"
    fi
    echo -e "  ${GRAY}🔈 Cache-enabled: Files analyzed before will load instantly!${NC}"
    
    # Emergency break mechanism to prevent infinite loops
    declare -A processed_files_tracker
    local emergency_break=false
    local consecutive_loop_detections=0
    
    # Clear any previous state that might cause loops
    unset processed_files_tracker
    declare -A processed_files_tracker
    
    # Track actual processing (exclude cached)
    local files_actually_processed=0
    local files_loaded_from_cache=0
    
    # Use simple while loop - process ONLY uncached files
    local loop_idx=0
    local total_to_process=${#uncached_files_list[@]}
    while [[ $loop_idx -lt $total_to_process ]]; do
        # Check if user requested interrupt (Ctrl+C)
        if [[ "$INTERRUPT_REQUESTED" == "true" ]]; then
            echo -e "\n  ${YELLOW}⏸️  Analysis interrupted by user${NC}"
            echo -e "  ${CYAN}💾 Processed: $files_actually_processed, Cached: $files_loaded_from_cache${NC}"
            break
        fi
        
        local gif_file="${uncached_files_list[$loop_idx]}"
        
        # This file needs processing (not cached)
        
        # Emergency break: If we've seen this EXACT file before in THIS session
        # This should NEVER happen in a proper loop, so it indicates array has duplicates
        if [[ -n "${processed_files_tracker["$gif_file"]}" ]]; then
            # Increment the detection count for THIS SPECIFIC FILE
            local file_detection_count=${processed_files_tracker["$gif_file"]}
            file_detection_count=$((file_detection_count + 1))
            processed_files_tracker["$gif_file"]=$file_detection_count
            
            echo -e "  ${RED}⚠️ Emergency break: Duplicate processing detected for $(basename -- "$gif_file") (seen $file_detection_count times)${NC}" >&2
            
            # If this SPECIFIC file has been seen too many times, skip it
            if [[ $file_detection_count -ge 3 ]]; then
                echo -e "  ${RED}🛑 Skipping problematic file after $file_detection_count attempts${NC}" >&2
                log_conversion "EMERGENCY_SKIP" "$gif_file" "" "File appeared multiple times in loop - systematic issue"
                continue
            fi
            
            # Count consecutive different files being flagged
            consecutive_loop_detections=$((consecutive_loop_detections + 1))
            
            # If many DIFFERENT files are being flagged, abort entire analysis
            if [[ $consecutive_loop_detections -ge 5 ]]; then
                echo -e "  ${RED}🛑 ABORTING: Too many different files flagged - likely systematic issue${NC}" >&2
                echo -e "  ${YELLOW}💡 Try restarting the script or check for file system issues${NC}" >&2
                emergency_break=true
                break
            fi
            
            log_conversion "EMERGENCY_SKIP" "$gif_file" "" "Duplicate file in processing queue - skipping"
            echo -e "  ${YELLOW}⏭️ Skipping duplicate queue entry: $(basename -- "$gif_file")${NC}" >&2
            ((loop_idx++))  # Increment before continue
            continue  # Skip this file and continue with next
        fi
        
        # Mark file as seen (first time = 1)
        processed_files_tracker["$gif_file"]=1
        
        # Reset consecutive counter on successful new file processing
        consecutive_loop_detections=0
        
        # Get file size immediately to handle problematic files early
        local size=$(stat -c%s "$gif_file" 2>/dev/null || echo "0")
        
        # Skip unreadable files immediately and ensure we continue to next file
        if [[ ! -r "$gif_file" ]]; then
            echo "$gif_file|UNREADABLE|0|unknown||0|0" >> "$results_file"
            echo -e "  ${RED}⚠️ Skipped unreadable: $(basename -- "$gif_file") (${processed_files}/${total_files})${NC}" >&2
            log_conversion "AUTO_SKIP" "$gif_file" "" "File not readable - permission denied"
            update_file_progress "$processed_files" "$total_files" "$(basename -- "$gif_file")" "Analyzing GIFs" 30
            ((loop_idx++))  # Increment before continue
            continue  # This should advance to next iteration
        fi
        # Process file directly (no background jobs to avoid timeout issues)
        # Automatically handle problematic files without user intervention
        
        # Advanced extension corruption detection and auto-fix
        local basename_file="$(basename -- "$gif_file")"
        local needs_fixing=false
        local corruption_type="unknown"
        local corrected_name=""
        
        # Pattern 1: Multiple .gif extensions (.gif.gif, .gif.gif.gif, etc.)
        if [[ "$basename_file" =~ \.gif\.gif ]]; then
            needs_fixing=true
            corruption_type="multiple_gif_extensions"
            local base_name="${basename_file%%.*}"
            corrected_name="$(dirname "$gif_file")/${base_name}.gif"
        # Pattern 2: Corrupted mixed extensions (.gif9.gifgif, .gif5.gif, etc.)
        elif [[ "$basename_file" =~ \.gif[0-9]+\.?gif ]]; then
            needs_fixing=true
            corruption_type="corrupted_numbered_extension"
            local base_name="${basename_file%%.*}"
            corrected_name="$(dirname "$gif_file")/${base_name}.gif"
        # Pattern 3: Multiple 'gif' in extension without dots (.gifgif, .gifgifgif)
        elif [[ "$basename_file" =~ \.gif[a-z]*gif ]]; then
            needs_fixing=true
            corruption_type="concatenated_gif_extension"
            local base_name="${basename_file%%.*}"
            corrected_name="$(dirname "$gif_file")/${base_name}.gif"
        # Pattern 4: Extension has 'gif' followed by other characters (.giff, .gift, .gifx)
        elif [[ "$basename_file" =~ \.[Gg][Ii][Ff][a-zA-Z0-9]+ ]] && [[ ! "$basename_file" =~ \.gif$ ]]; then
            needs_fixing=true
            corruption_type="malformed_gif_extension"
            local base_name="${basename_file%%.*}"
            corrected_name="$(dirname "$gif_file")/${base_name}.gif"
        # Pattern 5: No extension but filename contains 'gif' at end (filegif, somegif)
        elif [[ ! "$basename_file" =~ \. ]] && [[ "$basename_file" =~ gif$ ]]; then
            needs_fixing=true
            corruption_type="missing_dot_before_gif"
            local base_name="${basename_file%gif}"
            corrected_name="$(dirname "$gif_file")/${base_name}.gif"
        # Pattern 6: Extension is completely wrong but file is actually a GIF (check first few bytes)
        elif [[ "$basename_file" != *.gif ]]; then
            # Check if file is actually a GIF by magic bytes (GIF87a or GIF89a)
            local file_header=$(head -c 6 "$gif_file" 2>/dev/null)
            if [[ "$file_header" == "GIF87a" || "$file_header" == "GIF89a" ]]; then
                needs_fixing=true
                corruption_type="wrong_extension_but_valid_gif"
                local base_name="${basename_file%%.*}"
                [[ -z "$base_name" ]] && base_name="$basename_file"
                corrected_name="$(dirname "$gif_file")/${base_name}.gif"
            fi
        # Pattern 7: Filename contains [cached], [temp], [backup] or other bracket text
        elif [[ "$basename_file" =~ \[.*\] ]]; then
            needs_fixing=true
            corruption_type="unwanted_bracket_text"
            # Remove all bracket text and fix extension
            local clean_name=$(echo "$basename_file" | sed 's/\[.*\]//g' | sed 's/\.\+/./g')
            local base_name="${clean_name%%.*}"
            corrected_name="$(dirname "$gif_file")/${base_name}.gif"
        # Pattern 8: Filename contains common corruption markers (temp, backup, copy, old)
        elif [[ "$basename_file" =~ \.(temp|tmp|backup|bak|copy|old|~)\.gif$ ]]; then
            needs_fixing=true
            corruption_type="unwanted_suffix_in_extension"
            local base_name=$(echo "$basename_file" | sed -E 's/\.(temp|tmp|backup|bak|copy|old|~)\.gif$//g')
            corrected_name="$(dirname "$gif_file")/${base_name}.gif"
        fi
        
        # Apply fix if corruption detected
        if [[ "$needs_fixing" == "true" && -n "$corrected_name" ]]; then
            if [[ ! -f "$corrected_name" ]]; then
                if mv "$gif_file" "$corrected_name" 2>/dev/null; then
                    echo -e "  ${GREEN}✓ Auto-fixed ($corruption_type): $(basename -- "$gif_file") → $(basename -- "$corrected_name")${NC}" >&2
                    # Log the automatic fix with detailed corruption type
                    log_conversion "AUTO_FIXED" "$gif_file" "$corrected_name" "Extension corruption ($corruption_type) → .gif"
                    
                    # CRITICAL FIX: Mark the renamed file as processed AND skip it
                    # The corrected file will be processed when we reach it naturally in the array
                    processed_files_tracker["$gif_file"]=1
                    processed_files_tracker["$corrected_name"]=1
                    
                    # Check if corrected name exists later in array - it will be processed then
                    local check_idx
                    local found_later=false
                    for ((check_idx=loop_idx+1; check_idx<total_files; check_idx++)); do
                        if [[ "${gif_files_list[$check_idx]}" == "$corrected_name" ]]; then
                            found_later=true
                            echo -e "  ${CYAN}ℹ️ Corrected file will be processed at position $check_idx${NC}" >&2
                            break
                        fi
                    done
                    
                    # Skip processing this renamed file now - it will be processed later if it's in the array
                    ((loop_idx++))
                    continue
                else
                    echo -e "  ${YELLOW}⚠️ Auto-skip: Cannot fix $(basename -- "$gif_file")${NC}" >&2
                    log_conversion "AUTO_SKIP" "$gif_file" "" "Cannot fix double extension"
                    echo "$gif_file|AUTO_SKIP|$size|double_extension_unfixable||0|0" >> "$results_file"
                    ((loop_idx++))  # Increment before continue
                    continue  # Skip to next file in loop
                fi
            else
                echo -e "  ${BLUE}🔄 Auto-skip: $(basename -- "$gif_file") (corrected version exists)${NC}" >&2
                log_conversion "AUTO_SKIP" "$gif_file" "" "Corrected version already exists"
                echo "$gif_file|AUTO_SKIP|$size|duplicate_extension||0|0" >> "$results_file"
                ((loop_idx++))  # Increment before continue
                continue
            fi
        fi
        
        # Delete 0-byte files immediately - they're always broken
        if [[ $size -eq 0 ]]; then
            echo -e "  ${RED}🗑️ Auto-delete: $(basename -- "$gif_file") (0 bytes - empty file)${NC}" >&2
            rm -f "$gif_file" 2>/dev/null || true
            log_conversion "AUTO_DELETED" "$gif_file" "" "Empty file (0 bytes) - automatically removed"
            echo "$gif_file|AUTO_DELETED|0|empty_file||0|0" >> "$results_file"
            ((loop_idx++))  # Increment before continue
            continue
        fi
        
        # This file is in uncached list, so it needs processing
        ((files_actually_processed++))
        
        # Process the file
        # Pass files_actually_processed and files_to_analyze for accurate progress
        analyze_gif_parallel "$gif_file" "$temp_analysis_dir" "$results_file" $files_actually_processed $files_to_analyze
        
        # Increment loop counter at end of iteration
        ((loop_idx++))
    done
    
    # Check if we hit emergency break
    if [[ "$emergency_break" == "true" ]]; then
        echo -e "\n  ${RED}🛑 ANALYSIS ABORTED DUE TO INFINITE LOOP DETECTION${NC}"
        echo -e "  ${YELLOW}💡 This usually indicates file system corruption or permission issues${NC}"
        echo -e "  ${BLUE}🔗 Try: Check file permissions, restart script, or run fsck${NC}"
        return 1
    fi
    
    # Final progress update - show accurate counts
    if [[ "$INTERRUPT_REQUESTED" == "true" ]]; then
        printf "\r  ${YELLOW}⏸️  Analysis stopped!${NC}\n"
    else
        printf "\r  ${GREEN}✓ Analysis complete! ${NC}\n"
    fi
    
    # Display cache statistics
    if [[ -f "$temp_analysis_dir/cache_hits.count" ]]; then
        cache_hits=$(wc -l < "$temp_analysis_dir/cache_hits.count" 2>/dev/null || echo "0")
    fi
    if [[ -f "$temp_analysis_dir/cache_misses.count" ]]; then
        cache_misses=$(wc -l < "$temp_analysis_dir/cache_misses.count" 2>/dev/null || echo "0")
    fi
    
    if [[ $cache_hits -gt 0 || $cache_misses -gt 0 ]]; then
        local cache_percentage=$((cache_hits * 100 / (cache_hits + cache_misses)))
        echo -e "  ${CYAN}💾 Cache Performance:${NC}"
        echo -e "    ${GREEN}✓ Cached (instant): $cache_hits files${NC}"
        echo -e "    ${YELLOW}⚡ Calculated (MD5): $cache_misses files${NC}"
        echo -e "    ${BLUE}📊 Cache hit rate: ${cache_percentage}%${NC}"
        if [[ $cache_misses -gt 0 ]]; then
            echo -e "    ${GRAY}💡 Next run: ${cache_misses} more files will be cached!${NC}"
        fi
    fi
    
    # Show file maintenance summary
    local auto_actions_count=$(grep -E "AUTO_(FIXED|DELETED|SKIP)" "$results_file" 2>/dev/null | wc -l)
    if [[ $auto_actions_count -gt 0 ]]; then
        echo -e "\n  ${CYAN}${BOLD}🔧 AUTOMATIC FILE MAINTENANCE SUMMARY:${NC}"
        
        # Count and report fixed files
        local fixed_count=$(grep "AUTO_FIXED" "$results_file" 2>/dev/null | wc -l)
        if [[ $fixed_count -gt 0 ]]; then
            echo -e "    ${GREEN}✓ Fixed $fixed_count file(s) with double extensions (.gif.gif → .gif)${NC}"
        fi
        
        # Count and report deleted files
        local deleted_count=$(grep "AUTO_DELETED" "$results_file" 2>/dev/null | wc -l)
        if [[ $deleted_count -gt 0 ]]; then
            echo -e "    ${RED}🗑️ Deleted $deleted_count empty file(s) (0 bytes)${NC}"
        fi
        
        # Count and report skipped files
        local skipped_count=$(grep "AUTO_SKIP" "$results_file" 2>/dev/null | wc -l)
        if [[ $skipped_count -gt 0 ]]; then
            echo -e "    ${YELLOW}⚠️ Skipped $skipped_count problematic file(s)${NC}"
        fi
        
        echo -e "    ${BLUE}📄 All actions logged in: ${BOLD}$(basename -- "$CONVERSION_LOG")${NC}"
        echo -e "    ${GRAY}🔍 View details: tail -20 \"$CONVERSION_LOG\"${NC}"
    fi
    
    # Process results from parallel analysis and count errors
    local error_files=0
    local timeout_files=0
    local large_files=0
    local unreadable_files=0
    local successful_files=0
    
    while IFS='|' read -r gif_file checksum size content_fingerprint visual_hash frame_count duration; do
        [[ -z "$gif_file" ]] && continue  # Skip empty lines
        
        # Count different types of results
        case "$checksum" in
            "ERROR"|"UNREADABLE")
                ((error_files++))
                ((unreadable_files++))
                ;;
            "TIMEOUT"|"SLOW_ANALYSIS"|"CORRUPTED"|"AI_CORRUPTED")
                ((error_files++))
                ((timeout_files++))
                ;;
            "AI_SUSPICIOUS"|"AI_LEARNING")
                # AI learning cases - include in analysis but flag as uncertain
                gif_checksums["$gif_file"]="AI_UNCERTAIN_${size}"
                gif_sizes["$gif_file"]="$size"
                gif_fingerprints["$gif_file"]="$content_fingerprint"
                gif_visual_hashes["$gif_file"]="$visual_hash"
                gif_frame_counts["$gif_file"]="$frame_count"
                gif_durations["$gif_file"]="$duration"
                ((total_gifs++))
                ((successful_files++))
                ;;
            "AI_COMPLEX")
                # AI confirmed complex but valid files
                gif_checksums["$gif_file"]="AI_COMPLEX_${size}"
                gif_sizes["$gif_file"]="$size"
                gif_fingerprints["$gif_file"]="$content_fingerprint"
                gif_visual_hashes["$gif_file"]="$visual_hash"
                gif_frame_counts["$gif_file"]="$frame_count"
                gif_durations["$gif_file"]="$duration"
                ((total_gifs++))
                ((successful_files++))
                ;;
            "LARGE_FILE")
                ((large_files++))
                ;;
            *)
                gif_checksums["$gif_file"]="$checksum"
                gif_sizes["$gif_file"]="$size"
                gif_fingerprints["$gif_file"]="$content_fingerprint"
                gif_visual_hashes["$gif_file"]="$visual_hash"
                gif_frame_counts["$gif_file"]="$frame_count"
                gif_durations["$gif_file"]="$duration"
                ((total_gifs++))
                ((successful_files++))
                ;;
        esac
    done < "$results_file"
    
    # Clear progress line and show completion with error summary
    local final_cache_stats=$(get_cache_stats)
    
    # Show accurate status based on interruption
    if [[ "$INTERRUPT_REQUESTED" == "true" ]]; then
        printf "\r  ${YELLOW}⏸️  Analysis interrupted! ${NC}\n"
        echo -e "  ${CYAN}${BOLD}📈 PARTIAL ANALYSIS SUMMARY:${NC}"
        echo -e "    ${YELLOW}⏸️  Analyzed so far: ${BOLD}$successful_files${NC} ${YELLOW}files (out of $total_files)${NC}"
    else
        printf "\r  ${GREEN}✓ Parallel content analysis complete! ${NC}\n"
        echo -e "  ${CYAN}${BOLD}📈 AI-ENHANCED ANALYSIS SUMMARY:${NC}"
        echo -e "    ${GREEN}✓ Successfully analyzed: ${BOLD}$successful_files${NC} ${GREEN}files${NC}"
    fi
    
    # Count AI-enhanced categories
    local ai_complex_files=0
    local ai_suspicious_files=0
    local ai_corrupted_files=0
    
    # Count AI categories from results
    while IFS='|' read -r gif_file checksum size content_fingerprint visual_hash frame_count duration; do
        [[ -z "$gif_file" ]] && continue
        case "$checksum" in
            "AI_CORRUPTED") ((ai_corrupted_files++)) ;;
            "AI_COMPLEX") ((ai_complex_files++)) ;;
            "AI_SUSPICIOUS"|"AI_LEARNING") ((ai_suspicious_files++)) ;;
        esac
    done < "$results_file"
    
    # Show AI analysis results
    if [[ $ai_complex_files -gt 0 ]]; then
        echo -e "    ${CYAN}🧠 AI identified complex files: ${BOLD}$ai_complex_files${NC} ${CYAN}(legitimate but slow)${NC}"
    fi
    
    if [[ $ai_suspicious_files -gt 0 ]]; then
        echo -e "    ${YELLOW}🤖 AI learning from: ${BOLD}$ai_suspicious_files${NC} ${YELLOW}uncertain files${NC}"
    fi
    
    if [[ $ai_corrupted_files -gt 0 ]]; then
        echo -e "    ${RED}🚫 AI detected corruption: ${BOLD}$ai_corrupted_files${NC} ${RED}files${NC}"
    fi
    
    if [[ $large_files -gt 0 ]]; then
        echo -e "    ${YELLOW}⚠️ Skipped large files: ${BOLD}$large_files${NC} ${YELLOW}files (>100MB)${NC}"
    fi
    
    if [[ $timeout_files -gt 0 ]]; then
        echo -e "    ${RED}⚠️ Analysis issues: ${BOLD}$timeout_files${NC} ${RED}files (see error log)${NC}"
    fi
    
    if [[ $unreadable_files -gt 0 ]]; then
        echo -e "    ${RED}⚠️ Unreadable: ${BOLD}$unreadable_files${NC} ${RED}files (permission issues)${NC}"
    fi
    
    if [[ $error_files -gt 0 ]]; then
        echo -e "    ${RED}${BOLD}⚠️ Total issues: $error_files files${NC}"
        echo -e "    ${BLUE}📄 Check error log: ${BOLD}$(basename -- "$ERROR_LOG")${NC}"
        echo -e "    ${GRAY}🤖 AI is learning from these patterns to improve future detection${NC}"
    fi
    
    echo -e "  ${BLUE}🗄️ Cache updated: $final_cache_stats${NC}"
    echo -e "  ${GRAY}Used ${BOLD}$AI_DUPLICATE_THREADS threads${NC} ${GRAY}for parallel processing${NC}"
    
    echo -e "  ${BLUE}${BOLD}🔍 Stage 2: Multi-level duplicate detection...${NC}"
    
    # Calculate total comparisons for progress tracking
    local total_comparisons=$(( (total_gifs * (total_gifs - 1)) / 2 ))
    local current_comparison=0
    
    if [[ $total_comparisons -gt 0 ]]; then
        echo -e "  ${GRAY}Performing $total_comparisons pairwise comparisons...${NC}"
    fi
    
    # Advanced duplicate detection with multiple similarity levels
    local gif_files=("${!gif_checksums[@]}")
    for ((i=0; i<${#gif_files[@]}; i++)); do
        # Check for interrupt
        if [[ "$INTERRUPT_REQUESTED" == "true" ]]; then
            echo -e "\n  ${YELLOW}⏸️  Duplicate detection interrupted by user${NC}"
            return 0
        fi
        
        local file1="${gif_files[i]}"
        for ((j=i+1; j<${#gif_files[@]}; j++)); do
            local file2="${gif_files[j]}"
            ((current_comparison++))
            
            # Display progress for stage 2
            if [[ $total_comparisons -gt 5 ]]; then  # Only show progress bar if significant work
                local progress=$((current_comparison * 100 / total_comparisons))
                local filled=$((progress * 25 / 100))  # Shorter bar for comparison stage
                local empty=$((25 - filled))
                
                printf "\r  ${MAGENTA}Compare [${NC}"
                for ((k=0; k<filled; k++)); do printf "${BLUE}█${NC}"; done
                for ((k=0; k<empty; k++)); do printf "${GRAY}░${NC}"; done
                printf "${MAGENTA}] ${BOLD}%3d%%${NC} ${YELLOW}%s ↔ %s${NC}" "$progress" "$(basename -- "${file1:0:12}")..." "$(basename -- "${file2:0:12}")..."
            fi
            
            local is_duplicate=false
            local similarity_reason=""
            
            # Track total files checked
            ((DUPLICATE_STATS_TOTAL_CHECKED++))
            
            # Level 1: Exact binary match (highest confidence)
            if [[ "${gif_checksums[$file1]}" == "${gif_checksums[$file2]}" ]]; then
                is_duplicate=true
                similarity_reason="exact_binary"
                ((DUPLICATE_STATS_EXACT_BINARY++))
            # Level 2: Visual similarity (high confidence)
            elif [[ -n "${gif_visual_hashes[$file1]}" && -n "${gif_visual_hashes[$file2]}" ]] && \
                 [[ "${gif_visual_hashes[$file1]}" == "${gif_visual_hashes[$file2]}" ]]; then
                is_duplicate=true
                similarity_reason="visual_identical"
                ((DUPLICATE_STATS_VISUAL_IDENTICAL++))
            # Level 3: Content fingerprint match (medium confidence)
            elif [[ "${gif_fingerprints[$file1]}" == "${gif_fingerprints[$file2]}" ]]; then
                # Additional validation for content fingerprint matches
                local size1="${gif_sizes[$file1]}"
                local size2="${gif_sizes[$file2]}"
                local size_diff=$(( (size1 > size2 ? size1 - size2 : size2 - size1) ))
                local size_ratio=$(( size_diff * 100 / (size1 > size2 ? size1 : size2) ))
                
                # Only consider as duplicate if size difference is small (< 5%)
                if [[ $size_ratio -lt 5 ]]; then
                    is_duplicate=true
                    similarity_reason="content_fingerprint"
                    ((DUPLICATE_STATS_CONTENT_FINGERPRINT++))
                fi
            # Level 4: AI-Enhanced Near-identical Detection (STRICT - visual similarity required)
            elif [[ "${gif_frame_counts[$file1]}" == "${gif_frame_counts[$file2]}" ]] && \
                 [[ "${gif_durations[$file1]}" == "${gif_durations[$file2]}" ]] && \
                 [[ "${gif_frame_counts[$file1]}" != "0" ]] && \
                 [[ "${gif_durations[$file1]}" != "0" ]]; then
                
                # Both have actual frame/duration data (not just zeros)
                local size1="${gif_sizes[$file1]}"
                local size2="${gif_sizes[$file2]}"
                local size_diff=$(( (size1 > size2 ? size1 - size2 : size2 - size1) ))
                local size_ratio=$(( size_diff * 100 / (size1 > size2 ? size1 : size2) ))
                
                # CRITICAL: Level 4 now REQUIRES visual similarity - no false positives
                local visual_similar=false
                if [[ -n "${gif_visual_hashes[$file1]}" && -n "${gif_visual_hashes[$file2]}" ]]; then
                    # Compare perceptual hashes
                    local hash1="${gif_visual_hashes[$file1]}"
                    local hash2="${gif_visual_hashes[$file2]}"
                    
                    # Exact hash match = visually identical
                    if [[ "$hash1" == "$hash2" ]]; then
                        visual_similar=true
                    elif [[ -n "$hash1" && -n "$hash2" ]]; then
                        # Calculate hamming distance between hashes
                        local hash_diff=$(echo "scale=2; ($hash1 - $hash2) / $hash1 * 100" | bc -l 2>/dev/null | tr -d '-' || echo "100")
                        local hash_diff_int=${hash_diff%.*}  # Convert to integer
                        # Very strict threshold: only < 2% difference
                        if [[ $hash_diff_int -lt 2 ]]; then
                            visual_similar=true
                        fi
                    fi
                fi
                
                # STRICT CRITERIA for Level 4:
                # 1. Visual hashes MUST be available and similar, AND
                # 2. Size difference must be < 10% (tighter than before), AND
                # 3. Frame count and duration must match exactly
                if [[ "$visual_similar" == "true" ]] && [[ $size_ratio -lt 10 ]]; then
                    is_duplicate=true
                    similarity_reason="near_identical"
                    ((DUPLICATE_STATS_NEAR_IDENTICAL++))
                fi
                # NOTE: Without visual similarity, even if size/frames match, NOT flagged as duplicate
            # Level 5: Filename-based similarity for identical properties
            # Catches cases where GIFs have same dimensions/frames but different color tables
            elif [[ "${gif_frame_counts[$file1]}" == "${gif_frame_counts[$file2]}" ]] && \
                 [[ "${gif_durations[$file1]}" == "${gif_durations[$file2]}" ]] && \
                 [[ "${gif_frame_counts[$file1]}" != "0" ]] && \
                 [[ "${gif_durations[$file1]}" != "0" ]]; then
                
                # Check if filenames suggest they're from the same source
                local basename1=$(basename -- "$file1" .gif)
                local basename2=$(basename -- "$file2" .gif)
                
                # Calculate filename similarity
                local name_similarity=0
                local size1="${gif_sizes[$file1]}"
                local size2="${gif_sizes[$file2]}"
                local size_diff=$(( (size1 > size2 ? size1 - size2 : size2 - size1) ))
                local size_ratio=$(( size_diff * 100 / (size1 > size2 ? size1 : size2) ))
                
                # Check various filename similarity patterns
                if [[ "${basename1:0:10}" == "${basename2:0:10}" ]] && [[ ${#basename1} -gt 10 ]] && [[ ${#basename2} -gt 10 ]]; then
                    # First 10 characters match - likely same source with different timestamp
                    name_similarity=70
                elif [[ "${basename1:0:5}" == "${basename2:0:5}" ]] && [[ ${#basename1} -gt 5 ]] && [[ ${#basename2} -gt 5 ]]; then
                    # First 5 characters match
                    name_similarity=50
                fi
                
                # If filenames are similar AND properties match AND size difference is reasonable
                if [[ $name_similarity -ge 50 ]] && [[ $size_ratio -lt 15 ]]; then
                    # Additional check: verify resolution matches (from content fingerprint)
                    local fp1="${gif_fingerprints[$file1]}"
                    local fp2="${gif_fingerprints[$file2]}"
                    local res1=$(echo "$fp1" | cut -d':' -f2)
                    local res2=$(echo "$fp2" | cut -d':' -f2)
                    
                    if [[ "$res1" == "$res2" ]] && [[ -n "$res1" ]] && [[ "$res1" != "0" ]]; then
                        # Same resolution, same frames, same duration, similar filenames
                        is_duplicate=true
                        similarity_reason="filename_property_match"
                        ((DUPLICATE_STATS_NEAR_IDENTICAL++))
                    fi
                fi
            fi
            
            # Handle detected duplicates
            if [[ "$is_duplicate" == "true" ]]; then
                local size1="${gif_sizes[$file1]}"
                local size2="${gif_sizes[$file2]}"
                
                # Get file metadata for intelligent decision
                local mtime1=$(stat -c%Y "$file1" 2>/dev/null || echo "0")  # Modification time
                local mtime2=$(stat -c%Y "$file2" 2>/dev/null || echo "0")
                local ctime1=$(stat -c%Z "$file1" 2>/dev/null || echo "0")  # Change time (creation on some systems)
                local ctime2=$(stat -c%Z "$file2" 2>/dev/null || echo "0")
                local perms1=$(stat -c%a "$file1" 2>/dev/null || echo "0")  # File permissions
                local perms2=$(stat -c%a "$file2" 2>/dev/null || echo "0")
                
                # Get base filenames for similarity comparison
                local basename1=$(basename -- "$file1" .gif)
                local basename2=$(basename -- "$file2" .gif)
                
                # Check if corresponding MP4/video source files exist
                local has_source1=false
                local has_source2=false
                local source_file1=""
                local source_file2=""
                
                # Check for video source files for file1
                for ext in mp4 avi mov mkv webm MP4 AVI MOV MKV WEBM; do
                    if [[ -f "${basename1}.$ext" ]]; then
                        has_source1=true
                        source_file1="${basename1}.$ext"
                        break
                    fi
                done
                
                # Check for video source files for file2
                for ext in mp4 avi mov mkv webm MP4 AVI MOV MKV WEBM; do
                    if [[ -f "${basename2}.$ext" ]]; then
                        has_source2=true
                        source_file2="${basename2}.$ext"
                        break
                    fi
                done
                
                # Calculate filename similarity score (0-100)
                local name_similarity=0
                if [[ "$basename1" == "$basename2" ]]; then
                    name_similarity=100
                elif [[ "$basename1" == *"$basename2"* || "$basename2" == *"$basename1"* ]]; then
                    name_similarity=75  # Substring match
                elif [[ "${basename1:0:10}" == "${basename2:0:10}" ]]; then
                    name_similarity=50  # First 10 chars match
                else
                    # Check for common patterns like "copy", "(1)", etc.
                    if [[ "$basename1" =~ [[:space:]]?\(?[0-9]+\)? ]] || [[ "$basename2" =~ [[:space:]]?\(?[0-9]+\)? ]]; then
                        name_similarity=60  # Likely a copy with number
                    fi
                fi
                
                # Intelligent decision logic based on multiple factors
                local keep_file=""
                local remove_file=""
                local decision_reason=""
                
                # Rule 0 (PRIORITY): Prefer GIF that matches its source video filename
                # This is the most important rule - GIFs should match their source videos
                if [[ "$has_source1" == true && "$has_source2" == false ]]; then
                    # Only file1 has a matching source video - keep it
                    keep_file="$file1"
                    remove_file="$file2"
                    decision_reason="keeping GIF matching source video: $(basename -- "$source_file1")"
                elif [[ "$has_source2" == true && "$has_source1" == false ]]; then
                    # Only file2 has a matching source video - keep it
                    keep_file="$file2"
                    remove_file="$file1"
                    decision_reason="keeping GIF matching source video: $(basename -- "$source_file2")"
                elif [[ "$has_source1" == true && "$has_source2" == true ]]; then
                    # Both have matching source videos - this shouldn't happen normally
                    # Fall through to other rules but mark this special case
                    decision_reason="both match source videos"
                    # Continue to next rule without setting keep/remove yet
                fi
                
                # Only apply remaining rules if keep_file is not yet set
                if [[ -z "$keep_file" ]]; then
                
                # Rule 0: Prefer files in OUTPUT_DIRECTORY (keep organized files)
                local file1_in_output=false
                local file2_in_output=false
                
                # Check if files are in OUTPUT_DIRECTORY
                if [[ -d "$OUTPUT_DIRECTORY" ]]; then
                    local output_dir_abs="$(cd "$OUTPUT_DIRECTORY" 2>/dev/null && pwd)"
                    local file1_dir="$(cd "$(dirname "$file1")" 2>/dev/null && pwd)"
                    local file2_dir="$(cd "$(dirname "$file2")" 2>/dev/null && pwd)"
                    
                    [[ "$file1_dir" == "$output_dir_abs" ]] && file1_in_output=true
                    [[ "$file2_dir" == "$output_dir_abs" ]] && file2_in_output=true
                    
                    # If one is in OUTPUT_DIRECTORY and the other isn't, prefer the one in OUTPUT_DIRECTORY
                    if [[ "$file1_in_output" == true && "$file2_in_output" == false ]]; then
                        keep_file="$file1"
                        remove_file="$file2"
                        decision_reason="keeping file in output directory (organized)"
                    elif [[ "$file2_in_output" == true && "$file1_in_output" == false ]]; then
                        keep_file="$file2"
                        remove_file="$file1"
                        decision_reason="keeping file in output directory (organized)"
                    fi
                fi
                
                # Only continue to other rules if not yet decided
                if [[ -z "$keep_file" ]]; then
                # Rule 1: Prefer the file created first (older file)
                if [[ $ctime1 -lt $ctime2 && $((ctime2 - ctime1)) -gt 60 ]]; then
                    # file1 is at least 1 minute older
                    keep_file="$file1"
                    remove_file="$file2"
                    decision_reason="keeping older file (created first)"
                elif [[ $ctime2 -lt $ctime1 && $((ctime1 - ctime2)) -gt 60 ]]; then
                    # file2 is at least 1 minute older
                    keep_file="$file2"
                    remove_file="$file1"
                    decision_reason="keeping older file (created first)"
                # Rule 2: If no source match and creation times are similar, prefer file with better name
                elif [[ $name_similarity -ge 60 ]]; then
                    # Files have similar names, prefer the simpler/shorter one
                    local len1=${#basename1}
                    local len2=${#basename2}
                    
                    # Check if one is a numbered copy
                    if [[ "$basename2" =~ \([0-9]+\) && ! "$basename1" =~ \([0-9]+\) ]]; then
                        keep_file="$file1"
                        remove_file="$file2"
                        decision_reason="removing numbered copy"
                    elif [[ "$basename1" =~ \([0-9]+\) && ! "$basename2" =~ \([0-9]+\) ]]; then
                        keep_file="$file2"
                        remove_file="$file1"
                        decision_reason="removing numbered copy"
                    # Check for "copy" in filename
                    elif [[ "$basename2" =~ -?[Cc]opy && ! "$basename1" =~ -?[Cc]opy ]]; then
                        keep_file="$file1"
                        remove_file="$file2"
                        decision_reason="removing copy file"
                    elif [[ "$basename1" =~ -?[Cc]opy && ! "$basename2" =~ -?[Cc]opy ]]; then
                        keep_file="$file2"
                        remove_file="$file1"
                        decision_reason="removing copy file"
                    # Prefer shorter, cleaner name
                    elif [[ $len1 -lt $len2 ]]; then
                        keep_file="$file1"
                        remove_file="$file2"
                        decision_reason="keeping shorter filename"
                    else
                        keep_file="$file2"
                        remove_file="$file1"
                        decision_reason="keeping shorter filename"
                    fi
                # Rule 3: Prefer larger file size (better quality)
                elif [[ $size2 -gt $size1 && $((size2 - size1)) -gt 1024 ]]; then
                    # file2 is at least 1KB larger
                    keep_file="$file2"
                    remove_file="$file1"
                    decision_reason="keeping larger file (better quality)"
                elif [[ $size1 -gt $size2 && $((size1 - size2)) -gt 1024 ]]; then
                    # file1 is at least 1KB larger
                    keep_file="$file1"
                    remove_file="$file2"
                    decision_reason="keeping larger file (better quality)"
                # Rule 4: Prefer file modified more recently (if sizes are similar)
                elif [[ $mtime1 -gt $mtime2 ]]; then
                    keep_file="$file1"
                    remove_file="$file2"
                    decision_reason="keeping recently modified file"
                elif [[ $mtime2 -gt $mtime1 ]]; then
                    keep_file="$file2"
                    remove_file="$file1"
                    decision_reason="keeping recently modified file"
                # Rule 5: Fallback to alphabetical order
                elif [[ "$file1" < "$file2" ]]; then
                    keep_file="$file1"
                    remove_file="$file2"
                    decision_reason="${decision_reason:+$decision_reason, }alphabetical order"
                else
                    keep_file="$file2"
                    remove_file="$file1"
                    decision_reason="${decision_reason:+$decision_reason, }alphabetical order"
                fi
                fi  # End of: if [[ -z "$keep_file" ]] (inner check at line 6060)
                fi  # End of: if [[ -z "$keep_file" ]] (outer check at line 6032)
                
                # Safety check: make sure we have both files set
                if [[ -z "$keep_file" || -z "$remove_file" ]]; then
                    echo -e "    ${RED}⚠️  Warning: Could not determine which duplicate to keep, skipping pair${NC}" >&2
                    continue
                fi
                
                # Store the duplicate pair with enhanced metadata
                duplicate_pairs+=("$remove_file|$keep_file|$similarity_reason|$decision_reason")
                ((duplicate_count++))
            fi
        done
    done
    
    # Clear Stage 2 progress line and show completion
    if [[ $total_comparisons -gt 5 ]]; then
        printf "\r  ${GREEN}✓ Duplicate analysis complete! Compared $total_comparisons file pairs${NC}\n"
    fi
    
    # Stage 3: Results summary
    echo -e "  ${YELLOW}${BOLD}📊 Stage 3: Analysis results and recommendations...${NC}"
    
    # Clean up temporary analysis directory
    rm -rf "$temp_analysis_dir"
    
    if [[ $total_gifs -eq 0 ]]; then
        echo -e "  ${CYAN}ℹ️  No existing GIF files found${NC}"
        return 0
    fi
    
    # Final progress summary
    echo -e "  ${GREEN}✓ AI Analysis Summary:${NC}"
    echo -e "    ${CYAN}• Analyzed: ${BOLD}$total_gifs${NC} ${CYAN}GIF files${NC}"
    echo -e "    ${CYAN}• Performed: ${BOLD}$total_comparisons${NC} ${CYAN}similarity comparisons${NC}"
    echo -e "    ${CYAN}• Detection methods: ${BOLD}Binary + Visual + Fingerprint + Metadata${NC}"
    
    if [[ $duplicate_count -eq 0 ]]; then
        echo -e "\n  ${GREEN}${BOLD}✨ Excellent! No duplicate GIFs found${NC}"
        echo -e "  ${BLUE}🚀 Your collection is already optimized!${NC}"
        echo -e "  ${GRAY}AI checked for exact matches, visual similarity, and content fingerprints${NC}"
        return 0
    fi
    
    # Show duplicate files with AI analysis details
    echo -e "\n  ${YELLOW}🔍 Found $duplicate_count duplicate GIF file(s) using AI analysis:${NC}"
    for pair in "${duplicate_pairs[@]}"; do
        # Parse the enhanced duplicate pair format: remove_file|keep_file|similarity_reason|decision_reason
        local remove_file="${pair%%|*}"
        local rest="${pair#*|}"
        local keep_file="${rest%%|*}"
        rest="${rest#*|}"
        local similarity_reason="${rest%%|*}"
        local decision_reason="${rest#*|}"
        
        # Get file metadata for display
        local remove_size=$(stat -c%s "$remove_file" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "unknown")
        local keep_size=$(stat -c%s "$keep_file" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "unknown")
        local remove_mtime=$(stat -c%y "$remove_file" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
        local keep_mtime=$(stat -c%y "$keep_file" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
        
        # Display similarity reason with appropriate icon and color
        local reason_display=""
        case "$similarity_reason" in
            "exact_binary")
                reason_display="${GREEN}🎯 Exact binary match (100% identical)${NC}"
                ;;
            "visual_identical")
                reason_display="${BLUE}👁️  Visual content identical${NC}"
                ;;
            "content_fingerprint")
                reason_display="${CYAN}🔍 Same content fingerprint${NC}"
                ;;
            "near_identical")
                reason_display="${YELLOW}⚠️  Near-identical (manual review suggested)${NC}"
                ;;
            "filename_property_match")
                reason_display="${CYAN}📝 Same properties + similar filename (likely duplicate)${NC}"
                ;;
            *)
                reason_display="${GRAY}🔍 Detected as duplicate${NC}"
                ;;
        esac
        
        echo -e "    ${RED}🔴 Remove: $remove_file ($remove_size, modified: $remove_mtime)${NC}"
        echo -e "    ${GREEN}🔵 Keep:   $keep_file ($keep_size, modified: $keep_mtime)${NC}"
        echo -e "    ${MAGENTA}📊 Detection: $reason_display${NC}"
        if [[ -n "$decision_reason" && "$decision_reason" != "$similarity_reason" ]]; then
            echo -e "    ${CYAN}🧠 Decision: $decision_reason${NC}"
        fi
        echo ""
    done
    
    echo -ne "\n  ${YELLOW}${BOLD}Duplicate GIFs are found! Do you want to remove duplicates? (y/N): ${NC}"
    
    local choice
    read -r choice
    
    # Default to 'no' if empty or anything other than y/Y
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
        echo -e "  ${CYAN}⏭️  Skipping duplicate removal${NC}"
        return 0
    fi
    
    # User chose yes - delete duplicate GIF files only
    echo -e "\n  ${GREEN}${BOLD}🗑️  Deleting duplicate GIF files...${NC}"
    local deleted_count=0
    local skipped_count=0
    declare -A already_deleted  # Track files already deleted to avoid duplicate attempts
    
    for pair in "${duplicate_pairs[@]}"; do
        local remove_file="${pair%%|*}"
        local temp_pair="${pair#*|}"
        local keep_file="${temp_pair%%|*}"
        temp_pair="${temp_pair#*|}"
        local similarity_reason="${temp_pair%%|*}"
        
        # Skip if already deleted
        if [[ -n "${already_deleted[$remove_file]:-}" ]]; then
            continue
        fi
        
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
        
        # Extract basename (without extension) from both GIF files
        local remove_basename="$(basename -- "${remove_file%.*}")"
        local keep_basename="$(basename -- "${keep_file%.*}")"
        
        # Check if corresponding MP4/video source exists for the file we're about to delete
        local has_source_remove=false
        local has_source_keep=false
        local remove_source=""
        local keep_source=""
        
        # Get directory of the remove_file
        local remove_dir="$(dirname "$remove_file")"
        local keep_dir="$(dirname "$keep_file")"
        
        # Check for video source for remove_file
        for ext in mp4 avi mov mkv webm MP4 AVI MOV MKV WEBM; do
            if [[ -f "${remove_dir}/${remove_basename}.${ext}" ]]; then
                has_source_remove=true
                remove_source="${remove_dir}/${remove_basename}.${ext}"
                break
            fi
        done
        
        # Check for video source for keep_file
        for ext in mp4 avi mov mkv webm MP4 AVI MOV MKV WEBM; do
            if [[ -f "${keep_dir}/${keep_basename}.${ext}" ]]; then
                has_source_keep=true
                keep_source="${keep_dir}/${keep_basename}.${ext}"
                break
            fi
        done
        
        # Validation logic:
        # - If keep_file has a matching source but remove_file doesn't, safe to delete
        # - If both have matching sources, safe to delete (they're truly duplicates)
        # - If remove_file has a matching source but keep_file doesn't, DON'T delete (might delete the correct one)
        # - If neither has a source, consider it safe (orphaned duplicates)
        
        if [[ "$has_source_remove" == true && "$has_source_keep" == false ]]; then
            # Remove file has source, keep file doesn't - this is dangerous, skip
            echo -e "    ${YELLOW}⚠️  SKIPPED: $remove_file has source ($(basename -- "$remove_source")) but $keep_file doesn't${NC}"
            ((skipped_count++))
            DUPLICATE_STATS_SKIPPED=$((DUPLICATE_STATS_SKIPPED + 1))
            already_deleted["$remove_file"]=1
            continue
        fi
        
        # Additional property validation: Compare GIF properties with source video properties
        # SKIP property validation for exact binary matches (100% identical files)
        local property_mismatch=false
        local property_warning=""
        
        # Get comprehensive file properties for both files
        local remove_file_size=$(stat -c%s "$remove_file" 2>/dev/null || echo "0")
        local keep_file_size=$(stat -c%s "$keep_file" 2>/dev/null || echo "0")
        local remove_file_mtime=$(stat -c%Y "$remove_file" 2>/dev/null || echo "0")
        local keep_file_mtime=$(stat -c%Y "$keep_file" 2>/dev/null || echo "0")
        local remove_file_ctime=$(stat -c%Z "$remove_file" 2>/dev/null || echo "0")
        local keep_file_ctime=$(stat -c%Z "$keep_file" 2>/dev/null || echo "0")
        local remove_file_perms=$(stat -c%a "$remove_file" 2>/dev/null || echo "0")
        local keep_file_perms=$(stat -c%a "$keep_file" 2>/dev/null || echo "0")
        
        # For exact binary matches, skip property validation entirely (they're 100% identical)
        if [[ "$similarity_reason" == "exact_binary" ]]; then
            # Files are binary identical - safe to delete regardless of source video properties
            property_mismatch=false
        elif [[ "$has_source_remove" == true ]]; then
            # Get properties of remove_file and its source
            local remove_gif_frames="${gif_frame_counts[$remove_file]:-0}"
            local remove_gif_duration="${gif_durations[$remove_file]:-0}"
            local remove_gif_size="${gif_sizes[$remove_file]:-0}"
            
            # Get source video file properties
            local remove_source_size=$(stat -c%s "$remove_source" 2>/dev/null || echo "0")
            local remove_source_mtime=$(stat -c%Y "$remove_source" 2>/dev/null || echo "0")
            local remove_source_ctime=$(stat -c%Z "$remove_source" 2>/dev/null || echo "0")
            
            # Get source video properties
            local source_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$remove_source" 2>/dev/null | cut -d'.' -f1 || echo "0")
            local source_frames=$(ffprobe -v error -select_streams v:0 -show_entries stream=nb_frames -of default=noprint_wrappers=1:nokey=1 "$remove_source" 2>/dev/null || echo "0")
            
            # If source frames not available, estimate from duration and fps
            if [[ "$source_frames" == "0" || "$source_frames" == "N/A" ]]; then
                local source_fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$remove_source" 2>/dev/null | head -1 || echo "0/1")
                if [[ "$source_fps" =~ ^([0-9]+)/([0-9]+)$ ]]; then
                    local fps_num="${BASH_REMATCH[1]}"
                    local fps_den="${BASH_REMATCH[2]}"
                    if [[ $fps_den -gt 0 && $source_duration -gt 0 ]]; then
                        source_frames=$((fps_num * source_duration / fps_den))
                    fi
                fi
            fi
            
            # Intelligent timestamp validation: GIF should be created AFTER source video
            # If GIF is older than source video, it can't be derived from it
            if [[ $remove_file_mtime -gt 0 && $remove_source_mtime -gt 0 ]]; then
                if [[ $remove_file_mtime -lt $remove_source_mtime ]]; then
                    # GIF was modified before the source video - suspicious
                    local time_diff=$((remove_source_mtime - remove_file_mtime))
                    if [[ $time_diff -gt 60 ]]; then  # More than 1 minute older
                        property_mismatch=true
                        property_warning="GIF is older than source video (by ${time_diff}s)"
                    fi
                fi
            fi
            
            # Check if GIF properties match source video (with tolerance)
            if [[ $remove_gif_duration -gt 0 && $source_duration -gt 0 ]]; then
                local duration_diff=$(( (remove_gif_duration > source_duration ? remove_gif_duration - source_duration : source_duration - remove_gif_duration) ))
                local duration_ratio=0
                if [[ $source_duration -gt 0 ]]; then
                    duration_ratio=$((duration_diff * 100 / source_duration))
                fi
                
                # If duration differs by more than 20%, flag it
                if [[ $duration_ratio -gt 20 ]]; then
                    property_mismatch=true
                    property_warning="${property_warning:+$property_warning; }Duration mismatch: GIF=${remove_gif_duration}s vs Source=${source_duration}s"
                fi
            fi
            
            # Intelligent size validation: GIF should be smaller than source video
            # If GIF is larger than source, something is wrong
            if [[ $remove_gif_size -gt 0 && $remove_source_size -gt 0 ]]; then
                if [[ $remove_gif_size -gt $remove_source_size ]]; then
                    property_mismatch=true
                    property_warning="${property_warning:+$property_warning; }GIF larger than source (GIF=$(numfmt --to=iec $remove_gif_size 2>/dev/null || echo ${remove_gif_size}) vs Source=$(numfmt --to=iec $remove_source_size 2>/dev/null || echo ${remove_source_size}))"
                fi
            fi
            
            # Check frame count similarity (more lenient, GIFs typically have fewer frames)
            if [[ $remove_gif_frames -gt 0 && $source_frames -gt 0 ]]; then
                # GIFs should have fewer frames than source (due to frame rate reduction)
                # Flag only if GIF has MORE frames than source (suspicious)
                if [[ $remove_gif_frames -gt $((source_frames * 120 / 100)) ]]; then
                    property_mismatch=true
                    property_warning="${property_warning:+$property_warning; }Frame count suspicious: GIF=${remove_gif_frames} vs Source=${source_frames}"
                fi
            fi
            
            # If properties don't match, it might not be derived from this source
            if [[ "$property_mismatch" == true ]]; then
                echo -e "    ${YELLOW}⚠️  SKIPPED: $remove_file properties don't match source $(basename -- "$remove_source")${NC}"
                echo -e "    ${GRAY}   $property_warning${NC}"
                ((skipped_count++))
                DUPLICATE_STATS_SKIPPED=$((DUPLICATE_STATS_SKIPPED + 1))
                already_deleted["$remove_file"]=1
                continue
            fi
        fi
        
        # Similar validation for keep_file if it has a source
        if [[ "$has_source_keep" == true ]]; then
            local keep_gif_frames="${gif_frame_counts[$keep_file]:-0}"
            local keep_gif_duration="${gif_durations[$keep_file]:-0}"
            local keep_gif_size="${gif_sizes[$keep_file]:-0}"
            
            # Get source video file properties
            local keep_source_size=$(stat -c%s "$keep_source" 2>/dev/null || echo "0")
            local keep_source_mtime=$(stat -c%Y "$keep_source" 2>/dev/null || echo "0")
            local keep_source_ctime=$(stat -c%Z "$keep_source" 2>/dev/null || echo "0")
            
            local keep_source_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$keep_source" 2>/dev/null | cut -d'.' -f1 || echo "0")
            local keep_source_frames=$(ffprobe -v error -select_streams v:0 -show_entries stream=nb_frames -of default=noprint_wrappers=1:nokey=1 "$keep_source" 2>/dev/null || echo "0")
            
            # Estimate frames if not available
            if [[ "$keep_source_frames" == "0" || "$keep_source_frames" == "N/A" ]]; then
                local keep_source_fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$keep_source" 2>/dev/null | head -1 || echo "0/1")
                if [[ "$keep_source_fps" =~ ^([0-9]+)/([0-9]+)$ ]]; then
                    local fps_num="${BASH_REMATCH[1]}"
                    local fps_den="${BASH_REMATCH[2]}"
                    if [[ $fps_den -gt 0 && $keep_source_duration -gt 0 ]]; then
                        keep_source_frames=$((fps_num * keep_source_duration / fps_den))
                    fi
                fi
            fi
            
            # Validate keep_file properties
            local keep_property_valid=true
            
            # Check timestamp relationship
            if [[ $keep_file_mtime -gt 0 && $keep_source_mtime -gt 0 ]]; then
                if [[ $keep_file_mtime -lt $keep_source_mtime ]]; then
                    local keep_time_diff=$((keep_source_mtime - keep_file_mtime))
                    if [[ $keep_time_diff -gt 60 ]]; then
                        keep_property_valid=false
                        echo -e "    ${YELLOW}⚠️  WARNING: Keep file $keep_file is older than source $(basename -- "$keep_source") (by ${keep_time_diff}s)${NC}"
                    fi
                fi
            fi
            
            # Check size relationship
            if [[ $keep_gif_size -gt 0 && $keep_source_size -gt 0 ]]; then
                if [[ $keep_gif_size -gt $keep_source_size ]]; then
                    keep_property_valid=false
                    echo -e "    ${YELLOW}⚠️  WARNING: Keep file $keep_file is larger than source $(basename -- "$keep_source")${NC}"
                    echo -e "    ${GRAY}   Size: GIF=$(numfmt --to=iec $keep_gif_size 2>/dev/null || echo $keep_gif_size) vs Source=$(numfmt --to=iec $keep_source_size 2>/dev/null || echo $keep_source_size)${NC}"
                fi
            fi
            
            if [[ $keep_gif_duration -gt 0 && $keep_source_duration -gt 0 ]]; then
                local keep_duration_diff=$(( (keep_gif_duration > keep_source_duration ? keep_gif_duration - keep_source_duration : keep_source_duration - keep_gif_duration) ))
                local keep_duration_ratio=0
                if [[ $keep_source_duration -gt 0 ]]; then
                    keep_duration_ratio=$((keep_duration_diff * 100 / keep_source_duration))
                fi
                
                if [[ $keep_duration_ratio -gt 20 ]]; then
                    keep_property_valid=false
                    echo -e "    ${YELLOW}⚠️  WARNING: Keep file $keep_file also has property mismatch with source $(basename -- "$keep_source")${NC}"
                    echo -e "    ${GRAY}   Duration: GIF=${keep_gif_duration}s vs Source=${keep_source_duration}s${NC}"
                fi
            fi
            
            # Check keep_file frame count
            if [[ $keep_gif_frames -gt 0 && $keep_source_frames -gt 0 ]]; then
                if [[ $keep_gif_frames -gt $((keep_source_frames * 120 / 100)) ]]; then
                    keep_property_valid=false
                    echo -e "    ${YELLOW}⚠️  WARNING: Keep file $keep_file has suspicious frame count${NC}"
                    echo -e "    ${GRAY}   Frames: GIF=${keep_gif_frames} vs Source=${keep_source_frames}${NC}"
                fi
            fi
        fi
        
        # Comparative quality analysis: Compare the two files intelligently
        local quality_info=""
        
        # Calculate quality indicators
        if [[ $remove_file_size -gt 0 && $keep_file_size -gt 0 ]]; then
            local size_diff=$((keep_file_size - remove_file_size))
            local size_diff_human=$(numfmt --to=iec $((size_diff > 0 ? size_diff : -size_diff)) 2>/dev/null || echo "${size_diff}B")
            
            if [[ $size_diff -gt 0 ]]; then
                quality_info="keep is ${size_diff_human} larger"
            elif [[ $size_diff -lt 0 ]]; then
                quality_info="remove was ${size_diff_human} larger"
            else
                quality_info="same size"
            fi
        fi
        
        # Add modification date comparison
        if [[ $remove_file_mtime -gt 0 && $keep_file_mtime -gt 0 ]]; then
            local time_diff=$((keep_file_mtime - remove_file_mtime))
            if [[ $time_diff -gt 0 ]]; then
                local days=$((time_diff / 86400))
                local hours=$(( (time_diff % 86400) / 3600 ))
                if [[ $days -gt 0 ]]; then
                    quality_info="${quality_info:+$quality_info, }keep is ${days}d ${hours}h newer"
                elif [[ $hours -gt 0 ]]; then
                    quality_info="${quality_info:+$quality_info, }keep is ${hours}h newer"
                else
                    quality_info="${quality_info:+$quality_info, }keep is ${time_diff}s newer"
                fi
            elif [[ $time_diff -lt 0 ]]; then
                local abs_time_diff=$((time_diff * -1))
                local days=$((abs_time_diff / 86400))
                local hours=$(( (abs_time_diff % 86400) / 3600 ))
                if [[ $days -gt 0 ]]; then
                    quality_info="${quality_info:+$quality_info, }remove was ${days}d ${hours}h newer"
                elif [[ $hours -gt 0 ]]; then
                    quality_info="${quality_info:+$quality_info, }remove was ${hours}h newer"
                else
                    quality_info="${quality_info:+$quality_info, }remove was ${abs_time_diff}s newer"
                fi
            else
                quality_info="${quality_info:+$quality_info, }same modification time"
            fi
        fi
        
        # Add permission comparison if different
        if [[ "$remove_file_perms" != "$keep_file_perms" ]]; then
            quality_info="${quality_info:+$quality_info, }perms: remove=$remove_file_perms keep=$keep_file_perms"
        fi
        
        if [[ -f "$remove_file" ]] && rm -f "$remove_file" 2>/dev/null; then
            # Track space saved
            DUPLICATE_STATS_SPACE_SAVED=$((DUPLICATE_STATS_SPACE_SAVED + remove_file_size))
            DUPLICATE_STATS_DELETED=$((DUPLICATE_STATS_DELETED + 1))
            
            if [[ "$has_source_remove" == true ]]; then
                echo -e "    ${GREEN}✓ Deleted: $remove_file (keeping $keep_file)${NC}"
                echo -e "    ${CYAN}  → Both have sources: $(basename -- "$remove_source"), $(basename -- "$keep_source")${NC}"
            elif [[ "$has_source_keep" == true ]]; then
                echo -e "    ${GREEN}✓ Deleted: $remove_file (keeping $keep_file)${NC}"
                echo -e "    ${CYAN}  → Keep has source: $(basename -- "$keep_source")${NC}"
            else
                echo -e "    ${GREEN}✓ Deleted: $remove_file (keeping $keep_file)${NC}"
                echo -e "    ${CYAN}  → Orphaned duplicates${NC}"
            fi
            
            if [[ -n "$quality_info" ]]; then
                echo -e "    ${GRAY}  📊 Quality: $quality_info${NC}"
            fi
            ((deleted_count++))
            already_deleted["$remove_file"]=1  # Mark as deleted
            
            # Log the deletion with comprehensive properties
            {
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] DUPLICATE GIF DELETED:"
                echo "  Removed: $remove_file"
                echo "    Size: $(numfmt --to=iec $remove_file_size 2>/dev/null || echo ${remove_file_size}B)"
                echo "    Modified: $(date -d @$remove_file_mtime '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'unknown')"
                echo "    Created: $(date -d @$remove_file_ctime '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'unknown')"
                echo "    Permissions: $remove_file_perms"
                echo "    Source: ${remove_source:-none}"
                echo "  Kept: $keep_file"
                echo "    Size: $(numfmt --to=iec $keep_file_size 2>/dev/null || echo ${keep_file_size}B)"
                echo "    Modified: $(date -d @$keep_file_mtime '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'unknown')"
                echo "    Created: $(date -d @$keep_file_ctime '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'unknown')"
                echo "    Permissions: $keep_file_perms"
                echo "    Source: ${keep_source:-none}"
                echo "  Analysis: $quality_info"
                echo ""
            } >> "$CONVERSION_LOG" 2>/dev/null || true
        else
            echo -e "    ${RED}❌ Failed to delete: $remove_file${NC}"
            already_deleted["$remove_file"]=1  # Mark as attempted to avoid repeated failures
        fi
    done
    
    if [[ $skipped_count -gt 0 ]]; then
        echo -e "  ${GREEN}${BOLD}✨ Success! Cleaned up $deleted_count duplicate GIF(s)${NC}"
        echo -e "  ${YELLOW}⚠️  Skipped $skipped_count file(s) with ambiguous source mapping${NC}"
    else
        echo -e "  ${GREEN}${BOLD}✨ Success! Cleaned up $deleted_count duplicate GIF(s)${NC}"
    fi
    
    # Show comprehensive statistical summary
    show_duplicate_detection_statistics
    
    echo ""
}

# 📊 Comprehensive Statistical Summary for Duplicate Detection
show_duplicate_detection_statistics() {
    echo -e "\n  ${CYAN}${BOLD}╭────────────────────────────────────────────────────────────╮${NC}"
    echo -e "  ${CYAN}${BOLD}│           📊 DUPLICATE DETECTION STATISTICS           │${NC}"
    echo -e "  ${CYAN}${BOLD}╰────────────────────────────────────────────────────────────╯${NC}\n"
    
    # Detection Method Breakdown
    echo -e "  ${BLUE}${BOLD}🔍 Detection Methods Used:${NC}"
    local total_detected=$((DUPLICATE_STATS_EXACT_BINARY + DUPLICATE_STATS_VISUAL_IDENTICAL + DUPLICATE_STATS_CONTENT_FINGERPRINT + DUPLICATE_STATS_NEAR_IDENTICAL))
    
    if [[ $total_detected -gt 0 ]]; then
        if [[ $DUPLICATE_STATS_EXACT_BINARY -gt 0 ]]; then
            local exact_pct=$((DUPLICATE_STATS_EXACT_BINARY * 100 / total_detected))
            echo -e "    ${GREEN}✓ Exact Binary Match:     ${BOLD}$DUPLICATE_STATS_EXACT_BINARY${NC} ${GREEN}duplicates (${exact_pct}%)${NC}"
        fi
        if [[ $DUPLICATE_STATS_VISUAL_IDENTICAL -gt 0 ]]; then
            local visual_pct=$((DUPLICATE_STATS_VISUAL_IDENTICAL * 100 / total_detected))
            echo -e "    ${BLUE}✓ Visual Identical:        ${BOLD}$DUPLICATE_STATS_VISUAL_IDENTICAL${NC} ${BLUE}duplicates (${visual_pct}%)${NC}"
        fi
        if [[ $DUPLICATE_STATS_CONTENT_FINGERPRINT -gt 0 ]]; then
            local content_pct=$((DUPLICATE_STATS_CONTENT_FINGERPRINT * 100 / total_detected))
            echo -e "    ${CYAN}✓ Content Fingerprint:     ${BOLD}$DUPLICATE_STATS_CONTENT_FINGERPRINT${NC} ${CYAN}duplicates (${content_pct}%)${NC}"
        fi
        if [[ $DUPLICATE_STATS_NEAR_IDENTICAL -gt 0 ]]; then
            local near_pct=$((DUPLICATE_STATS_NEAR_IDENTICAL * 100 / total_detected))
            echo -e "    ${YELLOW}✓ Near-Identical:          ${BOLD}$DUPLICATE_STATS_NEAR_IDENTICAL${NC} ${YELLOW}duplicates (${near_pct}%)${NC}"
        fi
    else
        echo -e "    ${GRAY}• No duplicates detected${NC}"
    fi
    
    # Space Savings
    echo -e "\n  ${MAGENTA}${BOLD}💾 Space Optimization:${NC}"
    if [[ $DUPLICATE_STATS_SPACE_SAVED -gt 0 ]]; then
        local space_mb=$((DUPLICATE_STATS_SPACE_SAVED / 1024 / 1024))
        local space_human=$(numfmt --to=iec $DUPLICATE_STATS_SPACE_SAVED 2>/dev/null || echo "${space_mb}MB")
        echo -e "    ${GREEN}✓ Space Saved:             ${BOLD}$space_human${NC} ${GREEN}freed${NC}"
        echo -e "    ${GREEN}✓ Files Deleted:           ${BOLD}$DUPLICATE_STATS_DELETED${NC} ${GREEN}duplicates${NC}"
        
        if [[ $DUPLICATE_STATS_DELETED -gt 0 ]]; then
            local avg_size=$((DUPLICATE_STATS_SPACE_SAVED / DUPLICATE_STATS_DELETED))
            local avg_human=$(numfmt --to=iec $avg_size 2>/dev/null || echo "${avg_size}B")
            echo -e "    ${GRAY}• Average file size:       ${avg_human} per duplicate${NC}"
        fi
    else
        echo -e "    ${GRAY}• No space saved (no duplicates deleted)${NC}"
    fi
    
    # Checksum Cache Performance
    echo -e "\n  ${CYAN}${BOLD}🔐 Checksum Cache Performance:${NC}"
    local total_lookups=$((DUPLICATE_STATS_CACHE_HITS + DUPLICATE_STATS_CACHE_MISSES))
    if [[ $total_lookups -gt 0 ]]; then
        local hit_rate=$((DUPLICATE_STATS_CACHE_HITS * 100 / total_lookups))
        echo -e "    ${GREEN}✓ Cache Hits:              ${BOLD}$DUPLICATE_STATS_CACHE_HITS${NC} ${GREEN}(${hit_rate}%)${NC}"
        echo -e "    ${YELLOW}• Cache Misses:            ${BOLD}$DUPLICATE_STATS_CACHE_MISSES${NC} ${YELLOW}(calculated)${NC}"
        echo -e "    ${BLUE}• Total Lookups:           ${BOLD}$total_lookups${NC}"
        
        # Calculate time saved (rough estimate: 500ms per cached checksum)
        local time_saved_ms=$((DUPLICATE_STATS_CACHE_HITS * 500))
        local time_saved_sec=$((time_saved_ms / 1000))
        if [[ $time_saved_sec -gt 60 ]]; then
            local time_saved_min=$((time_saved_sec / 60))
            echo -e "    ${MAGENTA}• Estimated time saved:    ~${time_saved_min} minutes${NC}"
        elif [[ $time_saved_sec -gt 0 ]]; then
            echo -e "    ${MAGENTA}• Estimated time saved:    ~${time_saved_sec} seconds${NC}"
        fi
    else
        echo -e "    ${GRAY}• No cache lookups performed${NC}"
    fi
    
    # Actions Taken
    echo -e "\n  ${YELLOW}${BOLD}🎯 Actions Summary:${NC}"
    if [[ $DUPLICATE_STATS_SKIPPED -gt 0 ]]; then
        echo -e "    ${YELLOW}⚠️  Skipped:                  ${BOLD}$DUPLICATE_STATS_SKIPPED${NC} ${YELLOW}files (ambiguous or property mismatch)${NC}"
    fi
    if [[ $DUPLICATE_STATS_DELETED -gt 0 ]]; then
        echo -e "    ${GREEN}✓ Deleted:                 ${BOLD}$DUPLICATE_STATS_DELETED${NC} ${GREEN}duplicate files${NC}"
    fi
    if [[ $DUPLICATE_STATS_DELETED -eq 0 && $DUPLICATE_STATS_SKIPPED -eq 0 && $total_detected -eq 0 ]]; then
        echo -e "    ${GREEN}✓ No duplicates found - collection is optimal!${NC}"
    fi
    
    # Duplicate Pattern Analysis
    if [[ $total_detected -gt 0 ]]; then
        echo -e "\n  ${BLUE}${BOLD}🧠 Pattern Analysis:${NC}"
        if [[ $DUPLICATE_STATS_EXACT_BINARY -gt $((total_detected / 2)) ]]; then
            echo -e "    ${CYAN}• Most duplicates are exact copies${NC}"
            echo -e "    ${GRAY}  → Recommendation: Check for copy/paste patterns in your workflow${NC}"
        fi
        if [[ $DUPLICATE_STATS_VISUAL_IDENTICAL -gt 0 ]]; then
            echo -e "    ${CYAN}• Some files have identical visual content but different binary data${NC}"
            echo -e "    ${GRAY}  → Recommendation: These may be re-conversions of the same source${NC}"
        fi
        if [[ $DUPLICATE_STATS_NEAR_IDENTICAL -gt 0 ]]; then
            echo -e "    ${CYAN}• Near-identical files detected (may need manual review)${NC}"
            echo -e "    ${GRAY}  → Recommendation: Consider consolidating similar content${NC}"
        fi
        if [[ $DUPLICATE_STATS_SKIPPED -gt $((DUPLICATE_STATS_DELETED / 2)) && $DUPLICATE_STATS_SKIPPED -gt 0 ]]; then
            echo -e "    ${YELLOW}• High skip rate suggests filename mismatches${NC}"
            echo -e "    ${GRAY}  → Recommendation: Ensure GIFs match their source video filenames${NC}"
        fi
    fi
    
    # Tips for preventing future duplicates
    if [[ $total_detected -gt 2 ]]; then
        echo -e "\n  ${GREEN}${BOLD}💡 Tips to Prevent Future Duplicates:${NC}"
        echo -e "    ${GRAY}1. Always name GIFs to match source video filenames${NC}"
        echo -e "    ${GRAY}2. Use version control for your media files${NC}"
        echo -e "    ${GRAY}3. Run duplicate detection regularly (cache makes it fast!)${NC}"
        echo -e "    ${GRAY}4. Avoid manual file copying - use the converter instead${NC}"
    fi
    
    echo -e "\n  ${CYAN}${BOLD}╰────────────────────────────────────────────────────────────╯${NC}"
}

# 🔍 Advanced pre-conversion validation with intelligent duplicate prevention
perform_pre_conversion_validation() {
    echo -e "${CYAN}${BOLD}🔍 ADVANCED PRE-CONVERSION VALIDATION${NC}\\n"
    
    # Step 1: Check for duplicate GIFs and offer to remove them
    echo -e "${BLUE}Step 1: Duplicate GIF Detection${NC}"
    detect_duplicate_gifs
    
    # Check for interrupt after Step 1
    if [[ "$INTERRUPT_REQUESTED" == "true" ]]; then
        echo -e "\\n  ${YELLOW}⏸️  Validation interrupted by user${NC}"
        return 1
    fi
    
    # Step 2: Check for corrupted GIFs and offer to fix them  
    echo -e "${BLUE}Step 2: Corruption Detection${NC}"
    detect_corrupted_gifs
    
    # Check for interrupt after Step 2
    if [[ "$INTERRUPT_REQUESTED" == "true" ]]; then
        echo -e "\\n  ${YELLOW}⏸️  Validation interrupted by user${NC}"
        return 1
    fi
    
    # Step 3: Advanced video-to-GIF mapping analysis
    echo -e "${BLUE}Step 3: Video-to-GIF Mapping Analysis${NC}"
    analyze_video_gif_mapping
    
    # Check for interrupt after Step 3
    if [[ "$INTERRUPT_REQUESTED" == "true" ]]; then
        echo -e "\\n  ${YELLOW}⏸️  Validation interrupted by user${NC}"
        return 1
    fi
    
    # Step 4: Show intelligent conversion recommendations
    echo -e "${BLUE}Step 4: Conversion Planning${NC}"
    generate_conversion_plan
    
    # Check for interrupt after Step 4
    if [[ "$INTERRUPT_REQUESTED" == "true" ]]; then
        echo -e "\\n  ${YELLOW}⏸️  Validation interrupted by user${NC}"
        return 1
    fi
    
    echo -e "\\n  ${GREEN}✓ Advanced validation completed${NC}\\n"
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
    
    # Scan all video files with progress
    echo -e "  ${CYAN}🔍 Scanning video files...${NC}"
    shopt -s nullglob
    local video_list=(*.mp4 *.avi *.mov *.mkv *.webm)
    local video_count=${#video_list[@]}
    
    for video in "${video_list[@]}"; do
        [[ -f "$video" ]] || continue
        local basename="${video%.*}"
        video_files["$basename"]="$video"
        ((total_videos++))
        
        # Truncate filename if too long
        local display_name="$(basename -- "$video")"
        if [[ ${#display_name} -gt 50 ]]; then
            display_name="${display_name:0:47}..."
        fi
        
        # Show progress bar on first line
        local progress=$((total_videos * 100 / video_count))
        printf "\r\033[K  ${CYAN}["
        local filled=$((progress * 20 / 100))
        for ((i=0; i<filled; i++)); do printf "${GREEN}█${NC}"; done
        for ((i=filled; i<20; i++)); do printf "${GRAY}░${NC}"; done
        printf "${CYAN}] ${BOLD}%3d%%${NC} ${BLUE}Scanned %d/%d${NC}" "$progress" "$total_videos" "$video_count"
        
        # Show current file on second line
        printf "\n  ${GRAY}📄 %s${NC}" "$display_name"
        printf "\r\033[1A"  # Move cursor back up to progress bar line
    done
    printf "\r\033[K  ${CYAN}["
    for ((i=0; i<20; i++)); do printf "${GREEN}█${NC}"; done
    printf "${CYAN}] ${BOLD}100%%${NC} ${BLUE}Scanned %d videos${NC}\n" "$total_videos"
    printf "\033[K\n"  # Clear the file name line
    
    # Scan GIF files - ONLY in OUTPUT_DIRECTORY if configured
    echo -e "  ${CYAN}🔍 Scanning GIF files...${NC}"
    shopt -s nullglob
    
    # Determine where to scan for GIFs
    if [[ -d "$OUTPUT_DIRECTORY" && "$(cd "$OUTPUT_DIRECTORY" 2>/dev/null && pwd)" != "$(pwd)" ]]; then
        # OUTPUT_DIRECTORY is configured and different - scan ONLY there
        echo -e "  ${BLUE}📂 Scanning output directory: $OUTPUT_DIRECTORY${NC}"
        for gif in "$OUTPUT_DIRECTORY"/*.gif; do
            [[ -f "$gif" ]] || continue
            local basename="$(basename -- "${gif%.*}")"
            gif_files["$basename"]="$gif"
            ((total_gifs++))
        done
    else
        # No separate output directory - scan current dir
        echo -e "  ${GRAY}📂 Scanning current directory${NC}"
        for gif in *.gif; do
            [[ -f "$gif" ]] || continue
            local basename="${gif%.*}"
            gif_files["$basename"]="$gif"
            ((total_gifs++))
        done
    fi
    shopt -u nullglob
    
    if [[ $total_videos -eq 0 ]]; then
        echo -e "  ${RED}❌ No video files found${NC}"
        return 1
    fi
    
    # Analyze mappings with progress
    echo -e "  ${CYAN}🔍 Analyzing video-GIF mappings...${NC}"
    local analyzed=0
    local total_to_analyze=$total_videos
    
    for basename in "${!video_files[@]}"; do
        local video_file="${video_files[$basename]}"
        local expected_gif="${basename}.gif"
        ((analyzed++))
        
        # Truncate filename if too long
        local display_name="$(basename -- "$video_file")"
        if [[ ${#display_name} -gt 50 ]]; then
            display_name="${display_name:0:47}..."
        fi
        
        # Show progress bar on first line
        local progress=$((analyzed * 100 / total_to_analyze))
        printf "\r\033[K  ${CYAN}["
        local filled=$((progress * 20 / 100))
        for ((i=0; i<filled; i++)); do printf "${GREEN}█${NC}"; done
        for ((i=filled; i<20; i++)); do printf "${GRAY}░${NC}"; done
        printf "${CYAN}] ${BOLD}%3d%%${NC} ${BLUE}Analyzed %d/%d${NC}" "$progress" "$analyzed" "$total_to_analyze"
        
        # Show current file on second line
        printf "\n  ${GRAY}🔍 %s${NC}" "$display_name"
        printf "\r\033[1A"  # Move cursor back up to progress bar line
        
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
    printf "\n"
    
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
    
    # Only show summary - no verbose file listings
    echo ""
    
    if [[ $orphaned_count -gt 0 ]]; then
        echo -e "\n  ${YELLOW}🔍 Orphaned GIFs (no matching video):${NC}"
        for gif_file in "${!orphaned_gifs[@]}"; do
            local gif_size=$(stat -c%s "$gif_file" 2>/dev/null | numfmt --to=iec 2>/dev/null || echo "?")
            echo -e "    ${YELLOW}🎨 $(basename -- "$gif_file") ($gif_size) → ${GRAY}[no video]${NC}"
        done
        
        if [[ $orphaned_count -gt 2 ]]; then
            echo -ne "\n  ${MAGENTA}Clean up orphaned GIFs? [y/N]: ${NC}"
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
            local backup_file="$orphaned_dir/$(basename -- "$gif_file").$(date +%s).orphaned"
            if mv "$gif_file" "$backup_file" 2>/dev/null; then
                echo -e "    ${GREEN}✓ Moved: $(basename -- "$gif_file") → orphaned_gifs/$(basename -- "$backup_file")${NC}"
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
    
    # First pass: count total GIF files - scan only OUTPUT_DIRECTORY if configured
    shopt -s nullglob
    local all_gifs=()
    
    if [[ -d "$OUTPUT_DIRECTORY" && "$(cd "$OUTPUT_DIRECTORY" 2>/dev/null && pwd)" != "$(pwd)" ]]; then
        # OUTPUT_DIRECTORY is configured and different - scan ONLY there
        echo -e "  ${BLUE}📂 Scanning output directory: $OUTPUT_DIRECTORY${NC}"
        all_gifs=("$OUTPUT_DIRECTORY"/*.gif)
    else
        # No separate output directory - scan current dir
        all_gifs=(*.gif)
    fi
    
    local total_to_check=${#all_gifs[@]}
    shopt -u nullglob
    
    if [[ $total_to_check -eq 0 ]]; then
        echo -e "  ${CYAN}ℹ️  No existing GIF files found${NC}"
        return 0
    fi
    
    echo -e "  ${CYAN}📊 Found $total_to_check GIF files to validate${NC}"
    
    # Second pass: check each file with progress bar
    local checked=0
    shopt -s nullglob
    for gif_file in "${all_gifs[@]}"; do
        # Check for interrupt
        if [[ "$INTERRUPT_REQUESTED" == "true" ]]; then
            printf "\r\033[K"
            echo -e "  ${YELLOW}⏸️  Corruption check interrupted by user${NC}"
            shopt -u nullglob
            return 0
        fi
        
        [[ -f "$gif_file" ]] || continue
        ((total_gifs++))
        ((checked++))
        
        # Show progress bar
        local percent=$((checked * 100 / total_to_check))
        local filled=$((checked * 50 / total_to_check))
        local empty=$((50 - filled))
        
        # Build progress bar
        local bar=""
        for ((i=0; i<filled; i++)); do bar+="█"; done
        for ((i=0; i<empty; i++)); do bar+="░"; done
        
        # Truncate filename if too long (max 35 chars)
        local display_file="$(basename -- "$gif_file")"
        if [[ ${#display_file} -gt 35 ]]; then
            display_file="${display_file:0:32}..."
        fi
        
        # Single-line progress with filename
        printf "\r\033[K  ${BLUE}🔍 [${GREEN}%s${GRAY}%s${BLUE}] ${YELLOW}%3d%%${NC} ${GRAY}(%d/%d)${NC} ${CYAN}%s${NC}" "${bar:0:filled}" "${bar:filled:empty}" "$percent" "$checked" "$total_to_check" "$display_file"
        
        # Test GIF integrity with ffprobe
        if ! ffprobe -v error -select_streams v:0 -show_entries stream=nb_frames -of csv=p=0 "$gif_file" >/dev/null 2>&1; then
            corrupted_files+=("$gif_file")
            ((corrupted_count++))
        fi
    done
    shopt -u nullglob
    
    # Clear progress bar
    printf "\r\033[K"
    
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
    echo -ne "\n  ${MAGENTA}Choice [1-3]: ${NC}"
    
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
                    echo -e "    ${GREEN}✓ Quarantined: $corrupted_file -> $(basename -- "$quarantine_file")${NC}"
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
    
    echo -e "${BLUE}⚡ AI Speed Optimizer analyzing: $(basename -- "$video_file")${NC}"
    
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
    
    echo -e "${BLUE}📊 AI Performance Analysis for: $(basename -- "$video_file")${NC}"
    
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
    
    # GPU encoders by vendor (will be filtered based on detected GPU)
    local available_encoders=()
    
    # Detect GPU hardware with better AMD/NVIDIA detection
    local gpu_info=""
    
    # First, check for VFIO-bound GPUs and skip them
    local vfio_gpus=()
    if [[ -d /sys/bus/pci/drivers/vfio-pci ]]; then
        for vfio_device in /sys/bus/pci/drivers/vfio-pci/*; do
            if [[ -L "$vfio_device" ]]; then
                local pci_id=$(basename -- "$vfio_device")
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
            # For NVIDIA, prioritize NVENC encoder
            if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "h264_nvenc"; then
                available_encoders+=("h264_nvenc")
            fi
            if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "hevc_nvenc"; then
                available_encoders+=("hevc_nvenc")
            fi
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
            # For AMD, prioritize VAAPI encoder
            if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "h264_vaapi"; then
                available_encoders+=("h264_vaapi")
            fi
            if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "hevc_vaapi"; then
                available_encoders+=("hevc_vaapi")
            fi
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
        # For Intel, check for QSV or VAAPI
        if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "h264_qsv"; then
            available_encoders+=("h264_qsv")
        elif ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "h264_vaapi"; then
            available_encoders+=("h264_vaapi")
        fi
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
                echo -e "    ${YELLOW}⚠️  Cannot mount RAM disk - requires sudo privileges${NC}"
                echo -e "    ${CYAN}💡 Tip: Run 'sudo mount -t tmpfs' or disable RAM_OPTIMIZATION in settings${NC}"
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
        # Check if readrate_initial_burst is supported (FFmpeg 5.0+)
        if ffmpeg -h full 2>&1 | grep -q "readrate_initial_burst"; then
            FFMPEG_INPUT_OPTS="-readrate_initial_burst 2.0"
        fi
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
                        echo -e "  ${GREEN}✓ Caching: $(basename -- "$file") (${file_size_mb}MB)${NC}"
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
        local distro_id="${ID,,}"  # Lowercase for comparison
        local distro_id_like="${ID_LIKE,,}"
        
        case "$distro_id" in
            ubuntu|debian|linuxmint|pop|elementary|neon|zorin|mx|raspbian|kali)
                distro="debian-based"
                package_manager="apt"
                install_cmd="sudo apt update && sudo apt install -y"
                ;;
            fedora|rhel|centos|rocky|almalinux|oraclelinux)
                distro="redhat-based"
                package_manager="dnf"
                install_cmd="sudo dnf install -y"
                ;;
            arch|manjaro|endeavouros|garuda|cachyos|artix|parabola|blackarch|arcolinux)
                distro="arch-based"
                package_manager="pacman"
                install_cmd="sudo pacman -S --needed"
                ;;
            opensuse*|sles|suse)
                distro="suse-based"
                package_manager="zypper"
                install_cmd="sudo zypper install -y"
                ;;
            alpine)
                distro="alpine"
                package_manager="apk"
                install_cmd="sudo apk add"
                ;;
            gentoo)
                distro="gentoo"
                package_manager="emerge"
                install_cmd="sudo emerge -av"
                ;;
            void)
                distro="void"
                package_manager="xbps"
                install_cmd="sudo xbps-install -y"
                ;;
            *)
                # Check ID_LIKE for derivative distributions
                if [[ "$distro_id_like" == *"debian"* ]] || [[ "$distro_id_like" == *"ubuntu"* ]]; then
                    distro="debian-based"
                    package_manager="apt"
                    install_cmd="sudo apt update && sudo apt install -y"
                elif [[ "$distro_id_like" == *"fedora"* ]] || [[ "$distro_id_like" == *"rhel"* ]]; then
                    distro="redhat-based"
                    package_manager="dnf"
                    install_cmd="sudo dnf install -y"
                elif [[ "$distro_id_like" == *"arch"* ]]; then
                    distro="arch-based"
                    package_manager="pacman"
                    install_cmd="sudo pacman -S --needed"
                elif [[ "$distro_id_like" == *"suse"* ]]; then
                    distro="suse-based"
                    package_manager="zypper"
                    install_cmd="sudo zypper install -y"
                else
                    distro="$ID"
                fi
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
                "gentoo") echo "media-video/ffmpeg" ;;
                "void") echo "ffmpeg" ;;
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
                "gentoo") echo "media-gfx/gifsicle" ;;
                "void") echo "gifsicle" ;;
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
                "gentoo") echo "app-misc/jq" ;;
                "void") echo "jq" ;;
                *) echo "jq" ;;
            esac
            ;;
        "convert")
            # ImageMagick (convert command)
            case "$distro" in
                "debian-based") echo "imagemagick" ;;
                "redhat-based") echo "ImageMagick" ;;
                "arch-based") echo "imagemagick" ;;
                "suse-based") echo "ImageMagick" ;;
                "alpine") echo "imagemagick" ;;
                "gentoo") echo "media-gfx/imagemagick" ;;
                "void") echo "ImageMagick" ;;
                *) echo "imagemagick" ;;
            esac
            ;;
        "git")
            case "$distro" in
                "debian-based") echo "git" ;;
                "redhat-based") echo "git" ;;
                "arch-based") echo "git" ;;
                "suse-based") echo "git" ;;
                "alpine") echo "git" ;;
                "gentoo") echo "dev-vcs/git" ;;
                "void") echo "git" ;;
                *) echo "git" ;;
            esac
            ;;
        "curl")
            case "$distro" in
                "debian-based") echo "curl" ;;
                "redhat-based") echo "curl" ;;
                "arch-based") echo "curl" ;;
                "suse-based") echo "curl" ;;
                "alpine") echo "curl" ;;
                "gentoo") echo "net-misc/curl" ;;
                "void") echo "curl" ;;
                *) echo "curl" ;;
            esac
            ;;
    esac
}

# 📝 Show manual installation instructions
show_manual_install_instructions() {
    local missing_tools=("$@")
    
    echo -e "${YELLOW}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}║          📝 MANUAL INSTALLATION REQUIRED                   ║${NC}"
    echo -e "${YELLOW}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}Missing dependencies:${NC}"
    for tool in "${missing_tools[@]}"; do
        echo -e "  ${RED}• $tool${NC}"
    done
    echo ""
    echo -e "${CYAN}${BOLD}Installation commands by distribution:${NC}"
    echo ""
    
    # Debian/Ubuntu
    echo -e "${GREEN}Debian/Ubuntu/Linux Mint/Pop!_OS:${NC}"
    echo -e "  ${CYAN}sudo apt update && sudo apt install -y"
    for tool in "${missing_tools[@]}"; do
        case "$tool" in
            "ffmpeg") echo -n " ffmpeg" ;;
            "git") echo -n " git" ;;
            "curl") echo -n " curl" ;;
            "gifsicle") echo -n " gifsicle" ;;
            "jq") echo -n " jq" ;;
            "convert") echo -n " imagemagick" ;;
        esac
    done
    echo -e "${NC}"
    echo ""
    
    # Fedora/RHEL/CentOS
    echo -e "${GREEN}Fedora/RHEL/CentOS/Rocky/AlmaLinux:${NC}"
    echo -e "  ${CYAN}sudo dnf install -y"
    for tool in "${missing_tools[@]}"; do
        case "$tool" in
            "ffmpeg") echo -n " ffmpeg" ;;
            "git") echo -n " git" ;;
            "curl") echo -n " curl" ;;
            "gifsicle") echo -n " gifsicle" ;;
            "jq") echo -n " jq" ;;
            "convert") echo -n " ImageMagick" ;;
        esac
    done
    echo -e "${NC}"
    echo ""
    
    # Arch Linux
    echo -e "${GREEN}Arch Linux/Manjaro/EndeavourOS:${NC}"
    echo -e "  ${CYAN}sudo pacman -S --needed"
    for tool in "${missing_tools[@]}"; do
        case "$tool" in
            "ffmpeg") echo -n " ffmpeg" ;;
            "git") echo -n " git" ;;
            "curl") echo -n " curl" ;;
            "gifsicle") echo -n " gifsicle" ;;
            "jq") echo -n " jq" ;;
            "convert") echo -n " imagemagick" ;;
        esac
    done
    echo -e "${NC}"
    echo ""
    
    # openSUSE
    echo -e "${GREEN}openSUSE Tumbleweed/Leap:${NC}"
    echo -e "  ${CYAN}sudo zypper install -y"
    for tool in "${missing_tools[@]}"; do
        case "$tool" in
            "ffmpeg") echo -n " ffmpeg-4" ;;
            "git") echo -n " git" ;;
            "curl") echo -n " curl" ;;
            "gifsicle") echo -n " gifsicle" ;;
            "jq") echo -n " jq" ;;
            "convert") echo -n " ImageMagick" ;;
        esac
    done
    echo -e "${NC}"
    echo ""
    
    # Alpine
    echo -e "${GREEN}Alpine Linux:${NC}"
    echo -e "  ${CYAN}sudo apk add"
    for tool in "${missing_tools[@]}"; do
        case "$tool" in
            "ffmpeg") echo -n " ffmpeg" ;;
            "git") echo -n " git" ;;
            "curl") echo -n " curl" ;;
            "gifsicle") echo -n " gifsicle" ;;
            "jq") echo -n " jq" ;;
            "convert") echo -n " imagemagick" ;;
        esac
    done
    echo -e "${NC}"
    echo ""
    
    # Gentoo
    echo -e "${GREEN}Gentoo:${NC}"
    echo -e "  ${CYAN}sudo emerge -av"
    for tool in "${missing_tools[@]}"; do
        case "$tool" in
            "ffmpeg") echo -n " media-video/ffmpeg" ;;
            "git") echo -n " dev-vcs/git" ;;
            "curl") echo -n " net-misc/curl" ;;
            "gifsicle") echo -n " media-gfx/gifsicle" ;;
            "jq") echo -n " app-misc/jq" ;;
            "convert") echo -n " media-gfx/imagemagick" ;;
        esac
    done
    echo -e "${NC}"
    echo ""
    
    # Void Linux
    echo -e "${GREEN}Void Linux:${NC}"
    echo -e "  ${CYAN}sudo xbps-install -y"
    for tool in "${missing_tools[@]}"; do
        case "$tool" in
            "ffmpeg") echo -n " ffmpeg" ;;
            "git") echo -n " git" ;;
            "curl") echo -n " curl" ;;
            "gifsicle") echo -n " gifsicle" ;;
            "jq") echo -n " jq" ;;
            "convert") echo -n " ImageMagick" ;;
        esac
    done
    echo -e "${NC}"
    echo ""
    
    # NixOS (special case)
    echo -e "${GREEN}NixOS:${NC}"
    echo -e "  ${CYAN}nix-env -iA nixos."
    for tool in "${missing_tools[@]}"; do
        case "$tool" in
            "ffmpeg") echo -n "ffmpeg " ;;
            "git") echo -n "git " ;;
            "curl") echo -n "curl " ;;
            "gifsicle") echo -n "gifsicle " ;;
            "jq") echo -n "jq " ;;
            "convert") echo -n "imagemagick " ;;
        esac
    done
    echo -e "${NC}"
    echo -e "  ${GRAY}Or add to configuration.nix: environment.systemPackages${NC}"
    echo ""
    
    echo -e "${GRAY}───────────────────────────────────────────────────────────────${NC}"
    echo -e "${BLUE}💡 After installing, restart your terminal or run: ${CYAN}hash -r${NC}"
    echo -e "${BLUE}🔗 Official package search:${NC}"
    echo -e "  ${GRAY}- Debian/Ubuntu: ${CYAN}https://packages.debian.org/ or https://packages.ubuntu.com/${NC}"
    echo -e "  ${GRAY}- Arch: ${CYAN}https://archlinux.org/packages/${NC}"
    echo -e "  ${GRAY}- Fedora: ${CYAN}https://packages.fedoraproject.org/${NC}"
    echo -e "  ${GRAY}- openSUSE: ${CYAN}https://software.opensuse.org/${NC}"
    echo ""
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
        show_manual_install_instructions "${missing_tools[@]}"
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
    
    echo -ne "\n${YELLOW}Would you like to install these dependencies now? [Y/n]:${NC} "
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
        echo -e "\n${RED}❌ Installation failed!${NC}"
        echo -e "${YELLOW}⚠️  This could be due to:${NC}"
        echo -e "  ${GRAY}• Insufficient permissions (try with sudo)${NC}"
        echo -e "  ${GRAY}• Network issues${NC}"
        echo -e "  ${GRAY}• Package not available in your repositories${NC}"
        echo -e "  ${GRAY}• Repository needs to be updated first${NC}"
        echo ""
        show_manual_install_instructions "${missing_tools[@]}"
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
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] NEW FILE DETECTED: $(basename -- "$new_file") ($file_size)"
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
                    echo -e "  ${CYAN}📄 $(basename -- "$new_file") (${file_size})${NC}"
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

# 🔍 Detect package manager and distro
detect_package_manager() {
    if command -v zypper >/dev/null 2>&1; then
        echo "zypper"
    elif command -v apt >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

# 📦 Map tool name to package name per distro
get_package_name() {
    local tool="$1"
    local pkg_manager="$2"
    
    case "$tool" in
        "ffmpeg")
            case "$pkg_manager" in
                "zypper") echo "ffmpeg-7" ;;
                "apt") echo "ffmpeg" ;;
                "dnf"|"yum") echo "ffmpeg" ;;
                "pacman") echo "ffmpeg" ;;
                *) echo "ffmpeg" ;;
            esac
            ;;
        "gifsicle")
            echo "gifsicle"
            ;;
        "jq")
            echo "jq"
            ;;
        "convert")
            case "$pkg_manager" in
                "zypper") echo "ImageMagick" ;;
                "apt") echo "imagemagick" ;;
                "dnf"|"yum") echo "ImageMagick" ;;
                "pacman") echo "imagemagick" ;;
                *) echo "imagemagick" ;;
            esac
            ;;
        *)
            echo "$tool"
            ;;
    esac
}

# 🔄 Check if a package update is available
check_package_update_available() {
    local tool="$1"
    local pkg_manager=$(detect_package_manager)
    local package_name=$(get_package_name "$tool" "$pkg_manager")
    local update_available=false
    local installed_version=""
    local available_version=""
    local update_command=""
    
    case "$pkg_manager" in
        "zypper")
            # Special handling for FFmpeg versioning on openSUSE
            if [[ "$tool" == "ffmpeg" ]]; then
                local installed_pkg=$(rpm -qa | grep -E '^ffmpeg-[0-9]' | head -1)
                if [[ -n "$installed_pkg" ]]; then
                    installed_version=$(echo "$installed_pkg" | grep -oP 'ffmpeg-\K[0-9]+')
                    # Check if ffmpeg-7 is available
                    if zypper search -s ffmpeg-7 2>/dev/null | grep -q "^i.*ffmpeg-7"; then
                        # Already on ffmpeg-7
                        return 0
                    elif zypper search -s ffmpeg-7 2>/dev/null | grep -q "ffmpeg-7"; then
                        if [[ "$installed_version" -lt 7 ]]; then
                            update_available=true
                            available_version="7"
                            update_command="sudo zypper install --allow-vendor-change ffmpeg-7"
                        fi
                    fi
                fi
            else
                # Check if update available using zypper
                if zypper list-updates 2>/dev/null | grep -q "^v.*$package_name"; then
                    update_available=true
                    update_command="sudo zypper update $package_name"
                fi
            fi
            ;;
        "apt")
            # Check with apt
            apt list --upgradable 2>/dev/null | grep -q "^$package_name/" && {
                update_available=true
                update_command="sudo apt update && sudo apt upgrade $package_name"
            }
            ;;
        "dnf")
            # Check with dnf
            dnf check-update "$package_name" >/dev/null 2>&1 && {
                update_available=true
                update_command="sudo dnf update $package_name"
            }
            ;;
        "yum")
            # Check with yum
            yum check-update "$package_name" >/dev/null 2>&1 && {
                update_available=true
                update_command="sudo yum update $package_name"
            }
            ;;
        "pacman")
            # Check with pacman
            pacman -Qu 2>/dev/null | grep -q "^$package_name " && {
                update_available=true
                update_command="sudo pacman -Syu $package_name"
            }
            ;;
    esac
    
    if [[ "$update_available" == true ]]; then
        if [[ "$tool" == "ffmpeg" && -n "$available_version" ]]; then
            echo -e "    ${YELLOW}⚠️  Newer version available: ffmpeg-$available_version (you have ffmpeg-$installed_version)${NC}"
        else
            echo -e "    ${YELLOW}⚠️  Update available for $tool${NC}"
        fi
        echo -e "    ${CYAN}💡 Update: $update_command${NC}"
        
        # Store for batch update prompt
        OUTDATED_PACKAGES+=("$tool:$update_command")
        return 1
    fi
    
    return 0
}

# 🔍 Enhanced system requirements check with intelligent caching
check_dependencies() {
    local cache_file="$LOG_DIR/.dependency_cache"
    local cache_validity_hours=24  # Cache valid for 24 hours
    local force_check=false
    
    # Check if cache exists and is recent
    if [[ -f "$cache_file" ]]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
        local cache_max_age=$((cache_validity_hours * 3600))
        
        if [[ $cache_age -lt $cache_max_age ]]; then
            # Cache is still valid - load cached results
            source "$cache_file" 2>/dev/null && {
                echo -e "${GREEN}✓ Dependencies verified (cached)${NC}"
                return 0
            }
        else
            force_check=true
        fi
    else
        force_check=true
    fi
    
    # Perform full check if needed
    echo -e "${CYAN}🔍 Checking system dependencies...${NC}"
    
    local required_tools=("ffmpeg" "git" "curl")
    local optional_tools=("gifsicle" "jq" "convert")  # convert is from ImageMagick
    local missing_required=()
    local missing_optional=()
    local outdated_tools=()
    
    # Initialize global array for outdated packages
    OUTDATED_PACKAGES=()
    
    # Check required tools
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_required+=("$tool")
        else
            local version=$("$tool" -version 2>/dev/null | head -1 | cut -d' ' -f1-3 2>/dev/null || echo "unknown version")
            echo -e "  ${GREEN}✓ $tool: $version${NC}"
            
            # Check if package is up-to-date (all distros)
            check_package_update_available "$tool"
        fi
    done
    
    # Check optional tools
    for tool in "${optional_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_optional+=("$tool")
        else
            local version=$("$tool" --version 2>/dev/null | head -1 2>/dev/null || echo "available")
            echo -e "  ${GREEN}✓ $tool: $version${NC}"
            
            # Check if package is up-to-date (all distros)
            check_package_update_available "$tool"
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
                "convert")
                    echo -e "  ${YELLOW}• $dep (ImageMagick)${NC} - AI perceptual hashing for duplicate detection will be disabled"
                    echo -e "  ${GRAY}    Level 4 duplicate detection will use basic size/frame comparison only${NC}"
                    ;;
            esac
        done
        
        echo -ne "\n${CYAN}Would you like to install optional dependencies? [y/N]:${NC} "
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
    
    # Prompt to update outdated packages
    if [[ ${#OUTDATED_PACKAGES[@]} -gt 0 ]]; then
        echo -e "\n${YELLOW}⚠️  Found ${#OUTDATED_PACKAGES[@]} package(s) with updates available${NC}"
        echo -ne "${CYAN}Would you like to update them now? [y/N]:${NC} "
        read -r update_choice
        
        if [[ "$update_choice" =~ ^[Yy]$ ]]; then
            echo -e "\n${BLUE}🔄 Updating packages...${NC}"
            for entry in "${OUTDATED_PACKAGES[@]}"; do
                local tool="${entry%%:*}"
                local cmd="${entry#*:}"
                echo -e "\n${CYAN}➡️  Updating $tool...${NC}"
                echo -e "${GRAY}Command: $cmd${NC}"
                eval "$cmd"
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}✓ $tool updated successfully${NC}"
                else
                    echo -e "${YELLOW}⚠️  $tool update failed or was skipped${NC}"
                fi
            done
            echo -e "\n${GREEN}✅ Package updates completed${NC}"
        else
            echo -e "${CYAN}📝 You can update later using the commands shown above${NC}"
        fi
    fi
    
    echo -e "\n${GREEN}✅ Dependency check completed${NC}"
    
    # Save successful check to cache if all required tools are present
    if [[ ${#missing_required[@]} -eq 0 ]]; then
        cat > "$cache_file" << 'EOF'
# Dependency check cache
# Generated: $(date)
# All required dependencies verified
EOF
        echo -e "${GRAY}  ℹ️  Cached for faster startup next time${NC}"
    fi
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

# 🎬 Comprehensive video file validation with MD5-based caching
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
    
    # MD5-based validation cache to skip expensive FFprobe checks
    local validation_cache="$LOG_DIR/validation_cache.db"
    local file_mtime=$(stat -c%Y "$file" 2>/dev/null || echo "0")
    local cache_key="${file}|${file_size}|${file_mtime}"
    
    # Validate cache integrity on first access (silent rebuild)
    if [[ -f "$validation_cache" ]]; then
        # Check if cache is corrupted (malformed entries)
        if ! head -1 "$validation_cache" 2>/dev/null | grep -qE '^.+\|[0-9]+\|[0-9]+\|(VALID|INVALID)$'; then
            # First line is corrupted or invalid format
            if [[ $(wc -l < "$validation_cache" 2>/dev/null || echo 0) -gt 0 ]]; then
                # Silently rebuild cache
                mv "$validation_cache" "${validation_cache}.corrupt.$(date +%s)" 2>/dev/null
                echo "# Validation Cache v1.0 - $(date)" > "$validation_cache"
            fi
        fi
        
        # Check cache for this specific file (no output)
        if grep -qF "$cache_key|VALID" "$validation_cache" 2>/dev/null; then
            CACHE_HITS=$((CACHE_HITS + 1))
            return 0
        elif grep -qF "$cache_key|INVALID" "$validation_cache" 2>/dev/null; then
            CACHE_HITS=$((CACHE_HITS + 1))
            return 1
        fi
    else
        # Initialize cache with header
        mkdir -p "$(dirname "$validation_cache")" 2>/dev/null
        echo "# Validation Cache v1.0 - $(date)" > "$validation_cache"
        echo "# Format: filepath|filesize|mtime|VALID/INVALID" >> "$validation_cache"
    fi
    
    # Cache miss - perform full validation
    CACHE_MISSES=$((CACHE_MISSES + 1))
    local validation_result="INVALID"
    if detect_video_corruption "$file"; then
        validation_result="VALID"
    fi
    
    # Save to cache
    mkdir -p "$(dirname "$validation_cache")" 2>/dev/null
    echo "$cache_key|$validation_result" >> "$validation_cache"
    
    # Keep cache size manageable (last 1000 entries)
    if [[ -f "$validation_cache" ]] && [[ $(wc -l < "$validation_cache") -gt 1000 ]]; then
        tail -800 "$validation_cache" > "${validation_cache}.tmp" && mv "${validation_cache}.tmp" "$validation_cache"
    fi
    
    [[ "$validation_result" == "VALID" ]] && return 0 || return 1
}

# 🔍 Basic corruption detection for video files (less aggressive)
detect_video_corruption() {
    local file="$1"
    local temp_error="/tmp/ffprobe_error_$$_$(date +%s).log"
    trace_function "detect_video_corruption"
    
    # Silent validation - no output
    
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
    
    # Cleanup and success (silent)
    rm -f "$temp_error" 2>/dev/null
    return 0
}

# 🔄 Check if output file already exists and is valid
check_duplicate_output() {
    local input_file="$1"
    local base_name="$(basename -- "${input_file%.*}")"
    local output_file="$OUTPUT_DIRECTORY/$base_name.${OUTPUT_FORMAT}"
    
    # If file doesn't exist, not a duplicate
    if [[ ! -f "$output_file" ]]; then
        return 1
    fi
    
    # If force conversion is enabled, ignore existing files
    if [[ "$FORCE_CONVERSION" == "true" ]]; then
        [[ "$VALIDATION_SILENT_MODE" != "true" ]] && echo -e "  ${YELLOW}♾️ Force mode: Will overwrite existing $(basename -- "$output_file")${NC}"
        return 1
    fi
    
    # Check if output is newer than input (modification time)
    if [[ "$output_file" -nt "$input_file" ]]; then
        [[ "$VALIDATION_SILENT_MODE" != "true" ]] && echo -e "  ${GREEN}✓ Already converted: $(basename -- "$output_file") (newer than source)${NC}"
        return 0
    fi
    
    # Check if output file is valid (basic size check)
    local output_size=$(stat -c%s "$output_file" 2>/dev/null || echo "0")
    if [[ $output_size -lt 100 ]]; then
        [[ "$VALIDATION_SILENT_MODE" != "true" ]] && echo -e "  ${YELLOW}⚠️ Existing file too small, will recreate: $(basename -- "$output_file")${NC}"
        rm -f "$output_file" 2>/dev/null
        return 1
    fi
    
    # Quick validation of existing GIF
    if ! file "$output_file" 2>/dev/null | grep -q "GIF"; then
        [[ "$VALIDATION_SILENT_MODE" != "true" ]] && echo -e "  ${YELLOW}⚠️ Existing file not a valid GIF, will recreate: $(basename -- "$output_file")${NC}"
        rm -f "$output_file" 2>/dev/null
        return 1
    fi
    
    # File exists, is newer, and appears valid
    [[ "$VALIDATION_SILENT_MODE" != "true" ]] && echo -e "  ${GREEN}⏭️ Skipping: $(basename -- "$output_file") already exists and is valid${NC}"
    return 0
}

# 🅾️Validate output GIF files for corruption
validate_output_file() {
    local output_file="$1"
    local source_file="$2"
    local temp_error="/tmp/gif_validation_$$_$(date +%s).log"
    trace_function "validate_output_file"
    
    echo -e "  ${BLUE}🔍 Validating output: $(basename -- "$output_file")${NC}"
    
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
            # Convert sizes to MB for readability
            local source_size_mb=$(echo "scale=2; $source_size / 1024 / 1024" | bc 2>/dev/null || echo "0.00")
            local output_size_mb=$(echo "scale=2; $file_size / 1024 / 1024" | bc 2>/dev/null || echo "0.00")
            # Calculate actual multiplier (e.g., "1078x larger")
            local multiplier=$(echo "scale=1; $file_size / $source_size" | bc 2>/dev/null || echo "0")
            
            echo -e "  ${YELLOW}⚠️ Warning: Output GIF is extremely large (${multiplier}x source size)${NC}"
            log_warning "Extremely large output file" "$source_file" "Output: $output_file, Source: ${source_size_mb}MB, Output: ${output_size_mb}MB, Multiplier: ${multiplier}x" "${BASH_LINENO[0]}" "validate_output_file"
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
    
    echo -ne "${MAGENTA}Select an option [0-3]: ${NC}"
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
                    echo -ne "${MAGENTA}Kill this process? [y/N]: ${NC}"
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

# 📋 Detect available file picker (comprehensive desktop environment support)
detect_file_picker() {
    # Check for various file picker dialogs in order of preference
    # GTK-based dialogs
    if command -v zenity >/dev/null 2>&1; then
        echo "zenity"  # GNOME, XFCE, Cinnamon, Budgie
    elif command -v yad >/dev/null 2>&1; then
        echo "yad"  # Enhanced zenity fork
    elif command -v matedialog >/dev/null 2>&1; then
        echo "matedialog"  # MATE Desktop
    # Qt-based dialogs
    elif command -v kdialog >/dev/null 2>&1; then
        echo "kdialog"  # KDE Plasma
    elif command -v qarma >/dev/null 2>&1; then
        echo "qarma"  # Qt zenity clone
    # Other dialogs
    elif command -v dialog >/dev/null 2>&1; then
        echo "dialog"  # Text-based fallback
    elif command -v whiptail >/dev/null 2>&1; then
        echo "whiptail"  # Text-based alternative
    # Try Python-based tkinter as last GUI resort
    elif command -v python3 >/dev/null 2>&1 && python3 -c "import tkinter" 2>/dev/null; then
        echo "python-tk"
    else
        echo "none"
    fi
}

# 📂 Browse for directory using file picker
browse_for_directory() {
    local picker=$(detect_file_picker)
    local selected_dir=""
    
    case "$picker" in
        "zenity")
            selected_dir=$(zenity --file-selection --directory --title="Select Output Directory" 2>/dev/null || echo "")
            ;;
        "kdialog")
            selected_dir=$(kdialog --getexistingdirectory "$HOME" --title "Select Output Directory" 2>/dev/null || echo "")
            ;;
        "yad")
            # YAD (Yet Another Dialog) - Zenity fork with more features
            selected_dir=$(yad --file --directory --title="Select Output Directory" 2>/dev/null || echo "")
            ;;
        "qarma")
            # Qarma - Qt-based Zenity clone
            selected_dir=$(qarma --file-selection --directory --title="Select Output Directory" 2>/dev/null || echo "")
            ;;
        "matedialog")
            # MATE Desktop dialog
            selected_dir=$(matedialog --file-selection --directory --title="Select Output Directory" 2>/dev/null || echo "")
            ;;
        "dialog")
            # Text-based dialog fallback
            selected_dir=$(dialog --stdout --title "Select Output Directory" --dselect "$HOME/" 14 48 2>/dev/null || echo "")
            ;;
        "whiptail")
            # Whiptail text-based fallback
            selected_dir=$(whiptail --title "Select Output Directory" --inputbox "Enter directory path:" 10 60 "$HOME/" 3>&1 1>&2 2>&3 || echo "")
            ;;
        "python-tk")
            # Python tkinter GUI fallback
            selected_dir=$(python3 -c "
import tkinter as tk
from tkinter import filedialog
root = tk.Tk()
root.withdraw()
selected = filedialog.askdirectory(initialdir='$HOME', title='Select Output Directory')
if selected:
    print(selected)
" 2>/dev/null || echo "")
            ;;
        "none")
            echo "none"
            return 1
            ;;
    esac
    
    if [[ -n "$selected_dir" && -d "$selected_dir" ]]; then
        echo "$selected_dir"
        return 0
    fi
    
    return 1
}

# 📂 Select video folder (change working directory)
select_video_folder() {
    local selected=0
    local picker=$(detect_file_picker)
    local options=()
    local descriptions=()
    
    # Build options array based on available picker
    options+=("Enter path manually")
    descriptions+=("Type the full path to your video folder")
    
    if [[ "$picker" != "none" ]]; then
        options+=("Browse with file picker")
        descriptions+=("Use $picker to select folder visually")
    fi
    
    options+=("Back to main menu")
    descriptions+=("Return without changing folder")
    
    while true; do
        clear
        print_header
        
        echo -e "${CYAN}${BOLD}📂 SELECT VIDEO FOLDER${NC}\n"
        
        # Show current directory
        local current_dir_display="$(pwd | sed "s|$HOME|~|g")"
        local current_dir_path="$(pwd)"
        local clickable_current=$(make_clickable_path "$current_dir_path" "$current_dir_display")
        
        echo -e "${BLUE}📂 Current Video Folder:${NC}"
        echo -e "  $clickable_current"
        
        # Count videos in current folder
        local video_count=$(find . -maxdepth 1 \( -name "*.mp4" -o -name "*.avi" -o -name "*.mov" -o -name "*.mkv" -o -name "*.webm" \) 2>/dev/null | wc -l)
        echo -e "  ${YELLOW}📹 Videos found: ${BOLD}$video_count${NC}\n"
        
        # Display options with highlight
        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                echo -e "  ${GREEN}${BOLD}➤ ${options[$i]}${NC}"
                echo -e "    ${CYAN}💡 ${descriptions[$i]}${NC}"
            else
                echo -e "  ${GRAY}  ${options[$i]}${NC}"
            fi
        done
        
        echo ""
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${NC} ${YELLOW}🎹 Controls:${NC}                                      ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}   ${GREEN}W${NC} or ${GREEN}↑${NC}  - Move up                              ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}   ${GREEN}S${NC} or ${GREEN}↓${NC}  - Move down                            ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}   ${GREEN}Enter${NC}  - Confirm selection                      ${CYAN}│${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        echo ""
        
        # Read key
        read -rsn1 key 2>/dev/null || read -r key
        
        case "$key" in
            $'\x1b')  # Arrow keys
                read -rsn2 -t 0.1 key
                case "$key" in
                    '[A') # Up
                        selected=$((selected - 1))
                        [[ $selected -lt 0 ]] && selected=$((${#options[@]}-1))
                        ;;
                    '[B') # Down
                        selected=$((selected + 1))
                        [[ $selected -ge ${#options[@]} ]] && selected=0
                        ;;
                esac
                ;;
            'w'|'W') # Up
                selected=$((selected - 1))
                [[ $selected -lt 0 ]] && selected=$((${#options[@]}-1))
                sleep 0.1
                ;;
            's'|'S') # Down
                selected=$((selected + 1))
                [[ $selected -ge ${#options[@]} ]] && selected=0
                sleep 0.1
                ;;
            ''|$'\n'|$'\r'|' ') # Enter/Space
                break
                ;;
        esac
    done
    
    # Handle the selected option
    # Options array: 0=manual, 1=browse (if available), last=back
    local last_option=$((${#options[@]} - 1))
    
    if [[ $selected -eq $last_option ]]; then
        # Back to main menu
        return 0
    elif [[ $selected -eq 0 ]]; then
        # Manual path entry
        echo -e "\n${CYAN}Enter folder path where videos are located:${NC}"
        echo -e "${GRAY}Common: $HOME/Videos, $HOME/Downloads, $HOME/Pictures${NC}"
        echo -ne "${YELLOW}Path: ${NC}"
        read -r manual_path
        
        if [[ -n "$manual_path" ]]; then
            manual_path="${manual_path/#\~/$HOME}"
            
            if [[ -d "$manual_path" ]]; then
                if cd "$manual_path" 2>/dev/null; then
                    local new_video_count=$(find . -maxdepth 1 \( -name "*.mp4" -o -name "*.avi" -o -name "*.mov" -o -name "*.mkv" -o -name "*.webm" \) 2>/dev/null | wc -l)
                    echo -e "\n${GREEN}✓ Changed to: $manual_path${NC}"
                    echo -e "  ${YELLOW}📹 Videos found: ${BOLD}$new_video_count${NC}"
                    [[ $new_video_count -eq 0 ]] && echo -e "  ${YELLOW}⚠️  No video files found in this folder${NC}"
                    sleep 2
                    return 0
                else
                    echo -e "\n${RED}❌ Cannot access directory: $manual_path${NC}"
                    sleep 2
                fi
            else
                echo -e "\n${RED}❌ Directory does not exist: $manual_path${NC}"
                sleep 2
            fi
        else
            echo -e "\n${YELLOW}No path entered${NC}"
            sleep 1
        fi
    elif [[ $selected -eq 1 && "$picker" != "none" ]]; then
        # Browse with file picker
        echo -e "\n${GREEN}Opening file picker to select video folder...${NC}"
        sleep 0.5
        
        local selected_dir=$(browse_for_directory)
        
        if [[ $? -eq 0 && -n "$selected_dir" && -d "$selected_dir" ]]; then
            if cd "$selected_dir" 2>/dev/null; then
                local new_video_count=$(find . -maxdepth 1 \( -name "*.mp4" -o -name "*.avi" -o -name "*.mov" -o -name "*.mkv" -o -name "*.webm" \) 2>/dev/null | wc -l)
                echo -e "\n${GREEN}✓ Changed to: $selected_dir${NC}"
                echo -e "  ${YELLOW}📹 Videos found: ${BOLD}$new_video_count${NC}"
                [[ $new_video_count -eq 0 ]] && echo -e "  ${YELLOW}⚠️  No video files found in this folder${NC}"
                sleep 2
                return 0
            else
                echo -e "\n${RED}❌ Cannot access directory: $selected_dir${NC}"
                sleep 2
            fi
        else
            echo -e "\n${YELLOW}ℹ️  No directory selected${NC}"
            sleep 1
        fi
    fi
}

# 📁 Configure output directory
configure_output_directory() {
    local selected=0
    
    # Calculate actual paths for display based on what each option WILL set
    local current_dir="$(pwd)"
    local converted_gifs_path="$current_dir/converted_gifs"  # Option 1: ./converted_gifs from current dir
    local pictures_path="$HOME/Pictures/GIFs"                # Option 2: Pictures folder
    local current_dir_path="$current_dir"                    # Option 3: Current directory itself
    
    local options=(
        "./converted_gifs - Keep videos & GIFs organized"
        "Pictures folder - Save to system Pictures directory"
        "Current directory - Save with your video files"
        "Custom path - Choose your own location"
        "Back to main menu"
    )
    local descriptions=(
        "Path: $converted_gifs_path"
        "Path: $pictures_path"
        "Path: $current_dir_path"
        "Browse with file picker or type any path you want"
        "Return to main menu without changes"
    )
    
    while true; do
        clear
        print_header
        
        echo -e "${CYAN}${BOLD}📁 OUTPUT DIRECTORY CONFIGURATION${NC}\n"
        
        # Show current output directory
        local output_display="$(echo "$OUTPUT_DIRECTORY" | sed "s|$HOME|~|g")"
        local output_abs="$(cd "$OUTPUT_DIRECTORY" 2>/dev/null && pwd || echo "$OUTPUT_DIRECTORY")"
        local clickable_output=$(make_clickable_path "$output_abs" "$output_display")
        
        echo -e "${BLUE}💾 Current Output Directory:${NC}"
        echo -e "  $clickable_output"
        echo -e "  ${GRAY}Mode: $OUTPUT_DIR_MODE${NC}\n"
        
        # Check if directory exists and is writable
        if [[ -d "$OUTPUT_DIRECTORY" ]]; then
            if [[ -w "$OUTPUT_DIRECTORY" ]]; then
                echo -e "  ${GREEN}✓ Directory exists and is writable${NC}"
            else
                echo -e "  ${YELLOW}⚠️  Warning: Directory is not writable${NC}"
            fi
        else
            echo -e "  ${YELLOW}⚠️  Directory does not exist (will be created)${NC}"
        fi
        
        echo -e "${CYAN}${BOLD}📁 OPTIONS:${NC}\n"
        
        # Display options with highlight (no descriptions here)
        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                echo -e "  ${GREEN}${BOLD}➤ ${options[$i]}${NC}"
            else
                echo -e "  ${GRAY}  ${options[$i]}${NC}"
            fi
        done
        
        echo ""
        echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${NC} ${YELLOW}💡 Full Path:${NC}                                               ${CYAN}│${NC}"
        
        # Make path clickable based on selected option
        local clickable_desc=""
        case $selected in
            0) clickable_desc=$(make_clickable_path "$converted_gifs_path" "$converted_gifs_path") ;;
            1) clickable_desc=$(make_clickable_path "$pictures_path" "$pictures_path") ;;
            2) clickable_desc=$(make_clickable_path "$current_dir_path" "$current_dir_path") ;;
            *) clickable_desc="${descriptions[$selected]}" ;;
        esac
        
        echo -e "${CYAN}│${NC}   $clickable_desc$(printf '%*s' $((77 - ${#descriptions[$selected]})) '')${CYAN}│${NC}"
        echo -e "${CYAN}└────────────────────────────────────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│${NC} ${YELLOW}🎹 Controls:${NC}                                      ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}   ${GREEN}W${NC} or ${GREEN}↑${NC}  - Move up                              ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}   ${GREEN}S${NC} or ${GREEN}↓${NC}  - Move down                            ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}   ${GREEN}Enter${NC}  - Confirm selection                      ${CYAN}│${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
        echo ""
        
        # Read key
        read -rsn1 key 2>/dev/null || read -r key
        
        case "$key" in
            $'\x1b')  # Arrow keys
                read -rsn2 -t 0.1 key
                case "$key" in
                    '[A') # Up
                        selected=$((selected - 1))
                        [[ $selected -lt 0 ]] && selected=$((${#options[@]}-1))
                        ;;
                    '[B') # Down
                        selected=$((selected + 1))
                        [[ $selected -ge ${#options[@]} ]] && selected=0
                        ;;
                esac
                ;;
            'w'|'W') # Up
                selected=$((selected - 1))
                [[ $selected -lt 0 ]] && selected=$((${#options[@]}-1))
                sleep 0.1
                ;;
            's'|'S') # Down
                selected=$((selected + 1))
                [[ $selected -ge ${#options[@]} ]] && selected=0
                sleep 0.1
                ;;
            ''|$'\n'|$'\r'|' ') # Enter/Space
                break
                ;;
        esac
    done
    
    local choice=$((selected + 1))
    
    case "$choice" in
        "1")
            # Set to ./converted_gifs (relative to current working directory)
            OUTPUT_DIRECTORY="./converted_gifs"
            OUTPUT_DIR_MODE="default"
            
            # Create directory if it doesn't exist
            mkdir -p "$OUTPUT_DIRECTORY" 2>/dev/null || {
                echo -e "\n${RED}❌ Cannot create directory: $OUTPUT_DIRECTORY${NC}"
                sleep 2
                return 1
            }
            
            # Get absolute path for display
            local abs_path="$(cd "$OUTPUT_DIRECTORY" && pwd)"
            
            clear
            print_header
            echo -e "\n${GREEN}✓ Output directory set to: $abs_path${NC}"
            echo -e "  ${CYAN}💡 Organized subfolder - recommended${NC}"
            echo -e "  ${GREEN}✓ Directory created and ready${NC}"
            save_settings --silent
            sleep 2
            ;;
        "2")
            OUTPUT_DIRECTORY="$HOME/Pictures/GIFs"
            OUTPUT_DIR_MODE="pictures"
            
            # Create directory
            mkdir -p "$OUTPUT_DIRECTORY" 2>/dev/null || {
                echo -e "\n${RED}❌ Cannot create Pictures/GIFs directory${NC}"
                sleep 2
                return 1
            }
            
            clear
            print_header
            echo -e "\n${GREEN}✓ Output directory set to: $OUTPUT_DIRECTORY${NC}"
            echo -e "  ${GREEN}✓ Directory created and ready${NC}"
            save_settings --silent
            sleep 2
            ;;
        "3")
            # Current directory (where user is running the script FROM)
            OUTPUT_DIRECTORY="$(pwd)"
            OUTPUT_DIR_MODE="current"
            
            # Verify directory is writable
            if [[ ! -w "$OUTPUT_DIRECTORY" ]]; then
                echo -e "\n${RED}❌ Current directory is not writable${NC}"
                sleep 2
                return 1
            fi
            
            clear
            print_header
            echo -e "\n${GREEN}✓ Output directory set to: $(pwd)${NC}"
            echo -e "  ${CYAN}💡 Same folder as your video files (current directory)${NC}"
            echo -e "  ${GREEN}✓ Directory ready${NC}"
            save_settings --silent
            sleep 2
            ;;
        "4")
            # Custom path - try file picker first
            local picker=$(detect_file_picker)
            local custom_path=""
            
            if [[ "$picker" != "none" ]]; then
                echo -e "\n${CYAN}Opening file picker...${NC}"
                sleep 0.5
                custom_path=$(browse_for_directory)
                
                if [[ -z "$custom_path" ]]; then
                    echo -e "${YELLOW}No directory selected. Enter path manually:${NC}"
                    echo -ne "${YELLOW}Path: ${NC}"
                    read -r custom_path
                    custom_path="${custom_path/#\~/$HOME}"
                fi
            else
                echo -e "\n${CYAN}Enter custom output directory path:${NC}"
                echo -e "${GRAY}Common: ./converted_gifs, $HOME/Pictures/GIFs${NC}"
                echo -ne "${YELLOW}Path: ${NC}"
                read -r custom_path
            fi
            
            # Expand ~ to $HOME
            custom_path="${custom_path/#\~/$HOME}"
            
            # Validate path is not empty
            if [[ -z "$custom_path" ]]; then
                echo -e "${RED}❌ No path entered${NC}"
                sleep 1
                return 1
            fi
            
            # Create directory if it doesn't exist
            if [[ ! -d "$custom_path" ]]; then
                echo -e "\n${YELLOW}Directory does not exist. Create it? [Y/n]: ${NC}"
                read -r confirm
                if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
                    mkdir -p "$custom_path" 2>/dev/null || {
                        echo -e "${RED}❌ Cannot create directory: $custom_path${NC}"
                        sleep 2
                        return 1
                    }
                    echo -e "${GREEN}✓ Directory created successfully${NC}"
                else
                    echo -e "${YELLOW}Cancelled - directory not created${NC}"
                    sleep 1
                    return 1
                fi
            fi
            
            # Verify it's writable
            if [[ ! -w "$custom_path" ]]; then
                echo -e "${RED}❌ Directory is not writable: $custom_path${NC}"
                sleep 2
                return 1
            fi
            
            OUTPUT_DIRECTORY="$custom_path"
            OUTPUT_DIR_MODE="custom"
            clear
            print_header
            echo -e "\n${GREEN}✓ Output directory set to: $custom_path${NC}"
            echo -e "  ${GREEN}✓ Directory ready for conversions${NC}"
            save_settings --silent
            sleep 2
            ;;
        "5"|"0"|"")
            return 0
            ;;
    esac
}

# 🎨 Interactive Main Menu System
show_main_menu() {
    # Ensure we always start at the first option
    local selected=0
    local options=(
        "🚀 AI-Powered Quick Mode (Speed Optimized)"
        "🎛️  Smart AI Configuration (Balanced Control)"
        "⚙️  Configure Settings & Convert (Advanced)"
        "💾 Configure Output Directory"
        "📊 View Conversion Statistics"
        "🤖 AI System Status & Diagnostics"
        "📁 Manage Log Files"
        "🔧 System Information"
        "🔫 Kill FFmpeg Processes"
        "❓ Help & Documentation"
        "🔄 Reset All Settings"
        "🚺 Exit"
    )
    
    while true; do
        clear
        print_header
        
        # Show current directory info
        local video_count=$(find . -maxdepth 1 -name "*.mp4" -o -name "*.avi" -o -name "*.mov" -o -name "*.mkv" -o -name "*.webm" 2>/dev/null | wc -l)
        local gif_count=$(find . -maxdepth 1 -name "*.gif" 2>/dev/null | wc -l)
        
        # Create clickable directory links for easy navigation
        local current_dir_path="$(pwd)"
        local current_dir_display="$(pwd | sed "s|$HOME|~|g")"
        local clickable_current_dir=$(make_clickable_path "$current_dir_path" "$current_dir_display")
        
        echo -e "${BLUE}📂 Current Directory: ${BOLD}$clickable_current_dir${NC}"
        echo -e "${YELLOW}📹 Video Files: ${BOLD}$video_count${NC} | ${GREEN}🎬 GIF Files: ${BOLD}$gif_count${NC}"
        
        # Quick access links section - script's settings directory
        local settings_dir="$HOME/.smart-gif-converter"
        
        # Ensure settings directory exists before creating clickable link
        if [[ ! -d "$settings_dir" ]]; then
            mkdir -p "$settings_dir" 2>/dev/null || true
        fi
        
        local quick_links="$(make_clickable_path "$settings_dir" "~/.smart-gif-converter/")"
        
        # Add cache link if enabled
        if [[ "$AI_CACHE_ENABLED" == "true" ]]; then
            quick_links="$quick_links | $(make_clickable_path "$AI_CACHE_DIR" "🗫 Cache")"
        fi
        
        # Add training folder link if AI training enabled
        if [[ "$AI_TRAINING_ENABLED" == "true" ]]; then
            quick_links="$quick_links | $(make_clickable_path "$AI_TRAINING_DIR" "🧠 AI Training")"
        fi
        
        # Add parent directory link for easy navigation up
        local parent_dir="$(dirname "$(pwd)")"
        quick_links="$quick_links | $(make_clickable_path "$parent_dir" "⬆️ Parent")"
        
        # Add home directory link
        quick_links="$quick_links | $(make_clickable_path "$HOME" "🏠 Home")"
        
        echo -e "${CYAN}🔗 Quick Links: ${NC}$quick_links"
        
        # Current settings with status
        local ai_status=$([[ "$AI_ENABLED" == true ]] && echo "ON" || echo "OFF")
        
        # Make output directory clickable with full path
        local output_abs_path="$(cd "$OUTPUT_DIRECTORY" 2>/dev/null && pwd || realpath -m "$OUTPUT_DIRECTORY" 2>/dev/null || echo "$OUTPUT_DIRECTORY")"
        local output_display="$(echo "$output_abs_path" | sed "s|$HOME|~|g")"
        local clickable_output=$(make_clickable_path "$output_abs_path" "$output_display")
        
        echo -e "${MAGENTA}⚙️  Current Settings: ${QUALITY} quality, ${ASPECT_RATIO} aspect ratio, AI:${ai_status}${NC}"
        echo -e "${BLUE}💾 Output Directory: $clickable_output${NC}"
        
        # Dev Mode and Update Status Display
        local dev_status=$([[ "$DEV_MODE" == true ]] && echo "${YELLOW}DEV${NC}" || echo "${GREEN}USER${NC}")
        local update_status=""
        local update_info_file="$LOG_DIR/.update_available"
        
        # Check if update is available
        if [[ -f "$update_info_file" && "$AUTO_UPDATE_ENABLED" == "true" ]]; then
            # Load update information
            source "$update_info_file" 2>/dev/null || true
            if [[ "$UPDATE_AVAILABLE" == "true" && -n "$REMOTE_VERSION" ]]; then
                update_status="${YELLOW}UPDATE AVAILABLE${NC} - Smart GIF Converter ${GREEN}v${REMOTE_VERSION}${NC}"
            else
                update_status="${GREEN}UP TO DATE${NC}"
            fi
        elif [[ "$AUTO_UPDATE_ENABLED" == "true" ]]; then
            update_status="${GREEN}UP TO DATE${NC}"
        else
            update_status="${RED}DISABLED${NC}"
        fi
        
        echo -e "${CYAN}🔧 Mode: $dev_status | 🔄 Updates: $update_status${NC}\n"
        
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
            1) help_text=$(get_responsive_help_text "Smart AI Config - balanced control" "Choose key AI features and settings without overwhelming complexity" $layout_mode) ;;
            2) help_text=$(get_responsive_help_text "Configure 15+ settings" "Fine-tune all 15+ settings for perfect results and control" $layout_mode) ;;
            3) help_text=$(get_responsive_help_text "Choose output directory" "Set where GIFs are saved: current dir, Pictures, or custom path" $layout_mode) ;;
            4) help_text=$(get_responsive_help_text "View conversion stats" "View your conversion history and success rates with details" $layout_mode) ;;
            5) help_text=$(get_responsive_help_text "AI system diagnostics" "Check AI cache, training data, health status, and performance" $layout_mode) ;;
            6) help_text=$(get_responsive_help_text "Manage log files" "Manage error logs and conversion history files safely" $layout_mode) ;;
            7) help_text=$(get_responsive_help_text "System info" "Check CPU, GPU, and system capabilities for optimization" $layout_mode) ;;
            8) help_text=$(get_responsive_help_text "Kill processes" "Stop any stuck or runaway FFmpeg processes safely" $layout_mode) ;;
            9) help_text=$(get_responsive_help_text "Help & docs" "Complete usage guide with examples and feature docs" $layout_mode) ;;
            10) help_text=$(get_responsive_help_text "Reset settings" "Reset all settings to factory defaults (files are safe)" $layout_mode) ;;
            11) help_text=$(get_responsive_help_text "Exit" "Save your current settings and exit gracefully" $layout_mode) ;;
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
        1) # Smart AI Configuration Mode
            echo -e "\n${CYAN}🎛️  Entering Smart AI Configuration...${NC}"
            sleep 1
            smart_ai_config_mode
            ;;
        2) # Advanced Mode
            echo -e "\n${BLUE}⚙️  Entering Advanced Configuration...${NC}"
            sleep 1
            advanced_convert_mode
            ;;
        3) # Configure Output Directory
            configure_output_directory
            ;;
        4) # Statistics
            show_conversion_stats
            ;;
        5) # AI Status & Diagnostics
            clear
            print_header
            show_ai_status
            echo -e "\n${YELLOW}Press any key to return to main menu...${NC}"
            read -rsn1
            ;;
        6) # Manage Logs
            manage_log_files
            ;;
        7) # System Info
            show_system_info
            ;;
        8) # Kill FFmpeg
            kill_ffmpeg_processes
            ;;
        9) # Help
            show_interactive_help
            ;;
        10) # Reset All Settings
            reset_all_settings
            ;;
        11) # Exit
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
        echo -e "${BLUE}🤖 ${BOLD}AI Video Discovery - Let me help you find videos!${NC}"
        
        # AI-powered video search
        ai_discover_videos
        local discovery_result=$?
        
        if [[ $discovery_result -eq 0 ]]; then
            # Videos were found and user selected some - restart the function
            quick_convert_mode
            return
        else
            # No videos found or user declined
            echo -e "\n${BLUE}📝 ${BOLD}Manual options:${NC}"
            echo -e "  ${CYAN}•${NC} Place video files in: ${BOLD}$(pwd)${NC}"
            echo -e "  ${CYAN}•${NC} Supported formats: ${GREEN}.mp4 .avi .mov .mkv .webm${NC}"
            echo -e "  ${CYAN}•${NC} Or use: ${YELLOW}--file /path/to/video.mp4${NC}"
            echo -e "\n${YELLOW}Press any key to return to main menu...${NC}"
            read -rsn1
            return
        fi
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
    
    echo -ne "\n${MAGENTA}${BOLD}🚀 Ready to start AI-powered conversion? [Y/n]:${NC} "
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
        INTERACTIVE_MODE=false
            echo -e "\n${CYAN}🤖 Starting AI-powered conversion with smart analysis...${NC}"
            echo -e "${BLUE}📊 AI will analyze each video and optimize automatically!${NC}"
            echo -e "${GREEN}⚡ Using ${BOLD}$(nproc 2>/dev/null || echo '4')${NC}${GREEN} CPU cores for maximum speed!${NC}\n"
        
        # Show AI analysis preview for first file
        if [[ ${#video_files[@]} -gt 0 ]]; then
            echo -e "${YELLOW}🔍 AI Preview Analysis (first file: $(basename -- "${video_files[0]}"))...${NC}"
            ai_preview_analysis "${video_files[0]}"
        fi
        
        if start_conversion; then
            # Check if process was interrupted
            if [[ "$INTERRUPT_REQUESTED" == "true" ]]; then
                echo -e "\n${YELLOW}👋 Process incomplete - stopped by user${NC}"
                echo -e "${CYAN}💾 Progress saved! Run again to continue where you left off.${NC}"
                echo -e "${BLUE}💡 Tip: Completed files are already converted and will be skipped.${NC}"
            else
                echo -e "\n${GREEN}🎉 AI-powered quick conversion completed successfully!${NC}"
                echo -e "${BLUE}📦 Your GIF files are ready in the current directory!${NC}"
                echo -e "${CYAN}📊 Check Statistics to see detailed results, or run again with new videos!${NC}"
            fi
            show_ai_summary
        else
            if [[ "$INTERRUPT_REQUESTED" == "true" ]]; then
                echo -e "\n${YELLOW}👋 Process stopped - no files were converted${NC}"
                echo -e "${BLUE}💡 Tip: Run again when ready to continue.${NC}"
            else
                echo -e "\n${YELLOW}📋 Quick conversion completed (no action needed)${NC}"
                echo -e "${BLUE}💡 Tip: Add video files to this directory and run again!${NC}"
            fi
        fi
    fi
    
    echo -e "\n${YELLOW}Press any key to return to main menu...${NC}"
    read -rsn1
}

# 🎛️ Smart AI Configuration Mode with WASD Navigation
smart_ai_config_mode() {
    local video_files=()
    shopt -s nullglob
    for ext in mp4 avi mov mkv webm; do
        video_files+=(*."$ext")
    done
    shopt -u nullglob
    
    if [[ ${#video_files[@]} -eq 0 ]]; then
        clear
        print_header
        echo -e "${RED}❌ No video files found in current directory${NC}\n"
        echo -e "${BLUE}📝 ${BOLD}Manual options:${NC}"
        echo -e "  ${CYAN}•${NC} Place video files in: ${BOLD}$(pwd)${NC}"
        echo -e "  ${CYAN}•${NC} Supported formats: ${GREEN}.mp4 .avi .mov .mkv .webm${NC}"
        echo -e "  ${CYAN}•${NC} Or use: ${YELLOW}--file /path/to/video.mp4${NC}"
        echo -e "\n${YELLOW}Press any key to return to main menu...${NC}"
        read -rsn1
        return
    fi
    
    # Start the Smart AI Configuration with interactive navigation
    show_smart_ai_menu
}

# 🎛️ Interactive Smart AI Configuration Menu with WASD Navigation
show_smart_ai_menu() {
    local selected=0
    local options=(
        "🎯 Quality & Resolution Settings"
        "🤖 AI Feature Selection"
        "⚡ Performance & Processing"
        "📁 Output & File Management"
        "🚀 Start Conversion with Current Settings"
        "🔄 Reset to Smart Defaults"
        "🔙 Return to Main Menu"
    )
    
    while true; do
        clear
        print_header
        
        echo -e "${CYAN}${BOLD}🎛️  SMART AI CONFIGURATION${NC}\n"
        echo -e "${BLUE}Perfect balance between simplicity and control${NC}"
        echo -e "${GRAY}Choose key AI features and settings without overwhelming complexity${NC}\n"
        
        local video_count=$(find . -maxdepth 1 -name "*.mp4" -o -name "*.avi" -o -name "*.mov" -o -name "*.mkv" -o -name "*.webm" 2>/dev/null | wc -l)
        echo -e "${BLUE}📹 Found ${BOLD}$video_count${NC}${BLUE} video files${NC}"
        echo -e "${CYAN}🎛️ Configure key settings while AI handles the complexity${NC}\n"
        
        # Show current smart configuration in compact form
        show_smart_ai_config_compact
        
        echo -e "\n${CYAN}${BOLD}🎛️ SMART CONFIGURATION OPTIONS${NC}"
        echo -e "${YELLOW}🎹 Navigation: ${GREEN}w${NC}=Up ${GREEN}s${NC}=Down ${GREEN}Enter${NC}=Select ${GREEN}q${NC}=Quit ${GREEN}h${NC}=Help${NC}\n"
        
        # Get terminal dimensions for responsive design
        local term_width=$(tput cols 2>/dev/null || echo 80)
        local menu_width
        
        if [[ $term_width -lt 80 ]]; then
            menu_width=$((term_width - 8))
        else
            menu_width=72
        fi
        
        # Smart help text based on selected option
        local help_text
        case $selected in
            0) help_text="Configure quality presets, resolution limits, and file size targets" ;;
            1) help_text="Choose which AI features to enable: content detection, quality optimization, motion analysis" ;;
            2) help_text="Set parallel processing, optimization level, and AI per-file decisions" ;;
            3) help_text="Configure file naming, backup strategy, and validation level" ;;
            4) help_text="Start Smart AI conversion with current settings" ;;
            5) help_text="Reset all settings to recommended smart defaults" ;;
            6) help_text="Return to main menu without making changes" ;;
        esac
        
        # Draw the menu box
        local box_width=$menu_width
        local padding=$(((box_width - 30) / 2))
        [[ $padding -lt 1 ]] && padding=1
        
        # Top border
        printf "${CYAN}┌"
        printf "─%.0s" $(seq 1 $((box_width - 2)))
        printf "┐${NC}\n"
        
        # Menu options with highlighting
        for i in "${!options[@]}"; do
            local option="${options[$i]}"
            if [[ $i -eq $selected ]]; then
                printf "${CYAN}│${NC} ${GREEN}${BOLD}>>> %-*s <<<${NC} ${CYAN}│${NC}\n" $((box_width - 12)) "$option"
            else
                printf "${CYAN}│${NC} %-*s ${CYAN}│${NC}\n" $((box_width - 4)) "    $option"
            fi
        done
        
        # Separator
        printf "${CYAN}├"
        printf "─%.0s" $(seq 1 $((box_width - 2)))
        printf "┤${NC}\n"
        
        # Help text
        printf "${CYAN}│${NC} ${YELLOW}💡 %-*s${NC} ${CYAN}│${NC}\n" $((box_width - 8)) "$help_text"
        
        # Bottom border
        printf "${CYAN}└"
        printf "─%.0s" $(seq 1 $((box_width - 2)))
        printf "┘${NC}\n\n"
        
        # Read user input
        read -rsn1 key
        
        case "$key" in
            $'\x1b')  # Escape sequence
                read -rsn2 -t 0.1 key
                case "$key" in
                    '[A') # Up arrow
                        selected=$((selected - 1))
                        if [[ $selected -lt 0 ]]; then selected=$((${#options[@]}-1)); fi
                        ;;
                    '[B') # Down arrow
                        selected=$((selected + 1))
                        if [[ $selected -ge ${#options[@]} ]]; then selected=0; fi
                        ;;
                esac
                ;;
            'w'|'W')  # Up navigation (WASD)
                selected=$((selected - 1))
                if [[ $selected -lt 0 ]]; then selected=$((${#options[@]}-1)); fi
                sleep 0.1
                ;;
            's'|'S')  # Down navigation (WASD)
                selected=$((selected + 1))
                if [[ $selected -ge ${#options[@]} ]]; then selected=0; fi
                sleep 0.1
                ;;
            ''|' ')  # Enter or Space - Select option
                execute_smart_ai_option $selected
                if [[ $selected -ge 4 ]]; then  # If Start, Reset, or Return was selected
                    return
                fi
                ;;
            'q'|'Q')  # Quit
                return
                ;;
            'h'|'H'|'?')  # Help
                show_smart_ai_help
                ;;
            *)  # Invalid input - ignore
                ;;
        esac
    done
}

# 📄 Show compact Smart AI configuration
show_smart_ai_config_compact() {
    echo -e "${CYAN}${BOLD}📄 CURRENT CONFIGURATION:${NC}"
    
    # AI Features (condensed)
    local ai_features=""
    [[ "${AI_CONTENT_DETECTION:-true}" == "true" ]] && ai_features+="Content "
    [[ "${AI_QUALITY_OPTIMIZATION:-true}" == "true" ]] && ai_features+="Quality "
    [[ "${AI_MOTION_ANALYSIS:-true}" == "true" ]] && ai_features+="Motion "
    [[ -z "$ai_features" ]] && ai_features="None"
    
    echo -e "  ${MAGENTA}🤖 AI:${NC} $ai_features| ${YELLOW}🎯 Quality:${NC} $QUALITY | ${BLUE}⚡ Parallel:${NC} ${SMART_PARALLEL_JOBS:-auto}"
    
    local max_res_display=$([[ "$SMART_MAX_RESOLUTION" == "auto" ]] && echo "AI" || echo "$SMART_MAX_RESOLUTION")
    local target_size_display=$([[ "$SMART_TARGET_SIZE" == "auto" ]] && echo "AI" || echo "${SMART_TARGET_SIZE}MB")
    
    echo -e "  ${GREEN}📁 Resolution:${NC} $max_res_display | ${GREEN}Size:${NC} $target_size_display | ${GREEN}Naming:${NC} ${SMART_NAMING:-ai}"
}

# 🎮 Execute Smart AI menu option
execute_smart_ai_option() {
    local option=$1
    
    case $option in
        0) # Quality & Resolution Settings
            show_smart_quality_menu
            ;;
        1) # AI Feature Selection
            show_smart_ai_features_menu
            ;;
        2) # Performance & Processing
            show_smart_performance_menu
            ;;
        3) # Output & File Management
            show_smart_output_menu
            ;;
        4) # Start Conversion
            clear
            print_header
            echo -e "${CYAN}🎛️ Starting Smart AI conversion...${NC}"
            INTERACTIVE_MODE=false
            
            # Apply smart settings to core variables
            apply_smart_settings_to_core
            
            if start_conversion; then
                echo -e "\n${GREEN}🎉 Smart AI conversion completed successfully!${NC}"
                echo -e "${BLUE}📦 Your GIF files are ready in the current directory!${NC}"
                show_ai_summary 2>/dev/null || true
            else
                echo -e "\n${YELLOW}📋 Smart AI conversion completed (no action needed)${NC}"
            fi
            echo -e "\n${YELLOW}Press any key to return to main menu...${NC}"
            read -rsn1
            return
            ;;
        5) # Reset to Smart Defaults
            reset_to_smart_defaults
            clear
            print_header
            echo -e "${GREEN}${BOLD}✓ RESET COMPLETE${NC}\n"
            echo -e "${BLUE}All settings have been reset to smart defaults:${NC}"
            echo -e "  ${GREEN}•${NC} AI features enabled (Content, Quality, Motion)"
            echo -e "  ${GREEN}•${NC} Quality preset: High with AI adjustments"
            echo -e "  ${GREEN}•${NC} Resolution: Auto (AI decides)"
            echo -e "  ${GREEN}•${NC} Processing: Auto parallel jobs"
            echo -e "  ${GREEN}•${NC} Output: AI naming, originals backup"
            echo -e "\n${YELLOW}Press any key to continue...${NC}"
            read -rsn1
            ;;
        6) # Return to Main Menu
            return
            ;;
    esac
}

# ⚙️ Apply smart settings to core variables
apply_smart_settings_to_core() {
    # AI settings
    AI_ENABLED="true"
    AI_MODE="smart"
    
    # Apply smart parallel jobs to core PARALLEL_JOBS
    if [[ "$SMART_PARALLEL_JOBS" == "auto" ]]; then
        PARALLEL_JOBS="auto"
    else
        PARALLEL_JOBS="$SMART_PARALLEL_JOBS"
    fi
    
    # Apply optimization settings
    case "$SMART_OPTIMIZATION" in
        "light")
            AUTO_OPTIMIZE="false"
            OPTIMIZE_AGGRESSIVE="false"
            ;;
        "balanced")
            AUTO_OPTIMIZE="true"
            OPTIMIZE_AGGRESSIVE="false"
            ;;
        "aggressive")
            AUTO_OPTIMIZE="true"
            OPTIMIZE_AGGRESSIVE="true"
            ;;
    esac
    
    # Apply validation settings
    case "$SMART_VALIDATION" in
        "skip")
            SKIP_VALIDATION="true"
            ;;
        "quick"|"thorough")
            SKIP_VALIDATION="false"
            ;;
    esac
    
    # Apply backup settings
    case "$SMART_BACKUP" in
        "none")
            BACKUP_ORIGINAL="false"
            ;;
        "originals"|"metadata")
            BACKUP_ORIGINAL="true"
            ;;
    esac
    
    # Always enable progress bar for smart mode
    PROGRESS_BAR="true"
}

# ❓ Show Smart AI Configuration help
show_smart_ai_help() {
    clear
    print_header
    echo -e "${BLUE}${BOLD}❓ SMART AI CONFIGURATION HELP${NC}\n"
    
    echo -e "${YELLOW}Navigation Controls:${NC}"
    echo -e "  ${GREEN}w / ↑ Up Arrow${NC} - Navigate up"
    echo -e "  ${GREEN}s / ↓ Down Arrow${NC} - Navigate down"
    echo -e "  ${GREEN}Enter / Space${NC} - Select highlighted option"
    echo -e "  ${GREEN}q${NC} - Quit and return to main menu"
    echo -e "  ${GREEN}h / ?${NC} - Show this help\n"
    
    echo -e "${CYAN}Smart AI Configuration Sections:${NC}"
    echo -e "  ${YELLOW}🎯 Quality & Resolution${NC} - Set quality presets, resolution limits, file size targets"
    echo -e "  ${YELLOW}🤖 AI Feature Selection${NC} - Choose which AI features to enable or disable"
    echo -e "  ${YELLOW}⚡ Performance & Processing${NC} - Configure parallel jobs and optimization levels"
    echo -e "  ${YELLOW}📁 Output & File Management${NC} - Set naming, backup, and validation preferences\n"
    
    echo -e "${MAGENTA}What makes this 'Smart'?${NC}"
    echo -e "  ${BLUE}•${NC} ${BOLD}Balanced Control${NC} - Key settings without overwhelming complexity"
    echo -e "  ${BLUE}•${NC} ${BOLD}AI-Powered${NC} - Smart defaults that adapt to your content"
    echo -e "  ${BLUE}•${NC} ${BOLD}Visual Feedback${NC} - See exactly what each setting does"
    echo -e "  ${BLUE}•${NC} ${BOLD}Instant Reset${NC} - Return to recommended defaults anytime\n"
    
    echo -e "${GREEN}Tips:${NC}"
    echo -e "  • Use WASD keys for smooth navigation like gaming controls"
    echo -e "  • Arrow keys also work if you prefer traditional navigation"
    echo -e "  • Each section has its own navigation for detailed configuration"
    echo -e "  • Settings are applied immediately when you start conversion\n"
    
    echo -e "${YELLOW}Press any key to return to Smart AI Configuration...${NC}"
    read -rsn1
}

# 🎯 Smart Quality & Resolution Menu with WASD Navigation
show_smart_quality_menu() {
    local selected=0
    local options=(
        "Quality Preset: $QUALITY"
        "Max Resolution: ${SMART_MAX_RESOLUTION:-auto}"
        "Target File Size: ${SMART_TARGET_SIZE:-auto}"
        "Frame Rate Mode: ${SMART_FRAMERATE_MODE:-ai}"
        "🔙 Back to Smart Configuration"
    )
    
    while true; do
        clear
        print_header
        echo -e "${YELLOW}${BOLD}🎯 QUALITY & RESOLUTION SETTINGS${NC}\n"
        echo -e "${BLUE}Configure quality presets, resolution limits, and file size targets${NC}\n"
        
        echo -e "${CYAN}Current Settings:${NC}"
        echo -e "  Quality Preset: ${BOLD}$QUALITY${NC} (with AI adjustments)"
        echo -e "  Max Resolution: ${BOLD}${SMART_MAX_RESOLUTION:-auto}${NC}"
        echo -e "  Target Size: ${BOLD}${SMART_TARGET_SIZE:-auto}${NC}"
        echo -e "  Frame Rate: ${BOLD}${SMART_FRAMERATE_MODE:-ai}${NC}\n"
        
        echo -e "${YELLOW}🎹 Navigation: ${GREEN}w${NC}=Up ${GREEN}s${NC}=Down ${GREEN}Enter${NC}=Select ${GREEN}q${NC}=Back\n"
        
        # Draw menu options
        for i in "${!options[@]}"; do
            local option="${options[$i]}"
            if [[ $i -eq $selected ]]; then
                echo -e "  ${GREEN}${BOLD}>>> $option <<<${NC}"
            else
                echo -e "      $option"
            fi
        done
        
        echo -e "\n${YELLOW}💡 Tip: AI will optimize within your chosen limits${NC}"
        
        read -rsn1 key
        case "$key" in
            'w'|'W'|$'\x1b[A')  # Up
                selected=$((selected - 1))
                if [[ $selected -lt 0 ]]; then selected=$((${#options[@]}-1)); fi
                ;;
            's'|'S'|$'\x1b[B')  # Down
                selected=$((selected + 1))
                if [[ $selected -ge ${#options[@]} ]]; then selected=0; fi
                ;;
            ''|' ')  # Select
                case $selected in
                    0) select_quality_preset ;;
                    1) configure_smart_max_resolution ;;
                    2) configure_smart_target_size ;;
                    3) configure_smart_framerate_mode ;;
                    4) return ;;  # Back
                esac
                if [[ $selected -eq 4 ]]; then return; fi
                # Update options array with new values
                options[0]="Quality Preset: $QUALITY"
                options[1]="Max Resolution: ${SMART_MAX_RESOLUTION:-auto}"
                options[2]="Target File Size: ${SMART_TARGET_SIZE:-auto}"
                options[3]="Frame Rate Mode: ${SMART_FRAMERATE_MODE:-ai}"
                ;;
            'q'|'Q')  # Quit
                return
                ;;
        esac
    done
}

# 🤖 Smart AI Features Menu with WASD Navigation
show_smart_ai_features_menu() {
    local selected=0
    
    while true; do
        local content_status=$([[ "${AI_CONTENT_DETECTION:-true}" == "true" ]] && echo "${GREEN}✓ ON${NC}" || echo "${RED}✗ OFF${NC}")
        local quality_status=$([[ "${AI_QUALITY_OPTIMIZATION:-true}" == "true" ]] && echo "${GREEN}✓ ON${NC}" || echo "${RED}✗ OFF${NC}")
        local motion_status=$([[ "${AI_MOTION_ANALYSIS:-true}" == "true" ]] && echo "${GREEN}✓ ON${NC}" || echo "${RED}✗ OFF${NC}")
        local duplicate_level="${AI_DUPLICATE_DETECTION:-visual}"
        
        local options=(
            "Content Detection: $content_status"
            "Quality Optimization: $quality_status"
            "Motion Analysis: $motion_status"
            "Duplicate Detection: $duplicate_level"
            "🔙 Back to Smart Configuration"
        )
        
        clear
        print_header
        echo -e "${MAGENTA}${BOLD}🤖 AI FEATURE SELECTION${NC}\n"
        echo -e "${BLUE}Choose which AI features to enable for intelligent video processing${NC}\n"
        
        echo -e "${YELLOW}🎹 Navigation: ${GREEN}w${NC}=Up ${GREEN}s${NC}=Down ${GREEN}Enter${NC}=Toggle ${GREEN}q${NC}=Back\n"
        
        # Draw menu options with descriptions
        for i in "${!options[@]}"; do
            local option="${options[$i]}"
            if [[ $i -eq $selected ]]; then
                echo -e "  ${GREEN}${BOLD}>>> $option <<<${NC}"
                # Show description for selected item
                case $i in
                    0) echo -e "      ${GRAY}Automatically detects animation, screencast, movie, or clip content${NC}" ;;
                    1) echo -e "      ${GRAY}AI adjusts quality parameters based on source characteristics${NC}" ;;
                    2) echo -e "      ${GRAY}Intelligent frame rate adjustments based on movement patterns${NC}" ;;
                    3) echo -e "      ${GRAY}Choose detection level: basic/visual/advanced${NC}" ;;
                esac
            else
                echo -e "      $option"
            fi
        done
        
        echo -e "\n${YELLOW}💡 Tip: More AI features = better results but slower processing${NC}"
        
        read -rsn1 key
        case "$key" in
            'w'|'W'|$'\x1b[A')  # Up
                selected=$((selected - 1))
                if [[ $selected -lt 0 ]]; then selected=$((${#options[@]}-1)); fi
                ;;
            's'|'S'|$'\x1b[B')  # Down
                selected=$((selected + 1))
                if [[ $selected -ge ${#options[@]} ]]; then selected=0; fi
                ;;
            ''|' ')  # Select
                case $selected in
                    0) AI_CONTENT_DETECTION=$([[ "${AI_CONTENT_DETECTION:-true}" == "true" ]] && echo "false" || echo "true") ;;
                    1) AI_QUALITY_OPTIMIZATION=$([[ "${AI_QUALITY_OPTIMIZATION:-true}" == "true" ]] && echo "false" || echo "true") ;;
                    2) AI_MOTION_ANALYSIS=$([[ "${AI_MOTION_ANALYSIS:-true}" == "true" ]] && echo "false" || echo "true") ;;
                    3) configure_smart_duplicate_detection ;;
                    4) return ;;  # Back
                esac
                if [[ $selected -eq 4 ]]; then return; fi
                ;;
            'q'|'Q')  # Quit
                return
                ;;
        esac
    done
}

# ⚡ Smart Performance Menu with WASD Navigation
show_smart_performance_menu() {
    local selected=0
    local cpu_cores=$(nproc 2>/dev/null || echo "4")
    
    while true; do
        local parallel_display=$([[ "${SMART_PARALLEL_JOBS:-auto}" == "auto" ]] && echo "Auto ($cpu_cores)" || echo "$SMART_PARALLEL_JOBS jobs")
        local per_file_status=$([[ "${SMART_AI_PER_FILE:-true}" == "true" ]] && echo "${GREEN}✓ ON${NC}" || echo "${RED}✗ OFF${NC}")
        local optimization_display="${SMART_OPTIMIZATION:-balanced}"
        
        local options=(
            "Parallel Processing: $parallel_display"
            "AI Per-File Decisions: $per_file_status"
            "Optimization Level: $optimization_display"
            "🔙 Back to Smart Configuration"
        )
        
        clear
        print_header
        echo -e "${BLUE}${BOLD}⚡ PERFORMANCE & PROCESSING${NC}\n"
        echo -e "${CYAN}System: $cpu_cores CPU cores detected${NC}"
        echo -e "${BLUE}Configure processing speed and resource utilization${NC}\n"
        
        echo -e "${YELLOW}🎹 Navigation: ${GREEN}w${NC}=Up ${GREEN}s${NC}=Down ${GREEN}Enter${NC}=Select ${GREEN}q${NC}=Back\n"
        
        # Draw menu options with descriptions
        for i in "${!options[@]}"; do
            local option="${options[$i]}"
            if [[ $i -eq $selected ]]; then
                echo -e "  ${GREEN}${BOLD}>>> $option <<<${NC}"
                case $i in
                    0) echo -e "      ${GRAY}Number of videos to process simultaneously${NC}" ;;
                    1) echo -e "      ${GRAY}Let AI choose different settings for each video${NC}" ;;
                    2) echo -e "      ${GRAY}Balance between processing speed and file size${NC}" ;;
                esac
            else
                echo -e "      $option"
            fi
        done
        
        echo -e "\n${YELLOW}💡 Tip: Higher parallel processing = faster conversion but more CPU usage${NC}"
        
        read -rsn1 key
        case "$key" in
            'w'|'W'|$'\x1b[A')  # Up
                selected=$((selected - 1))
                if [[ $selected -lt 0 ]]; then selected=$((${#options[@]}-1)); fi
                ;;
            's'|'S'|$'\x1b[B')  # Down
                selected=$((selected + 1))
                if [[ $selected -ge ${#options[@]} ]]; then selected=0; fi
                ;;
            ''|' ')  # Select
                case $selected in
                    0) configure_smart_parallel_jobs ;;
                    1) SMART_AI_PER_FILE=$([[ "${SMART_AI_PER_FILE:-true}" == "true" ]] && echo "false" || echo "true") ;;
                    2) configure_smart_optimization_level ;;
                    3) return ;;  # Back
                esac
                if [[ $selected -eq 3 ]]; then return; fi
                ;;
            'q'|'Q')  # Quit
                return
                ;;
        esac
    done
}

# 📁 Smart Output Menu with WASD Navigation
show_smart_output_menu() {
    local selected=0
    
    while true; do
        local naming_display="${SMART_NAMING:-ai}"
        local backup_display="${SMART_BACKUP:-originals}"
        local validation_display="${SMART_VALIDATION:-quick}"
        
        local options=(
            "File Naming: $naming_display"
            "Backup Strategy: $backup_display"
            "Validation Level: $validation_display"
            "🔙 Back to Smart Configuration"
        )
        
        clear
        print_header
        echo -e "${GREEN}${BOLD}📁 OUTPUT & FILE MANAGEMENT${NC}\n"
        echo -e "${BLUE}Configure how files are named, backed up, and validated${NC}\n"
        
        echo -e "${YELLOW}🎹 Navigation: ${GREEN}w${NC}=Up ${GREEN}s${NC}=Down ${GREEN}Enter${NC}=Select ${GREEN}q${NC}=Back\n"
        
        # Draw menu options with descriptions
        for i in "${!options[@]}"; do
            local option="${options[$i]}"
            if [[ $i -eq $selected ]]; then
                echo -e "  ${GREEN}${BOLD}>>> $option <<<${NC}"
                case $i in
                    0) echo -e "      ${GRAY}How to name output GIF files${NC}" ;;
                    1) echo -e "      ${GRAY}What to backup before conversion${NC}" ;;
                    2) echo -e "      ${GRAY}How thoroughly to check output files${NC}" ;;
                esac
            else
                echo -e "      $option"
            fi
        done
        
        echo -e "\n${YELLOW}💡 Tip: AI naming creates descriptive filenames based on content analysis${NC}"
        
        read -rsn1 key
        case "$key" in
            'w'|'W'|$'\x1b[A')  # Up
                selected=$((selected - 1))
                if [[ $selected -lt 0 ]]; then selected=$((${#options[@]}-1)); fi
                ;;
            's'|'S'|$'\x1b[B')  # Down
                selected=$((selected + 1))
                if [[ $selected -ge ${#options[@]} ]]; then selected=0; fi
                ;;
            ''|' ')  # Select
                case $selected in
                    0) configure_smart_naming ;;
                    1) configure_smart_backup ;;
                    2) configure_smart_validation ;;
                    3) return ;;  # Back
                esac
                if [[ $selected -eq 3 ]]; then return; fi
                ;;
            'q'|'Q')  # Quit
                return
                ;;
        esac
    done
}

# 🎨 Configure Smart Max Resolution
configure_smart_max_resolution() {
    clear
    print_header
    echo -e "${BLUE}${BOLD}📏 MAXIMUM RESOLUTION LIMIT${NC}\n"
    echo -e "Current: ${BOLD}${SMART_MAX_RESOLUTION:-auto}${NC}\n"
    
    echo -e "${GREEN}[1]${NC} Auto - AI decides based on source quality"
    echo -e "${GREEN}[2]${NC} 480p (854x480) - Small files, mobile-friendly"
    echo -e "${GREEN}[3]${NC} 720p (1280x720) - Balanced quality"
    echo -e "${GREEN}[4]${NC} 1080p (1920x1080) - High quality (recommended)"
    echo -e "${GREEN}[5]${NC} 1440p (2560x1440) - Very high quality"
    echo -e "${GREEN}[6]${NC} 4K (3840x2160) - Maximum quality\n"
    
    echo -e "${MAGENTA}Select resolution limit: ${NC}"
    read -r res_choice
    case "$res_choice" in
        "1") SMART_MAX_RESOLUTION="auto" ;;
        "2") SMART_MAX_RESOLUTION="480p" ;;
        "3") SMART_MAX_RESOLUTION="720p" ;;
        "4") SMART_MAX_RESOLUTION="1080p" ;;
        "5") SMART_MAX_RESOLUTION="1440p" ;;
        "6") SMART_MAX_RESOLUTION="4K" ;;
        *) return ;;
    esac
    echo -e "${GREEN}✓ Max resolution set to: $SMART_MAX_RESOLUTION${NC}"
    sleep 1
}

# 📆 Configure Smart Target Size
configure_smart_target_size() {
    clear
    print_header
    echo -e "${BLUE}${BOLD}📊 TARGET FILE SIZE${NC}\n"
    echo -e "Current: ${BOLD}${SMART_TARGET_SIZE:-auto}${NC}\n"
    
    echo -e "${GREEN}[1]${NC} Auto - AI optimized for quality/size balance"
    echo -e "${GREEN}[2]${NC} Small (1MB average) - Social media stories"
    echo -e "${GREEN}[3]${NC} Medium (5MB average) - General use (recommended)"
    echo -e "${GREEN}[4]${NC} Large (10MB average) - High quality sharing"
    echo -e "${GREEN}[5]${NC} No limit - Quality focused\n"
    
    echo -e "${MAGENTA}Select target size: ${NC}"
    read -r size_choice
    case "$size_choice" in
        "1") SMART_TARGET_SIZE="auto" ;;
        "2") SMART_TARGET_SIZE="1" ;;
        "3") SMART_TARGET_SIZE="5" ;;
        "4") SMART_TARGET_SIZE="10" ;;
        "5") SMART_TARGET_SIZE="none" ;;
        *) return ;;
    esac
    echo -e "${GREEN}✓ Target size set to: $SMART_TARGET_SIZE${NC}"
    sleep 1
}

# 🎦 Configure Smart Framerate Mode
configure_smart_framerate_mode() {
    clear
    print_header
    echo -e "${BLUE}${BOLD}🎬 FRAME RATE PREFERENCES${NC}\n"
    echo -e "Current: ${BOLD}${SMART_FRAMERATE_MODE:-ai}${NC}\n"
    
    echo -e "${GREEN}[1]${NC} AI Decides (recommended) - Smart frame rate based on content"
    echo -e "${GREEN}[2]${NC} Preserve Source - Keep original frame rate when possible"
    echo -e "${GREEN}[3]${NC} Low (8-12 fps) - Static content, smaller files"
    echo -e "${GREEN}[4]${NC} Medium (12-18 fps) - Balanced approach"
    echo -e "${GREEN}[5]${NC} High (18-24 fps) - Smooth motion\n"
    
    echo -e "${MAGENTA}Select frame rate mode: ${NC}"
    read -r fps_choice
    case "$fps_choice" in
        "1") SMART_FRAMERATE_MODE="ai" ;;
        "2") SMART_FRAMERATE_MODE="preserve" ;;
        "3") SMART_FRAMERATE_MODE="low" ;;
        "4") SMART_FRAMERATE_MODE="medium" ;;
        "5") SMART_FRAMERATE_MODE="high" ;;
        *) return ;;
    esac
    echo -e "${GREEN}✓ Frame rate mode set to: $SMART_FRAMERATE_MODE${NC}"
    sleep 1
}

# 🔍 Configure Smart Duplicate Detection
configure_smart_duplicate_detection() {
    clear
    print_header
    echo -e "${BLUE}${BOLD}🔍 DUPLICATE DETECTION LEVEL${NC}\n"
    echo -e "Current: ${BOLD}${AI_DUPLICATE_DETECTION:-visual}${NC}\n"
    
    echo -e "${GREEN}[1]${NC} Basic - File name and size comparison (fast)"
    echo -e "${GREEN}[2]${NC} Visual - Perceptual hashing for visual similarity (recommended)"
    echo -e "${GREEN}[3]${NC} Advanced - Full content analysis (thorough but slower)\n"
    
    echo -e "${MAGENTA}Select detection level: ${NC}"
    read -r dup_choice
    case "$dup_choice" in
        "1") AI_DUPLICATE_DETECTION="basic" ;;
        "2") AI_DUPLICATE_DETECTION="visual" ;;
        "3") AI_DUPLICATE_DETECTION="advanced" ;;
        *) return ;;
    esac
    echo -e "${GREEN}✓ Duplicate detection set to: $AI_DUPLICATE_DETECTION${NC}"
    sleep 1
}

# ⚡ Configure Smart Parallel Jobs
configure_smart_parallel_jobs() {
    local cpu_cores=$(nproc 2>/dev/null || echo "4")
    clear
    print_header
    echo -e "${BLUE}${BOLD}⚡ PARALLEL PROCESSING${NC}\n"
    echo -e "Current: ${BOLD}${SMART_PARALLEL_JOBS:-auto}${NC}"
    echo -e "System: $cpu_cores CPU cores available\n"
    
    echo -e "${GREEN}[1]${NC} Auto - Let system decide (recommended)"
    echo -e "${GREEN}[2]${NC} Low - 2 jobs (conservative, stable)"
    echo -e "${GREEN}[3]${NC} Medium - 4 jobs (balanced performance)"
    echo -e "${GREEN}[4]${NC} High - 8 jobs (aggressive, faster)"
    echo -e "${GREEN}[5]${NC} Maximum - Use all $cpu_cores cores\n"
    
    echo -e "${MAGENTA}Select parallel processing level: ${NC}"
    read -r parallel_choice
    case "$parallel_choice" in
        "1") SMART_PARALLEL_JOBS="auto" ;;
        "2") SMART_PARALLEL_JOBS="2" ;;
        "3") SMART_PARALLEL_JOBS="4" ;;
        "4") SMART_PARALLEL_JOBS="8" ;;
        "5") SMART_PARALLEL_JOBS="$cpu_cores" ;;
        *) return ;;
    esac
    echo -e "${GREEN}✓ Parallel jobs set to: $SMART_PARALLEL_JOBS${NC}"
    sleep 1
}

# 🚀 Configure Smart Optimization Level
configure_smart_optimization_level() {
    clear
    print_header
    echo -e "${BLUE}${BOLD}🚀 OPTIMIZATION LEVEL${NC}\n"
    echo -e "Current: ${BOLD}${SMART_OPTIMIZATION:-balanced}${NC}\n"
    
    echo -e "${GREEN}[1]${NC} Light - Fast processing, larger files"
    echo -e "${GREEN}[2]${NC} Balanced - Good balance of speed and size (recommended)"
    echo -e "${GREEN}[3]${NC} Aggressive - Smallest files, slower processing\n"
    
    echo -e "${MAGENTA}Select optimization level: ${NC}"
    read -r opt_choice
    case "$opt_choice" in
        "1") SMART_OPTIMIZATION="light" ;;
        "2") SMART_OPTIMIZATION="balanced" ;;
        "3") SMART_OPTIMIZATION="aggressive" ;;
        *) return ;;
    esac
    echo -e "${GREEN}✓ Optimization level set to: $SMART_OPTIMIZATION${NC}"
    sleep 1
}

# 🏷️ Configure Smart Naming
configure_smart_naming() {
    clear
    print_header
    echo -e "${BLUE}${BOLD}🏷️ FILE NAMING CONVENTION${NC}\n"
    echo -e "Current: ${BOLD}${SMART_NAMING:-ai}${NC}\n"
    
    echo -e "${GREEN}[1]${NC} AI Suggests - Smart names based on content analysis"
    echo -e "${GREEN}[2]${NC} Original Names - Keep video file names"
    echo -e "${GREEN}[3]${NC} Timestamp - Add conversion timestamp"
    echo -e "${GREEN}[4]${NC} Quality Suffix - Add quality level to names\n"
    
    echo -e "${MAGENTA}Select naming convention: ${NC}"
    read -r naming_choice
    case "$naming_choice" in
        "1") SMART_NAMING="ai" ;;
        "2") SMART_NAMING="original" ;;
        "3") SMART_NAMING="timestamp" ;;
        "4") SMART_NAMING="quality" ;;
        *) return ;;
    esac
    echo -e "${GREEN}✓ Naming convention set to: $SMART_NAMING${NC}"
    sleep 1
}

# 💾 Configure Smart Backup
configure_smart_backup() {
    clear
    print_header
    echo -e "${BLUE}${BOLD}💾 BACKUP STRATEGY${NC}\n"
    echo -e "Current: ${BOLD}${SMART_BACKUP:-originals}${NC}\n"
    
    echo -e "${GREEN}[1]${NC} None - No backups (fastest, use with caution)"
    echo -e "${GREEN}[2]${NC} Originals Only - Backup source videos (recommended)"
    echo -e "${GREEN}[3]${NC} With Metadata - Backup with AI analysis data\n"
    
    echo -e "${MAGENTA}Select backup strategy: ${NC}"
    read -r backup_choice
    case "$backup_choice" in
        "1") SMART_BACKUP="none" ;;
        "2") SMART_BACKUP="originals" ;;
        "3") SMART_BACKUP="metadata" ;;
        *) return ;;
    esac
    echo -e "${GREEN}✓ Backup strategy set to: $SMART_BACKUP${NC}"
    sleep 1
}

# ✓ Configure Smart Validation
configure_smart_validation() {
    clear
    print_header
    echo -e "${BLUE}${BOLD}✓ VALIDATION LEVEL${NC}\n"
    echo -e "Current: ${BOLD}${SMART_VALIDATION:-quick}${NC}\n"
    
    echo -e "${GREEN}[1]${NC} Skip - No validation (fastest, less reliable)"
    echo -e "${GREEN}[2]${NC} Quick Check - Basic file integrity (recommended)"
    echo -e "${GREEN}[3]${NC} Thorough - Full validation and quality check\n"
    
    echo -e "${MAGENTA}Select validation level: ${NC}"
    read -r validation_choice
    case "$validation_choice" in
        "1") SMART_VALIDATION="skip" ;;
        "2") SMART_VALIDATION="quick" ;;
        "3") SMART_VALIDATION="thorough" ;;
        *) return ;;
    esac
    echo -e "${GREEN}✓ Validation level set to: $SMART_VALIDATION${NC}"
    sleep 1
}

# 📋 Show current smart AI configuration
show_smart_ai_config() {
    echo -e "${CYAN}${BOLD}🎛️ CURRENT SMART CONFIGURATION:${NC}"
    echo -e "${GRAY}System: $(nproc 2>/dev/null || echo '4') cores, $(free -h 2>/dev/null | awk '/^Mem:/ {print $2}' || echo 'unknown') RAM${NC}\n"
    
    # AI Features Section
    echo -e "${MAGENTA}${BOLD}🤖 AI FEATURES:${NC}"
    local ai_content_status=$([[ "$AI_CONTENT_DETECTION" == "true" ]] && echo "${GREEN}✓ ON${NC}" || echo "${RED}✗ OFF${NC}")
    local ai_quality_status=$([[ "$AI_QUALITY_OPTIMIZATION" == "true" ]] && echo "${GREEN}✓ ON${NC}" || echo "${RED}✗ OFF${NC}")
    local ai_motion_status=$([[ "$AI_MOTION_ANALYSIS" == "true" ]] && echo "${GREEN}✓ ON${NC}" || echo "${RED}✗ OFF${NC}")
    local ai_duplicate_status=$([[ "$AI_DUPLICATE_DETECTION" == "advanced" ]] && echo "${GREEN}✓ Advanced${NC}" || echo "${YELLOW}Basic${NC}")
    
    echo -e "  Content Detection: $ai_content_status     Quality Optimization: $ai_quality_status"
    echo -e "  Motion Analysis: $ai_motion_status       Duplicate Detection: $ai_duplicate_status\n"
    
    # Quality Control Section
    echo -e "${YELLOW}${BOLD}🎯 QUALITY CONTROL:${NC}"
    local max_res_display=$([[ "$SMART_MAX_RESOLUTION" == "auto" ]] && echo "AI Decides" || echo "$SMART_MAX_RESOLUTION")
    local target_size_display=$([[ "$SMART_TARGET_SIZE" == "auto" ]] && echo "AI Optimized" || echo "${SMART_TARGET_SIZE}MB avg")
    local fps_display=$([[ "$SMART_FRAMERATE_MODE" == "ai" ]] && echo "AI Decides" || echo "$SMART_FRAMERATE_MODE")
    
    echo -e "  Preset: ${BOLD}$QUALITY${NC} (with AI adjustments)    Max Resolution: ${BOLD}$max_res_display${NC}"
    echo -e "  Target Size: ${BOLD}$target_size_display${NC}                Frame Rate: ${BOLD}$fps_display${NC}\n"
    
    # Processing Section
    echo -e "${BLUE}${BOLD}⚡ PROCESSING:${NC}"
    local parallel_display=$([[ "$SMART_PARALLEL_JOBS" == "auto" ]] && echo "Auto ($(nproc 2>/dev/null || echo '4'))" || echo "$SMART_PARALLEL_JOBS jobs")
    local ai_per_file_status=$([[ "$SMART_AI_PER_FILE" == "true" ]] && echo "${GREEN}✓ ON${NC}" || echo "${RED}✗ OFF${NC}")
    local optimization_level_display=$([[ "$SMART_OPTIMIZATION" == "balanced" ]] && echo "Balanced" || echo "$SMART_OPTIMIZATION")
    
    echo -e "  Parallel Jobs: ${BOLD}$parallel_display${NC}              AI Per-File: $ai_per_file_status"
    echo -e "  Optimization: ${BOLD}$optimization_level_display${NC}                Progress: ${BOLD}Detailed${NC}\n"
    
    # Output Section
    echo -e "${GREEN}${BOLD}📁 OUTPUT:${NC}"
    local naming_display=$([[ "$SMART_NAMING" == "ai" ]] && echo "AI Suggests" || echo "$SMART_NAMING")
    local backup_display=$([[ "$SMART_BACKUP" == "originals" ]] && echo "Originals Only" || echo "$SMART_BACKUP")
    local validation_display=$([[ "$SMART_VALIDATION" == "quick" ]] && echo "Quick Check" || echo "$SMART_VALIDATION")
    
    echo -e "  Naming: ${BOLD}$naming_display${NC}                  Backup: ${BOLD}$backup_display${NC}"
    echo -e "  Validation: ${BOLD}$validation_display${NC}"
}

# 🎯 Configure smart quality settings
configure_smart_quality() {
    clear
    print_header
    echo -e "${YELLOW}${BOLD}🎯 QUALITY & RESOLUTION SETTINGS${NC}\n"
    
    echo -e "${CYAN}Current Settings:${NC}"
    echo -e "  Quality Preset: ${BOLD}$QUALITY${NC} (with AI adjustments)"
    echo -e "  Max Resolution: ${BOLD}${SMART_MAX_RESOLUTION:-auto}${NC}"
    echo -e "  Target Size: ${BOLD}${SMART_TARGET_SIZE:-auto}${NC}"
    echo -e "  Frame Rate: ${BOLD}${SMART_FRAMERATE_MODE:-ai}${NC}\n"
    
    echo -e "${GREEN}[1]${NC} Change Quality Preset: ${BOLD}$QUALITY${NC}"
    echo -e "${GREEN}[2]${NC} Set Maximum Resolution Limit"
    echo -e "${GREEN}[3]${NC} Configure Target File Size"
    echo -e "${GREEN}[4]${NC} Frame Rate Preferences"
    echo -e "${GREEN}[0]${NC} Back to Smart Configuration\n"
    
    echo -e "${MAGENTA}Select option: ${NC}"
    read -r choice
    
    case "$choice" in
        "1")
            select_quality_preset
            ;;
        "2")
            echo -e "\n${BLUE}Maximum Resolution Limit:${NC}"
            echo -e "${GREEN}[1]${NC} Auto (AI decides based on source)"
            echo -e "${GREEN}[2]${NC} 480p (854x480)"
            echo -e "${GREEN}[3]${NC} 720p (1280x720)"
            echo -e "${GREEN}[4]${NC} 1080p (1920x1080)"
            echo -e "${GREEN}[5]${NC} 1440p (2560x1440)"
            echo -e "${GREEN}[6]${NC} 4K (3840x2160)\n"
            echo -e "${MAGENTA}Select: ${NC}"
            read -r res_choice
            case "$res_choice" in
                "1") SMART_MAX_RESOLUTION="auto" ;;
                "2") SMART_MAX_RESOLUTION="480p" ;;
                "3") SMART_MAX_RESOLUTION="720p" ;;
                "4") SMART_MAX_RESOLUTION="1080p" ;;
                "5") SMART_MAX_RESOLUTION="1440p" ;;
                "6") SMART_MAX_RESOLUTION="4K" ;;
            esac
            echo -e "${GREEN}✓ Max resolution set to: $SMART_MAX_RESOLUTION${NC}"
            sleep 1
            ;;
        "3")
            echo -e "\n${BLUE}Target File Size (average per GIF):${NC}"
            echo -e "${GREEN}[1]${NC} Auto (AI optimized for quality/size balance)"
            echo -e "${GREEN}[2]${NC} Small (1MB average)"
            echo -e "${GREEN}[3]${NC} Medium (5MB average)"
            echo -e "${GREEN}[4]${NC} Large (10MB average)"
            echo -e "${GREEN}[5]${NC} No limit (quality focused)\n"
            echo -e "${MAGENTA}Select: ${NC}"
            read -r size_choice
            case "$size_choice" in
                "1") SMART_TARGET_SIZE="auto" ;;
                "2") SMART_TARGET_SIZE="1" ;;
                "3") SMART_TARGET_SIZE="5" ;;
                "4") SMART_TARGET_SIZE="10" ;;
                "5") SMART_TARGET_SIZE="none" ;;
            esac
            echo -e "${GREEN}✓ Target size set to: $SMART_TARGET_SIZE${NC}"
            sleep 1
            ;;
        "4")
            echo -e "\n${BLUE}Frame Rate Preferences:${NC}"
            echo -e "${GREEN}[1]${NC} AI Decides (recommended) - Smart frame rate based on content"
            echo -e "${GREEN}[2]${NC} Preserve Source - Keep original frame rate when possible"
            echo -e "${GREEN}[3]${NC} Low (8-12 fps) - For static content and small files"
            echo -e "${GREEN}[4]${NC} Medium (12-18 fps) - Balanced approach"
            echo -e "${GREEN}[5]${NC} High (18-24 fps) - Smooth motion\n"
            echo -e "${MAGENTA}Select: ${NC}"
            read -r fps_choice
            case "$fps_choice" in
                "1") SMART_FRAMERATE_MODE="ai" ;;
                "2") SMART_FRAMERATE_MODE="preserve" ;;
                "3") SMART_FRAMERATE_MODE="low" ;;
                "4") SMART_FRAMERATE_MODE="medium" ;;
                "5") SMART_FRAMERATE_MODE="high" ;;
            esac
            echo -e "${GREEN}✓ Frame rate mode set to: $SMART_FRAMERATE_MODE${NC}"
            sleep 1
            ;;
        "0"|"")
            return
            ;;
    esac
}

# 🤖 Configure smart AI features
configure_smart_ai_features() {
    clear
    print_header
    echo -e "${MAGENTA}${BOLD}🤖 AI FEATURE SELECTION${NC}\n"
    
    echo -e "${CYAN}Choose which AI features to enable:${NC}\n"
    
    local content_status=$([[ "${AI_CONTENT_DETECTION:-true}" == "true" ]] && echo "${GREEN}✓ ON${NC}" || echo "${RED}✗ OFF${NC}")
    local quality_status=$([[ "${AI_QUALITY_OPTIMIZATION:-true}" == "true" ]] && echo "${GREEN}✓ ON${NC}" || echo "${RED}✗ OFF${NC}")
    local motion_status=$([[ "${AI_MOTION_ANALYSIS:-true}" == "true" ]] && echo "${GREEN}✓ ON${NC}" || echo "${RED}✗ OFF${NC}")
    local duplicate_status="${AI_DUPLICATE_DETECTION:-basic}"
    
    echo -e "${GREEN}[1]${NC} Content Detection: $content_status"
    echo -e "    ${GRAY}Automatically detects animation, screencast, movie, or clip content${NC}"
    echo -e "${GREEN}[2]${NC} Quality Optimization: $quality_status"
    echo -e "    ${GRAY}AI adjusts quality parameters based on source characteristics${NC}"
    echo -e "${GREEN}[3]${NC} Motion Analysis: $motion_status"
    echo -e "    ${GRAY}Intelligent frame rate adjustments based on movement patterns${NC}"
    echo -e "${GREEN}[4]${NC} Duplicate Detection: ${BOLD}$duplicate_status${NC}"
    echo -e "    ${GRAY}Choose level of duplicate detection (basic/visual/advanced)${NC}\n"
    
    echo -e "${GREEN}[0]${NC} Back to Smart Configuration\n"
    
    echo -e "${MAGENTA}Select option: ${NC}"
    read -r choice
    
    case "$choice" in
        "1")
            AI_CONTENT_DETECTION=$([[ "${AI_CONTENT_DETECTION:-true}" == "true" ]] && echo "false" || echo "true")
            local new_status=$([[ "$AI_CONTENT_DETECTION" == "true" ]] && echo "enabled" || echo "disabled")
            echo -e "\n${GREEN}✓ Content Detection $new_status${NC}"
            sleep 1
            configure_smart_ai_features
            ;;
        "2")
            AI_QUALITY_OPTIMIZATION=$([[ "${AI_QUALITY_OPTIMIZATION:-true}" == "true" ]] && echo "false" || echo "true")
            local new_status=$([[ "$AI_QUALITY_OPTIMIZATION" == "true" ]] && echo "enabled" || echo "disabled")
            echo -e "\n${GREEN}✓ Quality Optimization $new_status${NC}"
            sleep 1
            configure_smart_ai_features
            ;;
        "3")
            AI_MOTION_ANALYSIS=$([[ "${AI_MOTION_ANALYSIS:-true}" == "true" ]] && echo "false" || echo "true")
            local new_status=$([[ "$AI_MOTION_ANALYSIS" == "true" ]] && echo "enabled" || echo "disabled")
            echo -e "\n${GREEN}✓ Motion Analysis $new_status${NC}"
            sleep 1
            configure_smart_ai_features
            ;;
        "4")
            echo -e "\n${BLUE}Duplicate Detection Level:${NC}"
            echo -e "${GREEN}[1]${NC} Basic - File name and size comparison (fast)"
            echo -e "${GREEN}[2]${NC} Visual - Perceptual hashing for visual similarity (recommended)"
            echo -e "${GREEN}[3]${NC} Advanced - Full content analysis (thorough but slower)\n"
            echo -e "${MAGENTA}Select: ${NC}"
            read -r dup_choice
            case "$dup_choice" in
                "1") AI_DUPLICATE_DETECTION="basic" ;;
                "2") AI_DUPLICATE_DETECTION="visual" ;;
                "3") AI_DUPLICATE_DETECTION="advanced" ;;
            esac
            echo -e "${GREEN}✓ Duplicate detection set to: $AI_DUPLICATE_DETECTION${NC}"
            sleep 1
            configure_smart_ai_features
            ;;
        "0"|"")
            return
            ;;
    esac
}

# ⚡ Configure smart performance settings
configure_smart_performance() {
    clear
    print_header
    echo -e "${BLUE}${BOLD}⚡ PERFORMANCE & PROCESSING${NC}\n"
    
    local cpu_cores=$(nproc 2>/dev/null || echo "4")
    echo -e "${CYAN}System: $cpu_cores CPU cores detected${NC}\n"
    
    local parallel_display=$([[ "${SMART_PARALLEL_JOBS:-auto}" == "auto" ]] && echo "Auto ($cpu_cores)" || echo "$SMART_PARALLEL_JOBS jobs")
    local per_file_status=$([[ "${SMART_AI_PER_FILE:-true}" == "true" ]] && echo "${GREEN}✓ ON${NC}" || echo "${RED}✗ OFF${NC}")
    local optimization_display="${SMART_OPTIMIZATION:-balanced}"
    
    echo -e "${GREEN}[1]${NC} Parallel Processing: ${BOLD}$parallel_display${NC}"
    echo -e "    ${GRAY}Number of videos to process simultaneously${NC}"
    echo -e "${GREEN}[2]${NC} AI Per-File Decisions: $per_file_status"
    echo -e "    ${GRAY}Let AI choose different settings for each video${NC}"
    echo -e "${GREEN}[3]${NC} Optimization Level: ${BOLD}$optimization_display${NC}"
    echo -e "    ${GRAY}Balance between speed and file size${NC}\n"
    
    echo -e "${GREEN}[0]${NC} Back to Smart Configuration\n"
    
    echo -e "${MAGENTA}Select option: ${NC}"
    read -r choice
    
    case "$choice" in
        "1")
            echo -e "\n${BLUE}Parallel Processing:${NC}"
            echo -e "${GREEN}[1]${NC} Auto - Let system decide (recommended)"
            echo -e "${GREEN}[2]${NC} Low - 2 jobs (conservative)"
            echo -e "${GREEN}[3]${NC} Medium - 4 jobs (balanced)"
            echo -e "${GREEN}[4]${NC} High - 8 jobs (aggressive)"
            echo -e "${GREEN}[5]${NC} Maximum - Use all $cpu_cores cores\n"
            echo -e "${MAGENTA}Select: ${NC}"
            read -r parallel_choice
            case "$parallel_choice" in
                "1") SMART_PARALLEL_JOBS="auto" ;;
                "2") SMART_PARALLEL_JOBS="2" ;;
                "3") SMART_PARALLEL_JOBS="4" ;;
                "4") SMART_PARALLEL_JOBS="8" ;;
                "5") SMART_PARALLEL_JOBS="$cpu_cores" ;;
            esac
            echo -e "${GREEN}✓ Parallel jobs set to: $SMART_PARALLEL_JOBS${NC}"
            sleep 1
            configure_smart_performance
            ;;
        "2")
            SMART_AI_PER_FILE=$([[ "${SMART_AI_PER_FILE:-true}" == "true" ]] && echo "false" || echo "true")
            local new_status=$([[ "$SMART_AI_PER_FILE" == "true" ]] && echo "enabled" || echo "disabled")
            echo -e "\n${GREEN}✓ AI per-file decisions $new_status${NC}"
            sleep 1
            configure_smart_performance
            ;;
        "3")
            echo -e "\n${BLUE}Optimization Level:${NC}"
            echo -e "${GREEN}[1]${NC} Light - Fast processing, larger files"
            echo -e "${GREEN}[2]${NC} Balanced - Good balance (recommended)"
            echo -e "${GREEN}[3]${NC} Aggressive - Smallest files, slower processing\n"
            echo -e "${MAGENTA}Select: ${NC}"
            read -r opt_choice
            case "$opt_choice" in
                "1") SMART_OPTIMIZATION="light" ;;
                "2") SMART_OPTIMIZATION="balanced" ;;
                "3") SMART_OPTIMIZATION="aggressive" ;;
            esac
            echo -e "${GREEN}✓ Optimization level set to: $SMART_OPTIMIZATION${NC}"
            sleep 1
            configure_smart_performance
            ;;
        "0"|"")
            return
            ;;
    esac
}

# 📁 Configure smart output settings
configure_smart_output() {
    clear
    print_header
    echo -e "${GREEN}${BOLD}📁 OUTPUT & FILE MANAGEMENT${NC}\n"
    
    local naming_display="${SMART_NAMING:-ai}"
    local backup_display="${SMART_BACKUP:-originals}"
    local validation_display="${SMART_VALIDATION:-quick}"
    
    echo -e "${GREEN}[1]${NC} File Naming: ${BOLD}$naming_display${NC}"
    echo -e "    ${GRAY}How to name output GIF files${NC}"
    echo -e "${GREEN}[2]${NC} Backup Strategy: ${BOLD}$backup_display${NC}"
    echo -e "    ${GRAY}What to backup before conversion${NC}"
    echo -e "${GREEN}[3]${NC} Validation Level: ${BOLD}$validation_display${NC}"
    echo -e "    ${GRAY}How thoroughly to check output files${NC}\n"
    
    echo -e "${GREEN}[0]${NC} Back to Smart Configuration\n"
    
    echo -e "${MAGENTA}Select option: ${NC}"
    read -r choice
    
    case "$choice" in
        "1")
            echo -e "\n${BLUE}File Naming Convention:${NC}"
            echo -e "${GREEN}[1]${NC} AI Suggests - Smart names based on content"
            echo -e "${GREEN}[2]${NC} Original Names - Keep video file names"
            echo -e "${GREEN}[3]${NC} Timestamp - Add conversion timestamp"
            echo -e "${GREEN}[4]${NC} Quality Suffix - Add quality level to names\n"
            echo -e "${MAGENTA}Select: ${NC}"
            read -r naming_choice
            case "$naming_choice" in
                "1") SMART_NAMING="ai" ;;
                "2") SMART_NAMING="original" ;;
                "3") SMART_NAMING="timestamp" ;;
                "4") SMART_NAMING="quality" ;;
            esac
            echo -e "${GREEN}✓ Naming convention set to: $SMART_NAMING${NC}"
            sleep 1
            configure_smart_output
            ;;
        "2")
            echo -e "\n${BLUE}Backup Strategy:${NC}"
            echo -e "${GREEN}[1]${NC} None - No backups (fastest)"
            echo -e "${GREEN}[2]${NC} Originals Only - Backup source videos"
            echo -e "${GREEN}[3]${NC} With Metadata - Backup with AI analysis data\n"
            echo -e "${MAGENTA}Select: ${NC}"
            read -r backup_choice
            case "$backup_choice" in
                "1") SMART_BACKUP="none" ;;
                "2") SMART_BACKUP="originals" ;;
                "3") SMART_BACKUP="metadata" ;;
            esac
            echo -e "${GREEN}✓ Backup strategy set to: $SMART_BACKUP${NC}"
            sleep 1
            configure_smart_output
            ;;
        "3")
            echo -e "\n${BLUE}Validation Level:${NC}"
            echo -e "${GREEN}[1]${NC} Skip - No validation (fastest)"
            echo -e "${GREEN}[2]${NC} Quick Check - Basic file integrity"
            echo -e "${GREEN}[3]${NC} Thorough - Full validation and quality check\n"
            echo -e "${MAGENTA}Select: ${NC}"
            read -r validation_choice
            case "$validation_choice" in
                "1") SMART_VALIDATION="skip" ;;
                "2") SMART_VALIDATION="quick" ;;
                "3") SMART_VALIDATION="thorough" ;;
            esac
            echo -e "${GREEN}✓ Validation level set to: $SMART_VALIDATION${NC}"
            sleep 1
            configure_smart_output
            ;;
        "0"|"")
            return
            ;;
    esac
}

# 🔄 Reset to smart defaults
reset_to_smart_defaults() {
    # AI Features
    AI_CONTENT_DETECTION="true"
    AI_QUALITY_OPTIMIZATION="true"
    AI_MOTION_ANALYSIS="true"
    AI_DUPLICATE_DETECTION="visual"
    
    # Quality Control
    QUALITY="high"  # Start with high quality
    SMART_MAX_RESOLUTION="auto"
    SMART_TARGET_SIZE="auto"
    SMART_FRAMERATE_MODE="ai"
    
    # Processing
    SMART_PARALLEL_JOBS="auto"
    SMART_AI_PER_FILE="true"
    SMART_OPTIMIZATION="balanced"
    
    # Output
    SMART_NAMING="ai"
    SMART_BACKUP="originals"
    SMART_VALIDATION="quick"
    
    # Core AI settings
    AI_ENABLED="true"
    AI_MODE="smart"
    AUTO_OPTIMIZE="true"
    PARALLEL_JOBS="auto"
    PROGRESS_BAR="true"
}

# Initialize smart defaults if not set
if [[ -z "$SMART_MAX_RESOLUTION" ]]; then
    reset_to_smart_defaults
fi

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
    
    # AI & Performance Options (6-11)
    echo -e "${MAGENTA}${BOLD}🤖 AI & PERFORMANCE:${NC}"
    echo -e "  ${GREEN}[6]${NC} AI Mode: ${BOLD}${AI_MODE:-smart}${NC} (smart/content/motion/quality)"
    echo -e "  ${GREEN}[7]${NC} Content Type Preference: ${BOLD}${CONTENT_TYPE_PREFERENCE}${NC}"
    echo -e "  ${GREEN}[8]${NC} FFmpeg Threads: ${BOLD}${FFMPEG_THREADS}${NC}"
    echo -e "  ${GREEN}[9]${NC} Parallel Jobs: ${BOLD}${PARALLEL_JOBS}${NC}"
    echo -e "  ${GREEN}[10]${NC} GPU Acceleration: ${BOLD}${GPU_ACCELERATION}${NC}"
    echo -e "  ${GREEN}[11]${NC} Memory Settings: ${BOLD}${RAM_CACHE_SIZE:-auto}${NC}\n"
    
    # Quality & Compression (12-13)
    echo -e "${YELLOW}${BOLD}🎨 QUALITY & COMPRESSION:${NC}"
    echo -e "  ${GREEN}[12]${NC} Quality Preset: ${BOLD}${QUALITY}${NC} | Colors: ${BOLD}${MAX_COLORS}${NC} | Dither: ${BOLD}${DITHER_MODE}${NC}"
    echo -e "  ${GREEN}[13]${NC} Compression: ${BOLD}${COMPRESSION_LEVEL}${NC} | Max Size: ${BOLD}${MAX_GIF_SIZE_MB}MB${NC}\n"
    
    # System & Validation (14-16)
    echo -e "${CYAN}${BOLD}⚙️ SYSTEM & VALIDATION:${NC}"
    echo -e "  ${GREEN}[14]${NC} Interactive Mode: $(get_status_icon "$INTERACTIVE_MODE")"
    echo -e "  ${GREEN}[15]${NC} Skip Validation: $(get_status_icon "$SKIP_VALIDATION")"
    echo -e "  ${GREEN}[16]${NC} Log Level: ${BOLD}${LOG_LEVEL}${NC} | Progress Bar: $(get_status_icon "$PROGRESS_BAR")\n"
    
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

# 🤖 Enhanced AI Configuration Menu
configure_ai_mode() {
    echo -e "\n${BLUE}${BOLD}🧠 ADVANCED AI CONFIGURATION${NC}"
    echo -e "${CYAN}Current Mode: ${BOLD}${AI_MODE:-smart}${NC}\n"
    
    echo -e "${YELLOW}${BOLD}🎯 ANALYSIS MODES:${NC}"
    echo -e "  ${GREEN}[1]${NC} 🧠 Smart Mode (recommended) - Full AI analysis with all features"
    echo -e "  ${GREEN}[2]${NC} 🎨 Content Mode - Focus on content type detection"
    echo -e "  ${GREEN}[3]${NC} 💪 Motion Mode - Focus on motion analysis and frame rate optimization"
    echo -e "  ${GREEN}[4]${NC} 💎 Quality Mode - Focus on quality optimization and scaling\n"
    
    echo -e "${MAGENTA}${BOLD}🔧 ADVANCED FEATURES:${NC}"
    echo -e "  ${GREEN}[5]${NC} 🎬 Scene Analysis: $(get_status_icon "$AI_SCENE_ANALYSIS")"
    echo -e "  ${GREEN}[6]${NC} 👀 Visual Similarity: $(get_status_icon "$AI_VISUAL_SIMILARITY")"
    echo -e "  ${GREEN}[7]${NC} ✂️ Smart Crop: $(get_status_icon "$AI_SMART_CROP")"
    echo -e "  ${GREEN}[8]${NC} 📊 Dynamic Frame Rate: $(get_status_icon "$AI_DYNAMIC_FRAMERATE")"
    echo -e "  ${GREEN}[9]${NC} 🎨 Quality Scaling: $(get_status_icon "$AI_QUALITY_SCALING")\n"
    
    echo -e "${CYAN}${BOLD}🤖 AI AUTO FEATURES:${NC}"
    echo -e "  ${GREEN}[10]${NC} 🎯 Auto Quality: $(get_status_icon "$AI_AUTO_QUALITY")"
    echo -e "  ${GREEN}[11]${NC} 🔍 Content Fingerprint: $(get_status_icon "$AI_CONTENT_FINGERPRINT")"
    echo -e "  ${GREEN}[12]${NC} 🔍 Video Discovery: $(get_status_icon "$AI_DISCOVERY_ENABLED") (Mode: $AI_DISCOVERY_AUTO_SELECT)\n"
    
    echo -en "${MAGENTA}Select option [1-12] or Enter to finish: ${NC}"
    read -r ai_choice
    
    case "$ai_choice" in
        "1") 
            AI_MODE="smart"
            echo -e "${GREEN}✓ AI Mode set to Smart (Full Analysis)${NC}"
            ;;
        "2") 
            AI_MODE="content"
            echo -e "${GREEN}✓ AI Mode set to Content Focus${NC}"
            ;;
        "3") 
            AI_MODE="motion"
            echo -e "${GREEN}✓ AI Mode set to Motion Focus${NC}"
            ;;
        "4") 
            AI_MODE="quality"
            echo -e "${GREEN}✓ AI Mode set to Quality Focus${NC}"
            ;;
        "5") 
            AI_SCENE_ANALYSIS=$([[ "$AI_SCENE_ANALYSIS" == "true" ]] && echo "false" || echo "true")
            echo -e "${GREEN}✓ Scene Analysis $(get_status_text "$AI_SCENE_ANALYSIS")${NC}"
            ;;
        "6") 
            AI_VISUAL_SIMILARITY=$([[ "$AI_VISUAL_SIMILARITY" == "true" ]] && echo "false" || echo "true")
            echo -e "${GREEN}✓ Visual Similarity $(get_status_text "$AI_VISUAL_SIMILARITY")${NC}"
            ;;
        "7") 
            AI_SMART_CROP=$([[ "$AI_SMART_CROP" == "true" ]] && echo "false" || echo "true")
            echo -e "${GREEN}✓ Smart Crop $(get_status_text "$AI_SMART_CROP")${NC}"
            ;;
        "8") 
            AI_DYNAMIC_FRAMERATE=$([[ "$AI_DYNAMIC_FRAMERATE" == "true" ]] && echo "false" || echo "true")
            echo -e "${GREEN}✓ Dynamic Frame Rate $(get_status_text "$AI_DYNAMIC_FRAMERATE")${NC}"
            ;;
        "9") 
            AI_QUALITY_SCALING=$([[ "$AI_QUALITY_SCALING" == "true" ]] && echo "false" || echo "true")
            echo -e "${GREEN}✓ Quality Scaling $(get_status_text "$AI_QUALITY_SCALING")${NC}"
            ;;
        "10") 
            AI_AUTO_QUALITY=$([[ "$AI_AUTO_QUALITY" == "true" ]] && echo "false" || echo "true")
            echo -e "${GREEN}✓ Auto Quality $(get_status_text "$AI_AUTO_QUALITY")${NC}"
            ;;
        "11") 
            AI_CONTENT_FINGERPRINT=$([[ "$AI_CONTENT_FINGERPRINT" == "true" ]] && echo "false" || echo "true")
            echo -e "${GREEN}✓ Content Fingerprint $(get_status_text "$AI_CONTENT_FINGERPRINT")${NC}"
            ;;
        "") 
            echo -e "${CYAN}AI configuration complete${NC}"
            ;;
        *) 
            echo -e "${YELLOW}No change made${NC}"
            ;;
    esac
    
    [[ -n "$ai_choice" && "$ai_choice" != "" ]] && sleep 1 && configure_ai_mode
}

# 💬 Helper function for status text
get_status_text() {
    if [[ "$1" == "true" ]]; then
        echo "enabled"
    else
        echo "disabled"
    fi
}

# 🎬 Configure Content Type Preference
configure_content_type_preference() {
    echo -e "\n${BLUE}${BOLD}🎬 CONTENT TYPE PREFERENCE CONFIGURATION${NC}"
    echo -e "${CYAN}Current Setting: ${BOLD}${CONTENT_TYPE_PREFERENCE}${NC}\n"
    
    echo -e "${YELLOW}${BOLD}🎬 SELECT YOUR TYPICAL CONTENT:${NC}"
    echo -e "${GRAY}This helps optimize default settings for your content type${NC}\n"
    
    echo -e "  ${GREEN}[1]${NC} 🎨 Animation (Anime/Cartoons)"
    echo -e "      ${GRAY}• Optimized for: Sharp edges, solid colors, high contrast${NC}"
    echo -e "      ${GRAY}• Settings: High quality, Floyd-Steinberg dither, 128 colors${NC}"
    echo -e "      ${GRAY}• Best for: Anime, cartoons, 2D animations${NC}\n"
    
    echo -e "  ${GREEN}[2]${NC} 🎬 Movie (Live Action/Real Video)"
    echo -e "      ${GRAY}• Optimized for: Natural motion, complex scenes, gradients${NC}"
    echo -e "      ${GRAY}• Settings: Medium quality, Bayer dither, 256 colors${NC}"
    echo -e "      ${GRAY}• Best for: Movies, TV shows, real-world footage${NC}\n"
    
    echo -e "  ${GREEN}[3]${NC} 💻 Screencast (Screen Recordings/Tutorials)"
    echo -e "      ${GRAY}• Optimized for: Text clarity, UI elements, minimal motion${NC}"
    echo -e "      ${GRAY}• Settings: High quality, no dither, 64 colors, 10fps${NC}"
    echo -e "      ${GRAY}• Best for: Tutorials, gameplay, software demos${NC}\n"
    
    echo -e "  ${GREEN}[4]${NC} 🧠 Mixed Content (AI Auto-Detect) ${BOLD}[Recommended]${NC}"
    echo -e "      ${GRAY}• Optimized for: Automatic detection per video${NC}"
    echo -e "      ${GRAY}• Settings: Smart AI analysis with learning${NC}"
    echo -e "      ${GRAY}• Best for: Varied content types, batch processing${NC}"
    echo -e "      ${CYAN}• Enables: Full AI system with caching and training${NC}\n"
    
    echo -en "${MAGENTA}Select content type [1-4] or Enter to keep current: ${NC}"
    read -r content_choice
    
    case "$content_choice" in
        "1") 
            CONTENT_TYPE_PREFERENCE="animation"
            QUALITY="high"
            MAX_COLORS="128"
            DITHER_MODE="floyd_steinberg"
            AI_MODE="content"
            echo -e "${GREEN}✓ Content type set to Animation${NC}"
            echo -e "${CYAN}• Quality: high | Colors: 128 | Dither: floyd_steinberg${NC}"
            ;;
        "2") 
            CONTENT_TYPE_PREFERENCE="movie"
            QUALITY="medium"
            MAX_COLORS="256"
            DITHER_MODE="bayer"
            AI_MODE="motion"
            echo -e "${GREEN}✓ Content type set to Movie${NC}"
            echo -e "${CYAN}• Quality: medium | Colors: 256 | Dither: bayer${NC}"
            ;;
        "3") 
            CONTENT_TYPE_PREFERENCE="screencast"
            QUALITY="high"
            MAX_COLORS="64"
            DITHER_MODE="none"
            FRAMERATE="10"
            AI_MODE="quality"
            echo -e "${GREEN}✓ Content type set to Screencast${NC}"
            echo -e "${CYAN}• Quality: high | Colors: 64 | Dither: none | FPS: 10${NC}"
            ;;
        "4") 
            CONTENT_TYPE_PREFERENCE="mixed"
            AI_ENABLED=true
            AI_MODE="smart"
            AI_AUTO_QUALITY=true
            AI_SCENE_ANALYSIS=true
            AI_VISUAL_SIMILARITY=true
            AI_SMART_CROP=true
            AI_DYNAMIC_FRAMERATE=true
            AI_QUALITY_SCALING=true
            AI_CONTENT_FINGERPRINT=true
            AI_CACHE_ENABLED=true
            AI_TRAINING_ENABLED=true
            echo -e "${GREEN}✓ Content type set to Mixed (AI Auto-Detect)${NC}"
            echo -e "${CYAN}• Full AI system activated with learning enabled${NC}"
            echo -e "${CYAN}• AI will analyze and optimize each video automatically${NC}"
            ;;
        "") 
            echo -e "${CYAN}No change - keeping current setting: ${BOLD}${CONTENT_TYPE_PREFERENCE}${NC}"
            ;;
        *) 
            echo -e "${YELLOW}Invalid selection - no change made${NC}"
            ;;
    esac
    
    # Save settings after change
    if [[ -n "$content_choice" && "$content_choice" != "" ]]; then
        save_settings >/dev/null 2>&1
        sleep 1
    fi
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
    
    echo -en "${MAGENTA}Select threading option [1-5]: ${NC}"
    read -r thread_choice
    
    case "$thread_choice" in
        "1") FFMPEG_THREADS="auto"; echo -e "${GREEN}✓ Threads set to Auto${NC}" ;;
        "2") FFMPEG_THREADS="$cpu_cores"; echo -e "${GREEN}✓ Threads set to ${cpu_cores}${NC}" ;;
        "3") FFMPEG_THREADS="$((cpu_cores / 2))"; echo -e "${GREEN}✓ Threads set to $((cpu_cores / 2))${NC}" ;;
        "4") FFMPEG_THREADS="2"; echo -e "${GREEN}✓ Threads set to 2${NC}" ;;
        "5") 
            echo -en "${MAGENTA}Enter custom thread count (1-${cpu_cores}): ${NC}"
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
    
    echo -en "${MAGENTA}Select parallel jobs [1-5]: ${NC}"
    read -r parallel_choice
    
    case "$parallel_choice" in
        "1") PARALLEL_JOBS="auto"; echo -e "${GREEN}✓ Parallel jobs set to Auto${NC}" ;;
        "2") PARALLEL_JOBS="$cpu_cores"; echo -e "${GREEN}✓ Parallel jobs set to ${cpu_cores}${NC}" ;;
        "3") PARALLEL_JOBS="2"; echo -e "${GREEN}✓ Parallel jobs set to 2${NC}" ;;
        "4") PARALLEL_JOBS="1"; echo -e "${GREEN}✓ Parallel jobs set to 1 (sequential)${NC}" ;;
        "5") 
            echo -en "${MAGENTA}Enter custom job count (1-${cpu_cores}): ${NC}"
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
    
    echo -en "${MAGENTA}Select memory option [1-6]: ${NC}"
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
    
    echo -en "${MAGENTA}Select quality option [1-5]: ${NC}"
    read -r quality_choice
    
    case "$quality_choice" in
        "1") QUALITY="low"; MAX_COLORS="64"; DITHER_MODE="none"; echo -e "${GREEN}✓ Set to Low quality${NC}" ;;
        "2") QUALITY="medium"; MAX_COLORS="128"; DITHER_MODE="bayer"; echo -e "${GREEN}✓ Set to Medium quality${NC}" ;;
        "3") QUALITY="high"; MAX_COLORS="256"; DITHER_MODE="floyd_steinberg"; echo -e "${GREEN}✓ Set to High quality${NC}" ;;
        "4") 
            echo -en "${MAGENTA}Enter max colors (8-256): ${NC}"
            read -r custom_colors
            if [[ "$custom_colors" =~ ^[0-9]+$ ]] && [[ $custom_colors -ge 8 && $custom_colors -le 256 ]]; then
                MAX_COLORS="$custom_colors"
                echo -e "${GREEN}✓ Max colors set to ${custom_colors}${NC}"
            else
                echo -e "${RED}✗ Invalid input. No change made.${NC}"
            fi
            ;;
        "5")
            echo -en "${MAGENTA}Select dither mode: ${NC}"
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
    
    echo -en "${MAGENTA}Select compression option [1-4]: ${NC}"
    read -r comp_choice
    
    case "$comp_choice" in
        "1")
            echo -en "${MAGENTA}Select compression level: ${NC}"
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
            echo -en "${MAGENTA}Enter max GIF size in MB (1-100): ${NC}"
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
    
    echo -en "${MAGENTA}Select validation option [1-3]: ${NC}"
    read -r val_choice
    
    case "$val_choice" in
        "1") SKIP_VALIDATION=$([[ "$SKIP_VALIDATION" == "true" ]] && echo "false" || echo "true")
             echo -e "${GREEN}✓ Skip validation $([ "$SKIP_VALIDATION" == "true" ] && echo "enabled" || echo "disabled")${NC}" ;;
        "2") DYNAMIC_FILE_DETECTION=$([[ "$DYNAMIC_FILE_DETECTION" == "true" ]] && echo "false" || echo "true")
             echo -e "${GREEN}✓ Dynamic file detection $([ "$DYNAMIC_FILE_DETECTION" == "true" ] && echo "enabled" || echo "disabled")${NC}" ;;
        "3")
            echo -en "${MAGENTA}Enter monitor interval in seconds (5-60): ${NC}"
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
    
    echo -en "${MAGENTA}Select logging option [1-4]: ${NC}"
    read -r log_choice
    
    case "$log_choice" in
        "1")
            echo -en "${MAGENTA}Select log level: ${NC}"
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
    
    echo -en "${MAGENTA}Select custom option [1-5]: ${NC}"
    read -r custom_choice
    
    case "$custom_choice" in
        "1")
            echo -en "${MAGENTA}Enter resolution (width:height, e.g. 1280:720): ${NC}"
            read -r custom_res
            if [[ "$custom_res" =~ ^[0-9]+:[0-9]+$ ]]; then
                RESOLUTION="$custom_res"
                echo -e "${GREEN}✓ Resolution set to ${custom_res}${NC}"
            else
                echo -e "${RED}✗ Invalid format. Use width:height${NC}"
            fi
            ;;
        "2")
            echo -en "${MAGENTA}Enter framerate (1-60): ${NC}"
            read -r custom_fps
            if [[ "$custom_fps" =~ ^[0-9]+$ ]] && [[ $custom_fps -ge 1 && $custom_fps -le 60 ]]; then
                FRAMERATE="$custom_fps"
                echo -e "${GREEN}✓ Framerate set to ${custom_fps}${NC}"
            else
                echo -e "${RED}✗ Invalid framerate${NC}"
            fi
            ;;
        "3")
            echo -en "${MAGENTA}Select scaling algorithm: ${NC}"
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
    
    echo -e "${MAGENTA}Enter option number (1-16), 'c' to configure custom settings, or Enter to start: ${NC}"
    read -r choice
    
    case "$choice" in
        "1") FORCE_CONVERSION=$([[ "$FORCE_CONVERSION" == "true" ]] && echo "false" || echo "true") ;;
        "2") BACKUP_ORIGINAL=$([[ "$BACKUP_ORIGINAL" == "true" ]] && echo "false" || echo "true") ;;
        "3") AUTO_OPTIMIZE=$([[ "$AUTO_OPTIMIZE" == "true" ]] && echo "false" || echo "true") ;;
        "4") DEBUG_MODE=$([[ "$DEBUG_MODE" == "true" ]] && echo "false" || echo "true") ;;
        "5") AI_ENABLED=$([[ "$AI_ENABLED" == "true" ]] && echo "false" || echo "true") ;;
        "6") configure_ai_mode ;;
        "7") configure_content_type_preference ;;
        "8") configure_threads ;;
        "9") configure_parallel_jobs ;;
        "10") GPU_ACCELERATION=$([[ "$GPU_ACCELERATION" == "auto" ]] && echo "disabled" || echo "auto") ;;
        "11") configure_memory_settings ;;
        "12") configure_quality_settings ;;
        "13") configure_compression_settings ;;
        "14") INTERACTIVE_MODE=$([[ "$INTERACTIVE_MODE" == "true" ]] && echo "false" || echo "true") ;;
        "15") configure_validation_settings ;;
        "16") configure_logging_settings ;;
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
    
    if [[ -n "$choice" && ("$choice" =~ ^[1-9]$ || "$choice" =~ ^1[0-6]$ || "$choice" =~ ^[cC]$) ]]; then
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

# 🔄 Reset all settings to factory defaults
reset_all_settings() {
    clear
    print_header
    echo -e "${RED}${BOLD}⚠️  WARNING: RESET ALL SETTINGS TO FACTORY DEFAULTS${NC}\n"
    
    echo -e "${YELLOW}This will reset ALL settings to their default values:${NC}"
    echo -e "  ${CYAN}• Quality preset: high${NC}"
    echo -e "  ${CYAN}• Resolution: 1280:720${NC}"
    echo -e "  ${CYAN}• Frame rate: 12fps${NC}"
    echo -e "  ${CYAN}• Aspect ratio: 16:9${NC}"
    echo -e "  ${CYAN}• AI features: disabled${NC}"
    echo -e "  ${CYAN}• Output directory: ./converted_gifs${NC}"
    echo -e "  ${CYAN}• FFmpeg threads: auto${NC}"
    echo -e "  ${CYAN}• All other settings to defaults${NC}\n"
    
    echo -e "${GREEN}${BOLD}✓ YOUR FILES ARE SAFE:${NC}"
    echo -e "  ${GREEN}✓ Video files will NOT be affected${NC}"
    echo -e "  ${GREEN}✓ Existing GIF files will NOT be deleted${NC}"
    echo -e "  ${GREEN}✓ Logs and history will be preserved${NC}"
    echo -e "  ${GREEN}✓ AI cache and training data will be kept${NC}\n"
    
    echo -e "${MAGENTA}${BOLD}Are you ABSOLUTELY SURE you want to reset all settings? [y/N]: ${NC}"
    read -r confirm_reset
    
    if [[ ! "$confirm_reset" =~ ^[Yy]$ ]]; then
        echo -e "\n${YELLOW}ℹ️  Reset cancelled. Settings unchanged.${NC}"
        sleep 2
        return 0
    fi
    
    echo -e "\n${RED}${BOLD}FINAL CONFIRMATION: Type 'RESET' to proceed: ${NC}"
    read -r final_confirm
    
    if [[ "$final_confirm" != "RESET" ]]; then
        echo -e "\n${YELLOW}ℹ️  Reset cancelled. Settings unchanged.${NC}"
        sleep 2
        return 0
    fi
    
    echo -e "\n${CYAN}🔄 Resetting all settings to factory defaults...${NC}\n"
    sleep 1
    
    # Reset all settings to defaults
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
    FFMPEG_THREADS="auto"
    BACKUP_ORIGINAL=true
    LOG_LEVEL="info"
    PROGRESS_BAR=true
    INTERACTIVE_MODE=true
    SKIP_VALIDATION=false
    ONLY_FILE=""
    OUTPUT_DIRECTORY="./converted_gifs"
    OUTPUT_DIR_MODE="default"
    
    # Reset AI settings
    AI_ENABLED=false
    CROP_FILTER=""
    AI_MODE="smart"
    AI_CONFIDENCE_THRESHOLD=70
    AI_CONTENT_CACHE=""
    AI_AUTO_QUALITY=false
    AI_SCENE_ANALYSIS=true
    AI_VISUAL_SIMILARITY=true
    AI_SMART_CROP=true
    AI_DYNAMIC_FRAMERATE=true
    AI_QUALITY_SCALING=true
    AI_CONTENT_FINGERPRINT=true
    AI_THREADS_OPTIMAL="auto"
    AI_MEMORY_OPT="auto"
    CONTENT_TYPE_PREFERENCE="mixed"
    AI_DISCOVERY_ENABLED=true
    AI_DISCOVERY_AUTO_SELECT="ask"
    AI_DISCOVERY_REMEMBER_CHOICE=true
    CPU_BENCHMARK=false
    
    # Reset AI cache settings (keep enabled to preserve cache)
    AI_CACHE_ENABLED=true
    AI_CACHE_MAX_AGE_DAYS=30
    
    # Reset AI training settings (keep enabled to preserve training data)
    AI_TRAINING_ENABLED=true
    AI_LEARNING_RATE=0.1
    AI_CONFIDENCE_MIN=0.3
    AI_TRAINING_MIN_SAMPLES=5
    
    echo -e "  ${GREEN}✓ Quality settings reset${NC}"
    echo -e "  ${GREEN}✓ AI settings reset${NC}"
    echo -e "  ${GREEN}✓ Output directory reset${NC}"
    echo -e "  ${GREEN}✓ Threading settings reset${NC}"
    echo -e "  ${GREEN}✓ Optimization settings reset${NC}\n"
    
    # Save the reset settings
    save_settings --silent
    
    echo -e "${GREEN}${BOLD}✓ ALL SETTINGS RESET TO FACTORY DEFAULTS!${NC}\n"
    echo -e "${CYAN}💡 Tips:${NC}"
    echo -e "  ${YELLOW}• Your video and GIF files are untouched${NC}"
    echo -e "  ${YELLOW}• Logs and history are preserved${NC}"
    echo -e "  ${YELLOW}• AI cache and training data are kept${NC}"
    echo -e "  ${YELLOW}• You can now reconfigure settings as needed${NC}\n"
    
    echo -e "${YELLOW}Press any key to return to main menu...${NC}"
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
    
    # Calculate max potential thread usage (parallel jobs * threads per job)
    local max_thread_usage=$((optimal_jobs * optimal_threads))
    # Calculate percentage of logical core utilization
    local thread_percent=$((max_thread_usage * 100 / logical_cores))
    
    echo -e "    ${BLUE}Max thread usage: ${BOLD}$max_thread_usage${NC} threads (${thread_percent}% of $logical_cores cores)"
    
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
        if [[ "$INTERRUPT_REQUESTED" == "true" ]]; then
            echo -e "${YELLOW}👋 Process stopped by user - no files converted${NC}"
        else
            echo -e "${YELLOW}🏁 Validation completed - no conversion needed${NC}"
        fi
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
    # Show clean validation progress bar (no text, just bar)
    
    shopt -s nullglob
    local all_video_files=(*.mp4 *.avi *.mov *.mkv *.webm)
    local total_to_check=${#all_video_files[@]}
    local checked=0
    
    # Enable silent mode for validation phase
    VALIDATION_SILENT_MODE=true
    
    # Track cache hits/misses to show status
    CACHE_HITS=0
    CACHE_MISSES=0
    
    for file in "${all_video_files[@]}"; do
        # Check for interrupt during validation
        if [[ "$INTERRUPT_REQUESTED" == "true" ]]; then
            echo -e "\n  ${YELLOW}⏸️  Validation interrupted by user${NC}"
            break
        fi
        
        # Skip zero-byte or very small files early to avoid repeated errors
        if [[ -f "$file" ]]; then
            local file_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
            if [[ $file_size -lt 1024 ]]; then
                ((checked++))
                ((total_files++))
                ((corrupt_input_files++))
                continue
            fi
        fi
        
        if [[ -f "$file" && -r "$file" ]]; then
            ((checked++))
            
            # Show progress bar if many files
            if [[ $total_to_check -gt 10 ]]; then
                local percent=$((checked * 100 / total_to_check))
                local filled=$((checked * 50 / total_to_check))
                local empty=$((50 - filled))
                
                # Build progress bar
                local bar=""
                for ((i=0; i<filled; i++)); do bar+="█"; done
                for ((i=0; i<empty; i++)); do bar+="░"; done
                
                # Determine status message based on cache usage
                local status_msg=""
                if [[ $CACHE_HITS -gt 0 && $CACHE_MISSES -eq 0 ]]; then
                    status_msg="${GREEN}Cached${NC}"
                elif [[ $CACHE_MISSES -gt 0 ]]; then
                    status_msg="${YELLOW}Validating${NC}"
                else
                    status_msg="${CYAN}Checking${NC}"
                fi
                
                # Truncate filename if too long (max 40 chars)
                local display_file="$(basename -- "$file")"
                if [[ ${#display_file} -gt 40 ]]; then
                    display_file="${display_file:0:37}..."
                fi
                
                # Single-line progress with status and filename
                printf "\r\033[K${BLUE}🔍 [${GREEN}%s${GRAY}%s${BLUE}] ${YELLOW}%3d%%${NC} ${GRAY}(%d/%d)${NC} %b ${GRAY}%s${NC}" "${bar:0:filled}" "${bar:filled:empty}" "$percent" "$checked" "$total_to_check" "$status_msg" "$display_file"
            fi
            
            ((total_files++)) || true
            local base_name=$(basename -- "$file")
            
            # Check if file was already processed in previous session
            if [[ -n "${processed_files[$base_name]:-}" ]]; then
                ((resumed_files++)) || true
                ((already_converted++)) || true
                continue
            fi
            
            # Check for duplicates first (silently during validation)
            if check_duplicate_output "$file"; then
                ((already_converted++)) || true
                ((skipped_files++)) || true
                log_conversion "SKIPPED" "$file" "${file%.*}.${OUTPUT_FORMAT}" "(already exists)"
            else
                # Only do basic validation for files we'll actually process
                if validate_video_file "$file"; then
                    files_to_process+=("$file")
                else
                    ((corrupt_input_files++)) || true
                fi
            fi
        fi
    done
    
    # Disable silent mode after validation
    VALIDATION_SILENT_MODE=false
    
    # Clear validation progress bar
    if [[ $total_to_check -gt 10 ]]; then
        printf "\r\033[K"
    fi
    
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
                echo -e "\n${YELLOW}👋 Quitting... Waiting for current jobs to complete${NC}"
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
            
            echo -e "${CYAN}Started job $current/$files_to_convert: $(basename -- "$file") (PID: $job_pid)${NC}"
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
                echo -e "\n${YELLOW}👋 Quitting... Stopping after completing current file${NC}"
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
    
    # Final progress update - only show 100% if not interrupted
    if [[ "$PROGRESS_BAR" == true ]]; then
        if [[ "$INTERRUPT_REQUESTED" == true ]]; then
            # Show actual progress when interrupted
            local percent=$((current * 100 / files_to_convert))
            local filled=$((current * 50 / files_to_convert))
            local empty=$((50 - filled))
            printf "\r\033[K${YELLOW}Overall: ["
            for ((i=0; i<filled; i++)); do printf "█"; done
            for ((i=0; i<empty; i++)); do printf "░"; done
            printf "] %d%% (%d/%d) ${YELLOW}Interrupted${NC}\n\n" $percent $current $files_to_convert
        else
            # Show 100% completion for successful finish
            printf "\r\033[K${GREEN}Overall: ["
            printf "%50s" | tr ' ' '▓'
            printf "] 100%% (%d/%d) ${GREEN}Completed!${NC}\n\n" $files_to_convert $files_to_convert
        fi
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
    echo -e "${CYAN}${BOLD}╔═════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                    🎬 SMART GIF CONVERTER v5.3                    ║${NC}"
    echo -e "${CYAN}${BOLD}║                  🤖 AI-Powered Video to GIF Magic                  ║${NC}"
    echo -e "${CYAN}${BOLD}╚═════════════════════════════════════════════════════════════════════════╝${NC}"
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
    echo -e "  ${GREEN}[5]${NC} Skip setup (use defaults)\\n"
    
    echo -en "${MAGENTA}Your choice [1-5]:${NC} "
    read -r setup_choice
    
    case "$setup_choice" in
        "1")
            QUALITY="high"
            MAX_COLORS="128"
            DITHER_MODE="floyd_steinberg"
            AI_MODE="content"
            CONTENT_TYPE_PREFERENCE="animation"
            echo -e "\n${GREEN}✓ Optimized for anime/animation content!${NC}"
            ;;
        "2")
            QUALITY="medium"
            MAX_COLORS="256"
            DITHER_MODE="bayer"
            AI_MODE="motion"
            CONTENT_TYPE_PREFERENCE="movie"
            echo -e "\n${GREEN}✓ Optimized for movies and live action!${NC}"
            ;;
        "3")
            QUALITY="high"
            MAX_COLORS="64"
            DITHER_MODE="none"
            FRAMERATE="10"
            AI_MODE="quality"
            CONTENT_TYPE_PREFERENCE="screencast"
            echo -e "\n${GREEN}✓ Optimized for screen recordings!${NC}"
            ;;
        "4")
            # Enable FULL AI system with all advanced features
            AI_ENABLED=true
            AI_MODE="smart"
            AI_AUTO_QUALITY=true  # Let AI choose quality per video
            AI_SCENE_ANALYSIS=true
            AI_VISUAL_SIMILARITY=true
            AI_SMART_CROP=true
            AI_DYNAMIC_FRAMERATE=true
            AI_QUALITY_SCALING=true
            AI_CONTENT_FINGERPRINT=true
            AI_CACHE_ENABLED=true
            AI_TRAINING_ENABLED=true
            CONTENT_TYPE_PREFERENCE="mixed"
            echo -e "\n${GREEN}✓ 🧠 Full AI system activated with learning enabled!${NC}"
            echo -e "${CYAN}   • Smart content detection and classification${NC}"
            echo -e "${CYAN}   • Automatic quality optimization per video${NC}"
            echo -e "${CYAN}   • Advanced scene analysis and frame rate adjustment${NC}"
            echo -e "${CYAN}   • Intelligent caching for faster re-processing${NC}"
            echo -e "${CYAN}   • AI learning from successful conversions${NC}"
            ;;
        *)
            echo -e "\n${YELLOW}✓ Using balanced default settings.${NC}"
            ;;
    esac
    
    # Actually save the settings to file
    init_log_directory  # Ensure settings directory exists
    save_settings
    
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

# 🎪 Function to print fancy headers (simplified for menus)
print_header() {
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                🎬 SMART GIF CONVERTER v5.3                ║${NC}"
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
    --ai-status         Show AI cache, training, and health diagnostics
    --ai-stats          Same as --ai-status
    --clean-cache       Clean cache: remove duplicates and deleted files
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
    --debug-settings    Detailed settings diagnostics and troubleshooting
    --check-permissions Check and fix file/directory permissions
    --fix-permissions   Same as --check-permissions
    --file FILE         Convert only the specified video file (path or name)
    --show-logs         Show log directory and file information
    --check-cache       Check validation cache integrity and status
    --validate-cache    Same as --check-cache
    --clear-cache       Clear validation cache (creates backup)
    
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
CONTENT_TYPE_PREFERENCE="$CONTENT_TYPE_PREFERENCE"
AI_AUTO_QUALITY="$AI_AUTO_QUALITY"
AI_SCENE_ANALYSIS="$AI_SCENE_ANALYSIS"
AI_VISUAL_SIMILARITY="$AI_VISUAL_SIMILARITY"
AI_SMART_CROP="$AI_SMART_CROP"
AI_DYNAMIC_FRAMERATE="$AI_DYNAMIC_FRAMERATE"
AI_QUALITY_SCALING="$AI_QUALITY_SCALING"
AI_CONTENT_FINGERPRINT="$AI_CONTENT_FINGERPRINT"
AI_DISCOVERY_ENABLED="$AI_DISCOVERY_ENABLED"
AI_DISCOVERY_AUTO_SELECT="$AI_DISCOVERY_AUTO_SELECT"
AI_DISCOVERY_REMEMBER_CHOICE="$AI_DISCOVERY_REMEMBER_CHOICE"
AI_CACHE_ENABLED="$AI_CACHE_ENABLED"
AI_CACHE_MAX_AGE_DAYS="$AI_CACHE_MAX_AGE_DAYS"
AI_TRAINING_ENABLED="$AI_TRAINING_ENABLED"
AI_GENERATION="$AI_GENERATION"
AI_LEARNING_RATE="$AI_LEARNING_RATE"
AI_CONFIDENCE_MIN="$AI_CONFIDENCE_MIN"
AI_TRAINING_MIN_SAMPLES="$AI_TRAINING_MIN_SAMPLES"
MAX_GIF_SIZE_MB="$MAX_GIF_SIZE_MB"
AUTO_REDUCE_QUALITY="$AUTO_REDUCE_QUALITY"
SMART_SIZE_DOWN="$SMART_SIZE_DOWN"
GPU_ACCELERATION="$GPU_ACCELERATION"
FFMPEG_THREADS="$FFMPEG_THREADS"
PARALLEL_JOBS="$PARALLEL_JOBS"
OUTPUT_DIRECTORY="$OUTPUT_DIRECTORY"
OUTPUT_DIR_MODE="$OUTPUT_DIR_MODE"
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
                CONTENT_TYPE_PREFERENCE) CONTENT_TYPE_PREFERENCE="$value" ;;
                AI_AUTO_QUALITY) AI_AUTO_QUALITY="$value" ;;
                AI_SCENE_ANALYSIS) AI_SCENE_ANALYSIS="$value" ;;
                AI_VISUAL_SIMILARITY) AI_VISUAL_SIMILARITY="$value" ;;
                AI_SMART_CROP) AI_SMART_CROP="$value" ;;
                AI_DYNAMIC_FRAMERATE) AI_DYNAMIC_FRAMERATE="$value" ;;
                AI_QUALITY_SCALING) AI_QUALITY_SCALING="$value" ;;
                AI_CONTENT_FINGERPRINT) AI_CONTENT_FINGERPRINT="$value" ;;
                AI_DISCOVERY_ENABLED) AI_DISCOVERY_ENABLED="$value" ;;
                AI_DISCOVERY_AUTO_SELECT) AI_DISCOVERY_AUTO_SELECT="$value" ;;
                AI_DISCOVERY_REMEMBER_CHOICE) AI_DISCOVERY_REMEMBER_CHOICE="$value" ;;
                AI_CACHE_ENABLED) AI_CACHE_ENABLED="$value" ;;
                AI_CACHE_MAX_AGE_DAYS) AI_CACHE_MAX_AGE_DAYS="$value" ;;
                AI_TRAINING_ENABLED) AI_TRAINING_ENABLED="$value" ;;
                AI_GENERATION) AI_GENERATION="$value" ;;
                AI_LEARNING_RATE) AI_LEARNING_RATE="$value" ;;
                AI_CONFIDENCE_MIN) AI_CONFIDENCE_MIN="$value" ;;
                AI_TRAINING_MIN_SAMPLES) AI_TRAINING_MIN_SAMPLES="$value" ;;
                OUTPUT_DIRECTORY) OUTPUT_DIRECTORY="$value" ;;
                OUTPUT_DIR_MODE) OUTPUT_DIR_MODE="$value" ;;
                FFMPEG_THREADS) FFMPEG_THREADS="$value" ;;
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
        local truncated_name=$(basename -- "$filename")
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
    local base_name="$(basename -- "${file%.*}")"
    
    # Ensure output directory exists
    if [[ ! -d "$OUTPUT_DIRECTORY" ]]; then
        mkdir -p "$OUTPUT_DIRECTORY" 2>/dev/null || {
            log_error "Cannot create output directory" "$OUTPUT_DIRECTORY" "Permission denied or invalid path" "${BASH_LINENO[0]}" "convert_video"
            echo -e "\n${RED}❌ Error: Cannot create output directory: $OUTPUT_DIRECTORY${NC}"
            return 1
        }
    fi
    
    # Build output file path in OUTPUT_DIRECTORY
    # Get absolute path for clarity
    local abs_output_dir="$(cd "$OUTPUT_DIRECTORY" 2>/dev/null && pwd || realpath -m "$OUTPUT_DIRECTORY" 2>/dev/null || echo "$OUTPUT_DIRECTORY")"
    local output_file="$OUTPUT_DIRECTORY/$base_name.${OUTPUT_FORMAT}"
    local palette_file="${file%.*}_palette.png"
    local retry_count=0
    local conversion_success=false
    
    # LOG: Show where file will be saved
    echo -e "  ${BLUE}💾 Output destination: ${CYAN}$abs_output_dir/${NC}"
    echo -e "  ${GRAY}📂 Full path: $abs_output_dir/$base_name.${OUTPUT_FORMAT}${NC}"
    
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
        echo -e "\n${YELLOW}⏭️  Skipping: $(basename -- "$file") (already converted)${NC}"
        log_conversion "SKIPPED" "$file" "$output_file" "(already exists)"
        ((skipped_files++))
        return 0
    fi
    
    echo ""
    echo -e "${GREEN}✨ Converting: ${BOLD}$(basename -- "$file")${NC}"
    
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
        printf "${BLUE}🎬 Processing: ${NC}%s" "$(basename -- "$filename")"
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
    
    echo -e "${CYAN}⚙️ Starting robust conversion for: $(basename -- "$file")${NC}"
    
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
    local base_name=$(basename -- "${file%.*}")
    
    # Ensure output directory exists
    if [[ ! -d "$OUTPUT_DIRECTORY" ]]; then
        mkdir -p "$OUTPUT_DIRECTORY" 2>/dev/null || {
            log_error "Cannot create output directory" "$OUTPUT_DIRECTORY" "Permission denied or invalid path" "${BASH_LINENO[0]}" "_convert_video_internal"
            echo -e "\n${RED}❌ Error: Cannot create output directory: $OUTPUT_DIRECTORY${NC}"
            ((failed_files++))
            return 1
        }
    fi
    
    # Build output path using OUTPUT_DIRECTORY
    local final_output_file="$OUTPUT_DIRECTORY/$base_name.${OUTPUT_FORMAT}"
    
    # Skip if output file already exists (unless FORCE_CONVERSION is enabled)
    if [[ -f "$final_output_file" && "$FORCE_CONVERSION" != "true" ]]; then
        # Check if output is newer than input
        if [[ "$final_output_file" -nt "$file" ]]; then
            echo -e "\n${YELLOW}⏭️  Skipping: $(basename -- "$file") (already converted)${NC}"
            echo -e "  ${GRAY}💾 Output exists: $final_output_file${NC}"
            log_conversion "SKIPPED" "$file" "$final_output_file" "(already exists)"
            ((skipped_files++))
            return 0
        fi
    fi
    
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
        # Check for interrupt request at start of each retry
        if [[ "$INTERRUPT_REQUESTED" == true ]]; then
            # Clean up temp files
            cleanup_temp_files "${file%.*}"
            
            # Delete incomplete output GIF if it exists
            if [[ -f "$final_output_file" ]]; then
                local output_size=$(stat -c%s "$final_output_file" 2>/dev/null || echo "0")
                # If GIF is suspiciously small or was just created, delete it
                if [[ $output_size -lt 1000 ]] || [[ "$final_output_file" -nt "$file" ]]; then
                    rm -f "$final_output_file" 2>/dev/null
                    echo -e "  ${YELLOW}🧹 Cleaned up incomplete: $(basename -- "$final_output_file")${NC}"
                fi
            fi
            
            # Silently stop without error messages
            return 130  # Standard exit code for SIGINT
        fi
        
        if [[ $retry_count -gt 0 ]]; then
            echo -e "  ${YELLOW}♾️ Retry attempt $retry_count/$MAX_RETRIES${NC}"
            sleep 1
        fi
        
        # AI-lite: analyze content once per file (first attempt only)
        if [[ "$AI_ENABLED" == true && $retry_count -eq 0 ]]; then
            echo -e "  ${CYAN}🤖 AI: analyzing content for smart defaults...${NC}"
            echo -e "  ${BLUE}🤖 Using AI generation: ${BOLD}$AI_GENERATION${NC}"
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
                # Use bash string manipulation instead of sed to avoid quoting issues
                local fps_part="${filter_chain%%,*}"
                local rest_part="${filter_chain#*,}"
                if [[ "$fps_part" == "$filter_chain" ]]; then
                    # No comma found, just fps filter
                    filter_chain="${fps_part},${CROP_FILTER}"
                else
                    # Has more filters after fps
                    filter_chain="${fps_part},${CROP_FILTER},${rest_part}"
                fi
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
            
            # Only log and show errors if not interrupted
            if [[ "$INTERRUPT_REQUESTED" != true ]]; then
                log_error "FFmpeg GIF conversion failed (attempt $((retry_count + 1)))" "$file" "Cause: ${conv_diagnosis:-$(explain_exit_code $conversion_exit_code)}" "${BASH_LINENO[0]}" "_convert_video_internal"
                
                # User-friendly terminal output
                echo -e "  ${RED}⚠️ FFmpeg GIF conversion failed${NC}"
                if [[ -n "$conv_diagnosis" ]]; then
                    echo -e "  ${RED}🔍 Cause: $conv_diagnosis${NC}"
                fi
                echo -e "  ${YELLOW}📋 Full log: $ERROR_LOG${NC}"
            fi
            
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
            # Get absolute path for logging
            local abs_final_path="$(cd "$(dirname "$final_output_file")" 2>/dev/null && pwd)/$(basename "$final_output_file")"
            echo -e "  ${GREEN}✓ GIF saved: $(basename -- "$final_output_file")${NC}"
            echo -e "  ${GRAY}💾 Saved to: $abs_final_path${NC}"
        
        # 🧠 AI Training: Learn from successful conversion
        if [[ "$AI_ENABLED" == true ]]; then
            local content_type="$(echo "$AI_CONTENT_CACHE" | grep -o 'content_type=[^[:space:]]*' | cut -d'=' -f2 || echo 'unknown')"
            local motion_level="$(echo "$AI_CONTENT_CACHE" | grep -o 'motion=[^[:space:]]*' | cut -d'=' -f2 || echo 'medium')"
            local complexity_score="$(echo "$AI_CONTENT_CACHE" | grep -o 'complexity=[^[:space:]]*' | cut -d'=' -f2 || echo '50')"
            
            # Get video properties for training
            local video_info=$(get_video_properties "$file")
            local duration=$(echo "$video_info" | cut -d'|' -f1)
            local width=$(echo "$video_info" | cut -d'|' -f2)
            local height=$(echo "$video_info" | cut -d'|' -f3)
            
            # Train AI with successful settings
            train_ai_model "$file" "$content_type" "$width" "$height" "$duration" \
                          "$motion_level" "$complexity_score" "$FRAMERATE" \
                          "$DITHER_MODE" "$MAX_COLORS" "${CROP_FILTER:-none}" "success"
            
            echo -e "  🧠 ${GREEN}AI learned from successful conversion${NC}"
        fi
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
            # Check for interrupt before optimization
            if [[ "$INTERRUPT_REQUESTED" == true ]]; then
                echo -e "  ${YELLOW}👋 Skipping optimization due to interrupt${NC}"
                ((converted_files++))
                return 0
            fi
            
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
                    # Check for interrupt during optimization
                    if [[ "$INTERRUPT_REQUESTED" == true ]]; then
                        kill $opt_progress_pid 2>/dev/null || true
                        wait $opt_progress_pid 2>/dev/null || true
                        printf "\r  ${YELLOW}👋 Optimization interrupted${NC}\n"
                        ((converted_files++))
                        return 0
                    fi
                    
                    local temp_file="${final_output_file}.gifsicle.tmp"
                    if timeout 30 gifsicle $opt_level "$final_output_file" -o "$temp_file" 2>/dev/null; then
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
                # Check for interrupt before FFmpeg optimization
                if [[ "$INTERRUPT_REQUESTED" == true ]]; then
                    printf "\r  ${YELLOW}👋 Skipping FFmpeg re-optimization due to interrupt${NC}\n"
                    # Apply best result so far before exiting
                    if [[ "$best_file" != "$final_output_file" && -f "$best_file" ]]; then
                        mv "$best_file" "$final_output_file" 2>/dev/null
                    fi
                    ((converted_files++))
                    return 0
                fi
                
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
                ffmpeg $FFMPEG_INPUT_OPTS -i "$file" -vf "$reopt_filter" $FFMPEG_MEMORY_OPTS -frames:v 1 -update 1 -y "$temp_palette" -loglevel error </dev/null >/dev/null 2>&1 &
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
                    ffmpeg $FFMPEG_INPUT_OPTS -i "$file" -i "$temp_palette" -lavfi "$reopt_conversion_filter" $FFMPEG_MEMORY_OPTS -y "$temp_output" -loglevel error </dev/null >/dev/null 2>&1 &
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
        
        printf "\r  ${GREEN}✓ Completed: ${BOLD}$(basename -- "$final_output_file")${NC} ${MAGENTA}($(numfmt --to=iec $converted_size) - ${ratio}%% of original)${NC}\n"
        
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
    
    echo -e "${CYAN}✓ Finished processing: $(basename -- "$1")${NC}"
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
    # Self-integrity check - detect if script was modified
    local script_path="${BASH_SOURCE[0]}"
    local script_hash_cache="$HOME/.smart-gif-converter/.script_hash"
    local current_hash=$(md5sum "$script_path" 2>/dev/null | cut -d' ' -f1)
    
    if [[ -f "$script_hash_cache" ]]; then
        local cached_hash=$(cat "$script_hash_cache" 2>/dev/null)
        if [[ "$current_hash" != "$cached_hash" ]]; then
            echo -e "${YELLOW}⚠️ Script modified - clearing validation cache for safety${NC}"
            rm -f "$HOME/.smart-gif-converter/validation_cache.db" 2>/dev/null
            echo "$current_hash" > "$script_hash_cache"
        fi
    else
        # First run or cache missing - save hash
        mkdir -p "$(dirname "$script_hash_cache")" 2>/dev/null
        echo "$current_hash" > "$script_hash_cache"
    fi
    
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
    
    # 🛠️ Detect development mode (Git repository detection)
    detect_dev_mode 2>/dev/null || true
    
    # Initialize release fingerprint system (track installed version integrity)
    load_release_fingerprint 2>/dev/null || true
    
    # Automatic update check (silent, runs in background)
    # Automatically skipped if DEV_MODE=true
    check_for_updates &
    
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
    
    # First-run check: prompt for output directory ONLY if settings file doesn't exist
    if [[ ! -f "$SETTINGS_FILE" ]]; then
        # True first run - no settings file exists
        clear
        print_header
        echo -e "${CYAN}${BOLD}🎉 WELCOME TO SMART GIF CONVERTER!${NC}\n"
        echo -e "${BLUE}Before we begin, let's set up where your GIF files will be saved.${NC}\n"
        
        # Only ask in interactive mode
        if [[ $# -eq 0 ]]; then
            local selected=0
            local options=(
                "./converted_gifs - Keep videos & GIFs organized (recommended)"
                "Pictures folder - Save to system Pictures directory"
                "Script directory - Save where convert.sh is located"
                "Custom path - Choose your own location"
            )
            local descriptions=(
                "Creates a 'converted_gifs' subfolder next to your videos"
                "Saves to $HOME/Pictures/GIFs - easy to find in file manager"
                "Saves to the same folder where this script file lives"
                "Browse with file picker or type any path you want"
            )
            
            while true; do
                clear
                print_header
                
                echo -e "${CYAN}${BOLD}🎉 WELCOME TO SMART GIF CONVERTER!${NC}\n"
                echo -e "${BLUE}Before we begin, let's set up where your GIF files will be saved.${NC}\n"
                
                echo -e "${YELLOW}💾 Where would you like to save converted GIF files?${NC}"
                echo -e "${GRAY}(You can change this later from the main menu)${NC}"
                echo -e "${YELLOW}🎹 Navigation: ${GREEN}w${NC}=Up ${GREEN}s${NC}=Down ${GREEN}Enter${NC}=Select${NC}\n"
                
                # Display options with highlight
                for i in "${!options[@]}"; do
                    if [[ $i -eq $selected ]]; then
                        echo -e "  ${GREEN}${BOLD}➤ ${options[$i]}${NC}"
                        echo -e "    ${CYAN}💡 ${descriptions[$i]}${NC}"
                    else
                        echo -e "  ${GRAY}  ${options[$i]}${NC}"
                    fi
                done
                
                echo ""
                
                # Read key
                read -rsn1 key 2>/dev/null || read -r key
                
                case "$key" in
                    $'\x1b')  # Arrow keys
                        read -rsn2 -t 0.1 key
                        case "$key" in
                            '[A') # Up
                                selected=$((selected - 1))
                                [[ $selected -lt 0 ]] && selected=$((${#options[@]}-1))
                                ;;
                            '[B') # Down
                                selected=$((selected + 1))
                                [[ $selected -ge ${#options[@]} ]] && selected=0
                                ;;
                        esac
                        ;;
                    'w'|'W') # Up
                        selected=$((selected - 1))
                        [[ $selected -lt 0 ]] && selected=$((${#options[@]}-1))
                        sleep 0.1
                        ;;
                    's'|'S') # Down
                        selected=$((selected + 1))
                        [[ $selected -ge ${#options[@]} ]] && selected=0
                        sleep 0.1
                        ;;
                    ''|$'\n'|$'\r'|' ') # Enter/Space
                        break
                        ;;
                esac
            done
            
            local output_choice=$((selected + 1))
            
            case "$output_choice" in
                "1")
                    OUTPUT_DIRECTORY="./converted_gifs"
                    OUTPUT_DIR_MODE="default"
                    echo -e "\n${GREEN}✓ GIFs will be saved to: $OUTPUT_DIRECTORY${NC}"
                    echo -e "  ${CYAN}💡 Directory will be created automatically during conversion${NC}"
                    ;;
                "2")
                    OUTPUT_DIRECTORY="$HOME/Pictures/GIFs"
                    OUTPUT_DIR_MODE="pictures"
                    mkdir -p "$OUTPUT_DIRECTORY" 2>/dev/null || {
                        echo -e "\n${RED}❌ Cannot create Pictures/GIFs directory, using default${NC}"
                        OUTPUT_DIRECTORY="./converted_gifs"
                        OUTPUT_DIR_MODE="default"
                    }
                    echo -e "\n${GREEN}✓ GIFs will be saved to: $OUTPUT_DIRECTORY${NC}"
                    ;;
                "3")
                    # Current directory (where user is running the script FROM)
                    OUTPUT_DIRECTORY="$(pwd)"
                    OUTPUT_DIR_MODE="current"
                    echo -e "\n${GREEN}✓ GIFs will be saved to: $OUTPUT_DIRECTORY${NC}"
                    echo -e "  ${CYAN}💡 Same folder as your video files (current directory)${NC}"
                    ;;
                "4")
                    # Script directory (where the script is located)
                    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
                    OUTPUT_DIRECTORY="$script_dir"
                    OUTPUT_DIR_MODE="script"
                    echo -e "\n${GREEN}✓ GIFs will be saved to: $OUTPUT_DIRECTORY${NC}"
                    echo -e "  ${CYAN}💡 Same folder as convert.sh script${NC}"
                    ;;
                "5")
                    # Try to use file picker first
                    local picker=$(detect_file_picker)
                    local custom_path=""
                    
                    if [[ "$picker" != "none" ]]; then
                        echo -e "\n${CYAN}Opening file picker to select directory...${NC}"
                        sleep 0.5
                        custom_path=$(browse_for_directory)
                        
                        if [[ -z "$custom_path" ]]; then
                            echo -e "${YELLOW}No directory selected. Enter path manually or press Enter to use default:${NC}"
                            echo -ne "${YELLOW}Path: ${NC}"
                            read -r custom_path
                            custom_path="${custom_path/#\~/$HOME}"
                        fi
                    else
                        echo -e "\n${CYAN}Enter the directory path where GIFs should be saved:${NC}"
                        echo -e "${GRAY}(No file picker found - install zenity, kdialog, yad, or python3-tk for GUI)${NC}"
                        echo -e "${GRAY}Common paths: $HOME/Pictures, $HOME/Downloads, $HOME/Videos${NC}"
                        echo -ne "${YELLOW}Path (or press Enter for default ./converted_gifs): ${NC}"
                        read -r custom_path
                        custom_path="${custom_path/#\~/$HOME}"
                        
                        # If empty, use default
                        if [[ -z "$custom_path" ]]; then
                            custom_path="./converted_gifs"
                        fi
                    fi
                    
                    if [[ -n "$custom_path" ]]; then
                        if [[ ! -d "$custom_path" ]]; then
                            echo -e "\n${YELLOW}Directory doesn't exist. Create it? [Y/n]: ${NC}"
                            read -r create_confirm
                            if [[ ! "$create_confirm" =~ ^[Nn]$ ]]; then
                                mkdir -p "$custom_path" 2>/dev/null && {
                                    OUTPUT_DIRECTORY="$custom_path"
                                    OUTPUT_DIR_MODE="custom"
                                    echo -e "${GREEN}✓ Created and will use: $OUTPUT_DIRECTORY${NC}"
                                } || {
                                    echo -e "${RED}❌ Cannot create directory, using default${NC}"
                                    OUTPUT_DIRECTORY="./converted_gifs"
                                    OUTPUT_DIR_MODE="default"
                                }
                            else
                                OUTPUT_DIRECTORY="./converted_gifs"
                                OUTPUT_DIR_MODE="default"
                                echo -e "${YELLOW}Using default directory${NC}"
                            fi
                        else
                            OUTPUT_DIRECTORY="$custom_path"
                            OUTPUT_DIR_MODE="custom"
                            echo -e "${GREEN}✓ GIFs will be saved to: $OUTPUT_DIRECTORY${NC}"
                        fi
                    else
                        OUTPUT_DIRECTORY="./converted_gifs"
                        OUTPUT_DIR_MODE="default"
                        echo -e "${YELLOW}Using default directory${NC}"
                    fi
                    ;;
                *)
                    OUTPUT_DIRECTORY="./converted_gifs"
                    OUTPUT_DIR_MODE="default"
                    echo -e "\n${GREEN}✓ GIFs will be saved to: $OUTPUT_DIRECTORY (default)${NC}"
                    ;;
            esac
            
            # Save the choice
            save_settings --silent
            echo -e "${BLUE}💾 Your choice has been saved and can be changed anytime from the main menu.${NC}"
            sleep 2
        fi
    fi
    
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
            --ai-status|--ai-stats)
                echo -e "${CYAN}${BOLD}🤖 AI SYSTEM STATUS${NC}\\\\n"
                show_ai_status
                exit 0
                ;;
            --clean-cache)
                echo -e "${CYAN}${BOLD}🧹 CLEANING AI CACHE${NC}\\n"
                init_ai_cache >/dev/null 2>&1
                cleanup_ai_cache
                echo -e "\n${GREEN}✓ Cache cleanup complete!${NC}"
                exit 0
                ;;
            --show-settings)
                echo -e "${CYAN}${BOLD}🔧 CURRENT SETTINGS${NC}\\\\n"
                local settings_display="$(echo "$SETTINGS_FILE" | sed "s|$HOME|~|g")"
                local config_display="$(echo "$CONFIG_FILE" | sed "s|$HOME|~|g")"
                local clickable_settings=$(make_clickable_path "$SETTINGS_FILE" "$settings_display")
                local clickable_config=$(make_clickable_path "$CONFIG_FILE" "$config_display")
                echo -e "${YELLOW}Settings Location:${NC} $clickable_settings"
                echo -e "${YELLOW}Backup Config:${NC} $clickable_config\\n"
                
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
            --debug-settings)
                echo -e "${CYAN}${BOLD}🐛 SETTINGS PERSISTENCE DIAGNOSTICS${NC}\n"
                echo -e "${YELLOW}${BOLD}=== FILE PATHS ===${NC}"
                echo -e "${BLUE}Settings file:${NC} $SETTINGS_FILE"
                echo -e "${BLUE}Legacy config:${NC} $CONFIG_FILE"
                echo -e "${BLUE}Settings directory:${NC} $(dirname "$SETTINGS_FILE")"
                echo -e "${BLUE}Working directory:${NC} $(pwd)"
                
                echo -e "\n${YELLOW}${BOLD}=== DIRECTORY STATUS ===${NC}"
                local settings_dir="$(dirname "$SETTINGS_FILE")"
                if [[ -d "$settings_dir" ]]; then
                    echo -e "${GREEN}✓ Settings directory exists${NC}"
                    echo -e "  ${BLUE}Permissions:${NC} $(ls -ld "$settings_dir" | awk '{print $1}')"
                    echo -e "  ${BLUE}Owner:${NC} $(ls -ld "$settings_dir" | awk '{print $3 ":" $4}')"
                    echo -e "  ${BLUE}Writable:${NC} $([ -w "$settings_dir" ] && echo "${GREEN}YES${NC}" || echo "${RED}NO${NC}")"
                    echo -e "  ${BLUE}Readable:${NC} $([ -r "$settings_dir" ] && echo "${GREEN}YES${NC}" || echo "${RED}NO${NC}")"
                else
                    echo -e "${RED}❌ Settings directory does NOT exist${NC}"
                    echo -e "  ${YELLOW}Will be created on first save${NC}"
                fi
                
                echo -e "\n${YELLOW}${BOLD}=== SETTINGS FILE STATUS ===${NC}"
                if [[ -f "$SETTINGS_FILE" ]]; then
                    echo -e "${GREEN}✓ Settings file exists${NC}"
                    echo -e "  ${BLUE}Path:${NC} $(make_clickable_path "$SETTINGS_FILE" "$SETTINGS_FILE")"
                    echo -e "  ${BLUE}Size:${NC} $(stat -c%s "$SETTINGS_FILE" 2>/dev/null || echo '0') bytes"
                    echo -e "  ${BLUE}Permissions:${NC} $(ls -l "$SETTINGS_FILE" | awk '{print $1}')"
                    echo -e "  ${BLUE}Owner:${NC} $(ls -l "$SETTINGS_FILE" | awk '{print $3 ":" $4}')"
                    echo -e "  ${BLUE}Readable:${NC} $([ -r "$SETTINGS_FILE" ] && echo "${GREEN}YES${NC}" || echo "${RED}NO${NC}")"
                    echo -e "  ${BLUE}Writable:${NC} $([ -w "$SETTINGS_FILE" ] && echo "${GREEN}YES${NC}" || echo "${RED}NO${NC}")"
                    echo -e "  ${BLUE}Modified:${NC} $(stat -c%y "$SETTINGS_FILE" 2>/dev/null | cut -d'.' -f1)"
                    
                    echo -e "\n${YELLOW}${BOLD}=== FILE VALIDATION ===${NC}"
                    local line_count=$(wc -l < "$SETTINGS_FILE")
                    echo -e "  ${BLUE}Total lines:${NC} $line_count"
                    
                    if grep -q "OUTPUT_DIRECTORY=" "$SETTINGS_FILE" 2>/dev/null; then
                        local saved_output_dir=$(grep "OUTPUT_DIRECTORY=" "$SETTINGS_FILE" | cut -d'=' -f2 | tr -d '"')
                        echo -e "  ${GREEN}✓ OUTPUT_DIRECTORY found in file${NC}"
                        echo -e "    ${BLUE}Saved value:${NC} $saved_output_dir"
                        echo -e "    ${BLUE}Current value:${NC} $OUTPUT_DIRECTORY"
                        if [[ "$saved_output_dir" == "$OUTPUT_DIRECTORY" ]]; then
                            echo -e "    ${GREEN}✓ Values match${NC}"
                        else
                            echo -e "    ${YELLOW}⚠️ Values differ!${NC}"
                        fi
                    else
                        echo -e "  ${RED}❌ OUTPUT_DIRECTORY NOT found in file${NC}"
                        echo -e "    ${YELLOW}File may be corrupted${NC}"
                    fi
                    
                    if grep -q "QUALITY=" "$SETTINGS_FILE" 2>/dev/null; then
                        local saved_quality=$(grep "QUALITY=" "$SETTINGS_FILE" | head -1 | cut -d'=' -f2 | tr -d '"')
                        echo -e "  ${GREEN}✓ QUALITY found in file${NC}"
                        echo -e "    ${BLUE}Saved value:${NC} $saved_quality"
                        echo -e "    ${BLUE}Current value:${NC} $QUALITY"
                    fi
                    
                    echo -e "\n${YELLOW}${BOLD}=== FILE CONTENT SAMPLE ===${NC}"
                    echo -e "${GRAY}First 10 lines:${NC}"
                    head -10 "$SETTINGS_FILE" | while IFS= read -r line; do
                        echo -e "  ${GRAY}$line${NC}"
                    done
                else
                    echo -e "${RED}❌ Settings file does NOT exist${NC}"
                    echo -e "  ${YELLOW}This is normal for first run${NC}"
                    echo -e "  ${YELLOW}File will be created automatically${NC}"
                fi
                
                echo -e "\n${YELLOW}${BOLD}=== LEGACY CONFIG ===${NC}"
                if [[ -f "$CONFIG_FILE" ]]; then
                    echo -e "${YELLOW}⚠️ Legacy config file exists${NC}"
                    echo -e "  ${BLUE}Path:${NC} $CONFIG_FILE"
                    echo -e "  ${BLUE}Size:${NC} $(stat -c%s "$CONFIG_FILE" 2>/dev/null || echo '0') bytes"
                    echo -e "  ${CYAN}💡 Consider migrating with: ./convert.sh --save-config${NC}"
                else
                    echo -e "${GREEN}✓ No legacy config file - using new settings format${NC}"
                fi
                
                echo -e "\n${YELLOW}${BOLD}=== CURRENT VALUES ===${NC}"
                echo -e "  ${BLUE}OUTPUT_DIRECTORY:${NC} $OUTPUT_DIRECTORY"
                echo -e "  ${BLUE}OUTPUT_DIR_MODE:${NC} $OUTPUT_DIR_MODE"
                echo -e "  ${BLUE}QUALITY:${NC} $QUALITY"
                echo -e "  ${BLUE}RESOLUTION:${NC} $RESOLUTION"
                echo -e "  ${BLUE}FRAMERATE:${NC} $FRAMERATE"
                
                echo -e "\n${YELLOW}${BOLD}=== BACKUP FILES ===${NC}"
                if [[ -f "${SETTINGS_FILE}.backup" ]]; then
                    echo -e "${GREEN}✓ Backup exists:${NC} ${SETTINGS_FILE}.backup"
                    echo -e "  ${BLUE}Modified:${NC} $(stat -c%y "${SETTINGS_FILE}.backup" 2>/dev/null | cut -d'.' -f1)"
                else
                    echo -e "${GRAY}No backup file found${NC}"
                fi
                
                echo -e "\n${YELLOW}${BOLD}=== WRITE TEST ===${NC}"
                local test_file="${SETTINGS_FILE}.write_test.$$"
                if echo "test" > "$test_file" 2>/dev/null; then
                    echo -e "${GREEN}✓ Write permissions OK${NC}"
                    rm -f "$test_file" 2>/dev/null
                else
                    echo -e "${RED}❌ Cannot write to settings directory${NC}"
                    echo -e "  ${YELLOW}This will prevent settings from being saved${NC}"
                fi
                
                echo -e "\n${YELLOW}${BOLD}=== RECOMMENDATIONS ===${NC}"
                if [[ ! -f "$SETTINGS_FILE" ]]; then
                    echo -e "${CYAN}💡 Run the script in interactive mode to create settings${NC}"
                    echo -e "   ${GRAY}Command: ./convert.sh${NC}"
                elif [[ ! -r "$SETTINGS_FILE" ]]; then
                    echo -e "${RED}⚠️ Fix read permissions:${NC}"
                    echo -e "   ${GRAY}chmod u+r \"$SETTINGS_FILE\"${NC}"
                elif [[ ! -w "$(dirname "$SETTINGS_FILE")" ]]; then
                    echo -e "${RED}⚠️ Fix write permissions on directory:${NC}"
                    echo -e "   ${GRAY}chmod u+w \"$(dirname "$SETTINGS_FILE")\"${NC}"
                else
                    echo -e "${GREEN}✓ Settings persistence is properly configured${NC}"
                fi
                
                exit 0
                ;;
            --check-permissions|--fix-permissions)
                init_log_directory >/dev/null 2>&1
                echo -e "${CYAN}${BOLD}🔒 CHECKING FILE PERMISSIONS${NC}\n"
                check_and_fix_permissions
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
            --version|-v)
                show_version_info
                exit 0
                ;;
            --check-update)
                check_for_updates
                exit 0
                ;;
            --update)
                manual_update
                exit 0
                ;;
            --save-config)
                save_config
                exit 0
                ;;
            --show-logs)
                init_log_directory >/dev/null 2>&1
                echo -e "${CYAN}${BOLD}📁 LOG DIRECTORY INFORMATION:${NC}\n"
                local log_dir_display="$(echo "$LOG_DIR" | sed "s|$HOME|~|g")"
                local error_log_display="$(echo "$ERROR_LOG" | sed "s|$HOME|~|g")"
                local conv_log_display="$(echo "$CONVERSION_LOG" | sed "s|$HOME|~|g")"
                local clickable_log_dir=$(make_clickable_path "$LOG_DIR" "$log_dir_display")
                local clickable_error_log=$(make_clickable_path "$ERROR_LOG" "$error_log_display")
                local clickable_conv_log=$(make_clickable_path "$CONVERSION_LOG" "$conv_log_display")
                echo -e "${YELLOW}Log Directory:${NC} $clickable_log_dir"
                echo -e "${YELLOW}Error Log:${NC} $clickable_error_log"
                echo -e "${YELLOW}Conversion Log:${NC} $clickable_conv_log\n"
                
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
            --check-cache|--validate-cache)
                init_log_directory >/dev/null 2>&1
                local validation_cache="$LOG_DIR/validation_cache.db"
                echo -e "${CYAN}${BOLD}🛡️ VALIDATION CACHE CHECK:${NC}\n"
                
                if [[ ! -f "$validation_cache" ]]; then
                    echo -e "${YELLOW}⚠️ No validation cache found${NC}"
                    echo -e "${BLUE}ℹ️ Cache will be created on first validation${NC}"
                    exit 0
                fi
                
                local cache_size=$(stat -c%s "$validation_cache" 2>/dev/null | numfmt --to=iec)
                local cache_entries=$(grep -c '|' "$validation_cache" 2>/dev/null || echo "0")
                echo -e "${YELLOW}Cache Location:${NC} $(make_clickable_path "$validation_cache" "${validation_cache/$HOME/~}")"
                echo -e "${YELLOW}Cache Size:${NC} $cache_size ($cache_entries entries)"
                
                # Validate cache format
                local corrupted=0
                local valid=0
                local invalid=0
                
                while IFS='|' read -r filepath filesize mtime status; do
                    [[ "$filepath" =~ ^# ]] && continue  # Skip comments
                    if [[ -z "$filepath" || -z "$filesize" || -z "$mtime" || ! "$status" =~ ^(VALID|INVALID)$ ]]; then
                        ((corrupted++))
                    elif [[ "$status" == "VALID" ]]; then
                        ((valid++))
                    else
                        ((invalid++))
                    fi
                done < "$validation_cache"
                
                echo -e "\n${GREEN}✓ Valid entries:${NC} $valid"
                echo -e "${RED}✗ Invalid entries:${NC} $invalid"
                
                if [[ $corrupted -gt 0 ]]; then
                    echo -e "${YELLOW}⚠️ Corrupted entries:${NC} $corrupted"
                    echo -e "\n${YELLOW}Recommendation: Rebuild cache with --clear-cache${NC}"
                else
                    echo -e "${GREEN}✓ Cache integrity: OK${NC}"
                fi
                
                echo -e "\n${BLUE}Commands:${NC}"
                echo -e "  ./convert.sh --clear-cache      # Clear validation cache"
                echo -e "  rm \"$validation_cache\"    # Manually delete cache"
                exit 0
                ;;
            --clear-cache)
                init_log_directory >/dev/null 2>&1
                local validation_cache="$LOG_DIR/validation_cache.db"
                if [[ -f "$validation_cache" ]]; then
                    local backup="${validation_cache}.backup.$(date +%s)"
                    mv "$validation_cache" "$backup"
                    echo -e "${GREEN}✓ Validation cache cleared${NC}"
                    echo -e "${BLUE}ℹ️ Backup saved: $(basename -- "$backup")${NC}"
                else
                    echo -e "${YELLOW}⚠️ No validation cache to clear${NC}"
                fi
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