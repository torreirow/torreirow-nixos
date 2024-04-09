# Linux Kali home-manager installation

- Install nix, use user root:

```zsh
apt-get install nix
groupadd -r nixbl
systemctl enable nix-daemon
systemctl status nix-daemon
systemctl start nix-daemon
usermod -a -G nixbld <users>
usermod -a -G nixusers <users>
echo "export NIX_REMOTE=daemon" >> /etc/zsh/zshrc
chown -R :nix-users /nix/var/nix/daemon-socket
echo "allowed-users = @nix-users"
systemctl restart nix-daemon
```



Following this page: [https://nix-community.github.io/home-manager/#sec-install-standalone](https://nix-community.github.io/home-manager/#sec-install-standalone). But the nix-command gives an error. To fix:

```bash
nix-channel --add https://nixos.org/channels/nixpkgs-unstable
nix-channel --update
```
- Test nix installation
```zsh
nix-instantiate '<nixpkgs>' -A hello
```

-Install **home-manager**
```zsh
nix-shell '<home-manager>' -A install
```
logout and log back in again.






