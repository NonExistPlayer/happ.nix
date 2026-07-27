<div align="center">

**English** | [Русский](README.ru.md)

</div>

> This repository is a fork and "flake-adaptation" of [happ-nixos](https://github.com/MrShitFox/happ-nixos).

# `happ.nix`

> Run the [Happ](https://github.com/Happ-proxy/happ-desktop) proxy client on NixOS — packaged properly, with a working HWID.

Happ ships as a prebuilt Debian package that assumes a regular FHS layout and a
writable `/opt/happ` — neither of which exists on NixOS. This module repackages it
for the Nix store and wires up everything needed to run it cleanly.

Flake includes:

- **Native Nix packaging**
- **Working HWID**
- **TUN-mode ready**
- **Fast rebuilds**

## Installation

> [!TIP]
> This flake has an output `apps`, which allows you to run Happ via `nix run`.
>
> You can try this flake before installing it!
> ```bash
> nix run github:NonExistPlayer/happ.nix
> ```

Add in your flake configuration a new input:
```nix
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    happ = {
      url = "github:NonExistPlayer/happ.nix";
      inputs.nixpkgs.follows = "nixpkgs"; # optional
    };
  };
```

And next in `nixosConfigurations`, add `nixosModules` from this flake:

```nix
  outputs = inputs@{ self, nixpkgs, ... }: {
    nixosConfigurations.pc =
       nixpkgs.lib.nixosSystem {
         system = "x86_64-linux";
         modules = [
           ./hosts/pc
           inputs.happ.nixosModules.default
         ];
       };
  };
```

Now just enable Happ:

```nix
{ ... }:
{
  services.happ.enable = true;
}
```

> [!WARNING]
> Don't install package directly, like this:
> ```nix
> { pkgs, ... }:
> {
>   environment.systemPackages =
>     let
>       happ = inputs.happ.packages.default;
>     in
>     [
>       happ
>     ];
> }
> ```
> You will lose all main and important features of this flake, including HWID fix.

## Options

| Option | Default | Description |
| --- | --- | --- |
| `services.happ.enable` | `false` | Enable the Happ client and the `happd` daemon. |
| `services.happ.package` | built from `happ.nix` | Override the Happ package. |
| `services.happ.forceXwayland` | `false` | Run Happ through XWayland instead of its bundled Qt6 Wayland plugins. See [Wayland / Hyprland crash](#wayland--hyprland-crash) below. |
| `services.happ.forceSoftwareRendering` | `false` | Force software rendering for Happ's Qt Quick UI. See [Wayland / Hyprland crash](#wayland--hyprland-crash) below. |
| `services.happ.tunInterface` | `"tun0"` | TUN device trusted by the firewall. |

## The HWID fix

Happ derives its hardware id from Qt's `machineUniqueId()`, which on Linux reads
`/var/lib/dbus/machine-id`. NixOS defaults to **dbus-broker**, and — unlike the
classic dbus-daemon — it doesn't create that file, so the id comes back empty and
the client shows a blank HWID. The module links it to the real machine id:

```nix
systemd.tmpfiles.rules = [ "L+ /var/lib/dbus/machine-id - - - - /etc/machine-id" ];
```

## Wayland / Hyprland crash

Happ's bundled Qt6 Wayland plugins can crash the client silently on
wlroots-based compositors (Hyprland, Sway, ...) — an ABI mismatch or missing
dependency against what the vendor shipped. If Happ doesn't start under one
of these, set:

```nix
services.happ.forceXwayland = true;
```

This drops the bundled Wayland plugins from the package and pins Qt to XCB
(XWayland), which sidesteps the crash. Left off by default since it's
unconfirmed whether the crash affects compositors with more mature Qt6
Wayland support (GNOME, KDE).

If the UI still renders incorrectly (or not at all) after that — a separate,
GPU/driver-level issue — also set:

```nix
services.happ.forceSoftwareRendering = true;
```

This is independent of `forceXwayland`: it forces Qt Quick to render in
software regardless of which platform backend (Wayland or XCB) is active.

## Notes

- Protocols: VLESS, VMess, Trojan, Shadowsocks over TUN. Hysteria2 is not supported.
- Happ have an unfree/distributable license. You'll need to enable `allowUnfree`
  or allow in other ways.
- Unofficial community module — not affiliated with the Happ project.

### Security trade-offs

- `happd` runs as **root with no systemd sandboxing** (no `ProtectSystem`,
  `PrivateTmp`, etc.) — hardening it breaks the machine-id bind mount TUN mode
  needs (see the HWID fix above).
- `networking.firewall.checkReversePath` is set to `"loose"` **system-wide**
  (not scoped to the TUN interface) — required for the asymmetric routing TUN
  mode produces.

Both are deliberate and required for TUN mode to work; don't sandbox `happd` or
tighten `checkReversePath` without re-testing that TUN still connects.

## License

[GPL-3.0](LICENSE) — see the LICENSE file.
