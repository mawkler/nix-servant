{
  description = "nix-serve binary caches between LAN machines, started on demand";

  # No inputs: the module builds with the system's own pkgs
  outputs = _: {
    nixosModules.default =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        cfg = config.services.nix-servant;
        port = toString config.services.nix-serve.port;
        # The full path, so it matches the `passwordless` sudo rule exactly
        systemctl = "${config.systemd.package}/bin/systemctl";
        cacheUrls = map (host: "http://${host}.local:${port}") (
          lib.filter (host: host != config.networking.hostName) cfg.hosts
        );

        # `nix-servant serve`/`stop` toggles this host's cache. `nix-servant dine`
        # opens a shell (or runs a command) that uses the caches of the hosts that are up.
        # `stop` inside that shell leaves it instead
        nix-servant =
          pkgs.writers.writeFishBin "nix-servant" # fish
            ''
              switch "$argv[1]"
                  case serve
                      sudo ${systemctl} start nix-serve && echo "Serving http://${config.networking.hostName}.local:${port}"
                  case stop
                      if set -q NIX_SERVANT_DINER
                          # A child can't change its parent shell's env, so end the dine shell
                          kill -HUP $NIX_SERVANT_DINER && echo "Stopped dining"
                      else
                          sudo ${systemctl} stop nix-serve
                      end
                  case dine
                      for url in ${toString cacheUrls}
                          if ${lib.getExe pkgs.curl} --silent --fail --max-time 2 $url/nix-cache-info >/dev/null
                              set -a urls $url
                          end
                      end
                      if not set -q urls[1]
                          echo "No binary cache is up, tried: ${toString cacheUrls}" >&2
                          exit 1
                      end
                      echo "Using binary caches: $urls"
                      # Picked up by every `nix` command, which forwards it to the daemon
                      set -gx NIX_CONFIG "extra-substituters = $urls"
                      # `exec` keeps the PID, so this is the PID of the dine shell or command
                      set -gx NIX_SERVANT_DINER $fish_pid
                      if set -q argv[2]
                          exec $argv[2..]
                      else
                          exec $SHELL
                      end
                  case '*'
                      echo "Usage: nix-servant serve | stop | dine [command...]" >&2
                      exit 1
              end
            '';
      in
      {
        options.services.nix-servant = {
          enable = lib.mkEnableOption "nix-serve binary caches between LAN machines, started on demand";
          hosts = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Hostnames of all the machines, reached as `<host>.local`. This one is skipped";
          };
          passwordless = lib.mkEnableOption "`nix-servant serve`/`stop` without a password, for users in `wheel`";
        };

        config = lib.mkIf cfg.enable {
          # Server. Off by default; toggled with `nix-servant serve`/`stop`
          services.nix-serve = {
            enable = true;
            openFirewall = true;
            # A faster drop-in replacement. Override with `services.nix-serve.package`
            package = lib.mkDefault pkgs.nix-serve-ng;
            # Override with `services.nix-serve.secretKeyFile`
            secretKeyFile = lib.mkDefault "/etc/nix/cache.sec";
          };

          # Don't start nix-serve at boot
          systemd.services.nix-serve.wantedBy = lib.mkForce [ ];

          # So hosts can reach each other via `<hostname>.local`. A default, so it
          # can be turned off where something else handles mDNS
          services.avahi = {
            enable = lib.mkDefault true;
            nssmdns4 = true;
          };

          environment.systemPackages = [ nix-servant ];

          # Lets `wheel` run exactly `systemctl start/stop nix-serve` as root without a password.
          # Set for both sudo implementations, since only the enabled one reads its rules
          security =
            let
              rules = lib.mkIf cfg.passwordless [
                {
                  groups = [ "wheel" ];
                  commands =
                    map
                      (verb: {
                        command = "${systemctl} ${verb} nix-serve";
                        options = [ "NOPASSWD" ];
                      })
                      [
                        "start"
                        "stop"
                      ];
                }
              ];
            in
            {
              sudo.extraRules = rules;
              sudo-rs.extraRules = rules;
            };

          # Client. Opt-in with `nix-servant dine`, since the other hosts are usually off
          nix.settings.trusted-substituters = cacheUrls;
        };
      };
  };
}
