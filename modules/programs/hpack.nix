{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.hpack;

  packageModule.options = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = ''
        Whether to process this package with hpack.
      '';
    };

    canonical = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = ''
        By default, hpack takes into account aspects of the format of an
        existing Cabal file when generating a new Cabal file. Pass this flag to
        cause hpack to ignore the format of an existing Cabal file when
        generating a new one.
      '';
    };

    force = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = ''
        By default, hpack will not generate a Cabal file unnecessarily. Set this
        to `true` to force the generation of a new Cabal file.
      '';
    };

    hash = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      example = true;
      description = ''
        Enable/disable the inclusion of a SHA-256 hash of the other content of
        the generated Cabal file in the header comment added by hpack to the
        generated Cabal file.
      '';
    };

    silent = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = ''
        Output no information other than error messages.
      '';
    };

    source = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "my-package/package.yaml";
      description = ''
        The YAML file (relative to the project root) to generate a
        corresponding Cabal file for. If `null` this will use the containing
        attribute name with “/package.yaml” appended.
      '';
    };
  };
in {
  meta.maintainers = [lib.maintainers.sellout];

  options.programs.hpack = {
    enable =
      lib.mkEnableOption
      "[hpack](https://github.com/sol/hpack#readme)";

    package = lib.mkPackageOption pkgs "hpack" {};

    cabalPackage = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule packageModule);
      default = {};
      description = ''
        An attribute set of the packages to process with hpack.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    project.devPackages = [cfg.package];

    ## TODO: Rather than generating a file directly into the tree, generate to
    ##       the Nix store and symlink or copy via `project.file`.
    project.activation.hpack =
      ## This ensures that Cabal files produced by hpack will be in place
      ## when cabal2nix wants to further process them.
      lib.pm.dag.entryBetween ["writeBoundary" "hpack-dhall"] ["cabal2nix"] (
        lib.concatLines (lib.mapAttrsToList (name: args:
          if args.enable
          then let
            options =
              lib.optional args.canonical "--canonical"
              ++ lib.optional args.force "--force"
              ++ lib.optional (args.hash != null) (
                if args.hash
                then "--hash"
                else "--no-hash"
              )
              ++ lib.optional args.silent "--silent";
          in ''
            ${lib.getExe cfg.package} \
              ${lib.concatStringsSep " " options} \
              "$PROJECT_ROOT/${
              if args.source == null
              then "${name}/package.yaml"
              else args.source
            }"
          ''
          else "")
        cfg.cabalPackage)
      );
  };
}
