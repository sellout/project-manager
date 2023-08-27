{
  configuration,
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

  pmModules = import ./modules.nix {
    inherit check pkgs;
    lib = extendedLib;
  };

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

  newsDisplay = rawModule.config.news.display;
  newsEntries = lib.sort (a: b: a.time > b.time) (
    lib.filter (a: a.condition) rawModule.config.news.entries
  );

  inherit (module._module.args) pkgs;
}
