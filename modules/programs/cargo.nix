{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.cargo;
in {
  options.programs.cargo = {
    enable = lib.mkEnableOption "[Cargo](https://doc.rust-lang.org/cargo/)";

    package = lib.mkPackageOption pkgs "cargo" {};

    generateLockfile = {
      enable = lib.mkEnableOption "running `cabal generate-lockfile` during project configuration activation.";

      verbose = lib.mkOption {
        type = lib.types.either lib.types.bool (lib.types.enum ["very"]);
        default = false;
        example = "very";
        description = ''
          Use verbose output. `"very"` includes extra output such as dependency
          warnings and build script output.
        '';
      };

      quiet = lib.mkOption {
        type = lib.types.bool;
        default = false;
        example = true;
        description = ''
          Do not print cargo log messages.
        '';
      };

      manifestPath = lib.mkOption {
        type = lib.types.nullOr (lib.types.pathWith {});
        default = null;
        example = "./rust/Cargo.toml";
        description = ''
          Path to the `Cargo.toml` file. By default, Cargo searches for the
          `Cargo.toml` file in the current directory or any parent directory.
        '';
      };

      ignoreRustVersion = lib.mkOption {
        type = lib.types.bool;
        default = false;
        example = true;
        description = ''
          Ignore `rust-version` specification in packages
        '';
      };

      locked = lib.mkOption {
        type = lib.types.bool;
        default = false;
        example = true;
        description = ''
          Asserts that the exact same dependencies and versions are used as when
          the existing `Cargo.lock` file was originally generated. Cargo will
          exit with an error when either of the following scenarios arises:

          - The lock file is missing.
          - Cargo attempted to change the lock file due to a different
            dependency resolution.

          It may be used in environments where deterministic builds are desired,
          such as in CI pipelines.
        '';
      };

      offline = lib.mkOption {
        type = lib.types.bool;
        default = false;
        example = true;
        description = ''
          Prevents Cargo from accessing the network for any reason. Without this
          flag, Cargo will stop with an error if it needs to access the network
          and the network is not available. With this flag, Cargo will attempt
          to proceed without the network if possible.

          Beware that this may result in different dependency resolution than
          online mode. Cargo will restrict itself to crates that are downloaded
          locally, even if there might be a newer version as indicated in the
          local copy of the index. See the cargo-fetch(1) command to download
          dependencies before going offline.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    project.devPackages = [cfg.package];

    ## TODO: Rather than generating a file directly into the tree, generate to
    ##       the Nix store and symlink or copy via `project.file`.
    project.activation.cargo-generate-lockfile = lib.mkIf cfg.generateLockfile.enable (
      lib.pm.dag.entryentryBetween ["writeBoundary"] ["cargo2nix"] (let
        options =
          lib.optional (cfg.vebose != false) "--verbose"
          ++ lib.optional (cfg.vebose == "very") "--verbose"
          ++ lib.optional cfg.quiet "--quiet"
          ++ lib.optionals (cfg.manifestPath != null)
          ["--manifest-path" (lib.escapeShellArg cfg.manifestPath)]
          ++ lib.optional cfg.ignoreRustVersion "--ignore-rust-version"
          ++ lib.optional cfg.locked "--locked"
          ++ lib.optional cfg.offline "--offline";
      in ''
        ${lib.getExe cfg.package} generate-lockfile ${lib.concatStringsSep " " options}
      '')
    );
  };
}
