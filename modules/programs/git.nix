{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.git;

  # create [section "subsection"] keys from "section.subsection" attrset names
  mkSectionName = name: let
    containsQuote = strings.hasInfix ''"'' name;
    sections = splitString "." name;
    section = head sections;
    subsections = tail sections;
    subsection = concatStringsSep "." subsections;
  in
    if containsQuote || subsections == []
    then name
    else ''${section} "${subsection}"'';

  mkValueString = v: let
    escapedV = ''
      "${
        replaceStrings ["\n" "	" ''"'' "\\"] ["\\n" "\\t" ''\"'' "\\\\"] v
      }"'';
  in
    generators.mkValueStringDefault {} (
      if isString v
      then escapedV
      else v
    );

  # generation for multiple ini values
  mkKeyValue = k: v: let
    mkKeyValue =
      generators.mkKeyValueDefault {inherit mkValueString;} " = " k;
  in
    concatStringsSep "\n" (map (kv: "	" + mkKeyValue kv) (toList v));

  # converts { a.b.c = 5; } to { "a.b".c = 5; } for toINI
  gitFlattenAttrs = let
    recurse = path: value:
      if isAttrs value
      then mapAttrsToList (name: value: recurse ([name] ++ path) value) value
      else if length path > 1
      then {
        ${concatStringsSep "." (reverseList (tail path))}.${head path} = value;
      }
      else {
        ${head path} = value;
      };
  in
    attrs: foldl recursiveUpdate {} (flatten (recurse [] attrs));

  gitToIni = attrs: let
    toIni = generators.toINI {inherit mkKeyValue mkSectionName;};
  in
    toIni (gitFlattenAttrs attrs);

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
        description = "Whether commits and tags should be signed by default.";
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
        description = "Path of the configuration file to include.";
      };

      contents = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        example = literalExpression ''
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
        (gitToIni config.contents)));
  });
in {
  meta.maintainers = [maintainers.sellout];

  options = {
    programs.git = {
      enable = mkEnableOption "Git";

      package = mkOption {
        type = types.package;
        default = pkgs.git;
        defaultText = literalExpression "pkgs.git";
        description = ''
          Git package to install. Use {var}`pkgs.gitAndTools.gitFull`
          to gain access to {command}`git send-email` for instance.
        '';
      };

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

      signing = mkOption {
        type = types.nullOr signModule;
        default = null;
        description = "Options related to signing commits using GnuPG.";
      };

      hooks = mkOption {
        type = types.attrsOf types.path;
        default = {};
        example = literalExpression ''
          {
            pre-commit = ./pre-commit-script;
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
        type = types.listOf types.str;
        default = [];
        example = ["*~" "*.swp"];
        description = "List of paths that should be globally ignored.";
      };

      ignoreRevs = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["*~" "*.swp"];
        description = "List of revisions that should be ignored when assigning blame.";
      };

      attributes = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["*.pdf diff=pdf"];
        description = "List of defining attributes set globally.";
      };

      includes = mkOption {
        type = types.listOf includeModule;
        default = [];
        example = literalExpression ''
          [
            { path = "~/path/to/config.inc"; }
            {
              path = "~/path/to/conditional.inc";
              condition = "gitdir:~/src/dir";
            }
          ]
        '';
        description = "List of configuration files to include.";
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
      ## TODO: This will conflict until we properly scope it to devShell or whatever.
      # project.packages = [cfg.package];

      project.file = let
        persistence = v:
          if
            (
              if v.commit-by-default == null
              then config.project.commit-by-default
              else v.commit-by-default
            )
          then "repository"
          else v.minimum-persistence;
      in {
        ## FIXME: Before enabling this, we might need to figure out how to not
        ##        overwrite the one that’s there already.
        # ".git/config".text = gitToIni cfg.iniContent;

        ## FIXME: This isn’t handled properly if it’s a symlink, so it needs to
        ##        actually be a copy, but can be added to itself, so we don’t
        ##        need to commit it.
        ".gitignore" = {
          minimum-persistence = "worktree";
          broken-symlink = true;
          text =
            concatStringsSep "\n" (mapAttrsToList (n: v: "/" + v.target)
              (filterAttrs (n: v: persistence v == "worktree") config.project.file)
              ++ cfg.ignores)
            + "\n";
        };

        ".gitattributes" = {
          minimum-persistence = "worktree";
          text = concatStringsSep "\n" cfg.attributes + "\n";
        };
      };
    }

    (mkIf (cfg.signing != null) {
      programs.git.iniContent = {
        commit.gpgSign = mkDefault cfg.signing.signByDefault;
        tag.gpgSign = mkDefault cfg.signing.signByDefault;
      };
    })

    (mkIf (cfg.hooks != {}) {
      programs.git.iniContent = {
        core.hooksPath = let
          entries =
            mapAttrsToList (name: path: {inherit name path;}) cfg.hooks;
        in
          toString (pkgs.linkFarm "git-hooks" entries);
      };
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
        (concatStringsSep "\n" (map gitToIni (map include cfg.includes)));
    })

    (mkIf cfg.lfs.enable {
      project.packages = [pkgs.git-lfs];

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
