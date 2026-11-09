# nix-servant

A small NixOS module that wraps [nix-serve](https://github.com/edolstra/nix-serve)/[nix-serve-ng](https://github.com/aristanetworks/nix-serve-ng) and gives it a convenient little CLI. nix-serve lets machines on the same LAN can share their Nix stores as binary caches.

## Setup

```nix
{
   services.nix-servant = {
    enable = true;
    hosts = [ "my-laptop" "my-desktop" ]; # put your host names here
  };
}
```

Every machine in `hosts` is reached as `<host>.local` over mDNS (Avahi).

The server is [nix-serve-ng](https://github.com/aristanetworks/nix-serve-ng) by default. To use the original nix-serve instead, set `services.nix-serve.package = pkgs.nix-serve;`.

## Usage

With two machines, `my-desktop` and `my-laptop`, where `my-laptop` should use `my-desktop`'s store as a binary cache:

```sh
# On my-desktop
nix-servant serve

# On my-laptop
nix-servant dine
nix build
```

nix-servant figures out which of your other hosts are currently online, and therefore avoids trying to fetch from any offline machine.

### All commands

```sh
nix-servant serve            # start this machine's cache
nix-servant stop             # stop it
nix-servant dine             # open a shell that uses the caches that are up
nix-servant dine nix build   # or run a single command with them
```
