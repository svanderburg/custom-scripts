gitlike-rsync
=============
`gitlike-rsync` is a tool that facilitates synchronisation of file collections
between directories on local or remote machines with `rsync` and a workflow that
is similar to managing Git repositories.

It can be used for the following purposes:
* A primitive backup tool for syncing to external drives
* A primitive tool to synchronize folders' contents between different machines

Installation
============
As prerequisites, you will need:

* [rsync](https://rsync.samba.org)
* [GNU sed](https://www.gnu.org/software/sed)
* [getopt](http://frodo.looijaard.name/project/getopt)

You can directly run the script stored in this directory.

Alternatively, you can install the script with [Nix](http://nixos.org/nix):

```nix
$ nix-env -f release.nix -iA build.x86_64-linux
```

The Nix installation automatically satisfies the prerequisites shown above.

Use cases
=========
There are varierty of interesting use case scenarios for this tool.

Configuring a destination directory
-----------------------------------
We can configure a destination directory as follows:

```bash
$ cd /media/data
$ gitlike-rsync destination-add /media/MyBackupDrive
```

The above instruction adds `/media/MyBackupDrive` as destination folder
for a data partition `/media/data` that we can use as a backup directory.

Creating a backup of the data partition
---------------------------------------
One of the applications of the `gitlike-rsync` tool is to perform a push
operation that can be used to create a backup.

The following command performs a dry-run operation providing an overview of
the changes that `rsync` intends to make to the destination folder:

```bash
$ cd /media/data
$ gitlike-rsync dry-push
sending incremental file list
.d..tp..... ./
>f+++++++++ bye.txt
>f+++++++++ hello.txt

sent 112 bytes  received 25 bytes  274.00 bytes/sec
total size is 10  speedup is 0.07 (DRY RUN)
```

With the following instruction, we can carry out the push operation for real
which synchronizes the content of the destination directory with the `data/`
directory:

```bash
$ gitlike-rsync push
sending incremental file list
.d..tp..... ./
>f+++++++++ bye.txt
>f+++++++++ hello.txt

sent 112 bytes  received 25 bytes  274.00 bytes/sec
total size is 10  speedup is 0.07 (DRY RUN)
Do you want to proceed (y/N)? y
sending incremental file list
.d..tp..... ./
>f+++++++++ bye.txt
              4 100%    0.00kB/s    0:00:00 (xfr#1, to-chk=1/3)
>f+++++++++ hello.txt
              6 100%    5.86kB/s    0:00:00 (xfr#2, to-chk=0/3)

sent 202 bytes  received 57 bytes  518.00 bytes/sec
total size is 10  speedup is 0.04
```

The above command will always do a dry run and asks for confirmation before it
intends to update anything. By providing the `-y` parameter the confirmation
step can be skipped.

Cloning a directory (locally or remote)
---------------------------------------
We can also automatically clone a directory and configure it in such a way that
it becomes the destination folder of the clone:

```bash
$ gitlike-rsync clone /media/MyBackupDrive copy
```

The above command creates a new folder: `/home/sander/copy` pulls all the
content from the backup partition: `/media/MyBackupDrive`.

In addition to a local directory, we can also create a clone from a remote
directory:

```bash
$ gitlike-rsync clone sander@remotemachine:/home/sander/papers

```

The above command connects to the `remotemachine` over SSH, downloads all
papers from the `/home/sander/papers` folder and puts in the local `papers`
folder. It automatically configures the local directory to synchronize with
the remote diectory.

Pulling all changes made from the destination directory
-------------------------------------------------------
In addition to pushing changed files to a destination, we can also pull changes.

The following command performs a dry-run showing what it intends to change:

```bash
$ gitlike-rsync dry-pull
sending incremental file list
.d..t...... ./
>f+++++++++ hello.txt

sent 137 bytes  received 22 bytes  318.00 bytes/sec
total size is 19  speedup is 0.12 (DRY RUN)
```

The following instruction actually carries out to pull operation:

```bash
$ gitlike-rsync pull
sending incremental file list
.d..t...... ./
>f+++++++++ hello.txt

sent 137 bytes  received 22 bytes  318.00 bytes/sec
total size is 19  speedup is 0.12 (DRY RUN)
Do you want to proceed (y/N)? y
sending incremental file list
.d..t...... ./
>f+++++++++ hello.txt
              6 100%    0.00kB/s    0:00:00 (xfr#1, to-chk=0/4)

sent 183 bytes  received 38 bytes  442.00 bytes/sec
total size is 19  speedup is 0.09
```

A pull operation is typically useful to restore files from a backup drive.

Pushing to multiple destination directories
-------------------------------------------
In addition to a single destination directory, it is also possible to provide
multiple destinations and push changes to them.

The following instruction allows you to query the currently configured
destinations:

```bash
$ gitlike-rsync destination
/media/MyBackupDrive/
```

The above directory has only one destination configured:
`/media/MyBackupDrive/`. It is also possible to add a second destination:

```bash
$ gitlike-rsync destination-add sander@remotemachine:/media/SecondBackupDrive
```

The above instruction configures a backup directory on the `remotemachine`:
`/media/SecondBackupDrive`.

When running a push, it will perform changes on both destination folders:

```bash
$ gitlike-rsync push
```

While it is possible to push to multiple destinations, pulling from multiple
destinations is not allowed, because the tool cannot decide which destination
folder is the source of truth.

Removing a destination folder
-----------------------------
If desired, a destination folder can be removed as follows:

```bash
$ gitlike-rsync destination-rm sander@remotemachine:/media/SecondBackupDrive/
```

The above command removes the previously configured secondary backup directory
on the remote machine.

Ignoring files
--------------
Sometimes it may be desired to ignore certain files when synchronizing
directories, such as the recycle bin directory on a Windows partition.

Files can be added to the ignore list by creating a `.gitlikersync-ignore`
in the root of the configured directory in which each line represents an ignore
pattern:

```bash
$RECYCLE.BIN
```

the above entry causes `rsync` to ignore any file named `$RECYCLE.BIN`.

The above entries get propagated as `--exclude` parameters to the `rsync`
command. To get more information about the accepted patterns, consult the rsync
manual page.

Comparing with checksums
------------------------
By default, `rsync` uses files sizes and modification times to determine file
changes. Although this works fine in almost most cases, it will not detect
changes when files are overwritten, but their sizes and modification time stamps
remain identical.

To cope with these kinds of changes, it is also possible to use the `--checksum`
parameter to do checksum based comparisons.
