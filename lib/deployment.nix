{
  nix-bitcoin = {
    # TODO-EXTERNAL:
    # Migrate this to the default secrets dir after 2022-11-01
    secretsDir = "/var/src/secrets";
    setupSecrets = true;
  };

  # ../cmds/deploy-secrets can reset the secrets file permissions.
  # So force `setup-secrets.service` to restart on deployment.
  # Stop it at activation start so that it gets restarted at the end.
  system.activationScripts.nixBitcoinStopSetupSecrets = ''
    ${/* Skip this step if systemd is not running, i.e. when booting or in nixos-install */ ""}
    if [[ -e /run/systemd/system ]]; then
      if ! output=$(/run/current-system/systemd/bin/systemctl stop setup-secrets.service --no-block 2>&1); then
        # Ignore if the unit is not loaded, which can happen on the first deployment
        if [[ $output != *setup-secrets.service\ not\ loaded* ]]; then
          echo "$output"
          false
        fi
      fi
    fi
  '';
}
