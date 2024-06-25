{config,pkgs,...}: {
programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
#      zsh.autosuggestion.enable = true;
      #syntaxHighlighting.enable = false; 
      initExtraFirst = ''                                                                                                                        
        eval "$(atuin init zsh --disable-up-arrow)"; 
        PATH=$HOME/bin:$PATH:$HOME/data/git/wearetechnative/race:$HOME/data/git/technative/Technative-AWS-DevOps-tools
        '';     

      shellAliases = {
       aws-switch=". $HOME/data/git/technative/Technative-AWS-DevOps-tools/aws-profile-select.sh";
       tfbackend="$HOME/data/git/technative/Technative-AWS-DevOps-tools/tfbackend.sh";
       tfplan="$HOME/data/git/technative/Technative-AWS-DevOps-tools/tfplan.sh";
       tfapply="$HOME/data/git/technative/Technative-AWS-DevOps-tools/tfapply.sh";
       tfunlock="terraform force-unlock -force ";
       ghrmbranch="for branch in $(git branch |grep -v -i -e main -e master); do git branch -D $branch; done";
       tfswitch="tfswitch -b $HOME/bin/terraform";
       
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
