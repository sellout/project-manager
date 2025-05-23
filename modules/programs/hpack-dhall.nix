{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.hpack-dhall;

  packageModule.options = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = ''
        Whether to process this package with hpack-dhall.
      '';
    };

    outputFormat = lib.mkOption {
      type = lib.types.enum ["cabal" "dhall" "json" "yaml"];
      default = "cabal";
      description = ''
        The output format to generate from Dhall. While the default is generally
        the right thing, if you primarily build with
        [cabal2nix](https://github.com/nixos/cabal2nix#readme) or
        [Stack](https://docs.haskellstack.org/) you might prefer `"yaml"`,
        which produces [hpack](https://github.com/cabalism/hpack#readme)
        package.yaml files that Stack can handle directly.
      '';
    };

    source = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "my-package/package.dhall";
      description = ''
        The Dhall file (relative to the project root) to generate a
        corresponding file in `outputFormat` for. If `null` this will use the
        containing attribute name with “/package.dhall” appended.
      '';
    };
  };
in {
  meta.maintainers = [lib.maintainers.sellout];

  options.programs.hpack-dhall = {
    enable =
      lib.mkEnableOption
      "[hpack-dhall](https://github.com/cabalism/hpack-dhall#readme)";

    package = lib.mkPackageOption pkgs "hpack-dhall" {
      default = ["haskellPackages" "hpack-dhall"];
    };

    dhallPackage = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule packageModule);
      default = {};
      description = ''
        An attribute set of the packages to process with hpack-dhall.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    project.devPackages = [cfg.package];

    ## TODO: Rather than generating a file directly into the tree, generate to
    ##       the Nix store and symlink or copy via `project.file`.
    project.activation.hpack-dhall =
      ## This ensures that Cabal files produced by hpack-dhall will be in place
      ## when cabal2nix or hpack want to further process them.
      lib.pm.dag.entryBetween ["writeBoundary"] ["hpack" "cabal2nix"] (
        lib.concatLines (lib.mapAttrsToList (name: args:
          if args.enable
          then let
            src =
              if args.source != null
              then args.source
              else "${name}/package.dhall";
            ## The commands other than `dhall-hpack-cabal` output to stdout, so we
            ## need to redirect those.
            redirect =
              if args.outputFormat == "cabal"
              then ""
              else ">$PROJECT_ROOT/${
                builtins.replaceStrings [".dhall"] [".${args.outputFormat}"] src
              }";
          in ''
            ${lib.getExe' cfg.package "dhall-hpack-${args.outputFormat}"} \
              --package-dhall "$PROJECT_ROOT/${src}" ${redirect}
          ''
          else "")
        cfg.dhallPackage)
      );
  };
}
