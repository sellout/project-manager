{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.flakehub;
in {
  meta.maintainers = [lib.maintainers.sellout];

  options.services.flakehub = {
    enable = lib.mkEnableOption (lib.mdDoc "FlakeHub");

    package = lib.mkPackageOptionMD pkgs "FlakeHub" {
      default = ["fh"];
    };

    mode = lib.mkOption {
      type = lib.types.either lib.types.str (lib.types.attrsOf lib.types.str);
      default = "tagged";
      example = ''{rolling: "main";}'';
      description = lib.mdDoc ''
        This is either the string “tagged” or an attrset with the key “rolling”
        whose value names the branch to watch for rolling changes.
      '';
    };

    name = lib.mkOption {
      description = lib.mdDoc ''
        The name to publish as on FlakeHub. This defaults to “owner/repo”.
      '';
      type = lib.types.str;
      # default = {}; # TODO: Infer from the upstream / origin (default?) remote
    };

    visibility = lib.mkOption {
      description = lib.mdDoc ''
        “unlisted” means that your flake can be accessed by Nix but only appears
        on the website if you directly navigate to it. “public” means that your
        flake can be found by searching.
      '';
      type = lib.types.str;
      default = "unlisted";
    };
  };

  config = lib.mkIf cfg.enable {
    ## Written as `lines` instead of an attr set to make it easier to compare
    ## against https://flakehub.com/new, which this mimics.
    services.github.workflow."flakehub-publish.yml".text =
      if cfg.mode ? rolling
      then ''
        name: "Publish every Git push to ${cfg.mode.rolling} to FlakeHub"
        on:
          push:
            branches:
              - "${cfg.mode.rolling}"
        jobs:
          flakehub-publish:
            runs-on: "ubuntu-latest"
            permissions:
              id-token: "write"
              contents: "read"
            steps:
              - uses: "actions/checkout@v4"
              - uses: "DeterminateSystems/nix-installer-action@main"
              - uses: "DeterminateSystems/flakehub-push@main"
                with:
                  name: "${cfg.name}"
                  rolling: true
                  visibility: "${cfg.visibility}"
      ''
      else ''
        name: "Publish tags to FlakeHub"
        on:
          push:
            tags:
              - "v?[0-9]+.[0-9]+.[0-9]+*"
          workflow_dispatch:
            inputs:
              tag:
                description: "The existing tag to publish to FlakeHub"
                type: "string"
                required: true
        jobs:
          flakehub-publish:
            runs-on: "ubuntu-latest"
            permissions:
              id-token: "write"
              contents: "read"
            steps:
              - uses: "actions/checkout@v4"
                with:
                  ref: "''${{ (inputs.tag != null) && format('refs/tags/{0}', inputs.tag) || ''' }}"
              - uses: "DeterminateSystems/nix-installer-action@main"
              - uses: "DeterminateSystems/flakehub-push@main"
                with:
                  visibility: "${cfg.visibility}"
                  name: "${cfg.name}"
                  tag: "''${{ inputs.tag }}"
      '';
  };
}
