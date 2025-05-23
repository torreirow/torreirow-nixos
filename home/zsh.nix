{config,pkgs,...}: {
programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
#     zsh.autosuggestion.enable = true;
      #syntaxHighlighting.enable = false; 
      initExtraFirst = ''                                                                                                                        
        eval "$(atuin init zsh --disable-up-arrow)"; 
        PATH=$HOME/bin:$PATH:/home/wtoorren/data/git/wearetechnative/toortools:/home/wtoorren/data/git/wearetechnative/bmc
        '';     

        shellAliases = {
          #tfbackend="$HOME/data/git/technative/Technative-AWS-DevOps-tools/tfbackend.sh";
          #tfplan="$HOME/data/git/technative/Technative-AWS-DevOps-tools/tfplan.sh";
          #tfapply="$HOME/data/git/technative/Technative-AWS-DevOps-tools/tfapply.sh";
          boostmic="pactl set-source-volume 2 190%";
          aws-switch=". $HOME/data/git/wearetechnative/bmc/aws-profile-select.sh";
          tfbackend="$HOME/data/git/wearetechnative/race/tfbackend.sh";
          tfplan="$HOME/data/git/wearetechnative/race/tfplan.sh";
          tfapply="$HOME/data/git/wearetechnative/race/tfapply.sh";
          tfunlock="terraform force-unlock -force ";
          ghrmbranch="for branch in $(git branch |grep -v -i -e main -e master); do git branch -D $branch; done";
          tfswitch="tfswitch -b $HOME/bin/terraform";
          vpnkardisconnect="openvpn3 session-manage --disconnect --config $HOME/.config/openvpn/lobos.ovpn";
          vpnkarconnect="openvpn3 session-start --config $HOME/.config/openvpn/lobos.ovpn";
          qdm="cd ./output; qdm=$(gum choose $(ls -t *.html ; echo none| head -5)); if [[ $qdm != 'none' ]]; then firefox --new-tab $qdm 2>/dev/null;fi";
          smg="smug $(basename -s \".yml\" $(gum filter  $(ls ~/.config/smug/*.yml)))";
          gbdel=" echo Removing branches from git repo: $(basename -s .git \"$(git config --get remote.origin.url)\"); for branch in $(git branch --format=\"%(refname:short)\" | grep -Ev '^(main|master)$'); do echo -n \"Verwijder branch '$branch'? (y/n) \";  read answer ;  [[ $answer == \"y\" ]] && git branch -D \"$branch\"; done";
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
