{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.cargo;
in {
  meta.maintainers = [lib.maintainers.sellout];

  options.programs.cargo = {
    enable = lib.mkEnableOption "[Cargo](https://doc.rust-lang.org/cargo/)";

    package = lib.mkPackageOption pkgs "cargo" {};

    generateLockfile = {
      enable =
        lib.mkEnableOption
        "running `cabal generate-lockfile` during project configuration activation";

      persistence = lib.mkOption {
        type = lib.types.enum ["worktree" "repository"];
        default = "worktree";
        example = "repository";
        description = ''
          Whether the file should be committed to the repository. This is much
          like the `project.file` option, but it doesn’t permit a “store” persistence.
        '';
      };

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

  config = lib.mkIf cfg.enable (let
    cargoLock = "Cargo.lock";
    glf = cfg.generateLockfile;
  in {
    ## TODO: Use real persistence settings for this file, but for now, just
    ##       treat it as `worktree`.
    programs = lib.mkIf (glf.enable && !glf.locked) {
      git = {
        attributes = lib.mkIf (glf.persistence == "repository") {
          "/${cargoLock}".linguist-generated = true;
        };
        ignores = lib.optional (glf.persistence == "worktree") "/${cargoLock}";
      };
      treefmt.settings.global.excludes = [cargoLock];
    };

    project.devPackages = [cfg.package];

    ## TODO: Rather than generating a file directly into the tree, generate to
    ##       the Nix store and symlink or copy via `project.file`.
    project.activation.cargo-generate-lockfile = lib.mkIf glf.enable (
      lib.pm.dag.entryBetween ["writeBoundary"] ["cargo2nix"] (let
        options =
          lib.optional (glf.verbose != false) "--verbose"
          ++ lib.optional (glf.verbose == "very") "--verbose"
          ++ lib.optional glf.quiet "--quiet"
          ++ lib.optionals (glf.manifestPath != null)
          ["--manifest-path" (lib.escapeShellArg glf.manifestPath)]
          ++ lib.optional glf.ignoreRustVersion "--ignore-rust-version"
          ++ lib.optional glf.locked "--locked"
          ++ lib.optional glf.offline "--offline";
      in ''
        ${lib.getExe cfg.package} generate-lockfile ${lib.concatStringsSep " " options}
        ${
          if !glf.locked && glf.persistence == "repository"
          then "${lib.getExe pkgs.git} add --force --intent-to-add ${lib.escapeShellArg cargoLock}"
          else ""
        }
      '')
    );
  });
}
