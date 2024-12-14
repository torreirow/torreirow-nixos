let
  wtoorren = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFH+KiVBYLoBByXonUb7Hq7JfZpJJYag1eK5/EQEQKvp";
  workload = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIizBgeyIEwUwpuOt0Q2Q9FcIZrJ3lgQg6MBw5AZK3cS";
  users = [ wtoorren workload ];

  wtoorren_workstation = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGt4v9ns8+HmnoyTMGvH7bNpgN4MkTgYst2YgSYzPTfO";
  #prod = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB65TTLa+J49yEthFh98kadBZTIMFQSLO4uw7xgfjGy/";
  prod = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICKG+/j0X7t8IhYpCeLExMV3ddsgC4B7zh5tybEJpnLE";
  nonprod = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMRZYXbx6yNqp7wCxztD2pHILbe+Kou+s15GnNaq0+b1";

  systems = [ nonprod prod wtoorren_workstation ];
  
in

{
  "secret1.age".publicKeys = users ++ [ wtoorren_workstation ];
  "secret2.age".publicKeys = users ++ [ wtoorren_workstation ];
  "togglwtoorren.age".publicKeys = users ++ [ wtoorren_workstation ];
  "loboskey.age".publicKeys = users ++ [ wtoorren_workstation ];
  "spotifywto.age".publicKeys = users ++ [ wtoorren_workstation ];
  "update_laptop.age".publicKeys = users ++ [ wtoorren_workstation ];
  "atticwto.age".publicKeys = users ++ [ wtoorren_workstation ];
  "kar01-lobos-ovpn.age".publicKeys = users ++ [ wtoorren_workstation ];
}
