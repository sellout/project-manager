{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.mercurial;

  iniFormat = pkgs.formats.ini {};
in {
  options = {
    programs.mercurial = {
      enable = mkEnableOption "Mercurial";

      package = mkOption {
        type = types.package;
        default = pkgs.mercurial;
        defaultText = literalExpression "pkgs.mercurial";
        description = "Mercurial package to install.";
      };

      aliases = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "Mercurial aliases to define.";
      };

      extraConfig = mkOption {
        type = types.either (types.attrsOf types.anything) types.lines;
        default = {};
        description = "Additional configuration to add.";
      };

      iniContent = mkOption {
        type = iniFormat.type;
        internal = true;
      };

      ignores = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["*~" "*.swp"];
        description = "List of globs for files to be globally ignored.";
      };

      ignoresRegexp = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["^.*~$" "^.*\\.swp$"];
        description = "List of regular expressions for files to be globally ignored.";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # home.packages = [cfg.package];

      project.file.".hg/hgrc" = {
        persistence = "store";
        source = iniFormat.generate "hgrc" cfg.iniContent;
      };

      project.file.".hgignore" = {
        persistence = "store";
        text =
          ''
            syntax: glob
          ''
          + concatStringsSep "\n" (mapAttrsToList (n: v: v.target)
            (filterAttrs (n: v: v.persistence != "repository") config.project.file)
            ++ cfg.ignores)
          + "\n"
          + ''
            syntax: regexp
          ''
          + concatStringsSep "\n" cfg.ignoresRegexp
          + "\n";
      };
    }

    (mkIf (cfg.aliases != {}) {
      programs.mercurial.iniContent.alias = cfg.aliases;
    })

    (mkIf (lib.isAttrs cfg.extraConfig) {
      programs.mercurial.iniContent = cfg.extraConfig;
    })

    (mkIf (lib.isString cfg.extraConfig) {
      project.file.".hg/hgrc" = {
        persistence = "store";
        text = cfg.extraConfig;
      };
    })
  ]);
}
