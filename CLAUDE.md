# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Nix flake that packages the official Notion desktop app for Linux by extracting and adapting the Mac version. The project creates a native Linux desktop application with full MCP (Model Context Protocol) integration and native dark mode support.

## Architecture

### Core Components

1. **Nix Flake (`flake.nix`)** - Main package definition and development shell
2. **Notion Package (`pkgs/notion-desktop.nix`)** - Complex derivation that:
   - Downloads and extracts the official Mac Notion DMG (version 4.16.0)
   - Replaces Mac-native SQLite module with custom Rust stub
   - Implements smart dark mode detection via shell script
   - Creates proper Linux desktop integration with icons and MIME types
3. **SQLite Stub (`sqlite-stub/`)** - Rust-based NAPI module that provides better-sqlite3 API compatibility

### Key Technical Details

- **Base Application**: Official Notion 4.16.0 Mac release extracted from DMG
- **Cross-Platform Compatibility**: Custom Rust SQLite stub replaces Mac-native better-sqlite3 module
- **Icon Extraction**: Uses libicns to convert Mac .icns files to standard Linux PNG icons
- **Dark Mode**: Intelligent system theme detection supporting GNOME/GTK preferences
- **Desktop Integration**: Full .desktop file with MIME type handlers for notion:// URLs

## Development Commands

### Building the Package
```bash
# Build the main package
nix build

# Build and run directly
nix run

# Build from GitHub (for testing)
nix build github:heytcass/notion-mac-flake
```

### Development Environment
```bash
# Enter development shell with Rust, Node.js, and other tools
nix develop

# In dev shell, build SQLite stub manually:
cd sqlite-stub
cargo build --release
```

### SQLite Stub Development
The `sqlite-stub/` directory contains a Rust crate using NAPI-RS that mimics the better-sqlite3 API:
```bash
# Build the Rust stub
cd sqlite-stub
cargo build --release

# The output goes to target/release/libsqlite_stub.so
# Which gets renamed to better_sqlite3.node in the final package
```

## Architecture Notes

- The package extracts the entire Mac Notion.app bundle but only uses `app.asar` and `app.asar.unpacked`
- SQLite functionality is stubbed out since Notion primarily uses web APIs
- Dark mode detection script (`detect-dark-mode.sh`) runs before Electron launch
- Wrapper script handles Wayland/X11 compatibility and Electron flags
- Icon conversion supports fallback to generated icons if extraction fails

## File Structure

- `flake.nix` - Main flake with package and devShell definitions
- `pkgs/notion-desktop.nix` - Main package derivation (300+ lines)
- `sqlite-stub/` - Rust crate for SQLite API compatibility
  - `src/lib.rs` - NAPI bindings for Database and Statement structs
  - `Cargo.toml` - Rust package definition
- `package.json` - Minimal Node.js package metadata for the final app

## Testing

No formal test suite exists. Testing is done by:
1. Building the package: `nix build`
2. Running the result: `./result/bin/notion-desktop`
3. Verifying the app launches and basic functionality works

## Platform Support

- **Supported**: x86_64-linux, aarch64-linux
- **Desktop Environments**: GNOME, KDE, and others with GTK/Qt theming
- **Display Servers**: Both Wayland and X11 supported