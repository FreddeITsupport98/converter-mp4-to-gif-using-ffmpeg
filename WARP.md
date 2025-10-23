# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Smart GIF Converter is an advanced, enterprise-grade video-to-GIF conversion tool built in Bash with comprehensive AI-powered analysis capabilities. It features intelligent optimization, robust error handling, multi-threading support, a sophisticated interactive menu system, AI generation tracking, intelligent caching with corruption protection, and clickable file paths for seamless file management.

## Core Architecture

### Main Components

- **convert.sh**: The primary executable (10,000+ lines) containing all functionality
- **Advanced AI Analysis Engine**: Revolutionary multi-stage content detection with ML-inspired algorithms and generation tracking
- **AI-Powered Duplicate Detection**: 4-level similarity analysis with visual fingerprinting and parallel processing
- **Intelligent Caching System**: Corruption-proof AI cache with atomic operations and automatic recovery
- **AI Training & Learning**: Persistent AI model with generation tracking and corruption protection
- **Intelligent Quality Optimization**: Smart parameter selection based on video characteristics
- **Interactive Menu System**: Full-featured TUI with enhanced AI configuration and diagnostics
- **Clickable File Management**: Terminal hyperlinks for seamless navigation to settings and logs
- **Error Handling & Recovery**: Multi-level logging with automatic retry mechanisms
- **Parallel Processing**: CPU and GPU acceleration with AI-optimized resource management

### Key Subsystems

1. **Video Processing Pipeline**: FFmpeg-based two-pass conversion with AI-optimized parameters
2. **Advanced AI Analysis Engine**: 5-stage multi-modal analysis with ML-inspired scoring and generation tracking
3. **Revolutionary Duplicate Detection**: 4-level similarity analysis with parallel visual fingerprinting
4. **Intelligent Caching System**: Corruption-proof cache with validation, atomic operations, and automatic recovery
5. **AI Training & Learning System**: Persistent model with generation tracking, corruption protection, and atomic updates
6. **Intelligent Scene Analysis**: Multi-threshold scene detection and transition analysis
7. **Smart Quality Optimization**: Dynamic parameter scaling based on content characteristics
8. **AI-Powered Quick Mode**: Automated quality selection with intelligent recommendations
9. **Comprehensive AI Diagnostics**: Full system status with clickable paths and health monitoring
10. **Resource Optimization**: CPU/GPU detection with AI-optimized threading and memory management
11. **Settings Management**: Enhanced configuration with 20+ AI-specific options and clickable file paths
12. **Progress Tracking**: Real-time progress bars, AI decision logging, generation display, and session recovery

## Common Development Tasks

### Build and Testing
```bash
# Make script executable
chmod +x convert.sh

# Test basic functionality
./convert.sh --help

# Run with single test video
./convert.sh --file example.mp4 --preset high

# Interactive mode for full testing
./convert.sh

# Test parallel processing
./convert.sh --parallel-jobs 4 --preset medium

# Debug mode for development
./convert.sh --debug --preset low

# Check AI system status
./convert.sh --ai-status

# Test AI cache and training systems
./convert.sh --ai --ai-mode smart
```

## How to Use

### Quick Start (Recommended)

```bash
# Make executable
chmod +x convert.sh

# Interactive mode with AI-powered quick conversion
./convert.sh
# Choose option 1: "🚀 AI-Powered Quick Mode"
# AI will analyze your videos and recommend optimal quality
```

### Command Line Usage

```bash
# Basic conversion with AI analysis
./convert.sh --ai --preset high

# Convert specific file with AI optimization
./convert.sh --file video.mp4 --ai-mode smart --preset medium

# Batch convert with parallel processing
./convert.sh --parallel-jobs 8 --ai --preset high

# Quick AI status check
./convert.sh --ai-status

# View all current settings (with clickable paths)
./convert.sh --show-settings

# View logs and diagnostics
./convert.sh --show-logs
```

### AI-Powered Features

#### 1. 🧠 Smart Analysis Modes
```bash
# Full AI analysis (recommended)
./convert.sh --ai --ai-mode smart

# Content-focused analysis
./convert.sh --ai --ai-mode content

# Motion-focused analysis  
./convert.sh --ai --ai-mode motion

# Quality-focused analysis
./convert.sh --ai --ai-mode quality
```

#### 2. 📊 AI System Diagnostics
```bash
# Comprehensive AI system status
./convert.sh --ai-status
# Shows: AI configuration, cache status, training data, generation tracking,
#        health checks, and clickable file paths

# Interactive AI diagnostics menu
./convert.sh
# Choose option 4: "🤖 AI System Status & Diagnostics"
```

#### 3. 🎯 Quality Selection Options
```bash
# Let AI automatically choose quality per video
./convert.sh --ai --ai-auto-quality

# Traditional presets
./convert.sh --preset low     # 480p, 8fps, optimized for size
./convert.sh --preset medium  # 720p, 12fps, balanced
./convert.sh --preset high    # 1080p, 15fps, recommended
./convert.sh --preset ultra   # 1440p, 20fps, high quality
./convert.sh --preset max     # 4K, 24fps, maximum quality
```

### Interactive Menu System

Run `./convert.sh` without arguments to access the full interactive menu:

```
🎯 MAIN MENU

1. 🚀 AI-Powered Quick Mode (Speed Optimized)
   → Just select quality - AI handles everything automatically
   
2. ⚙️ Configure Settings & Convert (Advanced) 
   → Fine-tune all 20+ settings for perfect control
   
3. 📊 View Conversion Statistics
   → View conversion history and success rates
   
4. 🤖 AI System Status & Diagnostics
   → Check AI cache, training data, health status (NEW!)
   
5. 📁 Manage Log Files
   → Manage error logs and conversion history (clickable paths)
   
6. 🔧 System Information
   → Check CPU, GPU, and system capabilities
   
7. 🔫 Kill FFmpeg Processes
   → Stop stuck or runaway processes safely
   
8. ❓ Help & Documentation
   → Complete usage guide with examples
```

### Advanced AI Configuration

Access via Interactive Menu → Advanced Mode → AI Configuration:

```
🎯 ANALYSIS MODES:
[1] 🧠 Smart Mode - Full AI analysis with all features
[2] 🎨 Content Mode - Focus on content type detection  
[3] 💪 Motion Mode - Focus on motion analysis and frame rate
[4] 💎 Quality Mode - Focus on quality optimization

🔧 ADVANCED FEATURES:
[5] 🎬 Scene Analysis: Advanced scene detection
[6] 👀 Visual Similarity: Visual similarity in duplicate detection
[7] ✂️ Smart Crop: Intelligent crop detection
[8] 📊 Dynamic Frame Rate: Smart FPS adjustment
[9] 🎨 Quality Scaling: Intelligent parameter scaling
[10] 🎯 Auto Quality: Per-video quality optimization
[11] 🔍 Content Fingerprint: Advanced duplicate fingerprinting
```

### Quality Presets
- **low**: 854x480, 8fps, 128 colors (small files, fast)
- **medium**: 1280x720, 12fps, 192 colors (balanced)  
- **high**: 1920x1080, 15fps, 256 colors (recommended default)
- **ultra**: 2560x1440, 20fps, 256 colors (high quality)
- **max**: 3840x2160, 24fps, 256 colors (maximum quality)

### AI Modes
- **smart**: Full analysis (content + motion + quality) - default
- **content**: Focus on content type detection (animation/movie/screencast/clip)
- **motion**: Focus on motion analysis and frame rate optimization
- **quality**: Focus on source quality analysis and preservation

## Key Configuration

### Settings Location
- Primary: `~/.smart-gif-converter/settings.conf`  
- Backup: `./gif-converter.conf`
- Logs: `~/.smart-gif-converter/` (errors.log, conversions.log)

### Important Variables
```bash
# Core quality settings
QUALITY="high"              # Preset level
RESOLUTION="1920:1080"      # Output resolution  
FRAMERATE="15"              # Target FPS
MAX_COLORS="256"            # GIF palette size
ASPECT_RATIO="16:9"         # Output aspect ratio

# Enhanced AI Configuration
AI_ENABLED="false"          # Enable AI analysis
AI_MODE="smart"             # Analysis mode (smart/content/motion/quality)
AI_GENERATION=1             # Current AI generation (increments with model rebuilds)
AI_AUTO_QUALITY="false"     # Let AI automatically select quality per video
AI_SCENE_ANALYSIS="true"    # Enable advanced scene detection
AI_VISUAL_SIMILARITY="true" # Enable visual similarity in duplicate detection
AI_SMART_CROP="true"        # Enable intelligent crop detection
AI_DYNAMIC_FRAMERATE="true" # Enable smart frame rate adjustment
AI_QUALITY_SCALING="true"   # Enable intelligent quality parameter scaling
AI_CONTENT_FINGERPRINT="true" # Enable content fingerprinting for duplicates

# AI Cache System
AI_CACHE_ENABLED=true       # Enable intelligent caching
AI_CACHE_VERSION="2.0"      # Cache version (increment to invalidate)
AI_CACHE_MAX_AGE_DAYS=30    # Cache entry expiration

# AI Training & Learning
AI_TRAINING_ENABLED=true    # Enable AI learning and training
AI_MODEL_VERSION="1.0"      # Model version
AI_LEARNING_RATE=0.1        # How quickly AI adapts
AI_CONFIDENCE_MIN=0.3       # Minimum confidence threshold
AI_TRAINING_MIN_SAMPLES=5   # Minimum samples before confident predictions

# Performance & Threading
FFMPEG_THREADS="auto"       # CPU threads for FFmpeg
PARALLEL_JOBS="auto"        # Concurrent conversions
AI_THREADS_OPTIMAL="auto"   # AI-optimized thread count
AI_MEMORY_OPT="auto"        # AI-optimized memory settings
AI_MAX_PARALLEL_JOBS=8      # Maximum AI parallel processing jobs
AI_DUPLICATE_THREADS=7      # Duplicate detection thread count
AI_ANALYSIS_BATCH_SIZE=8    # AI analysis batch processing size

# Optimization
AUTO_OPTIMIZE="true"        # Enable GIF optimization
OPTIMIZE_AGGRESSIVE="true"  # Aggressive compression
MAX_GIF_SIZE_MB="25"        # Size limit for output
```

### Critical Functions

1. **convert_video()** (Line ~9100): Main conversion pipeline with AI-enhanced error handling and generation display
2. **ai_smart_analyze()** (Line ~1578): Revolutionary AI content analysis system with caching
3. **detect_duplicate_gifs()** (Line ~3800): Advanced AI duplicate detection with 4-level similarity and parallel processing
4. **ai_quality_selection()** (Line ~2294): Intelligent quality recommendation system
5. **show_main_menu()** (Line ~6468): Enhanced interactive TUI with AI diagnostics menu
6. **start_conversion()** (Line ~5500): AI-powered batch processing controller
7. **configure_ai_mode()** (Line ~6907): Comprehensive AI settings configuration
8. **show_ai_status()** (Line ~1081): Comprehensive AI system diagnostics with clickable paths

### Latest AI Functions (v2024.10)

9. **make_clickable_path()** (Line ~1063): Terminal hyperlink creation for file management
10. **init_ai_cache()** (Line ~440): Corruption-proof AI cache initialization
11. **validate_cache_index()** (Line ~448): AI cache integrity validation
12. **save_ai_analysis_to_cache()** (Line ~580): Atomic cache operations
13. **init_ai_training()** (Line ~644): Corruption-proof AI training system initialization
14. **validate_ai_model()** (Line ~681): AI model integrity validation with generation loading
15. **rebuild_ai_model()** (Line ~724): AI model corruption recovery with generation increment
16. **atomic_update_model_entry()** (Line ~982): Atomic AI training data updates

### Core AI Analysis Functions

17. **ai_scene_detection()** (Line ~852): Advanced scene transition analysis
18. **ai_smart_framerate_adjustment()** (Line ~884): Dynamic frame rate optimization
19. **ai_intelligent_quality_scaling()** (Line ~933): Content-aware quality parameter scaling
20. **ai_enhanced_crop_detection()** (Line ~990): Intelligent crop detection with content awareness
21. **detect_content_type()** (Line ~636): ML-inspired content classification system
22. **analyze_motion_complexity()** (Line ~2800): Advanced motion analysis for FPS optimization

## Development Guidelines

### Error Handling
- All functions use `trace_function` for debugging
- Comprehensive logging to `~/.smart-gif-converter/errors.log`
- Automatic retry logic with exponential backoff
- Signal handling for graceful interruption (Ctrl+C)

### Process Management
- Process group isolation for clean termination
- Background job tracking in `SCRIPT_FFMPEG_PIDS` array
- Terminal binding for proper signal propagation
- Cleanup functions called on exit

### Code Organization
- Functions prefixed with emoji for visual organization
- Settings auto-saved on changes
- Responsive design for different terminal sizes
- Extensive input validation and sanitization

### Testing Considerations
- Test with various video formats (MP4, AVI, MOV, MKV, WebM)
- Verify FFmpeg and optional dependencies (gifsicle, jq)
- Test parallel processing with multiple CPU cores
- Validate interrupt handling and cleanup
- Check settings persistence across sessions

### AI System Testing
- **Content Detection**: Test with animation, screencast, movie, and clip content
- **Duplicate Detection**: Verify 4-level similarity analysis with parallel processing
- **Quality Selection**: Test AI recommendations with various video characteristics
- **Scene Analysis**: Validate scene detection with content having different transition patterns
- **Smart Crop**: Test crop detection with letterboxed and pillarboxed content
- **Frame Rate Optimization**: Verify dynamic FPS adjustment based on motion analysis
- **Visual Similarity**: Test perceptual hashing with resized/recompressed duplicates
- **Auto Quality Mode**: Validate per-video quality optimization in batch processing
- **AI Cache System**: Test corruption detection, recovery, and atomic operations
- **AI Training System**: Verify generation tracking, model persistence, and corruption protection
- **AI Diagnostics**: Test comprehensive status display and clickable file paths
- **Generation Tracking**: Verify AI generation increments on model rebuilds

```bash
# Test AI content analysis with caching
./convert.sh --ai-enabled --ai-mode smart --file test_video.mp4

# Test comprehensive AI diagnostics
./convert.sh --ai-status

# Test AI diagnostics in interactive mode
./convert.sh  # Select option 4 (AI System Status & Diagnostics)

# Test duplicate detection with parallel processing
./convert.sh --ai-enabled --file duplicate_test/

# Test AI generation tracking
./convert.sh --ai  # Check generation display during conversion

# Test clickable paths (in supported terminals)
./convert.sh --show-settings  # Click on file paths to open locations
./convert.sh --show-logs       # Click on log paths
./convert.sh --ai-status       # Click on AI system paths

# Test AI quick mode with generation display
./convert.sh  # Select option 1 (Quick Mode), then option 5 (Let AI Decide)

# Test advanced AI configuration
./convert.sh  # Advanced Mode → AI Configuration (option 6)

# Test AI cache corruption recovery
# (Manually corrupt cache file, then run AI analysis - should auto-recover)

# Test AI model corruption recovery
# (Manually corrupt model file, then run AI training - should increment generation)
```

## Dependencies

### Required
- **FFmpeg** (>=4.0): Core video processing
- **FFprobe**: Video analysis (included with FFmpeg)
- **Bash** (>=4.0): Shell interpreter with associative arrays

### Optional
- **gifsicle**: GIF optimization and compression
- **jq**: Enhanced JSON processing for auto-detection
- **bc**: Floating-point calculations
- **numfmt**: Human-readable file sizes

## File Structure

```
converter-mp4-to-gif-using-ffmpeg/
├── convert.sh              # Main executable (10,000+ lines) with advanced AI
├── README.md               # User documentation
├── AI_COMPRESSION_FEATURE.md  # AI feature documentation
├── WARP.md                 # Development guidance (this file)
├── LICENSE                 # License file
└── ~/.smart-gif-converter/ # Runtime directory (created on first run)
    ├── settings.conf       # Persistent settings with AI configuration
    ├── errors.log          # Error tracking with AI decision logging
    ├── conversions.log     # Conversion history with AI analysis results
    ├── progress.save       # Session recovery data
    ├── temp_work/          # Temporary processing files
    ├── ram_cache/          # RAM disk for high-performance systems
    ├── duplicate_gifs/     # Backup folder for duplicate GIF management
    ├── ai_cache/           # AI analysis cache system (NEW!)
    │   ├── analysis_cache.db   # Cached AI analysis results with corruption protection
    │   ├── analysis_cache.db.safe  # Cache backup
    │   └── cache_data/         # Individual cached analysis files
    └── ai_training/        # AI training and learning system (NEW!)
        ├── smart_model.db      # AI training model with generation tracking
        ├── smart_model.db.safe # Model backup
        ├── training_history.log # AI training session log
        └── training_history.log.safe # Training log backup
```

## AI System Overview

### Revolutionary AI Features

#### 1. 🧠 **Advanced Content Analysis**
- **5-Stage Analysis**: Visual patterns, edge detection, color complexity, motion vectors, frame consistency
- **ML-Inspired Scoring**: Weighted algorithms classify content as animation, screencast, movie, or clip
- **Smart Heuristics**: Confidence-based fallback ensures accurate detection even with challenging content
- **Content-Aware Optimization**: Different parameter sets optimized for each content type

#### 2. 🔍 **Revolutionary Duplicate Detection**
- **Level 1**: Exact binary match (100% confidence) - traditional MD5 checksum
- **Level 2**: Visual similarity (high confidence) - perceptual hashing of key frames
- **Level 3**: Content fingerprint (medium confidence) - frame count, duration, FPS, resolution analysis
- **Level 4**: Near-identical detection (manual review) - size ratio validation with smart thresholds
- **Smart Cleanup Options**: Delete duplicates, smart delete (with source videos), backup, or interactive review

#### 3. ⚡ **AI-Powered Quick Mode**
- **Pre-Analysis**: Examines your videos before asking for input
- **Intelligent Recommendations**: Suggests optimal quality based on video characteristics
- **Auto-Quality Mode**: Let AI automatically select different quality settings per video
- **Context-Aware**: Considers file size, resolution, duration, and bitrate for recommendations

#### 4. 🎬 **Advanced Scene Analysis**
- **Multi-Threshold Detection**: Major and minor scene changes with configurable sensitivity
- **Frame Consistency Analysis**: Optimal frame rate calculation based on temporal patterns
- **Static Region Detection**: Identifies low-motion areas for size optimization
- **Scene Density Calculation**: Quantifies visual complexity for parameter adjustment

#### 5. 📊 **Smart Parameter Optimization**
- **Dynamic Frame Rate**: Adjusts FPS based on motion level and scene complexity
- **Intelligent Color Scaling**: Selects optimal palette size based on visual complexity
- **Content-Aware Scaling**: Chooses best scaling algorithm (lanczos/bicubic/neighbor) per content type
- **Smart Crop Detection**: Content-type specific crop strategies with consistency validation

### AI Configuration Menu
Access via Advanced Mode → AI Configuration (option 6):

```
🎯 ANALYSIS MODES:
[1] 🧠 Smart Mode - Full AI analysis with all features
[2] 🎨 Content Mode - Focus on content type detection  
[3] 💪 Motion Mode - Focus on motion analysis and frame rate
[4] 💎 Quality Mode - Focus on quality optimization and scaling

🔧 ADVANCED FEATURES:
[5] 🎬 Scene Analysis: Enable/disable advanced scene detection
[6] 👀 Visual Similarity: Enable/disable visual similarity in duplicates
[7] ✂️ Smart Crop: Enable/disable intelligent crop detection
[8] 📊 Dynamic Frame Rate: Enable/disable smart FPS adjustment
[9] 🎨 Quality Scaling: Enable/disable intelligent parameter scaling

🤖 AI AUTO FEATURES:
[10] 🎯 Auto Quality: Enable per-video quality optimization
[11] 🔍 Content Fingerprint: Enable advanced duplicate fingerprinting
```

## Performance Notes

- Supports up to 16 parallel conversion jobs with AI load balancing
- Automatic CPU core and RAM detection with AI-optimized threading
- GPU acceleration for supported hardware (NVIDIA, AMD, Intel)
- RAM disk creation for ultra-fast temporary storage on high-memory systems
- Intelligent file caching and preloading for batch operations
- **AI Performance**: Multi-stage analysis adds ~10-30% processing time but significantly improves output quality
- **Smart Caching**: AI decisions cached per video to avoid re-analysis during retries
- **Optimized Analysis**: Scene detection and content analysis use optimized sampling to minimize overhead
- **Memory Efficient**: Temporary files for visual analysis automatically cleaned up
- **Scalable**: AI features gracefully degrade on lower-spec systems

## Special Considerations

- Script enforces Bash shell requirement (will not run in sh, zsh, or fish)
- Creates process groups for proper signal handling
- Single-instance locking prevents multiple concurrent runs  
- Comprehensive cleanup on exit (temp files, background processes, AI temp analysis files)
- Settings automatically saved on any configuration change, including AI feature toggles

### AI-Specific Considerations

- **Dependency**: AI features require FFmpeg with full codec support for optimal analysis
- **Temporary Storage**: AI analysis creates temporary files in system temp directory (auto-cleaned)
- **Processing Time**: Content analysis adds overhead but dramatically improves conversion quality
- **Memory Usage**: Visual similarity analysis may use additional RAM for frame processing
- **Backwards Compatibility**: All AI features can be disabled; script maintains full compatibility
- **Error Resilience**: AI analysis failures gracefully fall back to traditional processing
- **Logging**: AI decisions and confidence scores logged for debugging and optimization
- **Signal Handling**: AI analysis processes properly handle interruption signals
- **File Safety**: Duplicate detection includes multiple safety checks to prevent accidental deletions

## Latest AI Features (October 2024)

### 🤖 AI Generation Tracking
- **Generation Counter**: Tracks AI learning generations (increments on model rebuilds)
- **Persistent Tracking**: Generation number saved in settings and model files
- **Visual Display**: Shows "Using AI generation: X" during conversions
- **Status Integration**: Generation displayed in AI diagnostics menu

### 💾 Intelligent Caching System
- **Corruption Protection**: Validates cache integrity before use
- **Atomic Operations**: Uses temporary files and atomic moves for cache updates
- **Automatic Recovery**: Rebuilds corrupted cache automatically
- **Performance**: Dramatically speeds up repeated AI analysis
- **Version Control**: Cache versioning prevents compatibility issues

### 🎓 AI Training & Learning
- **Persistent Model**: AI learns from successful conversions
- **Generation Tracking**: Model rebuilds increment generation counter
- **Corruption Recovery**: Automatic model validation and rebuild
- **Atomic Updates**: Training data updates use atomic operations
- **Confidence Scoring**: AI decisions improve with more training data

### 🔗 Clickable File Paths
- **Terminal Hyperlinks**: File paths become clickable in modern terminals
- **File Manager Integration**: Click to open in system file manager
- **Universal Support**: Works in GNOME Terminal, kitty, iTerm2, Windows Terminal, Warp, etc.
- **Graceful Fallback**: Shows full paths in unsupported terminals
- **Location Display**: Applied to settings, logs, cache, and training directories

### 📊 Comprehensive AI Diagnostics
- **Full System Status**: Complete overview of all AI subsystems
- **Health Monitoring**: Automatic detection of corruption or issues
- **Performance Metrics**: CPU utilization, thread allocation, cache hit rates
- **Clickable Paths**: Direct navigation to AI system files
- **Real-time Information**: Live status updates and file modification times

### 🚀 Enhanced User Experience
- **Interactive Diagnostics**: New "AI System Status & Diagnostics" menu option
- **Command Line Access**: `--ai-status` flag for quick system checks
- **Helpful Tips**: Contextual tips about AI system usage
- **Visual Indicators**: Clear status icons (✓, ⚠️, ❌) for quick assessment
- **Integration**: Seamlessly integrated into existing menu system
