### This configures basic cross-editor formatting.
###
### See https://editorconfig.org/ for more info, and to see if your editor
### requires a plugin to take advantage of it.
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.editorconfig;

  iniFormat = pkgs.formats.ini {};
in {
  meta.maintainers = with maintainers; [sellout];

  options.editorconfig = {
    enable =
      mkEnableOption "EditorConfig project configuration file";

    settings = mkOption {
      type = iniFormat.type;
      default = {};
      description = ''
        Configuration written to {file}`$PROJECT_ROOT/.editorconfig`.
        `root = true` is automatically added to the file,
        it must not be added here.
        See <https://editorconfig.org> for documentation.
      '';
      example = lib.literalMD ''
        {
          "*" = {
            charset = "utf-8";
            end_of_line = "lf";
            trim_trailing_whitespace = true;
            insert_final_newline = true;
            max_line_width = 78;
            indent_style = "space";
            indent_size = 4;
          };
        };
      '';
    };
  };

  config = mkIf (cfg.enable && cfg.settings != {}) {
    programs.vale.excludes = mkIf (config.project.file.".editorconfig".persistence != "store") [
      "./${config.project.file.".editorconfig".target}"
    ];

    project.file.".editorconfig" = {
      ## TODO: This needs to be committed so that it affects the format `check`.
      ##       However, it should really be linked into there from the store
      ##       instead, and this should be “worktree” so that editors can find
      ##       it.
      minimum-persistence = "repository";
      text = lib.pm.generators.toTOML {} {
        globalSection = {root = true;};
        sections = cfg.settings;
      };
    };
  };
}
