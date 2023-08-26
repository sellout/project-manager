{ config, lib, pkgs, ... }:

with lib;

let

  inherit (config.project) stateVersion;

  cfg = config.project;

in

{
  meta.maintainers = [ maintainers.sellout ];

  options = {
    project.projectDirectory = mkOption {
      type = types.path;
      defaultText = literalExpression "undefined";
      apply = toString;
      example = "./.";
      description = "The project’s root directory relative to this file.";
    };

    project.shellAliases = mkOption {
      type = with types; attrsOf str;
      default = { };
      example = literalExpression ''
        {
          g = "git";
          "..." = "cd ../..";
        }
      '';
      description = ''
        An attribute set that maps aliases (the top level attribute names
        in this option) to command strings or directly to build outputs.

        This option should only be used to manage simple aliases that are
        compatible across all shells. If you need to use a shell specific
        feature then make sure to use a shell specific option, for example
        [](#opt-programs.bash.shellAliases) for Bash.
      '';
    };

    project.sessionVariables = mkOption {
      default = {};
      type = with types; lazyAttrsOf (oneOf [ str path int float ]);
      example = { EDITOR = "emacs"; GS_OPTIONS = "-sPAPERSIZE=a4"; };
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

    project.sessionVariablesPackage = mkOption {
      type = types.package;
      internal = true;
      description = ''
        The package containing the
        {file}`pm-session-vars.sh` file.
      '';
    };

    project.sessionPath = mkOption {
      type = with types; listOf str;
      default = [ ];
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

    project.sessionVariablesExtra = mkOption {
      type = types.lines;
      default = "";
      internal = true;
      description = ''
        Extra configuration to add to the
        {file}`pm-session-vars.sh` file.
      '';
    };

    project.packages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "The set of packages to appear in the user environment.";
    };

    project.extraOutputsToInstall = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "doc" "info" "devdoc" ];
      description = ''
        List of additional package outputs of the packages
        {var}`project.packages` that should be installed into
        the user environment.
      '';
    };

    project.path = mkOption {
      internal = true;
      description = "The derivation installing the user packages.";
    };

    project.emptyActivationPath = mkOption {
      internal = true;
      type = types.bool;
      default = true;
      defaultText = literalExpression "true";
      description = ''
        Whether the activation script should start with an empty
        {env}`PATH` variable. When `false` then the
        user's {env}`PATH` will be accessible in the script. It is
        recommended to keep this at `true` to avoid
        uncontrolled use of tools found in PATH.
      '';
    };

    project.activation = mkOption {
      type = pm.types.dagOf types.str;
      default = {};
      example = literalExpression ''
        {
          myActivationAction = lib.pm.dag.entryAfter ["writeBoundary"] '''
            $DRY_RUN_CMD ln -s $VERBOSE_ARG \
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

    project.activationPackage = mkOption {
      internal = true;
      type = types.package;
      description = "The package containing the complete activation script.";
    };

    project.extraActivationPath = mkOption {
      internal = true;
      type = types.listOf types.package;
      default = [ ];
      description = ''
        Extra packages to add to {env}`PATH` within the activation
        script.
      '';
    };

    project.extraBuilderCommands = mkOption {
      type = types.lines;
      default = "";
      internal = true;
      description = ''
        Extra commands to run in the Project Manager generation builder.
      '';
    };

    project.extraProfileCommands = mkOption {
      type = types.lines;
      default = "";
      internal = true;
      description = ''
        Extra commands to run in the Project Manager profile builder.
      '';
    };

    project.enableNixpkgsReleaseCheck = mkOption {
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
        assertion = config.project.projectDirectory != "";
        message = "Project directory could not be determined";
      }
    ];

    warnings =
      let
        pmRelease = config.project.version.release;
        nixpkgsRelease = lib.trivial.release;
        releaseMismatch =
          config.project.enableNixpkgsReleaseCheck
          && pmRelease != nixpkgsRelease;
      in
        optional releaseMismatch ''
          You are using

            Project Manager version ${pmRelease} and
            Nixpkgs version ${nixpkgsRelease}.

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
    project.sessionVariablesPackage = pkgs.writeTextFile {
      name = "pm-session-vars.sh";
      destination = "/etc/profile.d/pm-session-vars.sh";
      text = ''
        # Only source this once.
        if [ -n "$__PM_SESS_VARS_SOURCED" ]; then return; fi
        export __PM_SESS_VARS_SOURCED=1

        ${config.lib.shell.exportAll cfg.sessionVariables}
      '' + lib.optionalString (cfg.sessionPath != [ ]) ''
        export PATH="$PATH''${PATH:+:}${concatStringsSep ":" cfg.sessionPath}"
      '' + cfg.sessionVariablesExtra;
    };

    project.packages = [ config.project.sessionVariablesPackage ];

    # A dummy entry acting as a boundary between the activation
    # script's "check" and the "write" phases.
    project.activation.writeBoundary = pm.dag.entryAnywhere "";

    # Install packages to the user environment.
    #
    # Note, sometimes our target may not allow modification of the Nix
    # store and then we cannot rely on `nix-env -i`. This is the case,
    # for example, if we are running as a NixOS module and building a
    # virtual machine. Then we must instead rely on an external
    # mechanism for installing packages, which in NixOS is provided by
    # the `users.users.<name?>.packages` option. The activation
    # command is still needed since some modules need to run their
    # activation commands after the packages are guaranteed to be
    # installed.
    #
    # In case the user has moved from a user-install of Project Manager
    # to a submodule managed one we attempt to uninstall the
    # `project-manager-path` package if it is installed.
    project.activation.installPackages = pm.dag.entryAfter ["writeBoundary"] (
      if config.submoduleSupport.externalPackageInstall
      then
        ''
          if [[ -e $PROJECT_ROOT/.nix-profile/manifest.json ]] ; then
            nix profile list \
              | { grep 'project-manager-path$' || test $? = 1; } \
              | cut -d ' ' -f 4 \
              | xargs -t $DRY_RUN_CMD nix profile remove $VERBOSE_ARG
          else
            if nix-env -q | grep '^project-manager-path$'; then
              $DRY_RUN_CMD nix-env -e project-manager-path
            fi
          fi
        ''
      else
        ''
          function nixProfileList() {
            # We attempt to use `--json` first (added in Nix 2.17). Otherwise attempt to
            # parse the legacy output format.
            {
              nix profile list --json 2>/dev/null \
                | jq -r --arg name "$1" '.elements[].storePaths[] | select(endswith($name))'
            } || {
              nix profile list \
                | { grep "$1\$" || test $? = 1; } \
                | cut -d ' ' -f 4
            }
          }

          function nixRemoveProfileByName() {
              nixProfileList "$1" | xargs -t $DRY_RUN_CMD nix profile remove $VERBOSE_ARG
          }

          function nixReplaceProfile() {
            local oldNix="$(command -v nix)"

            nixRemoveProfileByName 'project-manager-path'

            $DRY_RUN_CMD $oldNix profile install $1
          }

          if [[ -e $PROJECT_ROOT/.nix-profile/manifest.json ]] ; then
            INSTALL_CMD="nix profile install"
            INSTALL_CMD_ACTUAL="nixReplaceProfile"
            LIST_CMD="nix profile list"
            REMOVE_CMD_SYNTAX='nix profile remove {number | store path}'
          else
            INSTALL_CMD="nix-env -i"
            INSTALL_CMD_ACTUAL="$DRY_RUN_CMD nix-env -i"
            LIST_CMD="nix-env -q"
            REMOVE_CMD_SYNTAX='nix-env -e {package name}'
          fi

          if ! $INSTALL_CMD_ACTUAL ${cfg.path} ; then
            echo
            _iError $'Oops, Nix failed to install your new Project Manager profile!\n\nPerhaps there is a conflict with a package that was installed using\n"%s"? Try running\n\n    %s\n\nand if there is a conflicting package you can remove it with\n\n    %s\n\nThen try activating your Project Manager configuration again.' "$INSTALL_CMD" "$LIST_CMD" "$REMOVE_CMD_SYNTAX"
            exit 1
          fi
          unset -f nixProfileList nixRemoveProfileByName nixReplaceProfile
          unset INSTALL_CMD INSTALL_CMD_ACTUAL LIST_CMD REMOVE_CMD_SYNTAX
        ''
    );

    # Text containing Bash commands that will initialize the Project Manager Bash
    # library. Most importantly, this will prepare for using translated strings
    # in the `pm-modules` text domain.
    lib.bash.initProjectManagerLib =
      let
        domainDir = pkgs.runCommand "pm-modules-messages" {
          nativeBuildInputs = [ pkgs.buildPackages.gettext ];
        } ''
          mkdir -p "$out"
          # for path in {./po}/*.po; do
          #   lang="''${path##*/}"
          #   lang="''${lang%%.*}"
          #   mkdir -p "$out/$lang/LC_MESSAGES"
          #   msgfmt -o "$out/$lang/LC_MESSAGES/pm-modules.mo" "$path"
          # done
        '';
      in
        ''
          export TEXTDOMAIN=pm-modules
          export TEXTDOMAINDIR=${domainDir}
          source ${../lib/bash/project-manager.sh}
        '';

    project.activationPackage =
      let
        mkCmd = res: ''
            _iNote "Activating %s" "${res.name}"
            ${res.data}
          '';
        sortedCommands = pm.dag.topoSort cfg.activation;
        activationCmds =
          if sortedCommands ? result then
            concatStringsSep "\n" (map mkCmd sortedCommands.result)
          else
            abort ("Dependency cycle in activation script: "
              + builtins.toJSON sortedCommands);

        # Programs that always should be available on the activation
        # script's PATH.
        activationBinPaths = lib.makeBinPath (
          with pkgs; [
            bash
            coreutils
            diffutils           # For `cmp` and `diff`.
            findutils
            gettext
            gnugrep
            gnused
            jq
            ncurses             # For `tput`.
          ]
          ++ config.project.extraActivationPath
        )
        + (
          # Add path of the Nix binaries, if a Nix package is configured, then
          # use that one, otherwise grab the path of the nix-env tool.
          # if config.nix.enable && config.nix.package != null then
          #   ":${config.nix.package}/bin"
          # else
            ":$(${pkgs.coreutils}/bin/dirname $(${pkgs.coreutils}/bin/readlink -m $(type -p nix-env)))"
        )
        + optionalString (!cfg.emptyActivationPath) "\${PATH:+:}$PATH";

        activationScript = pkgs.writeShellScript "activation-script" ''
          set -eu
          set -o pipefail

          cd $PROJECT_ROOT

          export PATH="${activationBinPaths}"
          ${config.lib.bash.initProjectManagerLib}

          ${builtins.readFile ./lib-bash/activation-init.sh}

          if [[ ! -v SKIP_SANITY_CHECKS ]]; then
            checkProjectDirectory ${escapeShellArg config.project.projectDirectory}
          fi

          ${activationCmds}
        '';
      in
        pkgs.runCommand
          "project-manager-generation"
          {
            preferLocalBuild = true;
          }
          ''
            mkdir -p $out

            echo "${config.project.version.full}" > $out/pm-version

            cp ${activationScript} $out/activate

            mkdir $out/bin
            ln -s $out/activate $out/bin/project-manager-generation

            substituteInPlace $out/activate \
              --subst-var-by GENERATION_DIR $out

            ln -s ${config.project-files} $out/project-files
            ln -s ${cfg.path} $out/project-path

            ${cfg.extraBuilderCommands}
          '';

    project.path = pkgs.buildEnv {
      name = "project-manager-path";

      paths = cfg.packages;
      inherit (cfg) extraOutputsToInstall;

      postBuild = cfg.extraProfileCommands;

      meta = {
        description = "Environment of packages installed through project-manager";
      };
    };
  };
}
