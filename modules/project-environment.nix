{
  config,
  lib,
  pkgs,
  pmPkgs,
  self,
  ...
}:
with lib; let
  inherit (config.project) stateVersion;

  cfg = config.project;
in {
  meta.maintainers = [maintainers.sellout];

  options.project = {
    name = mkOption {
      type = types.str;
      defaultText = lib.literalMD "undefined";
      example = "my-project";
      description = "The project’s name (as an identifier).";
    };

    summary = mkOption {
      type = types.str;
      defaultText = lib.literalMD "undefined";
      example = "Tooling for doing something I want.";
      description = ''
        A brief (approximately one line) description of the project.
      '';
    };

    authors = mkOption {
      type = types.nonEmptyListOf types.attrs;
      defaultText = lib.literalMD "undefined";
      example = "[lib.maintainers.sellout]";
      description = ''
        Authors of this project. See
        https://github.com/NixOS/nixpkgs/tree/master/maintainers for the
        structure.
      '';
    };

    maintainers = mkOption {
      type = types.nonEmptyListOf types.attrs;
      default = cfg.authors;
      defaultText = lib.literalMD "config.project.authors";
      example = "[lib.maintainers.sellout]";
      description = ''
        Current maintainers of this project. See
        https://github.com/NixOS/nixpkgs/tree/master/maintainers for the
        structure.
      '';
    };

    license = mkOption {
      type = types.str;
      defaultText = lib.literalMD "undefined";
      description = ''
        An SPDX license expression, see https://spdx.org/licenses/.
      '';
    };

    projectDirectory = mkOption {
      type = types.str;
      default = "./.";
      internal = true;
      defaultText = lib.literalMD "$PROJECT_ROOT";
      example = "./.";
      description = ''
        The project’s root directory relative to this file.
      '';
    };

    commit-by-default = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether all files in this project should default to being committed.
        This can be useful if you have contributors that don’t use Nix and
        expect everything to live directly in the repo (e.g., Open Source
        projects where you don’t know the contributors in advance).
      '';
    };

    wrapPrograms = mkOption {
      type = types.nullOr types.bool;
      default = null;
      apply = p:
        if p == null
        then !cfg.commit-by-default
        else p;
      description = ''
        Whether to default to wrapping programs instead of writing configuration
        files. If null, it falls back to the opposite of
        {var}`project.commit-by-default`.
      '';
    };

    shellAliases = mkOption {
      type = with types; attrsOf str;
      default = {};
      example = lib.literalMD ''
        {
          g = "git";
          "..." = "cd ../..";
        }
      '';
      description = ''
        An attribute set that maps aliases (the top level attribute names
        in this option) to command strings or directly to build outputs.
      '';
      # This option should only be used to manage simple aliases that are
      # compatible across all shells. If you need to use a shell specific
      # feature then make sure to use a shell specific option, for example
      # [](#opt-programs.bash.shellAliases) for Bash.
    };

    sessionVariables = mkOption {
      default = {};
      type = with types; lazyAttrsOf (oneOf [str path int float]);
      example = {
        EDITOR = "emacs";
        GS_OPTIONS = "-sPAPERSIZE=a4";
      };
      description = ''
        Environment variables to always set at login.

        The values may refer to other environment variables using
        POSIX.2 style variable references. For example, a variable
        {var}`parameter` may be referenced as
        `$parameter` or `''${parameter}`. A
        default value `foo` may be given as per
        `''${parameter:-foo}` and, similarly, an alternate
        value `bar` can be given as per
        `''${parameter:+bar}`.

        Note, these variables may be set in any order so no session
        variable may have a runtime dependency on another session
        variable. In particular code like
        ```nix
        project.sessionVariables = {
          FOO = "Hello";
          BAR = "$FOO World!";
        };
        ```
        may not work as expected. If you need to reference another
        session variable, then do so inside Nix instead. The above
        example then becomes
        ```nix
        project.sessionVariables = {
          FOO = "Hello";
          BAR = "''${config.project.sessionVariables.FOO} World!";
        };
        ```
      '';
    };

    sessionVariablesPackage = mkOption {
      type = types.package;
      internal = true;
      description = ''
        The package containing the
        {file}`pm-session-vars.sh` file.
      '';
    };

    sessionPath = mkOption {
      type = with types; listOf str;
      default = [];
      example = [
        "$PROJECT_ROOT/.local/bin"
        "\${xdg.configHome}/emacs/bin"
        ".git/safe/../../bin"
      ];
      description = ''
        Extra directories to add to {env}`PATH`.

        These directories are added to the {env}`PATH` variable in a
        double-quoted context, so expressions like `$PROJECT_ROOT` are
        expanded by the shell. However, since expressions like `~` or
        `*` are escaped, they will end up in the {env}`PATH`
        verbatim.
      '';
    };

    sessionVariablesExtra = mkOption {
      type = types.lines;
      default = "";
      internal = true;
      description = ''
        Extra configuration to add to the
        {file}`pm-session-vars.sh` file.
      '';
    };

    devPackages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = ''
        The set of packages to appear in the project environment.
      '';
    };

    extraOutputsToInstall = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["doc" "info" "devdoc"];
      description = ''
        List of additional package outputs of the packages
        {var}`project.devPackages` that should be installed into
        the user environment.
      '';
    };

    emptyActivationPath = mkOption {
      internal = true;
      type = types.bool;
      default = true;
      defaultText = lib.literalMD "true";
      description = ''
        Whether the activation script should start with an empty
        {env}`PATH` variable. When `false` then the
        user's {env}`PATH` will be accessible in the script. It is
        recommended to keep this at `true` to avoid
        uncontrolled use of tools found in PATH.
      '';
    };

    activation = mkOption {
      type = pm.types.dagOf types.str;
      default = {};
      example = lib.literalMD ''
        {
          myActivationAction = lib.pm.dag.entryAfter ["writeBoundary"] '''
            "''${DRY_RUN_CMD[@]}" ln -s "''${VERBOSE_ARG[@]}" \
                ''${builtins.toPath ./link-me-directly} $PROJECT_ROOT
          ''';
        }
      '';
      description = ''
        The activation scripts blocks to run when activating a Project
        Manager generation. Any entry here should be idempotent,
        meaning running twice or more times produces the same result
        as running it once.

        If the script block produces any observable side effect, such
        as writing or deleting files, then it
        *must* be placed after the special
        `writeBoundary` script block. Prior to the
        write boundary one can place script blocks that verifies, but
        does not modify, the state of the system and exits if an
        unexpected state is found. For example, the
        `checkLinkTargets` script block checks for
        collisions between non-managed files and files defined in
        [](#opt-project.file).

        A script block should respect the {var}`DRY_RUN`
        variable, if it is set then the actions taken by the script
        should be logged to standard out and not actually performed.
        The variable {var}`DRY_RUN_CMD` is set to
        {command}`echo` if dry run is enabled.

        A script block should also respect the
        {var}`VERBOSE` variable, and if set print
        information on standard out that may be useful for debugging
        any issue that may arise. The variable
        {var}`VERBOSE_ARG` is set to
        {option}`--verbose` if verbose output is enabled.
      '';
    };

    packages = mkOption {
      internal = true;
      type = types.attrsOf types.package;
      default = {};
      description = ''
        Packages provided by the project configuration. These generally don’t
        need to be explicitly referenced, as they’re part of the usual
        functioning of Project Manager.
      '';
    };

    checks = mkOption {
      internal = true;
      type = types.attrsOf types.package;
      default = {};
      description = ''
        Checks provided by the project configuration. These can be included in
        your flake’s checks.
      '';
    };

    sandboxedChecks = mkOption {
      internal = true;
      type = types.attrsOf types.package;
      description = ''
        The subset of `project.checks` that is sandboxed. You can use this
        instead of that in your flake to avoid disabling the sandbox.
      '';
    };

    unsandboxedChecks = mkOption {
      internal = true;
      type = types.attrsOf types.package;
      description = ''
        The subset of `project.checks` that is not sandboxed. These are also
        exposed via `project.devShells.lax-checks` which can be run outside of
        `nix flake check`.
      '';
    };

    devShells = mkOption {
      internal = true;
      type = types.attrsOf types.package;
      description = ''
        Packages providing shells with various tooling. There is always a
        `project.devShells.project-manager` which contains all the tooling
        declared in the project config. Other modules may also define their own
        `devShells`, for example, when they have a check that can’t be defined
        as a pure check, it’s provided as a devShell with the `check-` prefix.
      '';
    };

    formatter = mkOption {
      type = types.package;
      description = ''
        Package to use as the flake’s formatter. This needs to be assigned to
        the flake’s formatter output.
      '';
    };

    filterRepositoryPersistedExcept = mkOption {
      internal = true;
      type = types.functionTo (types.functionTo (types.functionTo types.bool));
      description = ''
        Remove repository-persisted files from some `src`, except for those
        listed in `exceptions`.
      '';
    };

    filterRepositoryPersisted = mkOption {
      internal = true;
      type = types.functionTo (types.functionTo types.bool);
      description = ''
        Remove all repository-persisted files from some `src`.
      '';
    };

    cleanRepositoryPersistedExcept = mkOption {
      internal = true;
      type = types.functionTo (types.functionTo types.attrs);
      description = ''
        Remove repository-persisted files from some `src`, except for those
        listed in `exceptions`.
      '';
    };

    cleanRepositoryPersisted = mkOption {
      internal = true;
      type = types.functionTo types.attrs;
      description = ''
        Remove all repository-persisted files from some `src`.
      '';
    };

    extraActivationPath = mkOption {
      internal = true;
      type = types.listOf types.package;
      default = [];
      description = ''
        Extra packages to add to {env}`PATH` within the activation
        script.
      '';
    };

    extraBuilderCommands = mkOption {
      type = types.lines;
      default = "";
      internal = true;
      description = ''
        Extra commands to run in the Project Manager generation builder.
      '';
    };

    extraProfileCommands = mkOption {
      type = types.lines;
      default = "";
      internal = true;
      description = ''
        Extra commands to run in the Project Manager profile builder.
      '';
    };

    enableNixpkgsReleaseCheck = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Determines whether to check for release version mismatch between Project
        Manager and Nixpkgs. Using mismatched versions is likely to cause errors
        and unexpected behavior. It is therefore highly recommended to use a
        release of Project Manager that corresponds with your chosen release of
        Nixpkgs.

        When this option is enabled and a mismatch is detected then a warning
        will be printed when the user configuration is being built.
      '';
    };
  };

  config = {
    assertions = [
      {
        assertion = cfg.projectDirectory != "";
        message = "Project directory could not be determined";
      }
    ];

    warnings = let
      ## Nixpkgs versions that have never been supported by Project Manager.
      unsupportedVersions = [
        "13.10"
        "14.04"
        "14.12"
        "15.09"
        "16.03"
        "16.09"
        "17.03"
        "17.09"
        "18.03"
        "18.09"
        "19.03"
        "19.09"
        "20.03"
        "20.09"
        "21.05"
        "21.11"
        "22.05"
      ];
      ## For each nixpkgs release, this lists the Project Manager versions that
      ## support it.
      ## TODO: The Project Manager release shouldn't include the revision.
      supportedVersions =
        lib.listToAttrs
        (map (name: lib.nameValuePair name []) unsupportedVersions)
        // {
          "22.11" = ["0.3" "0.4" "0.5" "0.6" "0.7"];
          "23.05" = ["0.1" "0.2" "0.3" "0.4" "0.5" "0.6" "0.7"];
          "23.11" = ["0.3" "0.4" "0.5" "0.6" "0.7"];
          "24.05" = ["0.3" "0.4" "0.5" "0.6" "0.7"];
          "24.11" = ["0.3" "0.4" "0.5" "0.6" "0.7"];
          "25.05" = ["0.7"];
          ## NB: These versions are only “supported” on unstable, not 25.11.
          "25.11" = ["0.7"];
        };
      pmRelease = cfg.version.release;
      nixpkgsRelease = lib.trivial.release;
      allowedPmVersions = supportedVersions.${nixpkgsRelease};
      releaseMismatch =
        cfg.enableNixpkgsReleaseCheck
        && !(lib.any
          (pmMinor: lib.hasPrefix "${pmMinor}." pmRelease)
          allowedPmVersions);
    in
      optional releaseMismatch ''
        You are using

          Project Manager version ${pmRelease} and
          Nixpkgs version ${nixpkgsRelease}.

        ${
          if allowedPmVersions == []
          then ''
            There are no Project Manager versions that support
            Nixpkgs ${nixpkgsRelease}.
          ''
          else ''
            Project Manager versions that support Nixpkgs ${nixpkgsRelease}:
            • ${concatStringsSep ".*\n• " supportedVersions.${nixpkgsRelease}}.*
          ''
        }

        Using mismatched versions is likely to cause errors and unexpected
        behavior. It is therefore highly recommended to use a release of
        Project Manager that corresponds with your chosen release of Nixpkgs.

        If you insist then you can disable this warning by adding

          project.enableNixpkgsReleaseCheck = false;

        to your configuration.
      '';

    # programs.bash.shellAliases = cfg.shellAliases;
    # programs.zsh.shellAliases = cfg.shellAliases;
    # programs.fish.shellAliases = cfg.shellAliases;

    # Provide a file holding all session variables.
    project.packages.sessionVariables = pkgs.writeTextFile {
      name = "pm-session-vars.sh";
      destination = "/etc/profile.d/pm-session-vars.sh";
      text =
        ''
          # Only source this once.
          if [[ -v __PM_SESS_VARS_SOURCED ]]; then return; fi
          export __PM_SESS_VARS_SOURCED=1

          ${config.lib.shell.exportAll cfg.sessionVariables}
        ''
        + lib.optionalString (cfg.sessionPath != []) ''
          export PATH="$PATH''${PATH:+:}${concatStringsSep ":" cfg.sessionPath}"
        ''
        + cfg.sessionVariablesExtra;
    };

    project.packages.shellAliases = let
      aliasesStr =
        lib.concatLines
        (lib.mapAttrsToList (k: v: "alias ${k}=${lib.escapeShellArg v}")
          cfg.shellAliases);
    in
      pkgs.writeTextFile {
        name = "pm-shell-aliases.sh";
        destination = "/etc/profile.d/pm-shell-aliases.sh";
        text = ''
          # Only source this once.
          if [[ -v __PM_SHELL_ALIASES_SOURCED ]]; then return; fi
          export __PM_SHELL_ALIASES_SOURCED=1

          ${aliasesStr}
        '';
      };

    project.devPackages = [
      cfg.packages.sessionVariables
      cfg.packages.shellAliases
    ];

    # A dummy entry acting as a boundary between the activation
    # script's "check" and the "write" phases.
    project.activation.writeBoundary = pm.dag.entryAnywhere "";

    # Install packages to the project environment.
    #
    project.activation.installPackages = pm.dag.entryAfter ["writeBoundary"] (
      let
        profileDir = "$PROJECT_ROOT/${config.xdg.stateDir}/nix/profiles/project-manager";
        pathPackageName = "project-manager-path-for-${cfg.name}";
      in ''
        function nixReplaceProfile() {
          local oldNix="$(command -v nix)"

          pm_removePackagesBySuffix "${profileDir}" '${pathPackageName}'

          "''${DRY_RUN_CMD[@]}" $oldNix profile install --profile ${profileDir} $1
        }

        INSTALL_CMD="nix profile install --profile ${profileDir}"
        INSTALL_CMD_ACTUAL="nixReplaceProfile"
        LIST_CMD="nix profile list --profile ${profileDir}"
        REMOVE_CMD_SYNTAX='nix profile remove --profile ${profileDir} {number | store path}'

        if ! $INSTALL_CMD_ACTUAL ${cfg.packages.path} ; then
          echo
          _iError $'Oops, Nix failed to install your new Project Manager profile!\n\nPerhaps there is a conflict with a package that was installed using\n"%s"? Try running\n\n    %s\n\nand if there is a conflicting package you can remove it with\n\n    %s\n\nThen try activating your Project Manager configuration again.' "$INSTALL_CMD" "$LIST_CMD" "$REMOVE_CMD_SYNTAX"
          exit 1
        fi
        unset -f nixReplaceProfile
        unset INSTALL_CMD INSTALL_CMD_ACTUAL LIST_CMD REMOVE_CMD_SYNTAX
      ''
    );

    # Text containing Bash commands that will initialize the Project Manager Bash
    # library. Most importantly, this will prepare for using translated strings
    # in the `pm-modules` text domain.
    lib.bash.initProjectManagerLib = let
      domainDir =
        pkgs.runCommand "pm-modules-messages" {
          nativeBuildInputs = [pkgs.buildPackages.gettext];
        } ''
          mkdir -p "$out"
          # for path in {./po}/*.po; do
          #   lang="''${path##*/}"
          #   lang="''${lang%%.*}"
          #   mkdir -p "$out/$lang/LC_MESSAGES"
          #   msgfmt -o "$out/$lang/LC_MESSAGES/pm-modules.mo" "$path"
          # done
        '';
    in ''
      export TEXTDOMAIN=pm-modules
      export TEXTDOMAINDIR=${domainDir}
      source ${../lib/bash/project-manager.bash}
    '';

    project.packages.activation = let
      mkCmd = res: ''
        _iNote "Activating %s" "${res.name}"
        ${res.data}
      '';
      sortedCommands = pm.dag.topoSort cfg.activation;
      activationCmds =
        if sortedCommands ? result
        then concatStringsSep "\n" (map mkCmd sortedCommands.result)
        else
          abort ("Dependency cycle in activation script: "
            + builtins.toJSON sortedCommands);

      # Programs that always should be available on the activation
      # script's PATH.
      activationBinPaths =
        lib.makeBinPath (
          with pkgs;
            [
              bash
              coreutils
              diffutils # For `cmp` and `diff`.
              findutils
              gettext
              gnugrep
              gnused
              jq
              ncurses # For `tput`.
            ]
            ++ cfg.extraActivationPath
        )
        + (
          # Add path of the Nix binaries, if a Nix package is configured, then
          # use that one, otherwise grab the path of the nix command.
          # if config.nix.enable && config.nix.package != null then
          #   ":${config.nix.package}/bin"
          # else
          ":$(${pkgs.coreutils}/bin/dirname $(${pkgs.coreutils}/bin/readlink -m $(type -p nix)))"
        )
        + optionalString (!cfg.emptyActivationPath) "\${PATH:+:}$PATH";

      activationScript = pkgs.writeShellScript "activation-script" ''
        set -eu
        set -o pipefail

        ## TODO: Is this needed here?
        # cd $PROJECT_ROOT

        export PATH="${activationBinPaths}"
        ${config.lib.bash.initProjectManagerLib}

        ${builtins.readFile ./lib-bash/activation-init.bash}

        if [[ ! -v SKIP_SANITY_CHECKS ]]; then
          checkProjectDirectory ${escapeShellArg cfg.projectDirectory}
        fi

        ${activationCmds}
      '';
    in
      pmPkgs.runStrictCommand
      "project-manager-generation-for-${cfg.name}"
      {
        preferLocalBuild = true;
        meta.mainProgram = "activate";
      }
      ''
        mkdir -p $out/bin

        echo "${cfg.version.full}" > $out/pm-version

        cp ${activationScript} $out/bin/activate

        ln -s $out/bin/activate $out/bin/project-manager-generation

        substituteInPlace $out/bin/activate \
          --subst-var-by GENERATION_DIR $out

        ln -s ${config.project-files} $out/project-files

        ${cfg.extraBuilderCommands}
      '';

    project.packages.path = pkgs.buildEnv {
      name = "project-manager-path-for-${cfg.name}";

      paths = cfg.devPackages;
      inherit (cfg) extraOutputsToInstall;

      postBuild = cfg.extraProfileCommands;

      meta = {
        description = ''
          Environment of packages installed through Project Manager.
        '';
      };
    };

    programs = {
      git.ignores = [
        "/.local/state/project-manager/"
        "/.local/state/nix/profiles/"
      ];
      mercurial.ignoresRooted = [
        ".local/state/project-manager/"
        ".local/state/nix/profiles/"
      ];
    };
    project = {
      checks.project-manager-files =
        pmPkgs.runEmptyCommand "project-manager-files" {
          nativeBuildInputs = [
            config.programs.git.package
            config.programs.project-manager.package
            pkgs.cacert
            pkgs.coreutils
          ];

          meta.description = "Check that the generated files are up-to-date.";
        } ''
          PRJ="$(mktemp --directory --tmpdir project.XXXXXX)"
          cp -r ${self}/. $PRJ
          chmod -R a+w $PRJ
          cd $PRJ
          export HOME="$(mktemp --directory --tmpdir fake-home.XXXXXX)"
          mkdir -p "$HOME/.local/state/nix/profiles"

          export NIX_CONFIG=$(cat <<'CONFIG'
          accept-flake-config = true
          extra-experimental-features = flakes nix-command
          CONFIG
          )

          ## Record the current state of the repo
          git init
          git config user.email nix@localhost
          git config user.name Nix
          git add .
          git commit --message "current files"
          ## Update everything
          project-manager switch --verbose
          ## Make sure there are no changes
          git --no-pager diff --exit-code
        '';

      sandboxedChecks =
        lib.filterAttrs
        (_: value: !(value.__noChroot or false))
        cfg.checks;

      unsandboxedChecks =
        lib.filterAttrs
        (_: value: value.__noChroot or false)
        cfg.checks;

      ## Makes using the configured formatter faster, since it doesn’t have to
      ## evaluate the flake each time.
      sessionVariables = lib.mkIf (cfg ? formatter) {
        __PM_FORMATTER = lib.getExe cfg.formatter;
      };

      extraProfileCommands = ''
        source ${cfg.packages.sessionVariables}/etc/profile.d/pm-session-vars.sh
        source ${cfg.packages.shellAliases}/etc/profile.d/pm-shell-aliases.sh
      '';

      devShells = {
        project-manager = pkgs.checkedDrv (pkgs.mkShell {
          inherit (pkgs) system;
          nativeBuildInputs = [cfg.packages.path];
          shellHook = cfg.extraProfileCommands;
          meta.description = "A shell provided by Project Manager.";
        });

        ## This includes all unsandboxed checks as dependencies, so they can be
        ## run independently of `nix flake check`.
        lax-checks =
          lib.mkIf (cfg.unsandboxedChecks != {})
          (pkgs.checkedDrv (pkgs.mkShell {
            meta.description = ''
              This shell runs all of the checks that are unsandboxed, then
              exits.
            '';
            nativeBuildInputs =
              builtins.attrValues cfg.unsandboxedChecks;

            shellHook = ''
              exit
            '';
          }));
      };

      filterRepositoryPersistedExcept = exceptions: _type: name:
        !(lib.elem name (lib.mapAttrsToList (_k: v: v.target) cfg.file))
        || lib.elem name exceptions;
      filterRepositoryPersisted = cfg.filterRepositoryPersistedExcept [];
      cleanRepositoryPersistedExcept = exceptions: src:
        lib.cleanSourceWith {
          inherit src;
          filter = cfg.filterRepositoryPersistedExcept exceptions;
        };
      cleanRepositoryPersisted = cfg.cleanRepositoryPersistedExcept [];
    };
  };
}
