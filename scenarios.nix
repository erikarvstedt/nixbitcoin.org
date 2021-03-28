{ pkgs, lib, scenarios }:
with lib;
rec {
  # Don't use the default test base scenario
  base = {};

  nixbitcoinorg = { config, ... }: {
    imports = [
      ./configuration.nix
      scenarios.regtestBase
      # Needed by regtestBase
      <nix-bitcoin/test/lib/test-lib.nix>
    ];

    # Improve eval performance by reusing pkgs
    nixpkgs.pkgs = pkgs;

    nix-bitcoin.generateSecrets = true;

    networking.nat.externalInterface = mkForce "eth0";

    # Disable ACME for local testing
    security.acme = mkForce {};
    services.nginx.virtualHosts."nixbitcoin.org" = {
      enableACME = mkForce false;
      forceSSL = mkForce false;
    };

    # When WAN is disabled, DNS bootstrapping slows down service startup by ~15 s.
    services.clightning.extraConfig = "disable-dns";

    # Disable clboss in offline mode until the delayed startup issue is fixed:
    # https://github.com/ZmnSCPxj/clboss/issues/49
    services.clightning.plugins.clboss.enable = mkIf config.test.noConnections (mkForce false);
  };

  nixbitcoinorg-container = {
    imports = [ nixbitcoinorg ];
    # This service fails if apparmor is not enabled in the host kernel
    security.apparmor.enable = mkForce false;
  };

  # Disable the hardened preset to improve VM performance
  nixbitcoinorg-non-hardened = {
    imports = [ nixbitcoinorg ];
    disabledModules = [ <nix-bitcoin/modules/presets/hardened.nix> ];
  };
}
