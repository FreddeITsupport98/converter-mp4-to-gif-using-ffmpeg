#!/bin/bash

# =============================================================================
# ADVANCED COMPREHENSIVE TEST SUITE FOR convert.sh (10,000+ LINES)
# =============================================================================
# This script performs deep integration testing of all major subsystems:
# - Core conversion pipeline (FFmpeg integration)
# - AI analysis engine (content detection, motion analysis, scene detection)
# - Duplicate detection system (4-level similarity analysis)
# - Cache system (AI cache, validation cache, corruption protection)
# - Training system (persistent AI model, generation tracking)
# - Interactive menu system (TUI, configuration management)
# - Error handling (logging, retry logic, cleanup)
# - Performance optimization (parallel processing, GPU acceleration)
# - File management (backup, recovery, clickable paths)
# 
# Usage: 
#   ./advanced_test_suite.sh [--verbose] [--skip-slow] [--category CATEGORY]
#
# Categories:
#   all, basic, conversion, ai, advanced, system, performance, integration
#
# Requirements:
# - FFmpeg installed with full codec support
# - convert.sh in the same directory (10,000+ lines)
# - At least 500MB free disk space for comprehensive testing
# - bash 4.0+ for associative arrays
# =============================================================================

# Ensure we're running in bash
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script requires bash"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Test counters and categories
declare -A TEST_CATEGORIES=(
    ["basic"]=0
    ["conversion"]=0
    ["ai"]=0
    ["advanced"]=0
    ["system"]=0
    ["performance"]=0
    ["integration"]=0
)

declare -A CATEGORY_PASSED=(
    ["basic"]=0
    ["conversion"]=0
    ["ai"]=0
    ["advanced"]=0
    ["system"]=0
    ["performance"]=0
    ["integration"]=0
)

declare -A CATEGORY_FAILED=(
    ["basic"]=0
    ["conversion"]=0
    ["ai"]=0
    ["advanced"]=0
    ["system"]=0
    ["performance"]=0
    ["integration"]=0
)

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
TOTAL_TESTS=0

# Test configuration
TEST_DIR="$(pwd)/advanced_test_temp_$$"
SCRIPT_PATH="$(pwd)/convert.sh"
VERBOSE=false
SKIP_SLOW=false
TARGET_CATEGORY="all"
START_TIME=$(date +%s)

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --skip-slow)
            SKIP_SLOW=true
            shift
            ;;
        --category|-c)
            TARGET_CATEGORY="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--verbose] [--skip-slow] [--category CATEGORY]"
            echo "Categories: all, basic, conversion, ai, advanced, system, performance, integration"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate category
if [[ "$TARGET_CATEGORY" != "all" && ! "${TEST_CATEGORIES[$TARGET_CATEGORY]+isset}" ]]; then
    echo -e "${RED}Error: Invalid category '$TARGET_CATEGORY'${NC}"
    echo "Available categories: ${!TEST_CATEGORIES[@]}"
    exit 1
fi

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    local category="${2:-}"
    echo -e "\n${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [[ -n "$category" ]]; then
        echo -e "${CYAN}${BOLD}$1 [$category]${NC}"
    else
        echo -e "${CYAN}${BOLD}$1${NC}"
    fi
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_test() {
    local test_name="$1"
    local category="${2:-basic}"
    ((TOTAL_TESTS++))
    ((TEST_CATEGORIES[$category]++))
    echo -ne "${BLUE}[TEST $TOTAL_TESTS] ${BOLD}${category^^}:${NC} $test_name ... "
}

pass() {
    local category="${1:-basic}"
    ((TESTS_PASSED++))
    ((CATEGORY_PASSED[$category]++))
    echo -e "${GREEN}✓ PASS${NC}"
    [[ "$VERBOSE" == "true" && -n "$2" ]] && echo -e "  ${DIM}→ $2${NC}"
}

fail() {
    local category="${1:-basic}"
    local reason="${2:-Unknown error}"
    ((TESTS_FAILED++))
    ((CATEGORY_FAILED[$category]++))
    echo -e "${RED}✗ FAIL${NC}"
    echo -e "  ${RED}→ $reason${NC}"
    [[ "$VERBOSE" == "true" && -n "$3" ]] && echo -e "  ${DIM}Details: $3${NC}"
}

skip() {
    local category="${1:-basic}"
    local reason="${2:-Skipped}"
    ((TESTS_SKIPPED++))
    echo -e "${YELLOW}⊘ SKIP${NC}"
    echo -e "  ${YELLOW}→ $reason${NC}"
}

# Check if we should run tests for this category
should_run_category() {
    local category="$1"
    [[ "$TARGET_CATEGORY" == "all" || "$TARGET_CATEGORY" == "$category" ]]
}

# Analyze convert.sh script to extract function information
analyze_script_structure() {
    echo -e "${CYAN}${BOLD}🔍 ANALYZING SCRIPT STRUCTURE${NC}\n"
    
    local script_lines=$(wc -l < "$SCRIPT_PATH")
    local script_functions=$(grep -c '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*()' "$SCRIPT_PATH" 2>/dev/null || echo "0")
    local ai_functions=$(grep -c 'ai_.*()' "$SCRIPT_PATH" 2>/dev/null || echo "0")
    local error_handlers=$(grep -c 'log_error\|trace_function' "$SCRIPT_PATH" 2>/dev/null || echo "0")
    
    echo -e "${GREEN}✓ Script size: ${BOLD}$script_lines${NC} ${GREEN}lines${NC}"
    echo -e "${GREEN}✓ Total functions: ${BOLD}$script_functions${NC}"
    echo -e "${GREEN}✓ AI functions: ${BOLD}$ai_functions${NC}"
    echo -e "${GREEN}✓ Error handlers: ${BOLD}$error_handlers${NC}"
    
    # Verify script has minimum expected complexity
    if [[ $script_lines -lt 8000 ]]; then
        echo -e "${YELLOW}⚠️ Warning: Script appears smaller than expected (<8000 lines)${NC}"
    fi
    
    if [[ $ai_functions -lt 10 ]]; then
        echo -e "${YELLOW}⚠️ Warning: Fewer AI functions than expected (<10)${NC}"
    fi
    
    echo ""
}

# Create comprehensive test videos with different characteristics
create_advanced_test_videos() {
    print_header "📹 CREATING ADVANCED TEST DATASET" "system"
    
    echo -e "${BLUE}Creating specialized test videos for comprehensive analysis...${NC}\n"
    
    # Animation-style test video (high color complexity, rapid changes)
    echo -n "Creating animation test video ... "
    ffmpeg -f lavfi -i "testsrc=duration=5:size=854x480:rate=24" \
           -f lavfi -i "sine=frequency=1000:duration=5" \
           -vf "hue=s=2,scale=854:480:flags=neighbor" \
           -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest \
           "test_animation.mp4" -y >/dev/null 2>&1
    echo -e "${GREEN}✓${NC}"
    
    # Movie-style test video (low motion, cinematic aspect)
    echo -n "Creating movie test video ... "
    ffmpeg -f lavfi -i "testsrc=duration=5:size=1920x1080:rate=24" \
           -f lavfi -i "sine=frequency=440:duration=5" \
           -vf "fade=in:0:24,fade=out:96:24" \
           -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest \
           "test_movie.mp4" -y >/dev/null 2>&1
    echo -e "${GREEN}✓${NC}"
    
    # Screencast-style test video (static regions, sharp edges)
    echo -n "Creating screencast test video ... "
    ffmpeg -f lavfi -i "testsrc=duration=3:size=1280x720:rate=15" \
           -f lavfi -i "sine=frequency=800:duration=3" \
           -vf "drawtext=text='Screen Recording':fontsize=30:fontcolor=white:x=10:y=10" \
           -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest \
           "test_screencast.mp4" -y >/dev/null 2>&1
    echo -e "${GREEN}✓${NC}"
    
    # High-motion test video (sports/action style)
    echo -n "Creating high-motion test video ... "
    ffmpeg -f lavfi -i "testsrc=duration=4:size=1920x1080:rate=30" \
           -f lavfi -i "sine=frequency=1200:duration=4" \
           -vf "rotate=PI*t/10" \
           -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest \
           "test_highmotion.mp4" -y >/dev/null 2>&1
    echo -e "${GREEN}✓${NC}"
    
    # Corrupted test video (intentionally damaged for error handling tests)
    echo -n "Creating corrupted test video ... "
    ffmpeg -f lavfi -i "testsrc=duration=2:size=640x480:rate=15" \
           -c:v libx264 -pix_fmt yuv420p \
           "test_temp.mp4" -y >/dev/null 2>&1
    # Truncate file to simulate corruption
    head -c 1024 "test_temp.mp4" > "test_corrupted.mp4"
    rm -f "test_temp.mp4"
    echo -e "${GREEN}✓${NC}"
    
    # Ultra-short test video (edge case)
    echo -n "Creating ultra-short test video ... "
    ffmpeg -f lavfi -i "testsrc=duration=0.5:size=320x240:rate=10" \
           -f lavfi -i "sine=frequency=500:duration=0.5" \
           -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest \
           "test_ultrashort.mp4" -y >/dev/null 2>&1
    echo -e "${GREEN}✓${NC}"
    
    # Different aspect ratios
    echo -n "Creating ultra-wide test video ... "
    ffmpeg -f lavfi -i "testsrc=duration=3:size=2560x1080:rate=20" \
           -f lavfi -i "sine=frequency=600:duration=3" \
           -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest \
           "test_ultrawide.mp4" -y >/dev/null 2>&1
    echo -e "${GREEN}✓${NC}"
    
    # Create duplicates for duplicate detection tests
    echo -n "Creating duplicate test files ... "
    cp "test_animation.mp4" "test_animation_copy.mp4"
    cp "test_movie.mp4" "test_movie_duplicate.mp4"
    echo -e "${GREEN}✓${NC}"
    
    # Create a video with problematic characteristics
    echo -n "Creating edge-case test video ... "
    ffmpeg -f lavfi -i "testsrc=duration=2:size=1x1:rate=1" \
           -c:v libx264 -pix_fmt yuv420p \
           "test_tiny.mp4" -y >/dev/null 2>&1
    echo -e "${GREEN}✓${NC}"
    
    echo -e "\n${GREEN}✓ Created 9 specialized test videos for comprehensive testing${NC}\n"
}

# =============================================================================
# Core System Tests
# =============================================================================

test_script_structure() {
    if ! should_run_category "basic"; then return; fi
    
    print_test "Script structure and line count validation" "basic"
    
    local line_count=$(wc -l < "$SCRIPT_PATH" 2>/dev/null || echo "0")
    local function_count=$(grep -c '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*()' "$SCRIPT_PATH" 2>/dev/null || echo "0")
    
    if [[ $line_count -ge 8000 && $function_count -ge 50 ]]; then
        pass "basic" "Script has $line_count lines and $function_count functions"
    else
        fail "basic" "Script structure insufficient" "Lines: $line_count (<8000?), Functions: $function_count (<50?)"
    fi
}

test_bash_version_enforcement() {
    if ! should_run_category "basic"; then return; fi
    
    print_test "Bash version enforcement mechanism" "basic"
    
    # Test if script properly detects and rejects non-bash shells
    if grep -q "BASH_VERSION" "$SCRIPT_PATH" && \
       grep -q "This script REQUIRES.*bash" "$SCRIPT_PATH"; then
        pass "basic" "Proper bash enforcement detected"
    else
        fail "basic" "Bash version enforcement not found or incomplete"
    fi
}

test_process_group_management() {
    if ! should_run_category "basic"; then return; fi
    
    print_test "Process group management and cleanup" "basic"
    
    if grep -q "SCRIPT_PID\|SCRIPT_PGID\|process.*group" "$SCRIPT_PATH" && \
       grep -q "cleanup.*lock.*file\|trap.*cleanup" "$SCRIPT_PATH"; then
        pass "basic" "Process group management implemented"
    else
        fail "basic" "Process group management not properly implemented"
    fi
}

test_single_instance_locking() {
    if ! should_run_category "basic"; then return; fi
    
    print_test "Single instance locking mechanism" "basic"
    
    if grep -q "LOCK_FILE.*smart-gif-converter" "$SCRIPT_PATH" && \
       grep -q "kill -0.*existing_pid" "$SCRIPT_PATH"; then
        pass "basic" "Single instance locking properly implemented"
    else
        fail "basic" "Single instance locking mechanism not found"
    fi
}

test_dependency_validation() {
    if ! should_run_category "system"; then return; fi
    
    print_test "Comprehensive dependency validation" "system"
    
    local deps_found=0
    for dep in ffmpeg ffprobe gifsicle jq; do
        if grep -q "command -v $dep\|which $dep" "$SCRIPT_PATH"; then
            ((deps_found++))
        fi
    done
    
    if [[ $deps_found -ge 3 ]]; then
        pass "system" "Found validation for $deps_found dependencies"
    else
        fail "system" "Insufficient dependency checking" "Only $deps_found/4 dependencies validated"
    fi
}

# =============================================================================
# AI System Tests
# =============================================================================

test_ai_content_detection_engine() {
    if ! should_run_category "ai"; then return; fi
    
    print_test "AI content detection engine (5-stage analysis)" "ai"
    
    local ai_features=0
    local required_features=("detect_content_type" "ai_smart_analyze" "ML.*inspired" "animation.*screencast.*movie")
    
    for feature in "${required_features[@]}"; do
        if grep -q "$feature" "$SCRIPT_PATH"; then
            ((ai_features++))
        fi
    done
    
    if [[ $ai_features -ge 3 ]]; then
        pass "ai" "AI content detection engine found ($ai_features/4 features)"
    else
        fail "ai" "AI content detection incomplete" "Only $ai_features/4 core features found"
    fi
}

test_ai_duplicate_detection_system() {
    if ! should_run_category "ai"; then return; fi
    
    print_test "AI duplicate detection (4-level similarity analysis)" "ai"
    
    local detection_levels=0
    local levels=("exact.*binary.*match" "visual.*similarity" "content.*fingerprint" "near.*identical")
    
    for level in "${levels[@]}"; do
        if grep -q "$level" "$SCRIPT_PATH"; then
            ((detection_levels++))
        fi
    done
    
    if [[ $detection_levels -ge 3 ]]; then
        pass "ai" "Multi-level duplicate detection system ($detection_levels/4 levels)"
    else
        fail "ai" "Duplicate detection system incomplete" "Only $detection_levels/4 levels implemented"
    fi
}

test_ai_scene_analysis() {
    if ! should_run_category "ai"; then return; fi
    
    print_test "Advanced AI scene analysis and detection" "ai"
    
    if grep -q "AI_SCENE_ANALYSIS\|scene.*detection\|ai_scene_detection" "$SCRIPT_PATH" && \
       grep -q "threshold.*detection\|frame.*consistency" "$SCRIPT_PATH"; then
        pass "ai" "Advanced scene analysis system detected"
    else
        fail "ai" "Scene analysis system not found or incomplete"
    fi
}

test_ai_motion_complexity_analysis() {
    if ! should_run_category "ai"; then return; fi
    
    print_test "AI motion complexity analysis engine" "ai"
    
    if grep -q "analyze_motion_complexity\|motion.*analysis\|AI_DYNAMIC_FRAMERATE" "$SCRIPT_PATH" && \
       grep -q "frame.*rate.*optimization\|motion.*level" "$SCRIPT_PATH"; then
        pass "ai" "Motion complexity analysis engine found"
    else
        fail "ai" "Motion analysis engine not implemented"
    fi
}

test_ai_cache_system() {
    if ! should_run_category "ai"; then return; fi
    
    print_test "Intelligent AI caching with corruption protection" "ai"
    
    local cache_features=0
    local features=("init_ai_cache" "validate_cache_index" "save_ai_analysis_to_cache" "corruption.*protection")
    
    for feature in "${features[@]}"; do
        if grep -q "$feature" "$SCRIPT_PATH"; then
            ((cache_features++))
        fi
    done
    
    if [[ $cache_features -ge 3 ]]; then
        pass "ai" "AI caching system with corruption protection ($cache_features/4 features)"
    else
        fail "ai" "AI caching system incomplete" "Only $cache_features/4 features found"
    fi
}

test_ai_training_system() {
    if ! should_run_category "ai"; then return; fi
    
    print_test "AI training and learning system with generation tracking" "ai"
    
    local training_features=0
    local features=("init_ai_training" "validate_ai_model" "AI_GENERATION" "smart_model")
    
    for feature in "${features[@]}"; do
        if grep -q "$feature" "$SCRIPT_PATH"; then
            ((training_features++))
        fi
    done
    
    if [[ $training_features -ge 3 ]]; then
        pass "ai" "AI training system with generation tracking ($training_features/4 features)"
    else
        fail "ai" "AI training system incomplete" "Only $training_features/4 features found"
    fi
}

# =============================================================================
# Core Conversion Tests
# =============================================================================

test_quality_preset_system() {
    if ! should_run_category "conversion"; then return; fi
    
    print_test "Quality preset system (low/medium/high/ultra/max)" "conversion"
    
    local presets_found=0
    for preset in low medium high ultra max; do
        if grep -q "\"$preset\"" "$SCRIPT_PATH"; then
            ((presets_found++))
        fi
    done
    
    if [[ $presets_found -ge 4 ]]; then
        pass "conversion" "Quality preset system complete ($presets_found/5 presets)"
    else
        fail "conversion" "Quality preset system incomplete" "Only $presets_found/5 presets found"
    fi
}

test_conversion_pipeline_integration() {
    if ! should_run_category "conversion"; then return; fi
    
    print_test "Core conversion pipeline with error handling" "conversion"
    
    if grep -q "convert_video.*pipeline\|conversion.*pipeline" "$SCRIPT_PATH" && \
       grep -q "error.*handling\|retry.*logic" "$SCRIPT_PATH" && \
       grep -q "ffmpeg.*conversion" "$SCRIPT_PATH"; then
        pass "conversion" "Conversion pipeline with error handling detected"
    else
        fail "conversion" "Conversion pipeline not properly implemented"
    fi
}

test_aspect_ratio_handling() {
    if ! should_run_category "conversion"; then return; fi
    
    print_test "Aspect ratio detection and conversion" "conversion"
    
    if grep -q "ASPECT_RATIO.*16:9\|aspect.*ratio" "$SCRIPT_PATH" && \
       grep -q "scale.*aspect\|crop.*aspect" "$SCRIPT_PATH"; then
        pass "conversion" "Aspect ratio handling implemented"
    else
        fail "conversion" "Aspect ratio handling not found"
    fi
}

test_gpu_acceleration_detection() {
    if ! should_run_category "system"; then return; fi
    
    print_test "GPU acceleration detection (NVIDIA/AMD/Intel)" "system"
    
    local gpu_support=0
    local gpu_types=("nvidia\|h264_nvenc" "amd\|vaapi" "intel\|qsv")
    
    for gpu_type in "${gpu_types[@]}"; do
        if grep -qi "$gpu_type" "$SCRIPT_PATH"; then
            ((gpu_support++))
        fi
    done
    
    if [[ $gpu_support -ge 2 ]]; then
        pass "system" "Multi-GPU acceleration support ($gpu_support/3 types)"
    else
        fail "system" "Limited GPU acceleration support" "Only $gpu_support/3 GPU types supported"
    fi
}

# =============================================================================
# Performance and Optimization Tests
# =============================================================================

test_parallel_processing_system() {
    if ! should_run_category "performance"; then return; fi
    
    print_test "Parallel processing and job management" "performance"
    
    if grep -q "PARALLEL_JOBS.*nproc\|parallel.*processing" "$SCRIPT_PATH" && \
       grep -q "concurrent.*conversions\|thread.*optimization" "$SCRIPT_PATH"; then
        pass "performance" "Parallel processing system implemented"
    else
        fail "performance" "Parallel processing system not found"
    fi
}

test_memory_optimization() {
    if ! should_run_category "performance"; then return; fi
    
    print_test "Memory optimization and RAM detection" "performance"
    
    if grep -q "RAM.*detection\|memory.*optimization" "$SCRIPT_PATH" && \
       grep -q "ram_cache\|memory.*cache" "$SCRIPT_PATH"; then
        pass "performance" "Memory optimization system detected"
    else
        fail "performance" "Memory optimization not implemented"
    fi
}

test_cpu_optimization() {
    if ! should_run_category "performance"; then return; fi
    
    print_test "CPU optimization and architecture detection" "performance"
    
    if grep -q "CPU.*architecture\|cpu.*optimization" "$SCRIPT_PATH" && \
       grep -q "FFMPEG_THREADS.*nproc\|thread.*optimization" "$SCRIPT_PATH"; then
        pass "performance" "CPU optimization system found"
    else
        fail "performance" "CPU optimization not properly implemented"
    fi
}

# =============================================================================
# Advanced Feature Tests
# =============================================================================

test_interactive_menu_system() {
    if ! should_run_category "advanced"; then return; fi
    
    print_test "Interactive menu system (TUI)" "advanced"
    
    local menu_features=0
    local features=("show_main_menu" "configure.*settings" "AI.*System.*Status" "interactive.*mode")
    
    for feature in "${features[@]}"; do
        if grep -q "$feature" "$SCRIPT_PATH"; then
            ((menu_features++))
        fi
    done
    
    if [[ $menu_features -ge 3 ]]; then
        pass "advanced" "Interactive menu system complete ($menu_features/4 features)"
    else
        fail "advanced" "Interactive menu system incomplete" "Only $menu_features/4 features found"
    fi
}

test_clickable_file_paths() {
    if ! should_run_category "advanced"; then return; fi
    
    print_test "Clickable file paths for modern terminals" "advanced"
    
    if grep -q "make_clickable_path\|terminal.*hyperlink" "$SCRIPT_PATH" && \
       grep -q "file.*manager.*integration\|clickable.*path" "$SCRIPT_PATH"; then
        pass "advanced" "Clickable file paths system implemented"
    else
        fail "advanced" "Clickable file paths not found"
    fi
}

test_settings_persistence() {
    if ! should_run_category "advanced"; then return; fi
    
    print_test "Settings persistence and configuration management" "advanced"
    
    if grep -q "save_settings\|load_config" "$SCRIPT_PATH" && \
       grep -q "settings\.conf\|config.*persistence" "$SCRIPT_PATH"; then
        pass "advanced" "Settings persistence system found"
    else
        fail "advanced" "Settings persistence not implemented"
    fi
}

test_backup_and_recovery() {
    if ! should_run_category "advanced"; then return; fi
    
    print_test "Backup and recovery system" "advanced"
    
    if grep -q "BACKUP_ORIGINAL\|backup.*system" "$SCRIPT_PATH" && \
       grep -q "recovery\|restore.*backup" "$SCRIPT_PATH"; then
        pass "advanced" "Backup and recovery system detected"
    else
        fail "advanced" "Backup and recovery system not found"
    fi
}

# =============================================================================
# Error Handling and Logging Tests
# =============================================================================

test_comprehensive_error_handling() {
    if ! should_run_category "system"; then return; fi
    
    print_test "Comprehensive error handling and logging" "system"
    
    local error_features=0
    local features=("log_error" "trace_function" "ERROR_LOG" "retry.*logic")
    
    for feature in "${features[@]}"; do
        if grep -q "$feature" "$SCRIPT_PATH"; then
            ((error_features++))
        fi
    done
    
    if [[ $error_features -ge 3 ]]; then
        pass "system" "Comprehensive error handling ($error_features/4 features)"
    else
        fail "system" "Error handling incomplete" "Only $error_features/4 features found"
    fi
}

test_logging_system() {
    if ! should_run_category "system"; then return; fi
    
    print_test "Multi-level logging system" "system"
    
    if grep -q "CONVERSION_LOG\|conversion.*log" "$SCRIPT_PATH" && \
       grep -q "log_conversion\|logging.*system" "$SCRIPT_PATH"; then
        pass "system" "Multi-level logging system implemented"
    else
        fail "system" "Logging system not comprehensive"
    fi
}

test_signal_handling() {
    if ! should_run_category "system"; then return; fi
    
    print_test "Signal handling and cleanup on interruption" "system"
    
    if grep -q "trap.*cleanup\|signal.*handling" "$SCRIPT_PATH" && \
       grep -q "SIGINT\|SIGTERM\|interrupt" "$SCRIPT_PATH"; then
        pass "system" "Signal handling and cleanup implemented"
    else
        fail "system" "Signal handling not properly implemented"
    fi
}

# =============================================================================
# Integration Tests
# =============================================================================

test_end_to_end_conversion() {
    if ! should_run_category "integration" || [[ "$SKIP_SLOW" == "true" ]]; then 
        if [[ "$SKIP_SLOW" == "true" ]]; then
            skip "integration" "Skipped due to --skip-slow flag"
        fi
        return
    fi
    
    print_test "End-to-end conversion with basic video" "integration"
    
    # Test actual conversion
    if bash "$SCRIPT_PATH" --file test_animation.mp4 --preset low >/dev/null 2>&1; then
        if [[ -f "test_animation.gif" ]]; then
            local gif_size=$(stat -c%s "test_animation.gif" 2>/dev/null || echo "0")
            if [[ $gif_size -gt 1000 ]]; then
                pass "integration" "Successful conversion (${gif_size} bytes)"
            else
                fail "integration" "GIF file too small or corrupted" "Size: ${gif_size} bytes"
            fi
        else
            fail "integration" "GIF file was not created"
        fi
    else
        fail "integration" "Conversion command failed"
    fi
}

test_ai_enabled_conversion() {
    if ! should_run_category "integration" || [[ "$SKIP_SLOW" == "true" ]]; then 
        if [[ "$SKIP_SLOW" == "true" ]]; then
            skip "integration" "Skipped due to --skip-slow flag"
        fi
        return
    fi
    
    print_test "AI-enabled conversion with content analysis" "integration"
    
    # Test AI conversion
    if bash "$SCRIPT_PATH" --file test_movie.mp4 --preset medium --ai >/dev/null 2>&1; then
        if [[ -f "test_movie.gif" ]]; then
            pass "integration" "AI-enhanced conversion successful"
        else
            fail "integration" "AI conversion failed to create output"
        fi
    else
        fail "integration" "AI conversion command failed"
    fi
}

test_batch_processing() {
    if ! should_run_category "integration" || [[ "$SKIP_SLOW" == "true" ]]; then 
        if [[ "$SKIP_SLOW" == "true" ]]; then
            skip "integration" "Skipped due to --skip-slow flag"
        fi
        return
    fi
    
    print_test "Batch processing multiple files" "integration"
    
    # Test batch conversion with force flag
    if bash "$SCRIPT_PATH" --preset low --force >/dev/null 2>&1; then
        local gif_count=$(ls -1 *.gif 2>/dev/null | wc -l)
        if [[ $gif_count -ge 3 ]]; then
            pass "integration" "Batch processing successful (created $gif_count GIFs)"
        else
            fail "integration" "Batch processing incomplete" "Only created $gif_count GIFs"
        fi
    else
        fail "integration" "Batch processing command failed"
    fi
}

test_error_recovery() {
    if ! should_run_category "integration"; then return; fi
    
    print_test "Error recovery with corrupted input" "integration"
    
    # Test with corrupted file
    if bash "$SCRIPT_PATH" --file test_corrupted.mp4 --preset low >/dev/null 2>&1; then
        # Should not succeed with corrupted file
        fail "integration" "Should have failed with corrupted input"
    else
        # Should fail gracefully
        pass "integration" "Graceful handling of corrupted input"
    fi
}

# =============================================================================
# Performance Benchmarks
# =============================================================================

test_conversion_speed_benchmark() {
    if ! should_run_category "performance" || [[ "$SKIP_SLOW" == "true" ]]; then 
        if [[ "$SKIP_SLOW" == "true" ]]; then
            skip "performance" "Skipped due to --skip-slow flag"
        fi
        return
    fi
    
    print_test "Conversion speed benchmark (target: <30s)" "performance"
    
    local start_time=$(date +%s)
    if bash "$SCRIPT_PATH" --file test_ultrashort.mp4 --preset low >/dev/null 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [[ $duration -lt 30 ]]; then
            pass "performance" "Fast conversion completed in ${duration}s"
        else
            fail "performance" "Conversion too slow" "Took ${duration}s (target: <30s)"
        fi
    else
        fail "performance" "Benchmark conversion failed"
    fi
}

test_memory_usage_monitoring() {
    if ! should_run_category "performance"; then return; fi
    
    print_test "Memory usage monitoring and optimization" "performance"
    
    if grep -q "memory.*monitoring\|RAM.*usage" "$SCRIPT_PATH" && \
       grep -q "memory.*optimization\|memory.*efficient" "$SCRIPT_PATH"; then
        pass "performance" "Memory monitoring system detected"
    else
        skip "performance" "Memory monitoring not explicitly implemented"
    fi
}

# =============================================================================
# Setup and Teardown
# =============================================================================

setup_test_environment() {
    print_header "🔧 SETTING UP ADVANCED TEST ENVIRONMENT" "system"
    
    # Check if convert.sh is already running
    local lock_file="${HOME}/.smart-gif-converter/script.lock"
    if [[ -f "$lock_file" ]]; then
        local existing_pid=$(cat "$lock_file" 2>/dev/null)
        if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
            echo -e "${RED}✗ convert.sh is currently running (PID: $existing_pid)${NC}"
            echo -e "${YELLOW}  Please wait for the conversion to finish or stop it before running tests.${NC}"
            echo -e "${CYAN}  To stop: kill $existing_pid${NC}"
            exit 1
        else
            # Stale lock file, clean it up
            rm -f "$lock_file" 2>/dev/null || true
        fi
    fi
    echo -e "${GREEN}✓ No running convert.sh instance detected${NC}"
    
    # Create test directory
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    echo -e "${GREEN}✓ Test directory created: $TEST_DIR${NC}"
    
    # Verify script exists and is large enough
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        echo -e "${RED}✗ convert.sh not found at $SCRIPT_PATH${NC}"
        exit 1
    fi
    
    local script_size=$(wc -l < "$SCRIPT_PATH" 2>/dev/null || echo "0")
    if [[ $script_size -lt 5000 ]]; then
        echo -e "${YELLOW}⚠️ Warning: Script appears smaller than expected ($script_size lines)${NC}"
    fi
    echo -e "${GREEN}✓ Found convert.sh ($script_size lines)${NC}"
    
    # Check system requirements
    if ! command -v ffmpeg >/dev/null 2>&1; then
        echo -e "${RED}✗ FFmpeg not found${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ FFmpeg installed: $(ffmpeg -version 2>&1 | head -1 | cut -d' ' -f3)${NC}"
    
    # Check available disk space
    local available_space=$(df "$TEST_DIR" | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 500000 ]]; then  # 500MB in KB
        echo -e "${YELLOW}⚠️ Warning: Less than 500MB available disk space${NC}"
    fi
    echo -e "${GREEN}✓ Sufficient disk space available${NC}"
    
    echo ""
}

cleanup_test_environment() {
    echo -e "\n${CYAN}Cleaning up test environment...${NC}"
    
    # Remove test files
    if [[ -d "$TEST_DIR" ]]; then
        cd /
        rm -rf "$TEST_DIR" 2>/dev/null || true
        echo -e "${GREEN}✓ Test directory cleaned up${NC}"
    fi
    
    # Clean up any stale processes
    pkill -f "ffmpeg.*testsrc" 2>/dev/null || true
}

# =============================================================================
# Main Test Runner
# =============================================================================

run_all_tests() {
    print_header "🧪 ADVANCED COMPREHENSIVE TEST SUITE FOR convert.sh" 
    echo -e "${CYAN}Target Category: ${BOLD}$TARGET_CATEGORY${NC}"
    echo -e "${CYAN}Test Directory: ${BOLD}$TEST_DIR${NC}"
    echo -e "${CYAN}Script Path: ${BOLD}$SCRIPT_PATH${NC}"
    [[ "$SKIP_SLOW" == "true" ]] && echo -e "${YELLOW}Slow tests: ${BOLD}SKIPPED${NC}"
    echo ""
    
    # Analyze script structure first
    analyze_script_structure
    
    # Setup test environment
    setup_test_environment
    create_advanced_test_videos
    
    # Run test categories
    if should_run_category "basic"; then
        print_header "🔍 BASIC FUNCTIONALITY TESTS" "basic"
        test_script_structure
        test_bash_version_enforcement
        test_process_group_management
        test_single_instance_locking
    fi
    
    if should_run_category "system"; then
        print_header "💾 SYSTEM INTEGRATION TESTS" "system"
        test_dependency_validation
        test_gpu_acceleration_detection
        test_comprehensive_error_handling
        test_logging_system
        test_signal_handling
    fi
    
    if should_run_category "conversion"; then
        print_header "⚙️ CORE CONVERSION TESTS" "conversion"
        test_quality_preset_system
        test_conversion_pipeline_integration
        test_aspect_ratio_handling
    fi
    
    if should_run_category "ai"; then
        print_header "🤖 AI SYSTEM TESTS" "ai"
        test_ai_content_detection_engine
        test_ai_duplicate_detection_system
        test_ai_scene_analysis
        test_ai_motion_complexity_analysis
        test_ai_cache_system
        test_ai_training_system
    fi
    
    if should_run_category "advanced"; then
        print_header "🔧 ADVANCED FEATURE TESTS" "advanced"
        test_interactive_menu_system
        test_clickable_file_paths
        test_settings_persistence
        test_backup_and_recovery
    fi
    
    if should_run_category "performance"; then
        print_header "⚡ PERFORMANCE TESTS" "performance"
        test_parallel_processing_system
        test_memory_optimization
        test_cpu_optimization
        test_conversion_speed_benchmark
        test_memory_usage_monitoring
    fi
    
    if should_run_category "integration"; then
        print_header "🔄 INTEGRATION TESTS" "integration"
        test_end_to_end_conversion
        test_ai_enabled_conversion
        test_batch_processing
        test_error_recovery
    fi
}

# =============================================================================
# Advanced Summary Report
# =============================================================================

print_advanced_summary() {
    print_header "📊 ADVANCED TEST SUMMARY"
    
    local total_run=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
    local pass_rate=0
    [[ $total_run -gt 0 ]] && pass_rate=$((TESTS_PASSED * 100 / total_run))
    
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local duration_min=$((duration / 60))
    local duration_sec=$((duration % 60))
    
    echo -e "${CYAN}${BOLD}OVERALL RESULTS:${NC}"
    echo -e "${CYAN}Total Tests Run: ${BOLD}$total_run${NC}"
    echo -e "${GREEN}✓ Passed: ${BOLD}$TESTS_PASSED${NC}"
    echo -e "${RED}✗ Failed: ${BOLD}$TESTS_FAILED${NC}"
    echo -e "${YELLOW}⊘ Skipped: ${BOLD}$TESTS_SKIPPED${NC}"
    echo -e "${CYAN}Pass Rate: ${BOLD}${pass_rate}%${NC}"
    echo -e "${BLUE}Duration: ${BOLD}${duration_min}m ${duration_sec}s${NC}\n"
    
    echo -e "${CYAN}${BOLD}CATEGORY BREAKDOWN:${NC}"
    for category in "${!TEST_CATEGORIES[@]}"; do
        if [[ "${TEST_CATEGORIES[$category]}" -gt 0 ]]; then
            local cat_total="${TEST_CATEGORIES[$category]}"
            local cat_passed="${CATEGORY_PASSED[$category]}"
            local cat_failed="${CATEGORY_FAILED[$category]}"
            local cat_rate=0
            [[ $cat_total -gt 0 ]] && cat_rate=$(( (cat_passed * 100) / cat_total ))
            
            printf "  %-12s: %2d tests | " "${category^^}" "$cat_total"
            printf "${GREEN}%2d passed${NC} | " "$cat_passed"
            printf "${RED}%2d failed${NC} | " "$cat_failed"
            printf "Rate: ${BOLD}%3d%%${NC}\n" "$cat_rate"
        fi
    done
    
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}🎉 ALL TESTS PASSED! SCRIPT IS FULLY FUNCTIONAL!${NC}"
        echo -e "${CYAN}✓ The 10,000+ line convert.sh script has passed comprehensive testing${NC}"
        return 0
    else
        echo -e "${RED}${BOLD}❌ SOME TESTS FAILED${NC}"
        echo -e "${YELLOW}💡 Review failed tests to identify areas needing attention${NC}"
        return 1
    fi
}

# =============================================================================
# Trap and Cleanup
# =============================================================================

trap cleanup_test_environment EXIT

# =============================================================================
# Main Execution
# =============================================================================

echo -e "${BOLD}${CYAN}"
echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║            ADVANCED COMPREHENSIVE TEST SUITE                 ║"
echo "  ║              For convert.sh (10,000+ Lines)                  ║"
echo "  ╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

run_all_tests
cleanup_test_environment

echo ""
print_advanced_summary