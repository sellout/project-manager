# Just a convenience function that returns the given Nixpkgs standard
# library extended with the HM library.
nixpkgsLib: let
  mkPmLib = import ./.;
in
  nixpkgsLib.extend (self: super: {
    pm = mkPmLib {lib = self;};

    # For forward compatibility.
    literalExpression = super.literalExpression or super.literalExample;
    literalDocBook = super.literalDocBook or super.literalExample;
    # Arrived in Nixpkgs 23.05, so 22.11 needs it spelled out.
    concatLines = super.concatLines or (super.concatMapStrings (s: s + "\n"));
  })
