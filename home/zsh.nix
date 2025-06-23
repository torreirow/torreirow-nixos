{config,pkgs, ...}: {
programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
#     zsh.autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      #initExtraFirst = ''                                                                                                                        
      #  eval "$(atuin init zsh --disable-up-arrow)"; 
      #  PATH=$HOME/bin:$PATH:/home/wtoorren/data/git/wearetechnative/toortools:/home/wtoorren/data/git/wearetechnative/bmc
      #  '';     
  initContent = pkgs.lib.mkBefore ''
    eval "$(atuin init zsh --disable-up-arrow)"
    export PATH="$HOME/bin:$PATH:/home/wtoorren/data/git/wearetechnative/toortools:/home/wtoorren/data/git/wearetechnative/bmc"
  '';

        shellAliases = {
          #aws-switch=". $HOME/data/git/wearetechnative/bmc/aws-profile-select.sh";
          #tfapply="$HOME/data/git/technative/Technative-AWS-DevOps-tools/tfapply.sh";
          #tfbackend="$HOME/data/git/technative/Technative-AWS-DevOps-tools/tfbackend.sh";
          #tfplan="$HOME/data/git/technative/Technative-AWS-DevOps-tools/tfplan.sh";
          aider="/run/keys/wouter/aider";
          aws-switch=". bmc profsel";
          boostmic="pactl set-source-volume 2 190%";
          gbdel=" echo Removing branches from git repo: $(basename -s .git \"$(git config --get remote.origin.url)\"); for branch in $(git branch --format=\"%(refname:short)\" | grep -Ev '^(main|master)$'); do echo -n \"Verwijder branch '$branch'? (y/n) \";  read answer ;  [[ $answer == \"y\" ]] && git branch -D \"$branch\"; done";
          ghrmbranch="for branch in $(git branch |grep -v -i -e main -e master); do git branch -D $branch; done";
          qdm="cd ./output; qdm=$(gum choose $(ls -t *.html ; echo none| head -5)); if [[ $qdm != 'none' ]]; then firefox --new-tab $qdm 2>/dev/null;fi";
          smg="smug $(basename -s \".yml\" $(gum filter  $(ls ~/.config/smug/*.yml)))";
          tfapply="$HOME/data/git/wearetechnative/race/tfapply.sh";
          tfbackend="$HOME/data/git/wearetechnative/race/tfbackend.sh";
          tfplan="$HOME/data/git/wearetechnative/race/tfplan.sh";
          tfswitch="tfswitch -b $HOME/bin/terraform";
          tfunlock="terraform force-unlock -force ";
          vpnkarconnect="openvpn3 session-start --config $HOME/.config/openvpn/lobos.ovpn";
          vpnkardisconnect="openvpn3 session-manage --disconnect --config $HOME/.config/openvpn/lobos.ovpn";
        };


     oh-my-zsh = {
        enable = true;
        theme = "wouter";
        custom = "$HOME/.ohmyzsh-wouter";
        #theme = "gnzh";
        plugins = [
          "git z kubectl emoji encode64 aws terraform"
        ];
        #customPkgs = with pkgs; [                                                                                                                      
        #  nix-zsh-completions                                                                                                                          
        #];  
      };
  };

}
