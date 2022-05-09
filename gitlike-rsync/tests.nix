{nixpkgs, gitlike-rsync}:

{
  local =
    with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

    simpleTest {
      nodes = {
        machine = {pkgs, ...}:

        {
          environment.systemPackages = [ gitlike-rsync ];
        };
      };
      testScript = ''
        def check_files(directory):
            machine.succeed("grep 'hello' {}/hello.txt".format(directory))
            machine.succeed("grep 'bye' {}/bye.txt".format(directory))


        def check_destinations(num):
            result = machine.succeed("cd /root/data; gitlike-rsync destination | wc -l")

            if int(result) != num:
                raise Exception(
                    "We expect {} destinations, but we found: {} destinations".format(
                        num, result
                    )
                )

        # Create a directory with test files
        machine.succeed("mkdir -p /root/data")
        machine.succeed("echo hello > /root/data/hello.txt")
        machine.succeed("echo bye > /root/data/bye.txt")

        # Add a destination, create a backup, and check if the files are there
        machine.succeed("cd /root/data; gitlike-rsync destination-add /root/backup")
        machine.succeed("cd /root/data; gitlike-rsync dry-push >&2")
        machine.succeed("cd /root/data; gitlike-rsync -y push >&2")
        check_files("/root/backup")

        # Try a push again, it should say that nothing gets synced
        machine.succeed("cd /root/data; gitlike-rsync dry-push >&2")

        # Create a clone of the backup files in a new directory and check if the expected files are there
        machine.succeed("cd /root; gitlike-rsync clone /root/backup data2")
        check_files("/root/data2")

        # Remove a file, do a pull, and check if the files are back again
        machine.succeed("rm /root/data2/hello.txt")
        machine.succeed("cd /root/data2; gitlike-rsync dry-pull >&2")
        machine.succeed("cd /root/data2; gitlike-rsync -y pull")
        check_files("/root/data2")

        # Remove the backup destination from the data directory, add two new destinations, check if the push works
        machine.succeed("cd /root/data; gitlike-rsync destination-rm /root/backup/")
        check_destinations(0)
        machine.succeed("cd /root/data; gitlike-rsync destination-add /root/copya")
        machine.succeed("cd /root/data; gitlike-rsync destination-add /root/copyb")
        check_destinations(2)
        machine.succeed("cd /root/data; gitlike-rsync dry-push >&2")
        machine.succeed("cd /root/data; gitlike-rsync -y push")
        check_files("/root/copya")
        check_files("/root/copyb")

        # Check that pulling is not allowed from multiple destinations
        machine.fail("cd /root/data; gitlike-rsync -y pull")
      '';
    };

  remote =
    with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

    simpleTest {
      nodes = {
        server = {pkgs, ...}:

        {
          services.openssh.enable = true;
          environment.systemPackages = [ gitlike-rsync ];
        };

        client = {pkgs, ...}:

        {
          environment.systemPackages = [ gitlike-rsync ];
        };
      };
      testScript = ''
        import subprocess

        server.wait_for_unit("sshd")

        # Initialise ssh stuff by creating a key pair for communication
        key = subprocess.check_output(
            '${pkgs.openssh}/bin/ssh-keygen -t ecdsa -f key -N ""',
            shell=True,
        )

        # Transfer keys to the machines
        server.copy_from_host("key.pub", "/root/.ssh/authorized_keys")

        client.succeed("mkdir -m 700 /root.ssh")
        client.copy_from_host("key", "/root/.ssh/id_dsa")
        client.succeed("chmod 600 /root/.ssh/id_dsa")
        client.succeed("(echo 'Host *'; echo '    StrictHostKeyChecking no') > /root/.ssh/config")

        # Create a test directory with a file on the server
        server.succeed('mkdir "/root/My Data"')
        server.succeed('echo hello > "/root/My Data/hello.txt"')

        # Clone the directory on the client
        client.succeed("mkdir -p /root/data")
        client.succeed('cd /root/data; gitlike-rsync clone "server:/root/My Data"')
        client.succeed('grep "hello" "/root/data/My Data/hello.txt"')

        # Change the hello.txt file on server and check if the pull works on the client
        server.succeed('echo bye > "/root/My Data/hello.txt"')
        client.succeed('cd "/root/data/My Data"; gitlike-rsync pull -y')
        client.succeed('grep "bye" "/root/data/My Data/hello.txt"')

        # Change the hello.txt file on client and check if the push works from the client
        client.succeed('echo greeting > "/root/data/My Data/hello.txt"')
        client.succeed('cd "/root/data/My Data"; gitlike-rsync push -y')
        server.succeed('grep "greeting" "/root/My Data/hello.txt"')
      '';
  };
}
