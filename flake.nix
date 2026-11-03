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
        cacheUrls = map (host: "http://${host}.local:${port}") (
          lib.filter (host: host != config.networking.hostName) cfg.hosts
        );

        # `nix-servant serve`/`stop` toggles this host's cache. `nix-servant client`
        # opens a shell (or runs a command) that uses the caches of the hosts that are up
        nix-servant =
          pkgs.writers.writeFishBin "nix-servant" # fish
            ''
              switch "$argv[1]"
                  case serve
                      sudo systemctl start nix-serve && echo "Serving http://${config.networking.hostName}.local:${port}"
                  case stop
                      sudo systemctl stop nix-serve
                  case client
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
                      if set -q argv[2]
                          exec $argv[2..]
                      else
                          exec $SHELL
                      end
                  case '*'
                      echo "Usage: nix-servant serve | stop | client [command...]" >&2
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
        };

        config = lib.mkIf cfg.enable {
          # Server. Off by default; toggled with `nix-servant serve`/`stop`
          services.nix-serve = {
            enable = true;
            openFirewall = true;
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

          # Client. Opt-in with `nix-servant client`, since the other hosts are usually off
          nix.settings.trusted-substituters = cacheUrls;
        };
      };
  };
}
