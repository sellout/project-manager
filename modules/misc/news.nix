{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.news;

  hostPlatform = pkgs.stdenv.hostPlatform;

  entryModule = types.submodule ({config, ...}: {
    options = {
      id = mkOption {
        internal = true;
        type = types.str;
        description = ''
          A unique entry identifier. By default it is a base16
          formatted hash of the entry message.
        '';
      };

      time = mkOption {
        internal = true;
        type = types.str;
        example = "2017-07-10T21:55:04+00:00";
        description = ''
          News entry time stamp in ISO-8601 format. Must be in UTC
          (ending in '+00:00').
        '';
      };

      condition = mkOption {
        internal = true;
        default = true;
        description = "Whether the news entry should be active.";
      };

      message = mkOption {
        internal = true;
        type = types.str;
        description = "The news entry content.";
      };
    };

    config = {
      id = mkDefault (builtins.hashString "sha256" config.message);
    };
  });
in {
  meta.maintainers = [maintainers.rycee];

  options = {
    news = {
      display = mkOption {
        type = types.enum ["silent" "notify" "show"];
        default = "notify";
        description = ''
          How unread and relevant news should be presented when
          running {command}`project-manager build` and
          {command}`project-manager switch`.

          The options are

          `silent`
          : Do not print anything during build or switch. The
            {command}`project-manager news` command still
            works for viewing the entries.

          `notify`
          : The number of unread and relevant news entries will be
            printed to standard output. The {command}`project-manager
            news` command can later be used to view the entries.

          `show`
          : A pager showing unread news entries is opened.
        '';
      };

      entries = mkOption {
        internal = true;
        type = types.listOf entryModule;
        default = [];
        description = "News entries.";
      };

      json = {
        output = mkOption {
          internal = true;
          type = types.package;
          description = "The generated JSON file package.";
        };
      };
    };
  };

  config = {
    news.json.output = pkgs.writeText "pm-news.json" (builtins.toJSON {
      inherit (cfg) display entries;
    });

    # Add news entries in chronological order (i.e., latest time
    # should be at the bottom of the list). The time should be
    # formatted as given in the output of
    #
    #     date --iso-8601=second --universal
    #
    # On darwin (or BSD like systems) use
    #
    #     date -u +'%Y-%m-%dT%H:%M:%S+00:00'
    news.entries = [
      {
        time = "2023-07-25T07:16:09+00:00";
        condition = hostPlatform.isDarwin;
        message = ''
          A new module is available: 'services.git-sync'.
        '';
      }

      {
        time = "2023-08-15T15:45:45+00:00";
        message = ''
          A new module is available: 'programs.xplr'.
        '';
      }

      {
        time = "2023-08-16T15:43:30+00:00";
        message = ''
          A new module is available: 'programs.pqiv'.
        '';
      }

      {
        time = "2023-08-22T16:06:52+00:00";
        message = ''
          A new module is available: 'programs.qcal'.
        '';
      }
    ];
  };
}
