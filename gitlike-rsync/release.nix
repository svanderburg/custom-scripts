{ nixpkgs ? <nixpkgs>
, systems ? [ "x86_64-linux" "x86_64-darwin" ]
}:

let
  pkgs = import nixpkgs {};
in
rec {
  build = pkgs.lib.genAttrs systems (system:
    let
      pkgs = import nixpkgs { inherit system; };
    in
    pkgs.runCommand "gitlike-rsync" {} ''
      mkdir -p $out/bin
      sed -e "s|/bin/bash|${pkgs.stdenv.shell}|" \
        -e "s|getopt|${pkgs.getopt}/bin/getopt|" \
        -e "s|sed |${pkgs.gnused}/bin/sed |" \
        ${./gitlike-rsync} > $out/bin/gitlike-rsync
      chmod +x $out/bin/gitlike-rsync
    ''
  );

  tests =
    with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

    simpleTest {
      nodes = {
        machine = {pkgs, ...}:

        {
          environment.systemPackages = [ build.x86_64-linux ];
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
}
