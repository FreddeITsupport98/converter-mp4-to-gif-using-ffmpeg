# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Smart GIF Converter is an advanced, enterprise-grade video-to-GIF conversion tool built in Bash with comprehensive AI-powered analysis capabilities. It features intelligent optimization, robust error handling, multi-threading support, and a sophisticated interactive menu system.

## Core Architecture

### Main Components

- **convert.sh**: The primary executable (8,500+ lines) containing all functionality
- **Advanced AI Analysis Engine**: Revolutionary multi-stage content detection with ML-inspired algorithms
- **AI-Powered Duplicate Detection**: 4-level similarity analysis with visual fingerprinting
- **Intelligent Quality Optimization**: Smart parameter selection based on video characteristics
- **Interactive Menu System**: Full-featured TUI with enhanced AI configuration options
- **Error Handling & Recovery**: Multi-level logging with automatic retry mechanisms
- **Parallel Processing**: CPU and GPU acceleration with AI-optimized resource management

### Key Subsystems

1. **Video Processing Pipeline**: FFmpeg-based two-pass conversion with AI-optimized parameters
2. **Advanced AI Analysis Engine**: 5-stage multi-modal analysis with ML-inspired scoring
3. **Revolutionary Duplicate Detection**: 4-level similarity analysis with visual fingerprinting
4. **Intelligent Scene Analysis**: Multi-threshold scene detection and transition analysis
5. **Smart Quality Optimization**: Dynamic parameter scaling based on content characteristics
6. **AI-Powered Quick Mode**: Automated quality selection with intelligent recommendations
7. **Resource Optimization**: CPU/GPU detection with AI-optimized threading and memory management
8. **Settings Management**: Enhanced configuration with 15+ AI-specific options
9. **Progress Tracking**: Real-time progress bars, AI decision logging, and session recovery

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
AI_AUTO_QUALITY="false"     # Let AI automatically select quality per video
AI_SCENE_ANALYSIS="true"    # Enable advanced scene detection
AI_VISUAL_SIMILARITY="true" # Enable visual similarity in duplicate detection
AI_SMART_CROP="true"        # Enable intelligent crop detection
AI_DYNAMIC_FRAMERATE="true" # Enable smart frame rate adjustment
AI_QUALITY_SCALING="true"   # Enable intelligent quality parameter scaling
AI_CONTENT_FINGERPRINT="true" # Enable content fingerprinting for duplicates

# Performance & Threading
FFMPEG_THREADS="auto"       # CPU threads for FFmpeg
PARALLEL_JOBS="auto"        # Concurrent conversions
AI_THREADS_OPTIMAL="auto"   # AI-optimized thread count
AI_MEMORY_OPT="auto"        # AI-optimized memory settings

# Optimization
AUTO_OPTIMIZE="true"        # Enable GIF optimization
OPTIMIZE_AGGRESSIVE="true"  # Aggressive compression
MAX_GIF_SIZE_MB="25"        # Size limit for output
```

### Critical Functions

1. **convert_video()** (Line ~7000): Main conversion pipeline with AI-enhanced error handling
2. **ai_smart_analyze()** (Line ~525): Revolutionary AI content analysis system
3. **detect_duplicate_gifs()** (Line ~1857): Advanced AI duplicate detection with 4-level similarity
4. **ai_quality_selection()** (Line ~967): Intelligent quality recommendation system
5. **show_main_menu()** (Line ~4177): Enhanced interactive TUI with AI configuration
6. **start_conversion()** (Line ~5342): AI-powered batch processing controller
7. **configure_ai_mode()** (Line ~5193): Comprehensive AI settings configuration

### New AI Functions

8. **ai_scene_detection()** (Line ~852): Advanced scene transition analysis
9. **ai_smart_framerate_adjustment()** (Line ~884): Dynamic frame rate optimization
10. **ai_intelligent_quality_scaling()** (Line ~933): Content-aware quality parameter scaling
11. **ai_enhanced_crop_detection()** (Line ~990): Intelligent crop detection with content awareness
12. **detect_content_type()** (Line ~636): ML-inspired content classification system

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
- **Duplicate Detection**: Verify 4-level similarity analysis with identical and near-identical files
- **Quality Selection**: Test AI recommendations with various video characteristics
- **Scene Analysis**: Validate scene detection with content having different transition patterns
- **Smart Crop**: Test crop detection with letterboxed and pillarboxed content
- **Frame Rate Optimization**: Verify dynamic FPS adjustment based on motion analysis
- **Visual Similarity**: Test perceptual hashing with resized/recompressed duplicates
- **Auto Quality Mode**: Validate per-video quality optimization in batch processing

```bash
# Test AI content analysis
./convert.sh --ai-enabled --ai-mode smart --file test_video.mp4

# Test duplicate detection with AI
./convert.sh --ai-enabled --file duplicate_test/

# Test AI quick mode
./convert.sh  # Select option 0 (Quick Mode), then option 5 (Let AI Decide)

# Test advanced AI configuration
./convert.sh  # Advanced Mode → AI Configuration (option 6)
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
├── convert.sh              # Main executable (8,500+ lines) with advanced AI
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
    └── duplicate_gifs/     # Backup folder for duplicate GIF management
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
