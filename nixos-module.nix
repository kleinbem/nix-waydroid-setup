{ self }:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.waydroid-setup;
in
{
  options.programs.waydroid-setup = {
    enable = lib.mkEnableOption "Waydroid setup tools and system configuration";
    
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.system}.default;
      description = "The waydroid-setup package providing the bootstrap tool.";
    };
  };

  config = lib.mkIf cfg.enable {
    # System settings required for Waydroid to function
    virtualisation.waydroid.enable = lib.mkDefault true;
    virtualisation.lxc.enable = lib.mkDefault true;

    # Waydroid needs these kernel environment settings
    boot.kernelParams = [ "psi=1" ];
    boot.kernelModules = [ "uhid" "binder_linux" ];

    # Fix for waydroid0 bridge issues
    # Pre-creating the bridge ensures Waydroid starts reliably
    networking.bridges."waydroid0".interfaces = lib.mkDefault [ ];
    
    # Enable nftables by default as Waydroid works best with it now
    networking.nftables.enable = lib.mkDefault true;

    environment.systemPackages = [
      cfg.package
      self.packages.${pkgs.system}.get-id
      self.packages.${pkgs.system}.status
      self.packages.${pkgs.system}.uninstall
      self.packages.${pkgs.system}.update-pif
      self.packages.${pkgs.system}.restart
    ];
  };
}
