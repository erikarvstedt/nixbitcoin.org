{ config, pkgs, lib, ... }: {
  imports = [
    <nix-bitcoin/modules/presets/secure-node.nix>
    ./nix-bitcoin-org
    ./hardware-configuration.nix
    <nix-bitcoin/modules/presets/hardened.nix>
  ];

  nix-bitcoin.onionServices.bitcoind.public = true;

  services.clightning = {
    enable = true;
    plugins.clboss.enable = true;
    extraConfig = ''
      alias=nixbitcoin.org
    '';
  };
  nix-bitcoin.onionServices.clightning.public = true;

  services.electrs.enable = true;

  services.btcpayserver = {
    enable = true;
    lightningBackend = "clightning";
  };
  nix-bitcoin.onionServices.btcpayserver.enable = true;

  nix-bitcoin.netns-isolation.enable = true;

  services.joinmarket = {
    enable = true;
    yieldgenerator.enable = true;
  }
  services.joinmarket-ob-watcher.enable = true;

  services.nix-bitcoin-org.enable = true;

  networking.hostName = "nixbitcoin-org";
  time.timeZone = "UTC";

  services.openssh.enable = true;
  users.users.root = {
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAO3kpItIalS3HHzqLRnXXFVRFtckuwE1FmytQ4HTh9u" ];
  };

  environment.systemPackages = with pkgs; [
    vim
  ];

  system.stateVersion = "20.09";

  nix-bitcoin.configVersion = "0.0.41";
}
