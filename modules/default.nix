{
  configuration,
  modules,
  pkgs,
  lib ? pkgs.lib,
  # Whether to check that each option has a matching declaration.
  check ? true,
  # Extra arguments passed to specialArgs.
  extraSpecialArgs ? {},
}: let
  collectFailed = cfg:
    map (x: x.message) (lib.filter (x: !x.assertion) cfg.assertions);

  showWarnings = res: let
    f = w: x: builtins.trace "[1;31mwarning: ${w}[0m" x;
  in
    lib.fold f res res.config.warnings;

  extendedLib = import ./lib/stdlib-extended.nix lib;

  pmModules = let
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
          lib = extendedLib.pm;
        };
      })
    ];

  rawModule = extendedLib.evalModules {
    modules = [configuration] ++ pmModules;
    specialArgs =
      {
        modulesPath = builtins.toString ./.;
      }
      // extraSpecialArgs;
  };

  module = showWarnings (
    let
      failed = collectFailed rawModule.config;
      failedStr = lib.concatStringsSep "\n" (map (x: "- ${x}") failed);
    in
      if failed == []
      then rawModule
      else throw "\nFailed assertions:\n${failedStr}"
  );
in {
  inherit (module) options config;

  activationPackage = module.config.project.activationPackage;

  devShell = module.config.project.devShell;

  newsDisplay = rawModule.config.news.display;
  newsEntries = lib.sort (a: b: a.time > b.time) (
    lib.filter (a: a.condition) rawModule.config.news.entries
  );

  inherit (module._module.args) pkgs;
}
