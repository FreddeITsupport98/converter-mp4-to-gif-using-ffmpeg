# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Smart GIF Converter is an advanced, enterprise-grade video-to-GIF conversion tool built in Bash with comprehensive AI-powered analysis capabilities. It features intelligent optimization, robust error handling, multi-threading support, and a sophisticated interactive menu system.

## Core Architecture

### Main Components

- **convert.sh**: The primary executable (7,992 lines) containing all functionality
- **AI Analysis Engine**: Smart content detection and parameter optimization
- **Interactive Menu System**: Full-featured TUI with responsive design
- **Error Handling & Recovery**: Multi-level logging with automatic retry mechanisms
- **Parallel Processing**: CPU and GPU acceleration with intelligent resource management

### Key Subsystems

1. **Video Processing Pipeline**: FFmpeg-based two-pass conversion (palette generation → GIF creation)
2. **AI Content Analysis**: Multi-modal analysis (content type, motion complexity, visual complexity)  
3. **Resource Optimization**: CPU/GPU detection, RAM disk creation, memory-mapped caching
4. **Settings Management**: Persistent configuration with auto-save functionality
5. **Progress Tracking**: Real-time progress bars, conversion statistics, and session recovery

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

# AI & Performance
AI_ENABLED="false"          # Enable AI analysis
AI_MODE="smart"             # Analysis mode
FFMPEG_THREADS="auto"       # CPU threads for FFmpeg
PARALLEL_JOBS="auto"        # Concurrent conversions

# Optimization
AUTO_OPTIMIZE="true"        # Enable GIF optimization
OPTIMIZE_AGGRESSIVE="true"  # Aggressive compression
MAX_GIF_SIZE_MB="25"        # Size limit for output
```

### Critical Functions

1. **convert_video()** (Line 6673): Main conversion pipeline with error handling
2. **ai_smart_analyze()** (Line 525): AI content analysis and optimization
3. **show_main_menu()** (Line 4177): Interactive TUI system
4. **start_conversion()** (Line 5342): Batch processing controller
5. **detect_gpu_acceleration()** (Line 2543): Hardware acceleration setup

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
├── convert.sh              # Main executable (7,992 lines)
├── README.md               # User documentation
├── AI_COMPRESSION_FEATURE.md  # AI feature documentation
├── LICENSE                 # License file
└── ~/.smart-gif-converter/ # Runtime directory (created on first run)
    ├── settings.conf       # Persistent settings
    ├── errors.log          # Error tracking
    ├── conversions.log     # Conversion history
    ├── progress.save       # Session recovery data
    ├── temp_work/          # Temporary processing files
    └── ram_cache/          # RAM disk for high-performance systems
```

## Performance Notes

- Supports up to 16 parallel conversion jobs
- Automatic CPU core and RAM detection
- GPU acceleration for supported hardware (NVIDIA, AMD, Intel)
- RAM disk creation for ultra-fast temporary storage on high-memory systems
- Intelligent file caching and preloading for batch operations

## Special Considerations

- Script enforces Bash shell requirement (will not run in sh, zsh, or fish)
- Creates process groups for proper signal handling
- Single-instance locking prevents multiple concurrent runs  
- Comprehensive cleanup on exit (temp files, background processes)
- Settings automatically saved on any configuration change