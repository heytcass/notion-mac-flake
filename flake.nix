{
  description = "Notion Desktop from Official Mac Release";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }: flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system: let
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    packages = rec {
      notion-desktop = pkgs.callPackage ./pkgs/notion-desktop.nix {};
      notion-desktop-debug = pkgs.callPackage ./pkgs/notion-desktop-debug.nix {};
      default = notion-desktop;
    };
    
    devShells.default = pkgs.mkShell {
      packages = with pkgs; [
        rustc
        cargo
        nodejs
        nodePackages.npm
      ];
      
      shellHook = ''
        echo "🦀 Notion Desktop Development Shell"
        echo "Available: rustc, cargo, nodejs, npm"
      '';
    };
  });
}