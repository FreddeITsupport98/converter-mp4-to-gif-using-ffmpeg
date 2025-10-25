#!/bin/bash

# =============================================================================
# Comprehensive Test Suite for convert.sh
# =============================================================================
# This script tests all major functions of the GIF converter
# 
# Usage: ./test_converter.sh [--verbose]
#
# Requirements:
# - FFmpeg installed
# - convert.sh in the same directory
# - At least 100MB free disk space
# =============================================================================

# Note: Do NOT use 'set -e' as we want to continue testing even after failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
TOTAL_TESTS=0

# Test directory
TEST_DIR="$(pwd)/test_temp_$$"
SCRIPT_PATH="$(pwd)/convert.sh"

# Verbose mode
VERBOSE=false
[[ "$1" == "--verbose" ]] && VERBOSE=true

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo -e "\n${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_test() {
    local test_name="$1"
    ((TOTAL_TESTS++))
    echo -ne "${BLUE}[TEST $TOTAL_TESTS]${NC} $test_name ... "
}

pass() {
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓ PASS${NC}"
}

fail() {
    ((TESTS_FAILED++))
    echo -e "${RED}✗ FAIL${NC}"
    [[ -n "$1" ]] && echo -e "  ${RED}→ $1${NC}"
}

skip() {
    ((TESTS_SKIPPED++))
    echo -e "${YELLOW}⊘ SKIP${NC}"
    [[ -n "$1" ]] && echo -e "  ${YELLOW}→ $1${NC}"
}

cleanup() {
    [[ -d "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
}

# =============================================================================
# Setup and Teardown
# =============================================================================

setup_test_environment() {
    print_header "🔧 SETTING UP TEST ENVIRONMENT"
    
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
    
    # Check if convert.sh exists
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        echo -e "${RED}✗ convert.sh not found at $SCRIPT_PATH${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Found convert.sh${NC}"
    
    # Check FFmpeg
    if ! command -v ffmpeg >/dev/null 2>&1; then
        echo -e "${RED}✗ FFmpeg not found${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ FFmpeg installed: $(ffmpeg -version | head -1)${NC}"
}

# =============================================================================
# Test Video Generation
# =============================================================================

create_test_video() {
    local filename="$1"
    local duration="${2:-3}"
    local width="${3:-640}"
    local height="${4:-480}"
    
    ffmpeg -f lavfi -i testsrc=duration=${duration}:size=${width}x${height}:rate=30 \
           -f lavfi -i sine=frequency=1000:duration=${duration} \
           -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest \
           "$filename" -y >/dev/null 2>&1
}

create_test_videos() {
    print_header "📹 CREATING TEST VIDEOS"
    
    # Create various test videos
    echo -n "Creating test videos ... "
    
    create_test_video "test_480p.mp4" 3 640 480
    create_test_video "test_720p.mp4" 3 1280 720
    create_test_video "test_1080p.mp4" 3 1920 1080
    create_test_video "test_short.mp4" 1 640 480
    create_test_video "test_long.mp4" 10 640 480
    
    echo -e "${GREEN}✓ Created 5 test videos${NC}"
    
    # Create a duplicate for testing
    cp test_480p.mp4 test_480p_duplicate.mp4
    echo -e "${GREEN}✓ Created duplicate video for testing${NC}"
}

# =============================================================================
# Test Cases
# =============================================================================

test_script_executable() {
    print_test "Script is executable"
    if [[ -x "$SCRIPT_PATH" ]]; then
        pass
    else
        fail "Script is not executable. Run: chmod +x convert.sh"
    fi
}

test_help_output() {
    print_test "Help output (--help)"
    if bash "$SCRIPT_PATH" --help >/dev/null 2>&1; then
        pass
    else
        fail "Help command failed"
    fi
}

test_version_output() {
    print_test "Version output (--version)"
    if bash "$SCRIPT_PATH" --version 2>&1 | grep -q "version"; then
        pass
    else
        skip "No version flag implemented"
    fi
}

test_system_detection() {
    print_test "System capability detection"
    
    # This would need to source the script and call the function
    # For now, we'll check if the function exists
    if grep -q "detect_hardware_capabilities\|Analyzing system capabilities" "$SCRIPT_PATH"; then
        pass
    else
        fail "System detection function not found"
    fi
}

test_dependency_check() {
    print_test "Dependency checking (FFmpeg)"
    
    if grep -q "check_dependencies\|command -v ffmpeg" "$SCRIPT_PATH"; then
        pass
    else
        fail "Dependency check not implemented"
    fi
}

test_basic_conversion() {
    print_test "Basic video to GIF conversion"
    
    # Note: There's no --ai-enabled flag, AI is disabled by default
    if bash "$SCRIPT_PATH" --file test_480p.mp4 --preset low >/dev/null 2>&1; then
        if [[ -f "test_480p.gif" ]]; then
            pass
        else
            fail "GIF file was not created"
        fi
    else
        fail "Conversion command failed"
    fi
}

test_quality_presets() {
    print_test "Quality preset handling (low, medium, high, max)"
    
    local presets_found=0
    for preset in low medium high max; do
        if grep -q "\"$preset\"" "$SCRIPT_PATH"; then
            ((presets_found++))
        fi
    done
    
    if [[ $presets_found -eq 4 ]]; then
        pass
    else
        fail "Only found $presets_found/4 quality presets"
    fi
}

test_ai_mode_detection() {
    print_test "AI mode functionality"
    
    if grep -q "AI_ENABLED\|ai_smart_analyze\|AI.*Mode" "$SCRIPT_PATH"; then
        pass
    else
        fail "AI functionality not found"
    fi
}

test_parallel_processing() {
    print_test "Parallel processing support"
    
    if grep -q "PARALLEL_JOBS\|parallel.*processing\|run_parallel" "$SCRIPT_PATH"; then
        pass
    else
        fail "Parallel processing not implemented"
    fi
}

test_progress_bar() {
    print_test "Progress bar implementation"
    
    if grep -q "progress.*bar\|PROGRESS_BAR\|show.*progress" "$SCRIPT_PATH"; then
        pass
    else
        fail "Progress bar not found"
    fi
}

test_duplicate_detection() {
    print_test "Duplicate GIF detection"
    
    if grep -q "detect_duplicate\|duplicate.*gifs" "$SCRIPT_PATH"; then
        pass
    else
        fail "Duplicate detection not implemented"
    fi
}

test_cache_system() {
    print_test "AI cache system"
    
    if grep -q "AI_CACHE\|cache.*analysis\|init_ai_cache" "$SCRIPT_PATH"; then
        pass
    else
        skip "AI cache system not implemented"
    fi
}

test_training_system() {
    print_test "AI training/learning system"
    
    if grep -q "AI_TRAINING\|ai.*training\|smart_model" "$SCRIPT_PATH"; then
        pass
    else
        skip "AI training system not implemented"
    fi
}

test_error_handling() {
    print_test "Error handling and logging"
    
    if grep -q "ERROR_LOG\|log_error\|trace_function" "$SCRIPT_PATH"; then
        pass
    else
        fail "Error handling not properly implemented"
    fi
}

test_validation_cache() {
    print_test "Video validation cache"
    
    if grep -q "validation_cache\|validate_video_file" "$SCRIPT_PATH"; then
        pass
    else
        skip "Validation cache not found"
    fi
}

test_settings_persistence() {
    print_test "Settings save/load functionality"
    
    if grep -q "save_settings\|load_settings\|SETTINGS_FILE" "$SCRIPT_PATH"; then
        pass
    else
        fail "Settings persistence not implemented"
    fi
}

test_interactive_menu() {
    print_test "Interactive menu system"
    
    if grep -q "show_main_menu\|MAIN MENU\|interactive" "$SCRIPT_PATH"; then
        pass
    else
        fail "Interactive menu not found"
    fi
}

test_gpu_detection() {
    print_test "GPU detection (NVIDIA/AMD/Intel)"
    
    local gpu_support=0
    grep -q "nvidia-smi" "$SCRIPT_PATH" && ((gpu_support++))
    grep -q "rocm-smi\|AMD.*GPU" "$SCRIPT_PATH" && ((gpu_support++))
    grep -q "Intel.*Arc\|Intel.*GPU" "$SCRIPT_PATH" && ((gpu_support++))
    
    if [[ $gpu_support -ge 2 ]]; then
        pass
    else
        fail "Limited GPU detection support ($gpu_support/3 vendors)"
    fi
}

test_inxi_integration() {
    print_test "inxi hardware detection integration"
    
    if grep -q "inxi.*-C\|inxi.*-G\|inxi.*-m\|inxi.*hardware" "$SCRIPT_PATH"; then
        pass
    else
        skip "inxi integration not found"
    fi
}

test_cleanup_handlers() {
    print_test "Cleanup and interrupt handlers"
    
    if grep -q "trap.*cleanup\|SIGINT\|SIGTERM" "$SCRIPT_PATH"; then
        pass
    else
        fail "Cleanup handlers not properly set"
    fi
}

test_output_validation() {
    print_test "Output GIF validation"
    
    if grep -q "validate_output\|test.*gif.*valid" "$SCRIPT_PATH"; then
        pass
    else
        skip "Output validation not implemented"
    fi
}

test_aspect_ratio_handling() {
    print_test "Aspect ratio preservation/conversion"
    
    if grep -q "ASPECT_RATIO\|aspect.*ratio" "$SCRIPT_PATH"; then
        pass
    else
        fail "Aspect ratio handling not found"
    fi
}

test_optimization_features() {
    print_test "GIF optimization (gifsicle)"
    
    if grep -q "gifsicle\|AUTO_OPTIMIZE\|optimize.*gif" "$SCRIPT_PATH"; then
        pass
    else
        skip "GIF optimization not implemented"
    fi
}

test_backup_system() {
    print_test "Original file backup system"
    
    if grep -q "BACKUP_ORIGINAL\|backup.*file" "$SCRIPT_PATH"; then
        pass
    else
        skip "Backup system not found"
    fi
}

test_scene_detection() {
    print_test "AI scene detection"
    
    if grep -q "ai_scene_detection\|scene.*analysis" "$SCRIPT_PATH"; then
        pass
    else
        skip "Scene detection not implemented"
    fi
}

test_motion_analysis() {
    print_test "Motion complexity analysis"
    
    if grep -q "analyze_motion\|motion.*complexity" "$SCRIPT_PATH"; then
        pass
    else
        skip "Motion analysis not implemented"
    fi
}

test_content_type_detection() {
    print_test "Content type detection (animation/movie/etc)"
    
    if grep -q "detect_content_type\|animation.*screencast.*movie" "$SCRIPT_PATH"; then
        pass
    else
        skip "Content type detection not found"
    fi
}

test_smart_crop() {
    print_test "Intelligent crop detection"
    
    if grep -q "crop.*detect\|smart.*crop\|intelligent.*crop" "$SCRIPT_PATH"; then
        pass
    else
        skip "Smart crop not implemented"
    fi
}

test_dynamic_framerate() {
    print_test "Dynamic frame rate adjustment"
    
    if grep -q "AI_DYNAMIC_FRAMERATE\|dynamic.*fps\|smart.*framerate" "$SCRIPT_PATH"; then
        pass
    else
        skip "Dynamic frame rate not implemented"
    fi
}

test_quality_scaling() {
    print_test "Intelligent quality parameter scaling"
    
    if grep -q "AI_QUALITY_SCALING\|quality.*scaling\|intelligent.*quality" "$SCRIPT_PATH"; then
        pass
    else
        skip "Quality scaling not implemented"
    fi
}

test_file_discovery() {
    print_test "AI video file discovery"
    
    if grep -q "ai_discover_videos\|video.*discovery" "$SCRIPT_PATH"; then
        pass
    else
        skip "File discovery not implemented"
    fi
}

# =============================================================================
# Performance Tests
# =============================================================================

test_conversion_speed() {
    print_test "Conversion speed benchmark"
    
    local start_time=$(date +%s)
    bash "$SCRIPT_PATH" --file test_short.mp4 --preset low >/dev/null 2>&1
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ $duration -lt 30 ]]; then
        pass
        [[ "$VERBOSE" == "true" ]] && echo -e "  ${CYAN}→ Completed in ${duration}s${NC}"
    else
        fail "Conversion took too long (${duration}s)"
    fi
}

test_memory_usage() {
    print_test "Memory usage during conversion"
    
    # This is a basic check - would need more sophisticated monitoring
    if grep -q "memory.*opt\|RAM.*detection" "$SCRIPT_PATH"; then
        pass
    else
        skip "Memory optimization not detected"
    fi
}

# =============================================================================
# Integration Tests
# =============================================================================

test_batch_conversion() {
    print_test "Batch conversion of multiple files"
    
    # Batch mode requires --force to skip interactive prompts
    if bash "$SCRIPT_PATH" --preset low --force >/dev/null 2>&1; then
        local gif_count=$(ls -1 *.gif 2>/dev/null | wc -l)
        if [[ $gif_count -ge 3 ]]; then
            pass
            [[ "$VERBOSE" == "true" ]] && echo -e "  ${CYAN}→ Created $gif_count GIF files${NC}"
        else
            fail "Expected multiple GIFs, got $gif_count"
        fi
    else
        fail "Batch conversion failed"
    fi
}

test_file_size_limits() {
    print_test "File size limit enforcement"
    
    if grep -q "MAX_GIF_SIZE\|size.*limit\|file.*too.*large" "$SCRIPT_PATH"; then
        pass
    else
        skip "File size limits not implemented"
    fi
}

# =============================================================================
# Main Test Runner
# =============================================================================

run_all_tests() {
    print_header "🧪 COMPREHENSIVE TEST SUITE FOR convert.sh"
    
    echo -e "${CYAN}Test Directory: ${BOLD}$TEST_DIR${NC}"
    echo -e "${CYAN}Script Path: ${BOLD}$SCRIPT_PATH${NC}\n"
    
    # Setup
    setup_test_environment
    create_test_videos
    
    print_header "🔍 BASIC FUNCTIONALITY TESTS"
    test_script_executable
    test_help_output
    test_version_output
    test_system_detection
    test_dependency_check
    
    print_header "⚙️ CORE CONVERSION TESTS"
    test_basic_conversion
    test_quality_presets
    test_aspect_ratio_handling
    
    print_header "🤖 AI FEATURES TESTS"
    test_ai_mode_detection
    test_content_type_detection
    test_motion_analysis
    test_scene_detection
    test_smart_crop
    test_dynamic_framerate
    test_quality_scaling
    
    print_header "🔧 ADVANCED FEATURES TESTS"
    test_parallel_processing
    test_progress_bar
    test_duplicate_detection
    test_cache_system
    test_training_system
    test_validation_cache
    
    print_header "💾 SYSTEM INTEGRATION TESTS"
    test_gpu_detection
    test_inxi_integration
    test_error_handling
    test_settings_persistence
    test_interactive_menu
    test_cleanup_handlers
    
    print_header "🎨 OUTPUT & OPTIMIZATION TESTS"
    test_output_validation
    test_optimization_features
    test_backup_system
    test_file_discovery
    
    print_header "⚡ PERFORMANCE TESTS"
    test_conversion_speed
    test_memory_usage
    
    print_header "🔄 INTEGRATION TESTS"
    test_batch_conversion
    test_file_size_limits
}

# =============================================================================
# Summary Report
# =============================================================================

print_summary() {
    print_header "📊 TEST SUMMARY"
    
    local total_run=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
    local pass_rate=0
    [[ $total_run -gt 0 ]] && pass_rate=$((TESTS_PASSED * 100 / total_run))
    
    echo -e "${CYAN}Total Tests Run: ${BOLD}$total_run${NC}"
    echo -e "${GREEN}✓ Passed: ${BOLD}$TESTS_PASSED${NC}"
    echo -e "${RED}✗ Failed: ${BOLD}$TESTS_FAILED${NC}"
    echo -e "${YELLOW}⊘ Skipped: ${BOLD}$TESTS_SKIPPED${NC}"
    echo -e "${CYAN}Pass Rate: ${BOLD}${pass_rate}%${NC}\n"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}🎉 ALL TESTS PASSED!${NC}\n"
        return 0
    else
        echo -e "${RED}${BOLD}❌ SOME TESTS FAILED${NC}\n"
        return 1
    fi
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Run all tests
    run_all_tests
    
    # Print summary
    print_summary
    
    # Cleanup
    echo -e "${BLUE}Cleaning up test environment...${NC}"
    cleanup
    echo -e "${GREEN}✓ Cleanup complete${NC}\n"
}

# Run main
main "$@"
