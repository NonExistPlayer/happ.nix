{
  description = "Happ proxy desktop client (VLESS/VMess/Trojan/Shadowsocks) with a TUN daemon";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
    };
  in
  {
    packages.${system}.default = pkgs.callPackage ./happ.nix {};

    apps.${system}.default = {
      type = "app";
      program = "${self.packages.${system}.default}/bin/happ";
    };

    nixosModules.default = import ./module.nix;
  };
}
