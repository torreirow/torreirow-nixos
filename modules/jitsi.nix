{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.jitsi-meet;
  
  # Get secrets from age files
  focusPassword = config.age.secrets.jitsi-focus-password.path;
  jvbPassword = config.age.secrets.jitsi-jvb-password.path;
  jibriPassword = config.age.secrets.jitsi-jibri-password.path;
  recorderPassword = config.age.secrets.jitsi-recorder-password.path;
in {
  options = {
    services.jitsi-meet = {
      enable = mkEnableOption "Jitsi Meet server";
      
      hostName = mkOption {
        type = types.str;
        description = "FQDN of the Jitsi Meet instance.";
        example = "meet.example.org";
      };
      
      config = mkOption {
        type = types.attrs;
        default = {};
        description = "Additional configuration for Jitsi Meet.";
      };
      
      jibri = {
        enable = mkEnableOption "Jibri for recording and streaming";
        
        xorgUsername = mkOption {
          type = types.str;
          default = "jibri";
          description = "Username for Jibri Xorg session.";
        };
        
        recordingDirectory = mkOption {
          type = types.str;
          default = "/var/lib/jibri/recordings";
          description = "Directory to store recordings.";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    # Age secrets for Jitsi passwords
    age.secrets = {
      jitsi-focus-password = {
        file = ../secrets/jitsi-focus-password.age;
        owner = "prosody";
        group = "prosody";
        mode = "0400";
      };
      
      jitsi-jvb-password = {
        file = ../secrets/jitsi-jvb-password.age;
        owner = "jitsi-videobridge";
        group = "jitsi-videobridge";
        mode = "0400";
      };
      
      jitsi-jibri-password = mkIf cfg.jibri.enable {
        file = ../secrets/jitsi-jibri-password.age;
        owner = cfg.jibri.xorgUsername;
        group = cfg.jibri.xorgUsername;
        mode = "0400";
      };
      
      jitsi-recorder-password = mkIf cfg.jibri.enable {
        file = ../secrets/jitsi-recorder-password.age;
        owner = cfg.jibri.xorgUsername;
        group = cfg.jibri.xorgUsername;
        mode = "0400";
      };
    };
    # Enable required services
    services = {
      # Prosody XMPP server
      prosody = {
        enable = true;
        virtualHosts.${cfg.hostName} = {
          enabled = true;
          domain = cfg.hostName;
          extraConfig = ''
            authentication = "anonymous"
            c2s_require_encryption = false
            admins = { }
            modules_enabled = {
              "bosh";
              "pubsub";
              "ping";
            }
          '';
        };
        
        # Conference focus component
        virtualHosts."auth.${cfg.hostName}" = {
          enabled = true;
          domain = "auth.${cfg.hostName}";
          extraConfig = ''
            authentication = "internal_hashed"
          '';
        };
        
        # Conference rooms
        virtualHosts."conference.${cfg.hostName}" = {
          domain = "conference.${cfg.hostName}";
          enabled = true;
          extraConfig = ''
            modules_enabled = {
              "muc_meeting_id";
              "muc_domain_mapper";
            }
            admins = { }
            muc_room_locking = false
            muc_room_default_public_jids = true
          '';
        };
        
        # Jibri components if enabled
        virtualHosts = mkIf cfg.jibri.enable {
          "internal.auth.${cfg.hostName}" = {
            enabled = true;
            domain = "internal.auth.${cfg.hostName}";
            extraConfig = ''
              authentication = "internal_hashed"
            '';
          };
          
          "recorder.${cfg.hostName}" = {
            enabled = true;
            domain = "recorder.${cfg.hostName}";
            extraConfig = ''
              authentication = "internal_hashed"
            '';
          };
        };
        
        # Prosody plugins
        communityModules = [
          "muc_meeting_id"
          "muc_domain_mapper"
          "presence_identity"
          "token_verification"
          "turncredentials"
        ];
      };
      
      # Jicofo (Jitsi Conference Focus)
      jicofo = {
        enable = true;
        config = {
          jicofo = {
            authentication = {
              enabled = true;
              type = "XMPP";
              login-url = "auth.${cfg.hostName}";
            };
            xmpp = {
              client = {
                hosts = [ "${cfg.hostName}" ];
                domain = "auth.${cfg.hostName}";
                username = "focus";
                password-file = focusPassword;
              };
              trusted-domains = [ "recorder.${cfg.hostName}" ];
            };
          };
        };
      };
      
      # Jitsi Videobridge
      jitsi-videobridge = {
        enable = true;
        config = {
          videobridge = {
            apis.xmpp-client = {
              configs = {
                xmpp-server-addresses = [ "${cfg.hostName}" ];
                domain = "${cfg.hostName}";
                username = "jvb";
                password-file = jvbPassword;
                muc-jids = "jvbbrewery@internal.${cfg.hostName}";
                muc-nickname = "jvb-instance";
              };
            };
            ice.udp.port = 10000;
            stats = {
              enabled = true;
              transports = [ { type = "muc"; } ];
            };
          };
        };
      };
      
      # Nginx for serving the web interface
      nginx = {
        enable = true;
        virtualHosts.${cfg.hostName} = {
          enableACME = true;
          forceSSL = true;
          locations = {
            "/" = {
              root = "${pkgs.jitsi-meet}";
              index = "index.html";
              extraConfig = ''
                ssi on;
              '';
            };
            
            "/http-bind" = {
              proxyPass = "http://localhost:5280/http-bind";
              extraConfig = ''
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header Host $host;
              '';
            };
            
            "/external_api.js" = {
              alias = "${pkgs.jitsi-meet}/libs/external_api.min.js";
            };
          };
        };
      };
      
      # Jibri configuration if enabled
      jibri = mkIf cfg.jibri.enable {
        enable = true;
        xorg.enable = true;
        xorg.username = cfg.jibri.xorgUsername;
        config = {
          recording = {
            recordings-directory = cfg.jibri.recordingDirectory;
            finalize-script = "${pkgs.bash}/bin/bash -c 'chmod -R 644 $RECORDING_DIR'";
          };
          
          xmpp = {
            environments = [{
              name = "prod environment";
              xmpp-server-hosts = [ "${cfg.hostName}" ];
              xmpp-domain = "${cfg.hostName}";
              
              control-muc = {
                domain = "internal.${cfg.hostName}";
                room-name = "JibriBrewery";
                nickname = "jibri-nickname";
              };
              
              control-login = {
                domain = "auth.${cfg.hostName}";
                username = "jibri";
                password-file = jibriPassword;
              };
              
              call-login = {
                domain = "recorder.${cfg.hostName}";
                username = "recorder";
                password-file = recorderPassword;
              };
              
              strip-from-room-domain = "conference.";
              usage-timeout = 0;
              trust-all-xmpp-certs = true;
            }];
          };
          
          chrome = {
            flags = [
              "--use-fake-ui-for-media-stream"
              "--start-maximized"
              "--kiosk"
              "--enabled"
              "--disable-infobars"
              "--autoplay-policy=no-user-gesture-required"
            ];
          };
        };
      };
    };
    
    # Firewall configuration
    networking.firewall = {
      allowedTCPPorts = [ 80 443 5222 5280 ];
      allowedUDPPorts = [ 10000 ];
    };
    
    # Create required directories
    system.activationScripts = mkIf cfg.jibri.enable {
      createJibriDirs = ''
        mkdir -p ${cfg.jibri.recordingDirectory}
        chown -R ${cfg.jibri.xorgUsername}:${cfg.jibri.xorgUsername} ${cfg.jibri.recordingDirectory}
        chmod -R 755 ${cfg.jibri.recordingDirectory}
      '';
    };
    
    # Install required packages
    environment.systemPackages = with pkgs; [
      jitsi-meet
      prosody
    ] ++ (if cfg.jibri.enable then [ ffmpeg chromium ] else []);
  };
}
