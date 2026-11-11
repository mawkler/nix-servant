# nix-servant

Wraps [nix-serve](https://github.com/edolstra/nix-serve)/[nix-serve-ng](https://github.com/aristanetworks/nix-serve-ng) and gives it a convenient CLI. nix-serve lets machines on the same LAN share their Nix stores as binary caches.

## Setup

On each machine, generate a signing key and print its public key:

```sh
sudo nix-store --generate-binary-cache-key $(hostname)-1 /etc/nix/cache.sec /etc/nix/cache.pub
cat /etc/nix/cache.pub
```

Then add this to every machine's config, for example by sending it to them using [croc](https://github.com/schollz/croc):

```nix
{
  services.nix-servant = {
    enable = true;
    # Put your host names here
    hosts = [ "my-laptop" "my-desktop" ];
  };

  # Put your machines' public keys here
  nix.settings.trusted-public-keys = [ "my-laptop-1:..." "my-desktop-1:..." ];
}
```

Every machine in `hosts` is reachable as `<host>.local` over mDNS ([avahi](https://github.com/avahi/avahi)).

To `serve` without typing your password, set `services.nix-servant.passwordless = true`. This only works for users in `wheel`.

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

To rebuild NixOS while dining, run `nixos-rebuild switch --sudo`. `sudo nixos-rebuild switch` won't use the caches, because sudo drops the setting that points Nix at them.

> [!WARNING]
> While serving, anyone on the network can download any path in your Nix store if they know its hash. Don't serve on untrusted networks, and keep secrets out of the store.

### All commands

```sh
nix-servant serve            # start this machine's cache
nix-servant dine             # enter a shell that uses the caches that are up, until you `exit`
nix-servant stop             # stop this machine's cache
nix-servant dine nix build   # or run a single command with them
```
