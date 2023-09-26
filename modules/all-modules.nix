{
  modules,
  pkgs,
  # Note, this should be "the standard library" + PM extensions.
  lib,
  # Whether to enable module type checking.
  check ? true,
}: let
  ## This includes modules from upstream projects, like nixpkgs.
  allModules =
    modules
    ++ [
      ## FIXME: nixpkgs should expose these via flake outputs (and all of its
      ##        modules) so we could instead have
      ##      > nixpkgs.nixosModules.assertions
      ##      > nixpkgs.nixosModules.lib
      ##      > nixpkgs.nixosModules.meta
      ##        or possibly even re-export them in _our_ `projectModules`.
      ##        See NixOS/nixpkgs#???)
      (pkgs.path + "/nixos/modules/misc/assertions.nix")
      (pkgs.path + "/nixos/modules/misc/lib.nix")
      (pkgs.path + "/nixos/modules/misc/meta.nix")
    ];
in
  allModules
  ++ [
    ({...}: {
      config = {
        _module.args.baseModules = allModules;
        _module.args.pkgsPath = lib.mkDefault pkgs.path;
        _module.args.pkgs = lib.mkDefault pkgs;
        _module.check = check;
        lib = lib.pm;
      };
    })
  ]
