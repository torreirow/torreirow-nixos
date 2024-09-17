{ pkgs ? import <nixpkgs> {} }:

let
  callPackage = pkgs.newScope self;
  self = rec {
    jsonify-aws-dotfiles                  = pkgs.callPackage ./pims-projects/jsonify-aws-dotfiles           { };
  };
in self
