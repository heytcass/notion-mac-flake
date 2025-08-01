{
  lib,
  stdenvNoCC,
  fetchurl,
  electron,
  p7zip,
  makeDesktopItem,
  makeWrapper,
  copyDesktopItems,
  undmg,
  rustPlatform,
  nodejs,
  imagemagick,
  fontconfig,
  dejavu_fonts,
  libicns,
  curl,
}: let
  pname = "notion-desktop";
  version = "4.16.0";
  
  # Pre-fetched official Notion icon
  notionIcon = fetchurl {
    url = "https://upload.wikimedia.org/wikipedia/commons/4/45/Notion_app_logo.png";
    sha256 = "1gnm4ib1i30winhz4qhpyx21syp9ahhwdj3n1l7345l9kmjiv06s";
  };
  
  srcDmg = fetchurl {
    url = "https://desktop-release.notion-static.com/Notion-${version}-universal.dmg";
    hash = "sha256-rcJo3eF5w3k1PME/Cv7NNdbKDs0iCkBh6CGtNSGnyCs=";
  };

  # Build SQLite stub in Rust using NAPI-RS
  sqliteStub = rustPlatform.buildRustPackage {
    pname = "sqlite-stub";
    version = "0.1.0";
    src = ../sqlite-stub;
    cargoHash = "sha256-mxcBuomRiIz7lq9i+G2hCrJ9Ddi1AlxDS7mxe8PXCRs=";
    
    nativeBuildInputs = [nodejs];
    
    buildPhase = ''
      export CARGO_TARGET_DIR=$PWD/target
      cargo build --release --target=x86_64-unknown-linux-gnu
    '';
    
    installPhase = ''
      mkdir -p $out/lib
      cp target/x86_64-unknown-linux-gnu/release/libsqlite_stub.so $out/lib/better_sqlite3.node
    '';
  };

  desktopItem = makeDesktopItem {
    name = "Notion";
    exec = "notion-desktop %u";
    icon = "notion";
    type = "Application";
    terminal = false;
    desktopName = "Notion";
    genericName = "Notion Desktop";
    comment = "Write, plan, share. With AI at your side.";
    startupWMClass = "Notion";
    startupNotify = true;
    categories = [
      "Office"
      "Utility"
      "Network"
      "TextEditor"
    ];
    mimeTypes = ["x-scheme-handler/notion"];
  };
in
stdenvNoCC.mkDerivation rec {
  inherit pname version;

  src = ./.;

  nativeBuildInputs = [
    undmg
    makeWrapper
    copyDesktopItems
    p7zip  # For additional extraction if needed
    imagemagick  # For icon conversion
    fontconfig  # For font configuration
    libicns  # For .icns file extraction
    curl  # For downloading official icon
  ];

  buildInputs = [
    dejavu_fonts  # For fallback icon text rendering
  ];

  desktopItems = [ desktopItem ];

  buildPhase = ''
    runHook preBuild

    # Create temp working directory
    mkdir -p $TMPDIR/build
    cd $TMPDIR/build

    # Extract DMG
    echo "Extracting DMG..."
    undmg ${srcDmg}
    
    # List contents to see structure
    echo "DMG contents:"
    find . -name "*.app" -type d
    
    # Find the Notion.app bundle
    NOTION_APP=$(find . -name "Notion.app" -type d | head -1)
    if [ -z "$NOTION_APP" ]; then
      echo "ERROR: Could not find Notion.app bundle!"
      exit 1
    fi
    
    echo "Found Notion app at: $NOTION_APP"
    
    # Copy the app bundle
    cp -r "$NOTION_APP" notion-app/
    
    # Examine the app structure and look for icons
    echo "App bundle structure:"
    ls -la notion-app/Contents/
    
    echo "Looking for icon files:"
    find notion-app/ -name "*.icns" -o -name "*.png" -o -name "*.ico" | head -10
    
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Create directories
    mkdir -p $out/lib/$pname $out/bin

    # Install the essential Electron app files
    cp -r $TMPDIR/build/notion-app/Contents/Resources/app.asar $out/lib/$pname/
    cp -r $TMPDIR/build/notion-app/Contents/Resources/app.asar.unpacked $out/lib/$pname/
    
    # Replace the Mac SQLite native module with our Linux-native Rust stub
    mkdir -p $out/lib/$pname/app.asar.unpacked/node_modules/better-sqlite3/build/Release
    cp ${sqliteStub}/lib/better_sqlite3.node $out/lib/$pname/app.asar.unpacked/node_modules/better-sqlite3/build/Release/
    
    # Create package.json to match original structure
    cat > $out/lib/$pname/app.asar.unpacked/node_modules/better-sqlite3/package.json << 'EOF'
{
  "name": "better-sqlite3",
  "version": "9.0.0",
  "main": "lib/index.js"
}
EOF
    
    # Copy other resources that might be needed
    cp $TMPDIR/build/notion-app/Contents/Resources/app-update.yml $out/lib/$pname/ || true
    
    # Create a minimal package.json to help the app identify itself
    cat > $out/lib/$pname/package.json <<EOF
{
  "name": "notion-desktop",
  "productName": "Notion",
  "version": "${version}",
  "main": "app.asar",
  "description": "Notion Desktop App"
}
EOF

    # Create a smart dark mode detection script
    cat > $out/lib/$pname/detect-dark-mode.sh << 'EOF'
#!/bin/bash
# Detect system dark mode preference from various sources

detect_dark_mode() {
  # Check GNOME/GTK settings first
  if command -v gsettings >/dev/null 2>&1; then
    GNOME_THEME=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null || echo "")
    if echo "$GNOME_THEME" | grep -qi dark; then
      return 0
    fi
    
    # Check color scheme preference (newer GNOME)
    COLOR_SCHEME=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || echo "default")
    if echo "$COLOR_SCHEME" | grep -qi dark; then
      return 0
    fi
  fi
  
  # Check environment variables
  if [ "$COLOR_SCHEME_PREFERENCE" = "dark" ] || [ "$GTK_APPLICATION_PREFER_DARK_THEME" = "1" ]; then
    return 0
  fi
  
  # Check current GTK theme
  if echo "\''${GTK_THEME:-}" | grep -qi dark; then
    return 0
  fi
  
  # Default to light mode
  return 1
}

# Set dark mode flags based on detection
if detect_dark_mode; then
  export ELECTRON_FORCE_DARK_MODE=1
  export ELECTRON_ENABLE_DARK_MODE=1
  export GTK_APPLICATION_PREFER_DARK_THEME=1
  export COLOR_SCHEME_PREFERENCE=dark
  DARK_MODE_FLAGS="--enable-features=WebUIDarkMode --force-dark-mode"
else
  export ELECTRON_FORCE_DARK_MODE=0
  export ELECTRON_ENABLE_DARK_MODE=0
  export COLOR_SCHEME_PREFERENCE=light
  DARK_MODE_FLAGS=""
fi

# Launch Electron with appropriate flags
exec ${electron}/bin/electron "$@" $DARK_MODE_FLAGS
EOF
    chmod +x $out/lib/$pname/detect-dark-mode.sh

    # Create wrapper script that uses our dark mode detection
    makeWrapper $out/lib/$pname/detect-dark-mode.sh $out/bin/$pname \
      --add-flags "$out/lib/$pname/app.asar" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}" \
      --add-flags "--no-sandbox" \
      --add-flags "--disable-web-security" \
      --add-flags "--disable-features=VizDisplayCompositor" \
      --add-flags "--disable-dev-shm-usage" \
      --add-flags "--disable-software-rasterizer" \
      --add-flags "--disable-extensions" \
      --add-flags "--disable-plugins" \
      --add-flags "--disable-background-timer-throttling" \
      --add-flags "--disable-backgrounding-occluded-windows" \
      --add-flags "--disable-renderer-backgrounding" \
      --set-default NIXOS_OZONE_WL "\''${WAYLAND_DISPLAY:+1}" \
      --set ELECTRON_OZONE_PLATFORM_HINT "auto" \
      --set-default GTK_THEME "\''${GTK_THEME:-Adwaita:dark}" \
      --set QT_STYLE_OVERRIDE "Adwaita-Dark" \
      --prefix XDG_DATA_DIRS : "$out/share" \
      --chdir "$out/lib/$pname" \
      --set-default NOTION_DATA_DIR "\''${XDG_CONFIG_HOME:-$HOME/.config}/Notion" \
      --set ELECTRON_ENABLE_LOGGING "1" \
      --set NOTION_DISABLE_SQLITE "1" \
      --set NOTION_WEB_ONLY "1" \
      --set NODE_SKIP_PLATFORM_CHECK "1" \
      --set ELECTRON_DISABLE_SECURITY_WARNINGS "1"

    # Extract and convert the icon from the Mac .icns file
    mkdir -p $out/share/icons/hicolor/{16x16,32x32,48x48,64x64,128x128,256x256,512x512}/apps
    
    # Use the pre-fetched official Notion icon
    echo "Using official Notion icon from ${notionIcon}"
    
    if [ -f "${notionIcon}" ]; then
      echo "Creating icons from official Notion logo"
      for size in 16 32 48 64 128 256 512; do
        magick "${notionIcon}" -resize ''${size}x''${size} "$out/share/icons/hicolor/''${size}x''${size}/apps/notion.png"
        echo "Created ''${size}x''${size} icon from official logo"
      done
    else
      # Fallback to extracting from .icns file
      echo "Official icon download failed, falling back to .icns extraction"
      
      # Find the main app icon (.icns file)
    echo "Searching for .icns files in Resources directory..."
    find $TMPDIR/build/notion-app/Contents/Resources -name "*.icns" -type f | while read -r icns; do
      echo "  Found: $icns ($(basename "$icns"))"
    done
    
    ICON_FILE=$(find $TMPDIR/build/notion-app/Contents/Resources -name "*.icns" | grep -v "document" | head -1)
    if [ -n "$ICON_FILE" ]; then
      echo "Selected icon file: $ICON_FILE"
      
      # Convert .icns to multiple PNG sizes using libicns
      echo "Extracting individual icon sizes from .icns file..."
      
      # Extract all available icons from the .icns file to current directory
      cd "$TMPDIR"
      icns2png -x "$ICON_FILE" 2>/dev/null || {
        echo "libicns extraction failed, trying ImageMagick..."
        magick "$ICON_FILE" -resize 512x512 "$TMPDIR/notion-icon-large.png" 2>/dev/null || {
          echo "Could not extract icon, will use fallback"
          ICON_FILE=""
        }
      }
      
      # Check if libicns extraction worked
      
      # Look for any extracted PNGs from the .icns file
      EXTRACTED_PNGS=$(find "$TMPDIR" -name "*.png" -type f 2>/dev/null | grep -v "notion-icon-large.png" || true)
      if [ -n "$EXTRACTED_PNGS" ]; then
        echo "Successfully extracted icons with libicns:"
        echo "$EXTRACTED_PNGS"
        # Find the largest available icon by file size
        LARGEST_ICON=$(ls -S $EXTRACTED_PNGS 2>/dev/null | head -1)
        echo "Using largest extracted icon: $LARGEST_ICON"
        # Create all standard sizes from the largest available
        for size in 16 32 48 64 128 256 512; do
          magick "$LARGEST_ICON" -resize ''${size}x''${size} "$out/share/icons/hicolor/''${size}x''${size}/apps/notion.png"
          echo "Created ''${size}x''${size} icon from extracted image"
        done
      elif [ -f "$TMPDIR/notion-icon-large.png" ]; then
        echo "Using ImageMagick extracted icon"
        for size in 16 32 48 64 128 256 512; do
          magick "$TMPDIR/notion-icon-large.png" -resize ''${size}x''${size} "$out/share/icons/hicolor/''${size}x''${size}/apps/notion.png"
          echo "Created ''${size}x''${size} icon"
        done
      else
        echo "All extraction methods failed, falling back to generated icon..."
      fi
    fi
    
    # Check if any real icon was created, if not create fallback
    if [ ! -f "$out/share/icons/hicolor/128x128/apps/notion.png" ]; then
      echo "Creating text-based fallback icons with font support..."
      
      # Set up font environment
      export FONTCONFIG_FILE=${fontconfig.out}/etc/fonts/fonts.conf
      export FONTCONFIG_PATH=${fontconfig.out}/etc/fonts
      mkdir -p $TMPDIR/fontconfig-cache
      export FONTCONFIG_CACHE_DIR=$TMPDIR/fontconfig-cache
      
      # Create a simple text-based fallback icon
      for size in 16 32 48 64 128 256 512; do
        echo "Creating ''${size}x''${size} fallback icon..."
        magick -size ''${size}x''${size} xc:'#2563eb' \
          -font DejaVu-Sans-Bold \
          -fill white \
          -gravity center \
          -pointsize $((''${size}/2)) \
          -annotate +0+0 'N' \
          "$out/share/icons/hicolor/''${size}x''${size}/apps/notion.png" || {
          echo "Font rendering failed, using geometric fallback"
          # Simple geometric fallback if font fails
          magick -size ''${size}x''${size} xc:'#2563eb' \
            -fill white \
            -draw "rectangle $((''${size}/6)),$((''${size}/6)) $((''${size}/3)),$((5*''${size}/6))" \
            -draw "rectangle $((2*''${size}/3)),$((''${size}/6)) $((5*''${size}/6)),$((5*''${size}/6))" \
            -draw "polygon $((''${size}/3)),$((''${size}/6)) $((2*''${size}/3)),$((5*''${size}/6)) $((2*''${size}/3)),$((''${size}/6)) $((''${size}/3)),$((5*''${size}/6))" \
            "$out/share/icons/hicolor/''${size}x''${size}/apps/notion.png"
        }
      done
    fi
    fi

    runHook postInstall
  '';

  dontUnpack = true;
  dontConfigure = true;

  meta = with lib; {
    description = "Notion Desktop from Official Mac Release";
    homepage = "https://www.notion.com";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    mainProgram = pname;
  };
}