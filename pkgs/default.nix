{ pkgs ? import <nixpkgs> {} }:

let
  callPackage = pkgs.newScope self;
  self = rec {
    jsonify-aws-dotfiles                  = pkgs.callPackage ./pims-projects/jsonify-aws-dotfiles           { };
    awscliwouter                          = pkgs.callPackage ./awscliwouter           { };
  };
in self
