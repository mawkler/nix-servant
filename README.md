# nix-servant

A small NixOS module that wraps [nix-serve](https://github.com/edolstra/nix-serve) so machines on the same LAN can share their Nix stores as binary caches. The cache only runs while you've started it.

## Setup

```nix
{
  inputs.nix-servant.url = "github:<owner>/nix-servant";

  outputs = { nixpkgs, nix-servant, ... }: {
    nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
      modules = [
        nix-servant.nixosModules.default
        {
          services.nix-servant = {
            enable = true;
            hosts = [ "laptop" "desktop" ];
          };
        }
      ];
    };
  };
}
```

Every machine in `hosts` is reached as `<host>.local` over mDNS (Avahi).

## Usage

```sh
nix-servant serve            # start this machine's cache
nix-servant stop             # stop it
nix-servant dine             # open a shell that uses the caches that are up
nix-servant dine nix build   # or run a single command with them
```
