# Changelog

All notable changes to Smart GIF Converter will be documented in this file.

## [5.2.0] - 2024-10-29

### 🔄 Auto-Update System

#### GitHub Releases Integration
- **Automatic Update Checking**: Checks GitHub Releases API once per day
  - Non-intrusive background check on script startup
  - Respects user preference (can be disabled)
  - Uses intelligent caching to avoid API rate limits
  - Validates GitHub URL before fetching (5s timeout)
  
- **Update Notifications**: Shows user-friendly notifications when updates available
  - Displays current vs. new version
  - Shows release notes preview (first 5 lines)
  - Provides link to full release notes
  - Offers interactive update prompt

#### Secure Update Process
- **SHA256 Verification**: Cryptographic checksum validation
  - Extracts SHA256 from release notes (multiple formats supported)
  - Verifies downloaded file before installation
  - Aborts update if checksum fails
  - Skips verification with warning if no checksum provided

- **Safe Update Procedure**
  - Creates timestamped backup before updating
  - Downloads from release tag (fallback to main branch)
  - Validates bash syntax before installation
  - Uses atomic file operations (mv)
  - Preserves executable permissions
  - Comprehensive error handling with cleanup

#### New Commands
```bash
./convert.sh --version         # Show version and repository info  
./convert.sh --check-update    # Manually check for updates
./convert.sh --update          # Interactive update installation
```

#### User Preferences
- **First-Run Prompt**: Asks user about auto-update preference on first use
- **Configurable Settings**:
  - `AUTO_UPDATE_ENABLED`: Enable/disable auto-updates
  - `UPDATE_CHECK_INTERVAL`: Check frequency (default: 24 hours)
  - `UPDATE_CHECK_FILE`: Tracks last check time

### 📦 Enhanced Dependency Management

#### New Required Dependencies
- **git**: Added as required dependency for version control and auto-updates
- **curl**: Added as required dependency for GitHub API access

#### Improved Auto-Installation
- **Interactive Installation Prompts**
  - Shows detected OS and package manager
  - Displays exact installation command
  - Asks for user confirmation before installing
  - Verifies installation after completion
  - Provides troubleshooting if verification fails

- **Enhanced Error Handling**
  - Clear error messages with common failure causes
  - Comprehensive manual installation instructions on failure
  - Instructions for all supported distributions
  - Direct links to package repositories

#### Manual Installation Guide
- **New Function**: `show_manual_install_instructions()`
  - Formatted installation commands for each distribution
  - Covers Debian, Ubuntu, Fedora, RHEL, Arch, openSUSE, Alpine, Gentoo, Void, NixOS
  - Includes package repository search links
  - Provides post-installation tips (hash -r)

### 🐧 Cross-Distribution Support

#### Enhanced Distribution Detection
- **Improved Detection Logic**
  - Uses both `ID` and `ID_LIKE` from `/etc/os-release`
  - Case-insensitive comparison
  - Automatically detects derivative distributions
  - Graceful fallback to package manager detection

- **Expanded Distribution Support**
  - **Debian family**: Ubuntu, Mint, Pop!_OS, Neon, Zorin, MX, Raspbian, Kali
  - **Red Hat family**: Fedora, RHEL, CentOS, Rocky, AlmaLinux, Oracle Linux
  - **Arch family**: Arch, Manjaro, EndeavourOS, Garuda, CachyOS, Artix
  - **SUSE family**: openSUSE Tumbleweed, openSUSE Leap, SLES
  - **Independent**: Alpine, Gentoo, Void Linux, NixOS

#### Package Name Mapping
- **Comprehensive Mapping**: All tools mapped for all distributions
  - ffmpeg: Correct package names including `ffmpeg-4` for openSUSE
  - git: Standard `git` or `dev-vcs/git` for Gentoo
  - curl: Standard `curl` or `net-misc/curl` for Gentoo  
  - gifsicle: All distributions supported
  - jq: All distributions supported
  - ImageMagick: Handles capitalization differences

- **Special Distribution Handling**
  - Gentoo: Uses category/name format (e.g., `media-video/ffmpeg`)
  - Void: Uses xbps package manager
  - NixOS: Declarative package management notes

### 📚 Documentation

#### New Documentation Files
1. **AUTO_UPDATE_IMPLEMENTATION.md** (378 lines)
   - Complete auto-update system documentation
   - Technical details and architecture
   - User guide and maintainer checklist
   - Troubleshooting section
   - Security considerations

2. **UPDATE_QUICK_REFERENCE.md** (196 lines)
   - Quick command reference
   - Release checklist for maintainers
   - SHA256 format examples
   - Update flow diagram
   - Error message reference

3. **CROSS_DISTRO_SUPPORT.md** (414 lines)
   - Comprehensive distribution support guide
   - Package name tables for all distributions
   - Distribution-specific notes
   - Testing procedures
   - Troubleshooting by distribution
   - Contributing guidelines

#### Updated Documentation
- **README.md**: Added v5.2 features section
- **WARP.md**: Updated with auto-update system information
- **CHANGELOG.md**: This file (comprehensive v5.2 changes)

### 🔧 Technical Changes

#### New Configuration Variables
```bash
GITHUB_REPO="FreddeITsupport98/converter-mp4-to-gif-using-ffmpeg"
GITHUB_API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
GITHUB_RELEASES_URL="https://github.com/${GITHUB_REPO}/releases"
CURRENT_VERSION="5.2"
UPDATE_CHECK_FILE="$LOG_DIR/.last_update_check"
UPDATE_CHECK_INTERVAL=86400  # 24 hours
AUTO_UPDATE_ENABLED=true
UPDATE_FIRST_RUN_PROMPT_DONE=false
```

#### New Functions
1. **Update System** (lines 402-590)
   - `check_for_updates()`: Automatic update checker
   - `show_update_available()`: Update notification display
   - `verify_sha256()`: Checksum verification
   - `extract_sha256_from_release()`: Release notes parser
   - `perform_update()`: Update installation
   - `manual_update()`: Interactive update command
   - `show_version_info()`: Version display

2. **Dependency Management** (lines 8973-9157)
   - `show_manual_install_instructions()`: Manual install guide
   - Enhanced `detect_distro()`: Improved detection
   - Enhanced `get_package_names()`: Added git and curl
   - Enhanced `auto_install_dependencies()`: Better error handling

#### Code Statistics
- Total lines: 16,500+ (up from 13,700+)
- New functions: 8
- Updated functions: 5
- New documentation: 988 lines
- Lines of code added: ~2,800

### ⚙️ Configuration Changes

#### Required Dependencies Updated
Before: `ffmpeg`
After: `ffmpeg`, `git`, `curl`

#### New Command-Line Options
- `--version` / `-v`: Show version information
- `--check-update`: Check for updates manually
- `--update`: Install latest version interactively

### 🐛 Bug Fixes
- Fixed: Auto-update check causing ERR trap (now returns 0)
- Fixed: Network failures don't block script execution
- Fixed: API rate limiting handled gracefully
- Fixed: Package installation failures provide clear guidance

### 🔒 Security Enhancements
- SHA256 checksum verification for all downloads
- Bash syntax validation before installing updates
- Atomic file operations to prevent corruption
- Automatic backups before any modification
- No sudo required for update system
- Respects system package repositories (no third-party additions)

### 🚀 Performance
- Update check runs in background (doesn't block startup)
- URL validation with 5s timeout
- API fetch with 10s timeout
- Cached update check status (respects interval)
- Minimal overhead when auto-updates disabled

### 🧪 Testing
- Tested on openSUSE Tumbleweed (primary development platform)
- Syntax validated with `bash -n`
- Cross-distribution detection tested via /etc/os-release parsing
- Update commands tested (`--version`, `--check-update`)
- Error handling tested (network failures, invalid responses)

---

## [5.1.0] - 2024-10-27

### 📁 Output Directory Management
- Fixed persistent settings for output directory selection
- Added four directory options with real-time preview
- Enhanced configuration flow with auto-save
- Clickable paths in modern terminals

### 🎯 Enhanced Menu System  
- Improved navigation and option mappings
- Visual feedback for all selections
- Seamless integration with settings persistence

---

## [2.0.0] - 2024-10-26

### 🚀 Performance Revolution

#### Smart Cache Detection System
- **Memory-Based Cache Lookups**: Complete rewrite of cache pre-scan system
  - Old: 200+ individual grep searches through cache file (10+ seconds)
  - New: Single load into associative array with O(1) lookups (<1 second)
  - **Result**: 10x faster cache pre-scanning

- **Intelligent Resume from Interruption**
  - Files analyzed before Ctrl+C are saved to cache
  - Next run automatically detects cached files and skips them
  - Only processes NEW, CHANGED, or uncached files
  - **Result**: Zero wasted work when resuming

- **Change Detection with Fingerprinting**
  - Uses file size + modification time (mtime) for instant change detection
  - No expensive MD5 recalculation for unchanged files
  - Automatically re-analyzes only files that have changed
  - **Result**: Efficient incremental updates

#### Automatic Cache Maintenance
- **Self-Cleaning Cache**: Runs automatically every 7 days in background
  - Removes entries for deleted files
  - Removes duplicate entries (keeps only latest)
  - Removes old entries (>30 days)
  - Tracked via `.last_cleanup` marker file
  - **Result**: Cache stays lean without manual intervention

- **Cache Optimization Results**
  - Real-world example: 620+ entries (115KB) → 0 entries (181 bytes)
  - 99% size reduction after cleanup of deleted file entries
  - Manual cleanup command: `./convert.sh --clean-cache`

### 🛡️ Enterprise Reliability

#### Process Management
- **Single Instance Lock**
  - Prevents multiple concurrent script executions
  - Lock file: `~/.smart-gif-converter/script.lock`
  - Detects and cleans stale locks from crashed processes
  - Shows helpful error with running PID if script already active

- **Process Group Management**
  - All child processes bound to terminal session
  - Clean termination of ALL ffmpeg processes on interrupt
  - No orphaned processes after Ctrl+C or terminal close
  - Process group tracking with `SCRIPT_PGID`

#### Data Integrity
- **Corruption-Proof Cache**
  - Atomic write operations using temporary files
  - Automatic integrity validation on every read
  - Automatic rebuild if corruption detected
  - Backup system (`.safe` files) for recovery

- **Cache Index Format v2.0**
  - Format: `filename|filesize|filemtime|timestamp|analysis_data`
  - Uses size+mtime fingerprint (no MD5 needed for validation)
  - Automatic migration from old format (v1.0)
  - Version checking prevents compatibility issues

### 🤖 AI Intelligence Enhancements

#### AI Generation Tracking
- **Learning Progress Monitoring**
  - Tracks AI "generation" number (increments on model rebuilds)
  - Displayed during conversions: "Using AI generation: X"
  - Persistent across script runs
  - Shows AI improvement over time

#### Enhanced Duplicate Detection
- **4-Level Similarity Analysis**
  - Level 1: Exact binary match (MD5 checksums)
  - Level 2: Visual similarity (perceptual hashing)
  - Level 3: Content fingerprinting (metadata analysis)
  - Level 4: Near-identical detection (size ratios, temporal analysis)

- **Smart Duplicate Caching**
  - Duplicate analysis results cached with `DUPLICATE_DETECT:` prefix
  - Separate from regular AI analysis cache
  - Parallel processing with configurable thread count
  - Visual progress showing cached vs analyzing files

#### Multi-Mode AI Analysis
- **Specialized Analysis Modes**
  - `smart`: Full analysis (content + motion + quality) - default
  - `content`: Focus on content type detection
  - `motion`: Focus on motion analysis and FPS optimization
  - `quality`: Focus on source quality analysis

- **Per-Video Quality Selection**
  - `--ai-auto-quality`: AI chooses different quality for each video
  - 4K sources → Max quality
  - Screen recordings → Medium quality (text-optimized)
  - Short clips → High quality
  - Long movies → Medium quality (balanced for size)

### 🎨 User Experience

#### Clickable Terminal Paths
- **Hyperlink Support** (Modern Terminals)
  - File paths become clickable in supported terminals
  - Click to open in system file manager
  - Works in: GNOME Terminal, kitty, iTerm2, Windows Terminal, Warp, Alacritty, Hyper
  - Graceful fallback to plain paths in unsupported terminals
  - Applied to: settings, logs, cache directory, training directory

#### Enhanced Progress Display
- **Accurate Progress Counters**
  - Shows only files needing analysis (not total files)
  - Example: "Processing 5/5" instead of "216/216" when 211 cached
  - Clear distinction between cached and analyzing
  - Real-time cache hit/miss statistics

- **Informative Pre-Scan Messages**
  ```
  📊 Found 216 GIF files (2.3GB total)
  💾 Cached: 211 files (instant load)
  ⚡ To analyze: 5 files (need MD5 calculation)
  ⏱️  Estimated time: ~1 minute
  ```

#### AI System Diagnostics
- **Comprehensive Status Display**
  - `./convert.sh --ai-status`: Full AI system overview
  - Shows: configuration, cache status, training data, generation number
  - Health monitoring with visual indicators (✓, ⚠️, ❌)
  - Cache hit rates and performance metrics
  - Clickable paths to all system files

### 📊 Performance Metrics

#### Benchmark Results
```
Operation                    | Before      | After (v2.0) | Improvement
-----------------------------|-------------|--------------|-------------
Duplicate scan (216 files)   | 8-12 min    | 5-10 sec     | 100x faster
Cache pre-scan (216 files)   | ~10 sec     | <1 sec       | 10x faster
Resume after Ctrl+C          | Start over  | Continue     | No waste
Re-run unchanged files       | Re-analyze  | Skip all     | ∞ speedup
Cache cleanup                | Manual      | Auto (7d)    | Set & forget
```

#### Memory & Storage
- Cache size optimization: 115KB → 181 bytes (99% reduction)
- Memory-efficient: Cache loads entirely into RAM (typically <1MB)
- Smart batching: Prevents memory exhaustion with large file counts
- Cleanup removes: deleted files, duplicates, old entries

### 🔧 Technical Changes

#### Code Statistics
- Total lines: 13,700+ (up from 10,000+)
- New functions added: 10+
- Cache system: Complete rewrite
- Process management: Enhanced cleanup and tracking

#### New Functions
- `init_ai_cache()`: Enhanced with periodic cleanup
- `cleanup_ai_cache()`: Deduplication + deleted file removal
- `make_clickable_path()`: Terminal hyperlink creation
- `validate_cache_index()`: Integrity checking
- `rebuild_cache_index()`: Corruption recovery
- `migrate_cache_format()`: Automatic format migration

#### Configuration
- `AI_CACHE_VERSION`: 2.0
- `AI_CACHE_MAX_AGE_DAYS`: 30 days
- `AI_CACHE_ENABLED`: true (default)
- `AI_GENERATION`: Tracks AI learning generation

### 📚 Documentation

#### README Updates
- Added "Latest Updates (Version 2.0)" section
- Added comprehensive "Smart Cache Management" section
- Added cache performance comparison table
- Added real-world scenario examples
- Updated architecture overview with v2.0 stats
- Added troubleshooting for cache issues

#### New Commands
```bash
./convert.sh --clean-cache    # Force cache cleanup
./convert.sh --ai-status      # Comprehensive AI diagnostics
```

### 🐛 Bug Fixes
- Fixed cache bloat from deleted files
- Fixed slow pre-scan with 200+ files
- Fixed re-analysis of unchanged files on every run
- Fixed duplicate entries in cache index
- Fixed interrupted scans not resuming properly

### ⚠️ Breaking Changes
- None - Fully backward compatible
- Old cache format (v1.0) automatically migrated to v2.0

---

## [1.0.0] - Previous Release

Initial release with:
- AI-powered content analysis
- Duplicate detection (4 levels)
- Parallel processing
- GPU acceleration support
- Interactive menu system
- Basic caching system

---

## Future Roadmap

### Planned Features
- [ ] Incremental cache updates (update only changed entries)
- [ ] Cache statistics dashboard
- [ ] Configurable cleanup interval
- [ ] Cache import/export for backup
- [ ] Real-time file system monitoring (inotify)
- [ ] Distributed cache for network shares
- [ ] Cache compression for very large datasets

---

**Note**: Version 2.0 represents a major performance upgrade while maintaining full backward compatibility. All existing settings and configurations continue to work without changes.
