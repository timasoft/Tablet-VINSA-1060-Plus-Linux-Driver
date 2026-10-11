{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    naersk.url  = "github:nix-community/naersk";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, naersk, flake-utils, ... }:
    let
      baseModule = import ./nix/nixos-module.nix;
    in
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
      naerskLib = pkgs.callPackage naersk {};
      rustSrc = pkgs.rust.packages.stable.rustPlatform.rustLibSrc;

      v1060p = naerskLib.buildPackage {
        name = "v1060p";
        src = ./.;

        buildInputs = with pkgs; [ libusb1 ];
        nativeBuildInputs = with pkgs; [ pkg-config ];
      };
    in {
      packages.default = v1060p;
      packages.v1060p = v1060p;

      defaultPackage = v1060p;

      devShells.default = pkgs.mkShell {
        inputsFrom = [ v1060p ];
        packages = with pkgs; [
          cargo rustc rustfmt clippy rust-analyzer
          fish
        ];
        nativeBuildInputs = [ pkgs.pkg-config ];

        shellHook = ''
          if [ -z "$FISH_VERSION" ] && [ -z "$NO_AUTO_FISH" ] && [ -t 0 ]; then
            exec ${pkgs.fish}/bin/fish
          fi
        '';

        RUST_SRC_PATH = "${rustSrc}";
      };
    })
    // {
      nixosModules.vinsa-tablet-base = baseModule;

      nixosModules.vinsa-tablet = { config, lib, pkgs, ... }: {
        imports = [ baseModule ];
        services.vinsa-tablet.package = lib.mkDefault (
          self.packages.${pkgs.stdenv.hostPlatform.system}.default
        );
      };

      nixosModule = self.nixosModules.vinsa-tablet;
    };
}
