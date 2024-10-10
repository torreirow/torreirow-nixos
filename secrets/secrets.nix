let
  user1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFH+KiVBYLoBByXonUb7Hq7JfZpJJYag1eK5/EQEQKvp";
  user2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFH+KiVBYLoBByXonUb7Hq7JfZpJJYag1eK5/EQEQKvp";
  users = [ user1 user2 ];

  system1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGt4v9ns8+HmnoyTMGvH7bNpgN4MkTgYst2YgSYzPTfO";
  systems = [ system1 ];
in
{
  "secret1.age".publicKeys = [ user1 system1 ];
  "secret2.age".publicKeys = users ++ systems;
  "togglwtoorren.age".publicKeys = users ++ systems;
  "loboskey.age".publicKeys = users ;
  "spotifywto.age".publicKeys = users ++ systems;
  "atticwto.age".publicKeys = users ++ systems;
}
