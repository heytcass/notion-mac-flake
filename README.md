# Notion Desktop for NixOS

A Nix flake that packages the official Notion desktop app for Linux by extracting and adapting the Mac version. Features full MCP (Model Context Protocol) integration and native dark mode support.

## Features

- ✅ **Official Notion App** - Extracted from the authentic Mac DMG release
- ✅ **Full MCP Integration** - Works seamlessly with Claude for AI-powered workflows  
- ✅ **Native Linux Compatibility** - Custom Rust-based SQLite stub for cross-platform support
- ✅ **Authentic Icon** - Properly extracted from Mac .icns with all standard sizes
- ✅ **Comprehensive Dark Mode** - Smart system theme detection and native dark UI
- ✅ **Wayland & X11 Support** - Works on both display servers
- ✅ **NixOS Integration** - Declarative installation and configuration

## Quick Start

### Using the Flake Directly

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    notion-desktop = {
      url = "github:heytcass/notion-mac-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, notion-desktop, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Your existing configuration
        {
          environment.systemPackages = [
            notion-desktop.packages.x86_64-linux.default
          ];
        }
      ];
    };
  };
}
```

### With Home Manager

```nix
home.packages = [
  inputs.notion-desktop.packages.${pkgs.system}.default
];
```

### Building Manually

```bash
nix build github:heytcass/notion-mac-flake
./result/bin/notion-desktop
```

## How It Works

This flake takes a unique approach to running Notion on Linux:

1. **Official Mac Extraction** - Downloads and extracts the authentic Mac Notion.app bundle
2. **Cross-Platform Adaptation** - Replaces Mac-native modules with Linux-compatible alternatives
3. **SQLite Stub** - Custom Rust implementation using NAPI-RS that provides the exact better-sqlite3 API
4. **Smart Theming** - Detects system dark mode preferences and applies them to all UI elements

## Technical Details

### Architecture

- **Base**: Official Notion 4.16.0 Mac release
- **Runtime**: Electron with Linux-native modules  
- **SQLite**: Custom Rust stub implementing better-sqlite3 API
- **Icons**: Extracted from Mac .icns using libicns
- **Theming**: Dynamic dark mode detection with GTK/Qt integration

### SQLite Compatibility

The custom SQLite stub provides:
- Full better-sqlite3 API compatibility
- Proper error handling and logging
- Transaction support (BEGIN/COMMIT/ROLLBACK)
- Schema introspection capabilities
- Graceful fallback for unsupported operations

### Dark Mode Features

- System theme detection via gsettings
- Native Electron dark mode (`--force-dark-mode`)
- GTK application theming integration
- Qt styling with Adwaita-Dark
- Dynamic switching without restart

## Requirements

- **NixOS** or **Nix** with flakes enabled
- **x86_64-linux** or **aarch64-linux** architecture
- Desktop environment (for optimal theming)

## MCP Integration

This package provides a true desktop Notion client that works with:
- Claude's MCP file system integration
- Home Assistant MCP servers
- Custom MCP server implementations
- Any MCP-compatible AI tools

## Contributing

Contributions welcome! This project demonstrates:
- Advanced Nix flake patterns
- Cross-platform Electron app packaging
- Rust FFI with Node.js via NAPI-RS
- macOS to Linux application porting techniques

## License

This flake is MIT licensed. Note that Notion itself remains proprietary software owned by Notion Labs, Inc.

## Acknowledgments

- Inspired by the [Claude Desktop Linux flake](https://github.com/heytcass/claude-desktop-linux-flake)
- Built with the amazing NixOS ecosystem
- SQLite stub powered by [NAPI-RS](https://napi.rs/)