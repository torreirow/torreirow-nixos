{config,pkgs,...}: {
programs.zsh = {
      enable = true;
      #autosuggestion.enable = true;
      enableAutosuggestions = true;
      syntaxHighlighting.enable = true; 
      initExtraFirst = ''                                                                                                                        
        eval "$(atuin init zsh --disable-up-arrow)"; '';     
      shellAliases = {
       aws-switch=". $HOME/data/git/technative/Technative-AWS-DevOps-tools/aws-profile-select.sh";
       tfbackend="$HOME/data/git/technative/Technative-AWS-DevOps-tools/tfbackend.sh";
       tfplan="$HOME/data/git/technative/Technative-AWS-DevOps-tools/tfplan.sh";
       tfapply="$HOME/data/git/technative/Technative-AWS-DevOps-tools/tfapply.sh";
       tfunlock="terraform force-unlock -force ";
       
      };
      oh-my-zsh = {
        enable = true;
        #theme = "robbyrussell";
        theme = "gnzh";
        plugins = [
          "git z kubectl emoji encode64 aws terraform"
        ];
        #customPkgs = with pkgs; [                                                                                                                      
        #  nix-zsh-completions                                                                                                                          
        #];  
      };
  };

}
