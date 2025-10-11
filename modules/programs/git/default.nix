{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.git;

  projectDirectory = config.project.projectDirectory;

  fileType =
    (import ../lib/file-type.nix {
      inherit projectDirectory lib pkgs;
      commit-by-default = config.project.commit-by-default;
    })
    .fileType;

  gitIniType = with types; let
    primitiveType = either str (either bool int);
    multipleType = either primitiveType (listOf primitiveType);
    sectionType = attrsOf multipleType;
    supersectionType = attrsOf (either multipleType sectionType);
  in
    attrsOf supersectionType;

  signModule = types.submodule {
    options = {
      signByDefault = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether commits and tags should be signed by default.
        '';
      };
    };
  };

  includeModule = types.submodule ({config, ...}: {
    options = {
      condition = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Include this configuration only when {var}`condition`
          matches. Allowed conditions are described in
          {manpage}`git-config(1)`.
        '';
      };

      path = mkOption {
        type = with types; either str path;
        description = ''
          Path of the configuration file to include.
        '';
      };

      contents = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        example = lib.literalMD ''
          {
            user = {
              email = "bob@work.example.com";
              name = "Bob Work";
              signingKey = "1A2B3C4D5E6F7G8H";
            };
            commit = {
              gpgSign = true;
            };
          };
        '';
        description = ''
          Configuration to include. If empty then a path must be given.

          This follows the configuration structure as described in
          {manpage}`git-config(1)`.
        '';
      };

      contentSuffix = mkOption {
        type = types.str;
        default = "gitconfig";
        description = ''
          Nix store name for the git configuration text file,
          when generating the configuration text from nix options.
        '';
      };
    };
    config.path = mkIf (config.contents != {}) (mkDefault
      (pkgs.writeText (hm.strings.storeFileName config.contentSuffix)
        (lib.pm.generators.toGitIni config.contents)));
  });
in {
  meta.maintainers = [maintainers.sellout];

  options = {
    programs.git = {
      enable = mkEnableOption "Git";

      package = lib.mkPackageOption pkgs "Git" ({
          default = ["git"];
        }
        // (
          if lib.trivial.release == "22.11"
          then {}
          else {
            extraDescription = ''
              Use {var}`pkgs.gitAndTools.gitFull` to gain access to
              {command}`git send-email` for instance.
            '';
          }
        ));

      config = mkOption {
        type = gitIniType;
        default = {};
        example = {
          core = {whitespace = "trailing-space,space-before-tab";};
          url."ssh://git@host".insteadOf = "otherhost";
        };
        description = ''
          Additional configuration to add.
        '';
      };

      ## TODO: Support “interactive”, where the user has to explicitly approve
      ##       changes during activation.
      installConfig = mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to have Project Manager link the generated config into
          $PROJECT_ROOT/.git/config.
        '';
      };

      signing = mkOption {
        type = types.nullOr signModule;
        default = null;
        description = ''
          Options related to signing commits using GnuPG.
        '';
      };

      ## TODO: Make this an attrset of a DAG of functions that return lines.
      ##       Each hook takes a parameter for each positional argument and the
      ##       config linearizes the DAG and passes strings like
      ##       `$remote_url_XXXXXX` for the arguments, resulting in a
      ##       comprehensive script. Each hook node also has a “builder” arg
      ##       (defaulting to `bash`) and a function for how to generate the arg
      ##       names (really, this should be part of the builder). So it still
      ##       has the flexibility for non-Bash scripts.
      hooks = mkOption {
        # types.nullOr (fileType "programs.git.hooks" "" hooksPath);
        type = types.nullOr (types.attrsOf types.attrs);
        default = {};
        example = lib.literalMD ''
          {
            pre-commit.source = ./pre-commit-script;
          }
        '';
        description = ''
          Configuration helper for Git hooks.
          See <https://git-scm.com/docs/githooks>
          for reference.
        '';
      };

      iniContent = mkOption {
        type = gitIniType;
        internal = true;
      };

      ignores = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        example = ["*~" "*.swp"];
        description = ''
          List of paths that should be globally ignored.
        '';
      };

      ignoreRevs = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        example = ["*~" "*.swp"];
        description = ''
          List of revisions that should be ignored when assigning blame.
        '';
      };

      attributes = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["*.pdf diff=pdf"];
        description = ''
          List of defining attributes set globally.
        '';
      };

      includes = mkOption {
        type = types.listOf includeModule;
        default = [];
        example = lib.literalMD ''
          [
            { path = "~/path/to/config.inc"; }
            {
              path = "~/path/to/conditional.inc";
              condition = "gitdir:~/src/dir";
            }
          ]
        '';
        description = ''
          List of configuration files to include.
        '';
      };

      lfs = {
        enable = mkEnableOption "Git Large File Storage";

        skipSmudge = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Skip automatic downloading of objects on clone or pull.
            This requires a manual {command}`git lfs pull`
            every time a new commit is checked out on your repository.
          '';
        };
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      project = {
        activation.updateGitStatus = pm.dag.entryAfter ["linkGeneration"] (let
          updateStatus = pkgs.writeText "updateStatus" ''
            ${config.lib.bash.initProjectManagerLib}

            # A symbolic link whose target path matches this pattern will be
            # considered part of a Project Manager generation.
            projectFilePattern="$(readlink -e ${escapeShellArg builtins.storeDir})/*-project-manager-files/*"

            newGenFiles="$1"
            shift
            declare -A persistence=( )
            while read -r var value; do
              persistence[$var]=$value
            done < "$newGenFiles/pm-metadata/persistence"
            cd $PROJECT_ROOT
            for sourcePath in "$@" ; do
              [[ $sourcePath =~ pm-metadata ]] && continue
              relativePath="''${sourcePath#$newGenFiles/}"
              if [[ ''${persistence[$relativePath]} == repository ]]; then
                ## We use force here in case the file is covered by an ignore
                ## somewhere.
                ${lib.getExe pkgs.git} add --force --intent-to-add "$relativePath"
              else
                ${lib.getExe pkgs.git} rm --cached --ignore-unmatch "$relativePath"
              fi
            done
          '';
        in ''
          function updateGitStatuses() {
            local newGenFiles
            newGenFiles="$(readlink -e "$newGenPath/project-files")"
            find "$newGenFiles" \( -type f -or -type l \) \
                -exec bash ${updateStatus} "$newGenFiles" {} +
          }

          updateGitStatuses || exit 1
        '');

        ## TODO: This should be conditionally generated, but it creates a cycle
        ##       with other modules (like github) that want to review the list
        ##       of files in order to determine what to add to .gitattributes.
        file.".gitattributes" = {
          minimum-persistence = "worktree";
          text = concatLines cfg.attributes;
        };

        devPackages = [cfg.package];
      };

      programs.vale.excludes = ["./.gitattributes"];

      xdg.cacheFile."git/config" = {
        minimum-persistence = "store";
        onChange =
          if cfg.installConfig
          then ''
            if $(${pkgs.git}/bin/git config --get extensions.worktreeConfig); then
              scope='--worktree'
            else
              scope='--local'
            fi

            ${pkgs.git}/bin/git config "$scope" \
              include.path "${config.xdg.cacheFile."git/config".reference config.xdg.cacheFile."git/config"}"
          ''
          else ''
            if $(${pkgs.git}/bin/git config --get extensions.worktreeConfig); then
              scope='--worktree'
            else
              scope='--local'
            fi

            ${pkgs.git}/bin/git config "$scope" --unset include.path || true
          '';
        text = lib.pm.generators.toGitINI cfg.iniContent;
      };
    }

    (mkIf (cfg.ignores != null) (let
      ## NB: For user config, we use .git/info/exclude instead.
      ignorePath = ".gitignore";
    in {
      ## FIXME: This isn’t handled properly if it’s a symlink, so it needs to
      ##        actually be a copy, but can be added to itself, so we don’t need
      ##        to commit it.
      project.file."${ignorePath}" = {
        minimum-persistence = "worktree";
        broken-symlink = true;
        text = concatLines (mapAttrsToList (n: v: "/" + v.target)
          (filterAttrs (n: v: v.persistence == "worktree") config.project.file)
          ++ cfg.ignores);
      };
    }))

    (mkIf (cfg.signing != null) {
      programs.git.iniContent = {
        commit.gpgSign = mkDefault cfg.signing.signByDefault;
        tag.gpgSign = mkDefault cfg.signing.signByDefault;
      };
    })

    (mkIf (cfg.ignoreRevs != null) (let
      ignoreRevsPath = "git/ignoreRevs";
    in {
      programs.git.iniContent.blame.ignoreRevsFile =
        config.xdg.cacheFile."${ignoreRevsPath}".reference
        config.xdg.cacheFile."git/config";
      xdg.cacheFile."${ignoreRevsPath}" = {
        minimum-persistence = "store";
        text = concatLines cfg.ignoreRevs;
      };
    }))

    (mkIf (cfg.hooks != null) {
      xdg.cacheFile = lib.mapAttrs' (name: file:
        lib.nameValuePair "git/hooks/${name}"
        (lib.mkMerge [
          file
          {
            executable = true;
            minimum-persistence = "store";
          }
        ]))
      cfg.hooks;

      programs.git.iniContent.core.hooksPath =
        if builtins.any (name: config.xdg.cacheFile."git/hooks/${name}".referenceViaStore config.xdg.cacheFile."git/config") (builtins.attrNames cfg.hooks)
        then let
          entries =
            mapAttrsToList (name: file: {
              inherit name;
              path = config.xdg.cacheFile."git/hooks/${name}".reference config.xdg.cacheFile."git/config";
            })
            cfg.hooks;
        in
          toString (pkgs.linkFarm "git-hooks-for-${config.project.name}" entries)
        else lib.pm.path.routeFromFile config.xdg.cacheFile."git/config".target "${config.xdg.cacheDir}/git/hooks";
    })

    (mkIf (lib.isAttrs cfg.config) {
      programs.git.iniContent = cfg.config;
    })

    (mkIf (cfg.includes != []) {
      project.file.".git/config".text = let
        include = i:
          with i;
            if condition != null
            then {
              includeIf.${condition}.path = "${path}";
            }
            else {
              include.path = "${path}";
            };
      in
        mkAfter
        (concatStringsSep "\n" (map lib.pm.generators.toGitINI (map include cfg.includes)));
    })

    (mkIf cfg.lfs.enable {
      project.devPackages = [pkgs.git-lfs];

      programs.git.iniContent.filter.lfs = let
        skipArg = optional cfg.lfs.skipSmudge "--skip";
      in {
        clean = "git-lfs clean -- %f";
        process =
          concatStringsSep " " (["git-lfs" "filter-process"] ++ skipArg);
        required = true;
        smudge =
          concatStringsSep " "
          (["git-lfs" "smudge"] ++ skipArg ++ ["--" "%f"]);
      };
    })
  ]);
}
