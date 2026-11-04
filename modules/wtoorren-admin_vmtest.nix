# VM-test voor modules/wtoorren-admin.nix: één host met het profiel aan en createUser.
#
#   nix build .#checks.x86_64-linux.wtoorren-admin -L
#
# Controleert het runtime-gedrag van de shell: zsh als login-shell, de AWS-wrappers alleen met
# ~/.aws/credentials, en SSH_AUTH_SOCK alleen naar de rbw-agent buiten een ssh-sessie. Daarnaast
# wat het profiel neerzet: bmc-config zonder wl-copy, geen ~/.aws/config, nvim en tmux-config.
{ ... }:

{
  name = "wtoorren-admin";

  nodes.machine = { ... }: {
    toorren.admin.enable = true;
    system.stateVersion = "26.05";
  };

  testScript = ''
    # Interactieve zsh als wtoorren (leest .zshrc), met een schone login-omgeving (su -l) plus
    # eventuele extra variabelen. Het commando gaat via een bestand: geen quoting-gedoe.
    def zsh(cmd, env=""):
        machine.succeed(f"cat > /tmp/cmd.zsh <<'EOF'\n{cmd}\nEOF\nchmod 644 /tmp/cmd.zsh")
        status, out = machine.execute(
            f"su -l wtoorren -c 'env {env} zsh -i /tmp/cmd.zsh' 2>/tmp/zsh.err"
        )
        if status != 0:
            raise Exception(f"zsh faalde ({status}): {machine.succeed('cat /tmp/zsh.err')}")
        return out.strip()

    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("home-manager-wtoorren.service")

    with subtest("account: wheel, ssh-sleutel en zsh"):
        machine.succeed("id -nG wtoorren | grep -qw wheel")
        machine.succeed("getent passwd wtoorren | cut -d: -f7 | grep -q zsh")
        machine.succeed("grep -q 'ssh-ed25519' /etc/ssh/authorized_keys.d/wtoorren")

    with subtest("login-shell zsh werkt"):
        assert zsh("echo $ZSH_VERSION") != "", "zsh start niet"

    with subtest("zonder ~/.aws/credentials geen bmc-functie"):
        machine.succeed("su -l wtoorren -c 'command -v bmc'")
        out = zsh("whence -w bmc")
        assert "function" not in out, out

    with subtest("met ~/.aws/credentials wel"):
        machine.succeed("su -l wtoorren -c 'mkdir -p ~/.aws && touch ~/.aws/credentials'")
        out = zsh("whence -w bmc")
        assert "function" in out, out
        assert "alias" in zsh("whence -w tfplan"), "tfplan-alias ontbreekt"
        machine.succeed("su -l wtoorren -c 'rm ~/.aws/credentials'")

    with subtest("SSH_AUTH_SOCK alleen buiten ssh naar rbw"):
        local = zsh("echo $SSH_AUTH_SOCK")
        assert local.endswith("rbw/ssh-agent-socket"), local
        remote = zsh("echo $SSH_AUTH_SOCK", "SSH_CONNECTION=10.0.0.1:1:10.0.0.2:22 SSH_AUTH_SOCK=/tmp/fwd-agent")
        assert remote == "/tmp/fwd-agent", remote

    with subtest("profielbestanden"):
        machine.succeed("grep -q 'rbw code' /home/wtoorren/.config/bmc/config.json")
        machine.fail("grep -q wl-copy /home/wtoorren/.config/bmc/config.json")
        machine.fail("test -e /home/wtoorren/.aws/config")
        machine.succeed("test -e /home/wtoorren/.config/rbw/config.json")
        machine.succeed("test -e /home/wtoorren/.config/rbw-technative/config.json")
        machine.succeed("test -e /home/wtoorren/.config/tmux/tmux.conf")
        machine.succeed("su -l wtoorren -c 'command -v nvim'")
        machine.succeed("su -l wtoorren -c 'command -v race'")
  '';
}
