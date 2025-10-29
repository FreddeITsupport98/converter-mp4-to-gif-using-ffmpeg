#!/bin/bash

# =============================================================================
# Auto-Update Feature for Smart GIF Converter (GitHub Releases)
# =============================================================================
# Add these functions to your convert.sh script

# 🔄 Configuration
GITHUB_REPO="FreddeITsupport98/converter-mp4-to-gif-using-ffmpeg"
GITHUB_API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
GITHUB_RELEASES_URL="https://github.com/${GITHUB_REPO}/releases"
CURRENT_VERSION="5.1"  # This should match the version in your script
UPDATE_CHECK_FILE="$HOME/.smart-gif-converter/.last_update_check"
UPDATE_CHECK_INTERVAL=86400  # Check once per day (in seconds)

# 🔍 Check for updates from GitHub Releases
check_for_updates() {
    # Skip if checked recently
    if [[ -f "$UPDATE_CHECK_FILE" ]]; then
        local last_check=$(cat "$UPDATE_CHECK_FILE" 2>/dev/null || echo "0")
        local now=$(date +%s)
        local time_diff=$((now - last_check))
        
        if [[ $time_diff -lt $UPDATE_CHECK_INTERVAL ]]; then
            return 0  # Skip check
        fi
    fi
    
    echo -e "${CYAN}🔍 Checking for updates from GitHub Releases...${NC}"
    
    # Fetch latest release info from GitHub API
    local release_json=$(curl -s "$GITHUB_API_URL" 2>/dev/null)
    
    if [[ -z "$release_json" ]] || [[ "$release_json" == *"Not Found"* ]]; then
        echo -e "${YELLOW}⚠️  Could not check for updates (network issue or no releases)${NC}"
        return 1
    fi
    
    # Extract version tag (e.g., "converter 5.1" or "v5.1")
    local remote_tag=$(echo "$release_json" | grep -o '"tag_name":"[^"]*"' | cut -d'"' -f4)
    # Extract just the version number
    local remote_version=$(echo "$remote_tag" | grep -oE '[0-9]+\.[0-9]+' | head -1)
    
    # Extract release notes
    local release_body=$(echo "$release_json" | grep -o '"body":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n/\n/g' | sed 's/\\r//g')
    
    if [[ -z "$remote_version" ]]; then
        echo -e "${YELLOW}⚠️  Could not parse version from release${NC}"
        return 1
    fi
    
    # Save check time
    mkdir -p "$(dirname "$UPDATE_CHECK_FILE")"
    echo "$(date +%s)" > "$UPDATE_CHECK_FILE"
    
    # Compare versions
    if [[ "$remote_version" != "$CURRENT_VERSION" ]]; then
        show_update_available "$remote_version" "$remote_tag" "$release_body"
    else
        echo -e "${GREEN}✓ You're running the latest version (${CURRENT_VERSION})${NC}"
    fi
}

# 📢 Show update notification with release notes
show_update_available() {
    local new_version="$1"
    local release_tag="$2"
    local release_notes="$3"
    
    clear
    echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                  🎉 UPDATE AVAILABLE!                        ║${NC}"
    echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Current version: ${BOLD}${CURRENT_VERSION}${NC}"
    echo -e "${GREEN}New version:     ${BOLD}${new_version}${NC} ${GRAY}(${release_tag})${NC}"
    echo ""
    
    # Display release notes (summary)
    if [[ -n "$release_notes" ]]; then
        echo -e "${BLUE}${BOLD}📝 What's New:${NC}"
        echo -e "${CYAN}─────────────────────────────────────────────────────────────${NC}"
        # Show first 15 lines of release notes
        echo "$release_notes" | head -15 | sed 's/^/  /'
        
        # Check if there are more lines
        local total_lines=$(echo "$release_notes" | wc -l)
        if [[ $total_lines -gt 15 ]]; then
            echo -e "  ${GRAY}... ($(($total_lines - 15)) more lines)${NC}"
        fi
        echo -e "${CYAN}─────────────────────────────────────────────────────────────${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}🔗 Full release notes: ${CYAN}${GITHUB_RELEASES_URL}/tag/${release_tag}${NC}"
    echo ""
    echo -e "${YELLOW}Would you like to update now? [y/N]: ${NC}"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        perform_update "$new_version" "$release_tag" "$release_notes"
    else
        echo -e "${BLUE}ℹ️  You can update later by running: ./convert.sh --update${NC}"
    fi
}

# 🔐 Verify SHA256 checksum
verify_sha256() {
    local file="$1"
    local expected_sha="$2"
    
    if [[ -z "$expected_sha" ]]; then
        echo -e "${YELLOW}⚠️  No SHA256 checksum provided in release${NC}"
        echo -e "${YELLOW}⚠️  Skipping checksum verification (not recommended)${NC}"
        return 0  # Continue without verification
    fi
    
    echo -e "${CYAN}🔐 Verifying SHA256 checksum...${NC}"
    
    # Calculate actual SHA256
    local actual_sha=$(sha256sum "$file" | awk '{print $1}')
    
    echo -e "${GRAY}   Expected: $expected_sha${NC}"
    echo -e "${GRAY}   Actual:   $actual_sha${NC}"
    
    if [[ "$actual_sha" == "$expected_sha" ]]; then
        echo -e "${GREEN}✓ SHA256 verification passed!${NC}"
        return 0
    else
        echo -e "${RED}❌ SHA256 verification FAILED!${NC}"
        echo -e "${RED}   This could indicate:${NC}"
        echo -e "${RED}   • Corrupted download${NC}"
        echo -e "${RED}   • Man-in-the-middle attack${NC}"
        echo -e "${RED}   • Tampered release${NC}"
        return 1
    fi
}

# 📥 Extract SHA256 from release body
extract_sha256_from_release() {
    local release_body="$1"
    
    # Look for SHA256 in various formats:
    # sha256:edfb5c3bb719f22bba8f7b5bc722e637f54ee5a7662fa48058b112a8c4df15b9
    # SHA256: edfb5c3bb719f22bba8f7b5bc722e637f54ee5a7662fa48058b112a8c4df15b9
    # convert.sh: edfb5c3bb719f22bba8f7b5bc722e637f54ee5a7662fa48058b112a8c4df15b9
    
    local sha256=$(echo "$release_body" | grep -iE '(sha256|checksum)' | grep -oE '[a-f0-9]{64}' | head -1)
    
    echo "$sha256"
}

# 🚀 Perform the update from GitHub Release with SHA256 verification
perform_update() {
    local new_version="$1"
    local release_tag="$2"
    local release_body="$3"  # Add release body parameter
    
    echo -e "${CYAN}⬇️  Downloading update from release ${release_tag}...${NC}"
    
    # Extract SHA256 from release notes
    local expected_sha256=$(extract_sha256_from_release "$release_body")
    
    if [[ -n "$expected_sha256" ]]; then
        echo -e "${BLUE}🔐 SHA256 checksum found in release${NC}"
    else
        echo -e "${YELLOW}⚠️  No SHA256 checksum found in release notes${NC}"
        echo -e "${YELLOW}   Add 'sha256:HASH' or 'SHA256: HASH' to release notes for verification${NC}"
    fi
    
    # Create backup
    local backup_dir="$HOME/.smart-gif-converter/backups"
    mkdir -p "$backup_dir"
    local backup_file="$backup_dir/convert.sh.v${CURRENT_VERSION}-$(date +%Y%m%d-%H%M%S)"
    cp convert.sh "$backup_file" 2>/dev/null || cp "${BASH_SOURCE[0]}" "$backup_file"
    echo -e "${GREEN}✓ Backup created: $backup_file${NC}"
    
    # Get the download URL for convert.sh from the release
    local download_url="https://raw.githubusercontent.com/${GITHUB_REPO}/${release_tag}/convert.sh"
    
    # Try main branch if tag-specific URL fails
    local fallback_url="https://raw.githubusercontent.com/${GITHUB_REPO}/main/convert.sh"
    
    echo -e "${BLUE}📥 Downloading from: $download_url${NC}"
    
    # Download new version
    if curl -sL "$download_url" -o convert.sh.new 2>/dev/null; then
        # Verify download
        if [[ ! -f "convert.sh.new" ]] || [[ ! -s "convert.sh.new" ]]; then
            echo -e "${YELLOW}⚠️  Tag-specific download failed, trying main branch...${NC}"
            curl -sL "$fallback_url" -o convert.sh.new 2>/dev/null
        fi
        
        if [[ -f "convert.sh.new" ]] && [[ -s "convert.sh.new" ]]; then
            # Verify SHA256 checksum
            if ! verify_sha256 "convert.sh.new" "$expected_sha256"; then
                echo -e "${RED}❌ Update aborted due to failed checksum verification${NC}"
                rm -f convert.sh.new
                return 1
            fi
            
            # Check syntax
            echo -e "${CYAN}🔍 Checking syntax...${NC}"
            if bash -n convert.sh.new 2>/dev/null; then
                echo -e "${GREEN}✓ Syntax check passed${NC}"
                
                # Get current script path
                local script_path="${BASH_SOURCE[0]}"
                [[ -z "$script_path" ]] && script_path="./convert.sh"
                
                # Replace old version
                mv convert.sh.new "$script_path"
                chmod +x "$script_path"
                
                echo -e "${GREEN}${BOLD}✓ Update successful! Updated to v${new_version}${NC}"
                echo -e "${YELLOW}🔄 Please restart the script to use the new version${NC}"
                echo ""
                echo -e "${BLUE}📋 Backup saved at: $backup_file${NC}"
                echo -e "${CYAN}💡 To revert: cp $backup_file $script_path${NC}"
                echo ""
                echo -e "${GREEN}🎉 Enjoy the new features!${NC}"
                exit 0
            else
                echo -e "${RED}❌ Downloaded file has syntax errors. Update cancelled.${NC}"
                rm -f convert.sh.new
                return 1
            fi
        else
            echo -e "${RED}❌ Download failed or file is empty${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Failed to download update${NC}"
        echo -e "${YELLOW}💡 You can manually download from: ${GITHUB_RELEASES_URL}${NC}"
        return 1
    fi
}

# 🔧 Manual update command
manual_update() {
    echo -e "${CYAN}🔄 Checking for updates from GitHub Releases...${NC}"
    
    # Fetch latest release info
    local release_json=$(curl -s "$GITHUB_API_URL" 2>/dev/null)
    
    if [[ -z "$release_json" ]] || [[ "$release_json" == *"Not Found"* ]]; then
        echo -e "${RED}❌ Could not fetch version info${NC}"
        echo -e "${YELLOW}Make sure you have internet connection${NC}"
        echo -e "${BLUE}Or visit manually: ${GITHUB_RELEASES_URL}${NC}"
        return 1
    fi
    
    # Extract version info
    local remote_tag=$(echo "$release_json" | grep -o '"tag_name":"[^"]*"' | cut -d'"' -f4)
    local remote_version=$(echo "$remote_tag" | grep -oE '[0-9]+\.[0-9]+' | head -1)
    local release_body=$(echo "$release_json" | grep -o '"body":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n/\n/g' | sed 's/\\r//g')
    
    if [[ -z "$remote_version" ]]; then
        echo -e "${RED}❌ Could not parse version from release${NC}"
        return 1
    fi
    
    if [[ "$remote_version" == "$CURRENT_VERSION" ]]; then
        echo -e "${GREEN}✓ You're already running the latest version (${CURRENT_VERSION})${NC}"
        echo -e "${BLUE}🔗 View releases: ${GITHUB_RELEASES_URL}${NC}"
        return 0
    fi
    
    show_update_available "$remote_version" "$remote_tag" "$release_body"
}

# 📊 Show version info
show_version() {
    echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║          Smart GIF Converter v${CURRENT_VERSION}                         ║${NC}"
    echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}📦 Repository: ${CYAN}https://github.com/${GITHUB_REPO}${NC}"
    echo -e "${BLUE}📋 Releases:   ${CYAN}${GITHUB_RELEASES_URL}${NC}"
    echo ""
    echo -e "${YELLOW}Update Commands:${NC}"
    echo -e "  ${GREEN}--version${NC}        Show version information"
    echo -e "  ${GREEN}--update${NC}         Check for and install updates from releases"
    echo -e "  ${GREEN}--check-update${NC}   Check if updates are available (no install)"
    echo ""
    echo -e "${GRAY}Auto-update checks run once per day automatically${NC}"
}

# =============================================================================
# ADD TO YOUR MAIN SCRIPT
# =============================================================================
# Add these to your argument parsing section:
#
#     --update)
#         manual_update
#         exit 0
#         ;;
#     --check-update)
#         check_for_updates
#         exit 0
#         ;;
#     --version)
#         show_version
#         exit 0
#         ;;
#
# And add this to the start of your main() function:
#
#     # Auto-check for updates (once per day)
#     check_for_updates 2>/dev/null &
#
# =============================================================================

# =============================================================================
# HOW TO ADD SHA256 TO YOUR RELEASES
# =============================================================================
# When creating a release on GitHub, add the SHA256 checksum to the release notes:
#
# 1. Generate SHA256 for convert.sh:
#    sha256sum convert.sh
#
# 2. Add to release notes in any of these formats:
#    sha256:edfb5c3bb719f22bba8f7b5bc722e637f54ee5a7662fa48058b112a8c4df15b9
#    SHA256: edfb5c3bb719f22bba8f7b5bc722e637f54ee5a7662fa48058b112a8c4df15b9
#    convert.sh: edfb5c3bb719f22bba8f7b5bc722e637f54ee5a7662fa48058b112a8c4df15b9
#
# Example release notes:
# ```
# ## What's New in v5.2
# - Feature 1
# - Feature 2
#
# ## Security
# sha256:edfb5c3bb719f22bba8f7b5bc722e637f54ee5a7662fa48058b112a8c4df15b9
# ```
# =============================================================================

# Example usage:
# ./convert.sh --update          # Manual update with SHA256 verification
# ./convert.sh --check-update    # Check without updating
# ./convert.sh --version          # Show version info
