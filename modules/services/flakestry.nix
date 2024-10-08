{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.flakestry;
in {
  meta.maintainers = [lib.maintainers.sellout];

  options.services.flakestry = {
    enable = lib.mkEnableOption "Flakestry";
  };

  config = lib.mkIf cfg.enable {
    ## Written as `lines` instead of an attr set to make it easier to compare
    ## against https://flakestry.dev/publish.
    services.github.workflow."flakestry-publish.yml".text = ''
      name: "Publish a flake to flakestry"
      on:
          push:
              tags:
              - "v?[0-9]+.[0-9]+.[0-9]+"
              - "v?[0-9]+.[0-9]+"
          workflow_dispatch:
              inputs:
                  tag:
                      description: "The existing tag to publish"
                      type: "string"
                      required: true
      jobs:
          publish-flake:
              runs-on: ubuntu-24.04
              permissions:
                  id-token: "write"
                  contents: "read"
              steps:
                  - uses: flakestry/flakestry-publish@main
                    with:
                      version: "''${{ inputs.tag || github.ref_name }}"
    '';
  };
}
