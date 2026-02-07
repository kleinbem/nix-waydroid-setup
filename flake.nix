{
  description = "Waydroid Setup for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      perSystem = { pkgs, ... }:
        let
          sources = import ./sources.nix { inherit pkgs; };

          # Pre-built assets derivation
          assets = pkgs.stdenv.mkDerivation {
            name = "waydroid-assets";
            dontUnpack = true;
            dontBuild = true;
            dontConfigure = true;
            
            installPhase = ''
              mkdir -p $out/{system/etc/init,vendor,magisk}
              
              # Houdini (ARM translation)
              cp -rL ${sources.houdini}/prebuilts/* $out/system/
              chmod -R u+w $out/system/
              cp ${./assets/houdini.rc} $out/system/etc/init/houdini.rc
              
              # Widevine (DRM)
              cp -rL ${sources.widevine}/prebuilts/* $out/vendor/
              
              # Magisk Delta
              ${pkgs.unzip}/bin/unzip -q ${sources.magisk} -d $out/magisk
              cp ${sources.magisk} $out/magisk/magisk.apk
              cp ${./assets/bootanim.rc} $out/magisk/bootanim.rc
            '';
          };

          # Runtime deps for scripts
          runtimeDeps = with pkgs; [ coreutils util-linux e2fsprogs gnused gnugrep curl sqlite ];

          # Main install script with ASSETS substituted
          installScript = pkgs.writeShellApplication {
            name = "waydroid-setup";
            runtimeInputs = runtimeDeps;
            text = builtins.replaceStrings 
              [ ''ASSETS="''${ASSETS:-}"'' ] 
              [ ''ASSETS="${assets}"'' ]
              (builtins.readFile ./scripts/install.sh);
          };

          # Simple script wrappers
          getIdScript = pkgs.writeShellApplication {
            name = "waydroid-get-id";
            runtimeInputs = runtimeDeps;
            text = builtins.readFile ./scripts/get-id.sh;
          };

          statusScript = pkgs.writeShellApplication {
            name = "waydroid-status";
            runtimeInputs = runtimeDeps;
            text = builtins.readFile ./scripts/status.sh;
          };

          uninstallScript = pkgs.writeShellApplication {
            name = "waydroid-uninstall";
            runtimeInputs = runtimeDeps;
            text = builtins.readFile ./scripts/uninstall.sh;
          };

          updatePifScript = pkgs.writeShellApplication {
            name = "waydroid-update-pif";
            runtimeInputs = runtimeDeps;
            text = builtins.readFile ./scripts/update-pif.sh;
          };

          restartScript = pkgs.writeShellApplication {
            name = "waydroid-restart";
            runtimeInputs = runtimeDeps;
            text = builtins.readFile ./scripts/restart.sh;
          };
        in
        {
          packages = {
            default = installScript;
            install = installScript;
            get-id = getIdScript;
            status = statusScript;
            uninstall = uninstallScript;
            update-pif = updatePifScript;
            restart = restartScript;
            inherit assets;
          };

          devShells.default = pkgs.mkShell {
            packages = [ installScript pkgs.just pkgs.shellcheck ];
          };

          apps = {
            default = { type = "app"; program = "${installScript}/bin/waydroid-setup"; };
            get-id = { type = "app"; program = "${getIdScript}/bin/waydroid-get-id"; };
            status = { type = "app"; program = "${statusScript}/bin/waydroid-status"; };
            uninstall = { type = "app"; program = "${uninstallScript}/bin/waydroid-uninstall"; };
            update-pif = { type = "app"; program = "${updatePifScript}/bin/waydroid-update-pif"; };
            restart = { type = "app"; program = "${restartScript}/bin/waydroid-restart"; };
          };
        };

      flake = {
        nixosModules = {
          default = import ./nixos-module.nix { self = inputs.self; };
          waydroid = inputs.self.nixosModules.default;
        };
      };
    };
}
