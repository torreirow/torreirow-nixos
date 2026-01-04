let
  wtoorren = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFH+KiVBYLoBByXonUb7Hq7JfZpJJYag1eK5/EQEQKvp";
  workload = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIizBgeyIEwUwpuOt0Q2Q9FcIZrJ3lgQg6MBw5AZK3cS";
  users = [ wtoorren workload ];

  wtoorren_workstation = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGt4v9ns8+HmnoyTMGvH7bNpgN4MkTgYst2YgSYzPTfO";
  malandro_workstation = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFwxP+MM4rwc6T5g4NZrjSYxQ3yRwlFCK6pnXZt/JWCX";
  #prod = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB65TTLa+J49yEthFh98kadBZTIMFQSLO4uw7xgfjGy/";
  prod = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICKG+/j0X7t8IhYpCeLExMV3ddsgC4B7zh5tybEJpnLE";
  nonprod = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMRZYXbx6yNqp7wCxztD2pHILbe+Kou+s15GnNaq0+b1";

  systems = [ nonprod prod wtoorren_workstation malandro_workstation];
  
in

{
  "secret1.age".publicKeys = users ++ [ wtoorren_workstation malandro_workstation ];
  "secret2.age".publicKeys = users ++ [ wtoorren_workstation malandro_workstation ];
  "togglwtoorren.age".publicKeys = users ++ [ wtoorren_workstation malandro_workstation ];
  "loboskey.age".publicKeys = users ++ [ wtoorren_workstation malandro_workstation ];
  "spotifywto.age".publicKeys = users ++ [ wtoorren_workstation malandro_workstation ];
  "update_laptop.age".publicKeys = users ++ [ wtoorren_workstation malandro_workstation ];
  "atticwto.age".publicKeys = users ++ [ wtoorren_workstation malandro_workstation ];
  "kar01-lobos-ovpn.age".publicKeys = users ++ [ wtoorren_workstation malandro_workstation ];
  "improvement-ovpn.age".publicKeys = users ++ [ wtoorren_workstation malandro_workstation ];
  "aider.age".publicKeys = users ++ [ wtoorren_workstation malandro_workstation ];
  "postgresql-password.age".publicKeys = users ++ [ wtoorren_workstation malandro_workstation ];
  "postgresql-admin-password.age".publicKeys = users ++ [ wtoorren_workstation malandro_workstation ];
  "crowdsec-postgres-password.age".publicKeys = users ++ [ wtoorren_workstation malandro_workstation ];
  "castopod-db-password.age".publicKeys = users ++ [ wtoorren_workstation malandro_workstation ];
  "castopod-admin-password.age".publicKeys = users ++ [ wtoorren_workstation malandro_workstation ];
  "castopod-analytics-salt.age".publicKeys = users ++ [ wtoorren_workstation malandro_workstation ];
  "authelia-jwt.age".publicKeys = users ++ [ wtoorren_workstation malandro_workstation ];
  "authelia-session.age".publicKeys =  users ++ [ wtoorren_workstation malandro_workstation ];
  "authelia-storage.age".publicKeys =  users ++ [ wtoorren_workstation malandro_workstation ];
  "authelia-users.age".publicKeys =  users ++ [ wtoorren_workstation malandro_workstation ];
  "rfc2136.env.age".publicKeys = users ++ [ wtoorren_workstation malandro_workstation ];

  
  # Jitsi Meet passwords
  "jitsi-focus-password.age".publicKeys = users ++ systems;
  "jitsi-jvb-password.age".publicKeys = users ++ systems;
  "jitsi-jibri-password.age".publicKeys = users ++ systems;
  "jitsi-recorder-password.age".publicKeys = users ++ systems;
  
# Monitoring
  "module-monitoring-slack_webhook.age".publicKeys = users ++ systems;
}
