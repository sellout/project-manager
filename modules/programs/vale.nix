{
  bash-strict-mode,
  config,
  lib,
  pkgs,
  self,
  ...
}: let
  cfg = config.programs.vale;
in {
  options.programs.vale = {
    ## TODO: Enabling this currently requires the flake to have
    ##      `nixConfig.sandbox = false;` to allow the check to run.
    enable = lib.mkEnableOption (lib.mdDoc "Vale");

    package = lib.mkPackageOptionMD pkgs "Vale" {
      default = ["vale"];
    };

    coreSettings = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      description = lib.mdDoc ''
        The .vale.ini file. The `target` is ignored.
      '';
    };

    formatSettings = lib.mkOption {
      type = lib.types.nullOr (lib.types.attrsOf lib.types.attrs);
      default = null;
      description = lib.mdDoc ''
        The .vale.ini file. The `target` is ignored.
      '';
    };

    vocab = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf (lib.types.listOf lib.types.str));
      default = {};
      description = lib.mdDoc ''
        An attrset with two optional keys, “accept” and “reject”. Each contains
        a list of words that are either accepted or rejected by Vale’s spell
        checker.
      '';
    };

    excludes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = lib.mdDoc ''
        A list of glob patterns to skip when checking Vale compliance.
      '';
    };
  };
  config = lib.mkIf cfg.enable (let
    ## This is a bit complicated, because if we’re _not_ generating a .vale.ini,
    ## then this needs to have the default "styles" value, but if we are, then
    ## we want to default to ".cache/vale".
    actualCoreSettings =
      if cfg.coreSettings == null
      then {StylesPath = "styles";}
      ## TODO: Can we instead pre-populate this and have `stylesPath` simply point
      ##       to the Nix store? That would declutter the working tree even more
      ##       while also giving us additional sharing between worktrees and across
      ##       projects.
      ##     - There are a couple issues here
      ##       1. it involves downloading the packages. We could define a fixed-
      ##           output Nix package for each Vale package to get around that, then
      ##           combine the requested packages with our Vocabs for a new package
      ##       2. if we _don’t_ create a Nix package for this, then the check
      ##           requires downloading.
      else {StylesPath = "${config.xdg.cacheDir}/vale";} // cfg.coreSettings;
  in {
    project = {
      file =
        {
          ".vale.ini" = lib.mkIf (cfg.coreSettings != null || cfg.formatSettings != null) {
            ## TODO: Should be able to make this `"store"`.
            # minimum-persistence = "worktree";
            onChange = ''
              ${cfg.package}/bin/vale sync
            '';
            text = lib.generators.toINIWithGlobalSection {} {
              globalSection = actualCoreSettings;
              sections = cfg.formatSettings or {};
            };
          };
        }
        // lib.concatMapAttrs (k: v: {
          "${actualCoreSettings.StylesPath}/Vocab/${k}/accept.txt" = lib.mkIf (v ? accept) {
            # minimum-persistence = "worktree";
            text = lib.concatLines v.accept;
          };
          "${actualCoreSettings.StylesPath}/Vocab/${k}/reject.txt" = lib.mkIf (v ? reject) {
            # minimum-persistence = "worktree";
            text = lib.concatLines v.reject;
          };
        })
        cfg.vocab;

      packages = [cfg.package];

      ## TODO: Certain checks functions (like this one) require the sandbox to be
      ##       disabled, otherwise they fail. We should be able to
      ##    1. see if the sandbox is enabled for this project;
      ##    2. if so, identify which checks those are (`__noChroot`); and
      ##    3. expose them via `devShells.laxChecks` instead of as checks.
      checks.vale =
        bash-strict-mode.lib.checkedDrv pkgs
        (pkgs.runCommand "vale" {
            ## TODO: Wouldn’t need this if we had the Vale packages available as Nix
            ##       packages, but as it is, they need to be downloaded via
            ##      `vale sync`.
            __noChroot = true;
            nativeBuildInputs = [pkgs.vale];
            src = self;
          } ''
            cp -R "$src/." build
            chmod -R +w build
            cd build || exit

            vale sync
            find . -type f \
              ${lib.concatStringsSep " " (map (v: "-not -path '${v}' ") cfg.excludes)} \
              -exec vale {} +
            mkdir -p "$out"
          '');

      # ## TODO: Generalize this to a `projects.laxChecks` that produces a devShell
      # ##       for each check.
      # devShells.check-vale = let
      #   lax-check = src: nativeBuildInputs: command:
      #     bash-strict-mode.lib.checkedDrv pkgs
      #       (pkgs.mkShell {
      #         inherit nativeBuildInputs src;
      #     shellHook = ''
      #       ## Shouldn’t need this, but apparently `bash-strict-mode` isn’t
      #       ## working properly.
      #       ##
      #       ## Also, can’t use `-u` because of Starship, which is a personal issue
      #       ## that I should report.
      #       set -eo pipefail

      #       build_dir=$(mktemp -d -t "project-manager-check-vale.XXXXXX")
      #       cp -R "$src/." "$build_dir"
      #       chmod -R +w "$build_dir"
      #       cd "$build_dir" || exit
      #       ${command}
      #     '';
      # });
      # in lax-check ../../.. [pkgs.vale] ''
      #   vale sync
      #   ## We skip licenses because they are written by lawyers, not by us.
      #   ## TODO: Have a general `ignores` list that we can process into
      #   ##       gitignores, `find -not` lists, etc.
      #   find . -type f \
      #     -not -path './.cache/*' \
      #     -not -path './flake.lock' \
      #     -not -path '*/LICENSE' \
      #     -not -path '*/Eldev' \
      #     -not -path '*.nix' \
      #     -exec vale {} +
      # '';
    };

    programs.git.ignores = let
      stylesPath = actualCoreSettings.StylesPath;
    in
      if actualCoreSettings ? Vocab
      ## See https://vale.sh/docs/topics/packages/#packages-and-vcs for an
      ## explanation of this convoluted ignoring.
      then [
        "/${stylesPath}/*"
        "!/${stylesPath}/Vocab/"
        "/${stylesPath}/Vocab/*"
        "!/${stylesPath}/Vocab/${actualCoreSettings.Vocab}/"
      ]
      else ["/${stylesPath}/"];

    ## Can’t build un-sandboxed derivations on Garnix (see garnix-io/issues#33)
    services.garnix.builds.exclude = ["checks.*.vale"];
  });
}
