{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.cabal2nix;

  ## TODO: Implement the remaining command-line options:
  ##     • [--hackage-db PATH]
  ##     • [--system ARG]
  ##     • [--hackage-snapshot ARG]
  ##
  ## NB: This intentionally doesn’t support the [--sha256 HASH]
  ##     [--hpack | --no-hpack] [--revision ARG] [--subpath PATH]
  ##     [--dont-fetch-submodules] options, per NixOS/cabal2nix#628.
  packageModule.options = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = ''
        Whether to process this package with cabal2nix.
      '';
    };

    benchmark = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = ''
        Whether to run benchmarks when building the package.
      '';
    };

    check = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = ''
        Whether to run test suites when building the package.
      '';
    };

    compiler = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "ghc-9.10.1";
      description = ''
        The compiler version to assume when evaluating conditionals in the Cabal
        file. This can affect things like the set of Haskell packages available
        to the derivation. If you have, say, conditionalized dependencies, you
        want to choose a compiler that will include them all.
      '';
    };

    extraArguments = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Extra arguments to pass to the resulting derivation.
      '';
    };

    flags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["omit-interface-pragmas"];
      description = ''
        Flags to pass to the compiler when building the package. Each one will
        be prefixed with “-f”.
      '';
    };

    haddock = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = ''
        Whether to generate Haddock documentation as part of the derivation.
      '';
    };

    hyperlinkSource = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = ''
        Whether to include hyperlinked source code in the derivation.
      '';
    };

    jailbreak = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = ''
        Whether to ignore version bounds when building the package.
      '';
    };

    maintainers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["sellout"];
      description = ''
        The maintainers to include in the derivation. Each one should be a
        string that forms a valid attribute path when appended to
        “lib.maintainers.”.
      '';
    };

    profiling = lib.mkOption {
      type = lib.types.listOf (lib.types.enum ["executable" "library"]);
      default = [];
      example = ["executable" "library"];
      description = ''
        Which components to build with profiling information.
      '';
    };

    shell = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = ''
        Whether to generate a shell.nix-style file rather than one expected to
        be passed to `callPackage`.
      '';
    };

    source = lib.mkOption {
      type = lib.types.str;
      example = "my-package/my-package.cabal";
      description = ''
        The Cabal file (relative to the project root) to generate a
        corresponding Nix file for.
      '';
    };

    target = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "my-package/package.nix";
      description = ''
        The name of the Nix file to generate (relative to the project root).
        If `null` this will use the containing attribute name with
        “/package.nix” appended.
      '';
    };
  };
in {
  meta.maintainers = [lib.maintainers.sellout];

  options.programs.cabal2nix = {
    enable =
      lib.mkEnableOption
      "[cabal2nix](https://github.com/nixos/cabal2nix#readme)";

    package = lib.mkPackageOption pkgs "cabal2nix" {};

    cabalPackage = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule packageModule);
      default = {};
      example = {
        "my-project/package.nix" = {
          benchmark = true;
          maintainers = ["sellout"];
          source = "my-project/my-project.cabal";
        };
      };
      description = ''
        An attribute set of the packages to process with cabal2nix.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    project.devPackages = [cfg.package];

    ## TODO: Rather than generating a file directly into the tree, generate to
    ##       the Nix store and symlink or copy via `project.file`.
    project.activation.cabal2nix =
      ## This ensures that Cabal files produced by hpack* will be in place when
      ## cabal2nix wants to generate its Nix files.
      lib.pm.dag.entryAfter ["writeBoundary" "hpack-dhall" "hpack"] (
        lib.concatLines (
          lib.mapAttrsToList (name: args:
            if args.enable
            then let
              options =
                lib.optional args.benchmark "--benchmark"
                ++ lib.optional (!args.check) "--no-check"
                ++ lib.optionals (args.compiler != null) ["--compiler" (lib.escapeShellArg args.compiler)]
                ++ lib.concatMap (argument: ["--extra-arguments" (lib.escapeShellArg argument)]) args.extraArguments
                ++ lib.concatMap (flag: ["--flag" (lib.escapeShellArg flag)]) args.flags
                ++ lib.optional (!args.haddock) "--no-haddock"
                ++ lib.optional (!args.hyperlinkSource) "--no-hyperlink-source"
                ++ lib.optional args.jailbreak "--jailbreak"
                ++ lib.concatMap (maintainer: ["--maintainer" (lib.escapeShellArg maintainer)]) args.maintainers
                ++ map (type: "--enable-${type}-profiling") args.profiling
                ++ lib.optional args.shell "--shell";
            in ''
              ${lib.getExe cfg.package} \
                ${lib.concatStringsSep " " options} \
                "$PROJECT_ROOT/${args.source}" \
                >${lib.escapeShellArg (
                if args.target == null
                then "${name}/package.nix"
                else args.target
              )}
            ''
            else "")
          cfg.cabalPackage
        )
      );
  };
}
