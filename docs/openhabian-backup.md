---
layout: documentation
title: openHABian Backup
source: https://github.com/openhab/openhabian/blob/main/docs/openhabian-backup.md
---

# Backing up openHABian

Accidents happen, electronics wear out, SD cards die, but you don't need to wait until then to prepare for it.
In fact you should not ever do that!

Reconfiguring openHAB and openHABian from scratch can be incredibly painful (trust me, I speak from experience).
If you take a couple of basic precautions and implement some basic backup features when you setup openHABian, you can greatly reduce the chance that you would need to restart from scratch.

We will provide some basic guidance below, please take the time to implement it, we promise you will regret it if you don't!

## What to Prepare For

In an ideal world, you should have a spare for *every* component that you use in your smart home system.
This means having a backup SD card, RPi, router, switch, and any external addons (e.g. ZWave stick).

Since you probably won't actually do that (but you should) here are some simple things that can reduce the headache if it is simply a part of your openHABian instance fails.
But in all reality, we **strongly** recommend getting a ZWave or Zigbee stick of the same model if you use those devices.

### SD Card Failure

One of the most common points of failure in a Raspberry Pi is an SD card failing.
This is why we *strongly* recommend using SD cards that are labelled "Endurance" as they are made for applications like this.

#### SD Mirroring

We have a builtin option to mirror SD cards so that you can always have a backup ready.

If you plan to mirror you SD card using the auto-backup features in openHAB, you should purchase 2 of the same model of SD card when you setup your system.
A different model of SD card may work, but sometimes models differ slightly in size causing issues.
If you can't find the same model, play it safe and buy a model larger than what you currently have to use for your backup.

We also provide a couple of different options to allow you to backup your system to a local NAS, cloud storage, or a second SD card.
For more information on these options, please see [Storage Preparation](#storage-preparation).

##### Moving the Root Filesystem

Moving your system root to a USB stick or SSD is unsupported and dangerous.
It may seem appealing but it cannot be supported by the openHABian maintainers and will not provide a significant amount of additional reliability.

Besides USB sticks and SSD devices still suffer from the same issues as SD cards in the long run.
Overall don't try to do this unless you are confident in what you are doing.

::: danger Moving the Root Filesystem
If you choose to proceed and move your root filesystem, you are on your own!
It is very easy to break your system so proceed with **extreme** caution.
:::

## Builtin Protections

We have included a couple of things with openHABian to reduce the chance of system failure.

### ZRAM

On Raspberry Pi systems with 1+ GB of RAM we install ZRAM by default.
ZRAM helps to reduce wear on the SD card by preventing constant writes to the SD card.
It keeps select logs and persistence data in a compressed RAM disk and then syncs it back to the SD card before shutdown.

The major downside of this is that in the event of sudden power loss you may lose some persistence and logging data.
You can reduce the chance of sudden power loss by putting your openHABian system on a Uninterruptable Power Supply (UPS).

If you would rather not use ZRAM you can use menu option 38 to remove it.

For more information on ZRAM see [zram-config](https://github.com/ecdye/zram-config)

### Auto Backup

We provide a feature that can be setup on first boot to combine SD card mirroring with [Amanda](#amanda) to attempt to automatically configure some sensible backup settings for you as part of the inital install.
It'll essentially mirror your internal SD card to another (bigger) card in an external card reader and uses the remaining space as your Amanda storage area.

To configure this you should purchase a second SD card that is *at least* twice the size of your main SD card.
You will also need an SD to USB adapter to use when plugging in your backup card to your system.

To configure these settings before first boot see [Backup Settings](./openhabian.md#backup-settings) for more information.

These settings can be configured using menu option 50 following first boot as well.

## Amanda

Amanda is a backup solution that is builtin to openHABian to provide rotating backups.
The best way to understand it is to read up on and understand some of the basic Amanda concepts over at [amanda.org](https://www.amanda.org).
Reading more not a mandatory step but it will probably help you understand the basic concepts better.
The world of UNIX and backups *is* complex and in the end, there's no way to fully hide that from you as the user.
Here's a couple of those concepts, but this is not a comprehensive list and if you are having trouble understanding, you will need to read the offical Amanda documentation.

#### History

It's helpful to know that Amanda was originally built to use magnetic tape changer libraries as backup storage in professional data center installations.
These tape changer libraries can operate multiple tape drives in parallel, and a tape commonly stored in what is called a 'slot'.

The ability to backup to a directory was added later, but the 'slot', 'drive' and 'tape' concepts were kept.
That's why in openHABian we will have *virtual* tapes and slots which are implemented as subdirectories (one for each 'tape') and filesystem links (two for the default configuration: `drive0` and `drive1`) which point to a virtual tape.
This means that if you have the `drive1` point to the slot3 directory, it effectively means that tape 3 is currently inserted in drive 1.

#### Amanda on openHABian

The default dumpcycle for an openHABian installation is 2 weeks.
Amanda will run a 'level 0' dump (that means to backup **everything**) once in a dumpcycle and will run 'level 1' dumps for the rest of the time (that means to only backup files that have **changed** since the last level 0 dump was done, also called an 'incremental' backup).
Amanda will combine level 0 of some devices with levels 1 or 2 of others, aiming to have the more or less same amount of data to be backed up every run.

See the Amanda [FAQ](https://wiki.zmanda.com/index.php/FAQ:How_do_I_make_Amanda_do_full_backups_on_weekends_and_incrementals_during_the_week%3F) on full backups for more information.

#### Raw Device Backups

Backing up *raw* devices such as `/dev/mmcblk0` (which is the internal SD card reader of a RPi) can only use a level 0 dump.
So if you include `/dev/mmcblk0` in your disklist, it'll be backed up on *every* run.
If you don't want that (as it'll likely consume the by far largest part of your backup run time and capacity) then remove it from the disklist.
You can create a second Amanda configuration to only include that raw device and run it less often (e.g. monthly).

#### Storage for Amanda

Typically, for a backup system to use this methodology, you need the amount of storage to be 2-3 times as large as the amount of data to be backed up.
The number of tapes and their capacity (both of which are sort of artificially set when you store to a filesystem) determines how long your storage capacity will last until Amanda starts to overwrite old backups.
By asking you to enter the total size of the storage area, the Amanda installation routine will compute the maximum amount of data that Amanda will store into each tape subdirectory as (storage size) divided by (number of tapes, 15 by default).

#### Amanda Filesystem Permissions

Amanda was built on top of UNIX and makes use of its user and rights system, so it is very useful to familiarize yourself with that.
As a general good UNIX practice, you shouldn’t use functional users such as `backup` (the OS uses functional users to execute tasks with specific access rights) for administrative functions.
Use your personal user instead (i.e `openhabian` by default).

Installation tasks including edits of the Amanda config files, require the use the `root` user.
Any ordinary user (such as your personal one) can execute commands on behalf of root (and with root permission) by prepending `sudo` to the command.
As yourself, prepend `sudo -u backup` to execute the following commands as the "backup" user.

### Storage Preparation

Now once you have read up on all of this and feel you have understood this stuff, the next step will be to prepare your storage.

::: tip Important
You need to provide your storage *before* you install Amanda.
:::

You have to mount the USB stick or disk from your NAS to a directory on your openHABian box.
If you don't know what this means in UNIX terms, please do some internet searches now to learn more.
Your mountpoint should be a directory on your Raspberry Pi with the USB device or NAS mounted to.

#### Networked Storage Warnings

If you have a NAS, you should typically export the storage shares using the NFS protocol.

::: warning
If you are a Windows user, please note that CIFS shares are not supported and will not work.
You should use a properly formatted UNIX shares if you are mounting from a NAS.
:::

Amanda does not work with CIFS because of issues with symlinks.
Additionally it doesn't make sense to use a Windows protocol to share a disk from a UNIX server (which is any NAS) to a UNIX client (openHABian) at all.
If you don't have a NAS, **do not** use your Windows box as the storage server.
Attach a USB stick to your Pi instead for storage.

Another specific thing to watch out for when configuring your export share on the NFS server is to add the `no_root_squash` option (that's the name on a generic Linux box, depending on your server OS or UI it might have a different name but it'll be available, too).
Its function is to NOT map accesses of userID 0 (root) to some other UID as your server will do by default.

Here's examples how to mount a NAS (to have the DNS name "nas" and IP address 192.168.1.100) and two partitions from an attached USB stick identified as `/dev/sda8` (Linux ext4) and `/dev/sda1` and Windows vfat(FAT-32) filesystems.

HEADS UP: These are just **examples**.
Device and directory names will be different on your system.
Do not deploy these commands unless you are fully aware what they will do to your system, using a command with a wrong device name can destroy your system.

#### NAS Mount Example

```
----- EXAMPLE ONLY ----- Don't use unless you understand what these commands do! ----- EXAMPLE ONLY -----

pi@pi:~ $ sudo bash
root@pi:/home/pi# host nas
nas.fritz.box has address 192.168.1.100
root@pi:/home/pi#
root@pi:/home/pi# mkdir -p /storage/server
root@pi:/home/pi# echo "192.168.1.100://share/freespace     /storage/server    nfs     nolock,noatime  0       0" >> /etc/fstab
root@pi:/home/pi# mount /storage/server
root@pi:/home/pi# df -k /server
Filesystem                       1K-blocks       Used Available  Use% Mounted on
192.168.1.100://share/freespace 2882740768 2502091488 380649280   87% /storage/server
root@pi:/home/pi#

----- EXAMPLE ONLY ----- Don't use unless you understand what these commands do! ----- EXAMPLE ONLY -----
```

#### USB Mount Example

You cannot use Windows FAT formatting (which is the standard on USB sticks).
You must use the ext4 native Linux filesystem on your stick or USB-attached hard drive.
Remember that the storage area has to be physically (plugged in) and logically (mounted) available anytime Amanda runs.
That's why we do not recommend using removable media, but if you nonetheless do, the non-Windows filesystem will actually also help you in not accidentially unplugging the storage stick.

```
root@pi:/home/pi# fdisk -l /dev/sda
Disk /dev/sda: 14,8 GiB, 15836643328 bytes, 30930944 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel : dos
Disk identifier: 0x000210ce

Device     Boot    Start      End  Sectors  Size Id Type
/dev/sda1           8192  2357421  2349230  1,1G  e W95 FAT16 (LBA)
/dev/sda2        2357422 31116287 28758866 13,7G 85 Linux extended
/dev/sda5        2359296  2424829    65534   32M 83 Linux
/dev/sda6        2424832  2553855   129024   63M  c W95 FAT32 (LBA)
/dev/sda7        2555904 30056445 27500542 13,1G 83 Linux
/dev/sda8       30056448 31105023  1048576  512M 83 Linux
root@pi:/# mke2fs -t ext4  /dev/sda8
mke2fs 1.43.3 (04-Sep-2016)
/dev/sda8 contains a ext4 file system
        created on Sun Oct 29 00:17:48 2017
Proceed anyway? (y,n) y
Creating filesystem with 437248 1k blocks and 109728 inodes
Filesystem UUID: edb36b80-f363-434c-a50e-ca4a81a6bb7d
Superblock backups stored on blocks:
        8193, 24577, 40961, 57345, 73729, 204801, 221185, 401409

Allocating group tables: done
Writing inode tables: done
Creating journal (8192 blocks): done
Writing superblocks and filesystem accounting information: done

root@pi:/home/pi# mkdir -p /storage/usbstick-linux
root@pi:/home/pi# echo "/dev/sda8     /storage/usbstick-linux    ext4     defaults,noatime  0       1" >> /etc/fstab
root@pi:/home/pi# mount /storage/usbstick-linux
root@pi:/home/pi# df -k /storage/usbstick-linux
Filesystem     1K-blocks    Used Available  Use% Mounted on
/dev/sda8       13403236 8204144   4495196   65% /storage/usbstick-linux
root@pi:/home/pi#
```

### Amanda Installation

First, mount/prepare your storage (see examples).
Next, double check that your `backup` user has write access to all of the storage area (preferrably `backup` should **own** the directory).

You can do this by creating a file there: `touch /path/to/storage/test_file`.
Then check its ownership by running: `ls -l /path/to/storage/test_file`.
Finally you can then delete it: `rm /path/to/storage/test_file`.

If that does not produce a file that is owned by the `backup` user, you need to change export options on your NAS/NFS server.
Also ensure you have [no_root_squash`](#storage-preparation) set correctly.

Now finally, install Amanda using the openHABian menu using option 50.
The installation procedure should create the appropriate directory structure in the directory you point it to (which should be the directory your storage is mounted on).
Your local user named `backup` will need to have write access there.
Amanda install routine should do that for you, but it can only do it for you if you created/mounted it before you ran the installation.

Installation will ask you a couple of questions.
-   "What's the directory to store backups into?"
    Here you need to enter the *local* directory of your openHABian box, also known as the *mount point*.
    This is where you have mounted your USB storage or NAS disk share (which in above example for the NAS is `/storage/server` and for the USB stick is `/storage/usbstick-linux`).
-   "How much storage do you want to dedicate to your backup in megabytes?"
    Amanda will use at most this number of megabytes in total as its storage for backup.
    If you choose to include the raw device in the backup cycle (next question), that means you should enter 3 times the size of your SD disk NOW.
    If you choose not to include it (or selected the AWS S3 variant which omits raw SD backups per default), it's a lot less data and you need to estimate it by adding up the size of the config directories that are listed in the `disklist` file.
    If you don't have any idea and chose to NOT backup your SD card, enter 1024 (= 1 GByte).
    If you chose to backup it, the number should be larger than the SD capacity in megabytes plus 1024.
    You can change it in the Amanda config file at any later time (the entry below the line reading `define tapetype DIRECTORY {`).
-   "Backup raw SD card?" (not asked if you selected AWS S3 storage)
    Answer "yes" if you want to create raw disk backups of your SD card.
    This is only recommended if your SD card is 8GB or less in size, otherwise the backup can take too long.
    You can always add/remove this by editing `${confdir}/disklist` at a later time.

All of your input will be used to create the initial Amanda config files, but you are free to change them later on.

::: tip
If you re-run the install routine, it will **overwrite** the config files at any time so if you make changes manually, make sure to save them.
:::

The first thing you should do after your first backup run ended successfully is to create a clone of your active server SD card by restoring the backup to a blank SD card as shown below as an `amfetchdump` example for recovery of a raw device's contents.
`/dev/mmcblk0` is the RPi's internal SD reader device, and from an Amanda perspective, this is a raw device to be backed up to have that same name.
You will have two Amanda config directories (located in `/etc/amanda`) called `openhab-dir` and `openhab-AWS` if you choose to setup both of them.
If any of your Amanda backup or recovery runs fail (particularly if you try to use the S3 backup), you should try getting it to work following the guides and knowledge base available on the web at [amanda.org](https://www.amanda.org).
There's online documentation including tutorials and FAQs at <https://wiki.zmanda.com/index.php/User_documentation>.
In case you come across inherent problems or improvements, please let us (openHABian authors) know through a GitHub issue, but please don't expect us to guide you through Amanda, which is a rather complex system, and we're basically just users only, too.


# Operating Amanda - a (yes, very brief) usage guide

The overall config is to be found in `/etc/amanda/openhab-<config>/amanda.conf`.
You are free to change this file, but doing so is at your own risk.
You can specify files, directories and raw devices (such as HDD partitions or SD cards) that you want to be backed up in `/etc/amanda/openhab-<config>/disklist`.
You are free to add more lines here to have Amanda also take backup of other directories of yours.

Note: the raw SD card backup was left out for the AWS S3 config, as that would require a lot of bandwidth and runtime.

openHABian setup routine will create systemd timers in `/etc/systemd/system/` to start all backups you select every night at around 01:00AM.

## Backup

Find below a terminal session log of a manually started backup run.
It's showing the three most important commands to use.
They all can be started as user _backup_ only, interactively, via systemd.timer or cron, and you always need to specify the config to use.
You can have multiple backup configs in parallel use.

The `amcheck` command is meant to remind you to put in the right removeable storage medium such as a tape or SD card, but for the AWS and local/NAS-mounted directory based backup configs, we don't have removable media.
So don't get confused, `amcheck` is not a required step.

The `amdump` command will start the backup run itself.
The result will be mailed to you (once your mail system was setup - see openHABian menu option 2C).

You can run `amreport [-l=logfile] <config>` at any time to see a report on the last backup run for that config.
Use -l with a filename of /var/log/amanda/<config>/log* to get reports of past dumps.

**Reminder:** you have to be logged in or use `sudo -u backup` to execute commands as the `backup` user.
To accomplish that, you can also login as your ordinary user and use the `sudo` (execute commands with superuser privileges) and `su` (switch user) commands as shown below.

```
pi@pi:/etc/amanda/openhab-dir $ sudo su - backup
backup@pi:~$
backup@pi:~$ amcheck openhab-dir

  Amanda Tape Server Host Check
  -----------------------------
  slot 3: contains an empty volume
  Will write label 'openhab-openhab-dir-001' to new volume in slot 3.
  NOTE: skipping tape-writable test
  NOTE: host info dir /var/lib/amanda/openhab-dir/curinfo/pi does not exist
  NOTE: it will be created on the next run.
  NOTE: index dir /var/lib/amanda/openhab-dir/index/pi does not exist
  NOTE: it will be created on the next run.
  Server check took 2.218 seconds

  Amanda Backup Client Hosts Check
  --------------------------------
  Client check: 1 host checked in 5.705 seconds.  0 problems found.

  (brought to you by Amanda 3.3.6)

  backup@pi:~$ amreport openhab-dir
  nothing to report on!
  backup@pi:~$ amdump openhab-dir
  backup@pi:~$ amreport openhab-dir
  Hostname: pi
  Org     : openHABian openhab-dir
  Config  : openhab-dir
  Date    : März 30, 2017

  These dumps were to tape openhab-openhab-dir-001.
  The next tape Amanda expects to use is: 1 new tape.

  STATISTICS:
                            Total       Full      Incr.   Level:#
                          --------   --------   --------  --------
  Estimate Time (hrs:min)     0:12
  Run Time (hrs:min)          1:31
  Dump Time (hrs:min)         1:19       1:19       0:00
  Output Size (meg)         7951.1     7951.1        0.0
  Original Size (meg)      15581.6    15581.6        0.0
  Avg Compressed Size (%)     51.0       51.0        --
  DLEs Dumped                    4          4          0
  Avg Dump Rate (k/s)       1723.1     1723.1        --

  Tape Time (hrs:min)         1:19       1:19       0:00
  Tape Size (meg)           7951.1     7951.1        0.0
  Tape Used (%)                8.0        8.0        0.0
  DLEs Taped                     4          4          0
  Parts Taped                    4          4          0
  Avg Tp Write Rate (k/s)   1722.4     1722.4        --

  USAGE BY TAPE:
    Label                     Time         Size      %  DLEs Parts
    openhab-openhab-dir-001   1:19     8141884k    8.0     4     4

  NOTES:
    planner: Adding new disk pi:/dev/mmcblk0.
    planner: Adding new disk pi:/etc/openhab.
    planner: Adding new disk pi:/var/lib/openhab/persistence.
    planner: Adding new disk pi:/var/lib/openhab/zwave.
    planner: WARNING: no history available for pi:/var/lib/openhab/zwave; guessing that size will be 1000000 KB
    planner: WARNING: no history available for pi:/var/lib/openhab/persistence; guessing that size will be 1000000 KB
    planner: WARNING: no history available for pi:/etc/openhab; guessing that size will be 1000000 KB
    taper: Slot 3 without label can be labeled
    taper: tape openhab-openhab-dir-001 kb 8141884 fm 4 [OK]
    big estimate: pi /etc/openhab 0
                    est: 1000032k    out 259820k
    big estimate: pi /var/lib/openhab/persistence 0
                    est: 1000032k    out 48720k
    big estimate: pi /var/lib/openhab/zwave 0
                    est: 1000032k    out 1370k


  DUMP SUMMARY:
                                                                       DUMPER STATS   TAPER STATS
  HOSTNAME     DISK                          L  ORIG-kB  OUT-kB  COMP%  MMM:SS   KB/s MMM:SS   KB/s
  -------------------------------------------- ----------------------- -------------- -------------
  pi           /dev/mmcblk0                  0 15645696 7831974   50.1   78:01 1673.2  77:59 1673.9
  pi           /etc/openhab                 0   259820  259820     --    0:32 8077.0   0:34 7641.8
  pi           /var/lib/openhab/persistence 0    48720   48720     --    0:11 4501.6   0:13 3747.7
  pi           /var/lib/openhab/zwave       0     1370    1370     --    0:01 1156.1   0:01 1370.0

  (brought to you by Amanda version 3.3.6)
```

## Restore

### Locating a backup

Depending on the type of storage medium, you may need to locate which volume a wanted backup is stored on.
You can use the `amadmin` and `amtape` commands to do this:

```
[14:24:16] backup@openhabianpi:~$ amadmin openhab-dir find  openhabianpi /dev/mmcblk0 /var/lib/openhab

date                host         disk              lv storage     pool        tape or file    file part  status
2019-12-06 01:00:02 openhabianpi /dev/mmcblk0       0 openhab-dir openhab-dir openhab-dir-005    5   1/1 OK
2019-12-07 01:00:02 openhabianpi /dev/mmcblk0       0 openhab-dir openhab-dir openhab-dir-008    5   1/1 OK
2019-12-08 01:00:02 openhabianpi /dev/mmcblk0       0 openhab-dir openhab-dir openhab-dir-009    5   1/1 OK
2019-12-09 01:00:03 openhabianpi /dev/mmcblk0       0 openhab-dir openhab-dir openhab-dir-010    5   1/1 OK
2019-12-10 01:00:06 openhabianpi /dev/mmcblk0       0 openhab-dir openhab-dir openhab-dir-011    5   1/1 OK
2019-12-11 01:00:03 openhabianpi /dev/mmcblk0       0 openhab-dir openhab-dir openhab-dir-012    5   1/1 OK
2019-12-12 01:00:04 openhabianpi /dev/mmcblk0       0 openhab-dir openhab-dir openhab-dir-013    5   1/1 OK
2019-12-13 01:00:04 openhabianpi /dev/mmcblk0       0 openhab-dir openhab-dir openhab-dir-014    5   1/1 OK
2019-12-14 01:00:03 openhabianpi /dev/mmcblk0       0 openhab-dir openhab-dir openhab-dir-015    5   1/1 OK
2019-12-15 01:00:06 openhabianpi /dev/mmcblk0       0                                            0 -1/-1 FAILED (planner) "[/usr/lib/amanda/application/amraw terminated with signal 15: see /var/log/amanda/client/openhab-dir/sendsize.20191215010011.debug]"
2019-12-16 01:00:03 openhabianpi /dev/mmcblk0       0                                            0 -1/-1 FAILED (planner) "[missing result for /dev/mmcblk0 in openhabianpi response]"
2019-12-17 01:00:03 openhabianpi /dev/mmcblk0       0 openhab-dir openhab-dir openhab-dir-018    5   1/1 OK
2019-12-18 01:00:02 openhabianpi /dev/mmcblk0       0 openhab-dir openhab-dir openhab-dir-019    5   1/1 OK
2019-12-19 01:00:02 openhabianpi /dev/mmcblk0       0 openhab-dir openhab-dir openhab-dir-006    5   1/1 OK
2019-12-30 01:00:03 openhabianpi /dev/mmcblk0       0 openhab-dir openhab-dir openhab-dir-007    5   1/1 OK
2019-12-06 01:00:02 openhabianpi /var/lib/openhab   0 openhab-dir openhab-dir openhab-dir-005    1   1/1 OK
2019-12-07 01:00:02 openhabianpi /var/lib/openhab   0 openhab-dir openhab-dir openhab-dir-008    1   1/1 OK
2019-12-08 01:00:02 openhabianpi /var/lib/openhab   0 openhab-dir openhab-dir openhab-dir-009    1   1/1 OK
2019-12-09 01:00:03 openhabianpi /var/lib/openhab   0 openhab-dir openhab-dir openhab-dir-010    1   1/1 OK
2019-12-10 01:00:06 openhabianpi /var/lib/openhab   0 openhab-dir openhab-dir openhab-dir-011    1   1/1 OK
2019-12-11 01:00:03 openhabianpi /var/lib/openhab   0 openhab-dir openhab-dir openhab-dir-012    1   1/1 OK
2019-12-12 01:00:04 openhabianpi /var/lib/openhab   1 openhab-dir openhab-dir openhab-dir-013    2   1/1 OK
2019-12-13 01:00:04 openhabianpi /var/lib/openhab   0 openhab-dir openhab-dir openhab-dir-014    1   1/1 OK
2019-12-14 01:00:03 openhabianpi /var/lib/openhab   1 openhab-dir openhab-dir openhab-dir-015    2   1/1 OK
2019-12-15 01:00:06 openhabianpi /var/lib/openhab   1 openhab-dir openhab-dir openhab-dir-016    2   1/1 OK
2019-12-17 01:00:03 openhabianpi /var/lib/openhab   0 openhab-dir openhab-dir openhab-dir-018    1   1/1 OK
2019-12-18 01:00:02 openhabianpi /var/lib/openhab   1 openhab-dir openhab-dir openhab-dir-019    1   1/1 OK
2019-12-19 01:00:02 openhabianpi /var/lib/openhab   0 openhab-dir openhab-dir openhab-dir-006    1   1/1 OK
2019-12-30 01:00:03 openhabianpi /var/lib/openhab   0 openhab-dir openhab-dir openhab-dir-007    1   1/1 OK
```

`amtape` can show which volume is in which slot:

```
  [13:59:15] backup@openhabianpi:~$ amtape openhab-dir show
  scanning all 15 slots in changer:
  slot   1: date 20191215010006 label openhab-dir-016
  slot   2: date 20191216010003 label openhab-dir-017
  slot   3: date 20191217010003 label openhab-dir-018
  slot   4: date 20191218010002 label openhab-dir-019
  slot   5: in use
  slot   6: date 20191219010002 label openhab-dir-006
  slot   7: date 20191230010003 label openhab-dir-007
  slot   8: date 20191207010002 label openhab-dir-008
  slot   9: date 20191208010002 label openhab-dir-009
  slot  10: date 20191209010003 label openhab-dir-010
  slot  11: date 20191210010006 label openhab-dir-011
  slot  12: date 20191211010003 label openhab-dir-012
  slot  13: date 20191212010004 label openhab-dir-013
  slot  14: date 20191213010004 label openhab-dir-014
  slot  15: date 20191214010003 label openhab-dir-015
```

### Restoring a file

To restore a file, you need to use the `amrecover` command as the `root` user.
Note that since Amanda is designed to restore ANY file of the system, you are required to run `amrecover` as the root user to have the appropriate file access rights everywhere (neither the `backup` nor your personal user are allowed to write everywhere).
Remember in openHABian you can _execute_ commands as root using `sudo <command>`.

`amrecover` sort of provides a shell-like interface to allow for navigating through the stored files.
Here's another terminal session log to show how a couple of files are restored into a target directory `/server/temp`.

```
  pi@pi:/etc/amanda/openhab-dir $ sudo bash
  root@pi:/etc/amanda/openhab-dir# amrecover openhab-dir
  AMRECOVER Version 3.3.6. Contacting server on localhost ...
  220 pi AMANDA index server (3.3.6) ready.
  Setting restore date to today (2017-03-30)
  200 Working date set to 2017-03-30.
  200 Config set to openhab-dir.
  200 Dump host set to pi.
  Use the setdisk command to choose dump disk to recover
  amrecover> listdisk
  200- List of disk for host pi
  201- /dev/mmcblk0
  201- /etc/openhab
  201- /var/lib/openhab/persistence
  201- /var/lib/openhab/zwave
  200 List of disk for host pi
  amrecover> setdisk /etc/openhab
  200 Disk set to /etc/openhab.
  amrecover> ls
  2017-03-30-13-25-29 quartz.properties
  2017-03-30-13-25-29 login.conf
  2017-03-30-13-25-29 logback_debug.xml
  2017-03-30-13-25-29 logback.xml
  2017-03-30-13-25-29 jetty/
  2017-03-30-13-25-29 configurations/
  2017-03-30-13-25-29 .
  amrecover> add quartz.properties
  Added file /quartz.properties
  amrecover> add logb*
  Added file /logback_debug.xml
  Added file /logback.xml
  amrecover> lcd /server/temp
  amrecover> pwd
  /etc/openhab
  amrecover> lpwd
  /server/temp
  amrecover> extract

  Extracting files using tape drive changer on host localhost.
  The following tapes are needed: openhab-openhab-dir-001

  Extracting files using tape drive changer on host localhost.
  Load tape openhab-openhab-dir-001 now
  Continue [?/Y/n/s/d]? Y
  Restoring files into directory /server/temp
  All existing files in /server/temp can be deleted
  Continue [?/Y/n]? Y

  ./logback.xml
  ./logback_debug.xml
  ./quartz.properties
  amrecover>quit
  root@pi:/etc/amanda/openhab-dir# cd /server/temp
  root@pi:/server/temp# ls -l
  insgesamt 12
  -rw-rw-r-- 1 openhab openhab 2515 Feb 19  2016 logback_debug.xml
  -rw-rw-r-- 1 openhab openhab 3573 Mär 30 06:45 logback.xml
  -rw-r--r-- 1 openhab openhab  302 Feb  3  2016 quartz.properties
  root@pi:/server/temp#
```

### Restoring a partition

To restore a raw disk partition, you need to use `amfetchdump` command.
Unlike `amdump`, you have to run amfetchdump as user backup, though.
Here’s another terminal session log to use `amfetchdump` to first retrieve the backup image from your backup storage to image called `openhabianpi-image` on `/server/temp/`.

**Reminder:** you have to be logged in as the `backup` user.

```
backup@pi:/server/temp$ amfetchdump -p openhab-dir openhabianpi /dev/mmcblk0 20191218010002  > /server/temp/openhabianpi-image
 1 volume(s) needed for restoration
  The following volumes are needed: openhab-openhab-dir-001
  Press enter when ready
```

Remember to specify the date.
If you don't, Amanda will restore ALL available dumps.
That likely is not what you want.
When the partition(s) you specify to restore are stored across multiple (virtual) tapes, Amanda will eventually ask you to mount a specific volume (put a virtual tape into a virtual tape drive).
Be prepared and have another terminal window open as the backup user.
Use `amadmin` (see above) to find out where a specific backup is located.
When in need, you can instruct Amanda to load a specific volume like this:

```
backup@pi:/server/temp$ amtape openhab-dir slot 1
slot   1: time 20170322084708 label openhab-openhab-dir-001
changed to slot 1
```

Finally you can go back to the first terminal window and press <kbd>Enter</kbd>.
Amanda will automatically pick up the other files if the backup consists of more than one file.

```
amfetchdump: 4: restoring split dumpfile: date 20170322084708 host pi disk /dev/mmcblk0 part 1/UNKNOWN lev 0 comp N program APPLICATION
  927712 kb
```

You can also provide amfetchdump with the date of the backup that you want to restore by adding the date parameter (format e.g. 20180327).

```
backup@pi:/server/temp$ amfetchdump -p openhab-dir pi /dev/mmcblk0 > /server/temp/openhabianpi-image 20180327
```

This line also shows how to restore this image file to a SD card from Linux.
In this example, we have an external SD card writer with a (blank) SD card attached to /dev/sdd.

```
backup@pi:/server/temp$ dd bs=4M if=/server/temp/openhabianpi-image of=/dev/sdd
```

You could also move that temporary recovered image file to your Windows PC that has a card writer, rename the file to have a .raw extension, and use Etcher or other tool in order to write the image to the card.


### A final word on when things have gone badly...

If your SD card that contains the Amanda database is broken: you don't have to give up.
Whenever you use a directory as the storage area, openHABian Amanda by default creates a copy of its config and index files (to know what's stored where) in your storage directory once a day (see `/etc/systemd/system/amandaBackupDB.service`).
So you can reinstall openHABian including Amanda from scratch and copy back those files.
See `amadmin import` option.
Even if you fail to recover your index files, you can still access the files in your storage area.
The `amindex` command can be used to regenerate the database.
How to apply unfortunately is out of scope for this document so please use and internet search if needed.
There's also a manual way: Amanda storage files are tar files of the destination directory or compressed raw copies of partitions, both have an additional 32KB header.
If you just want to retrieve some files from a partition backup file, you can mount that file.
See <https://major.io/2010/12/14/mounting-a-raw-partition-file-made-with-dd-or-dd_rescue-in-linux/>.
Here's examples how to decode them:

```
[18:13:29] root@openhabianpi:/volatile/backup/slots/slot7# ls -l
insgesamt 2196552
-rw-rw----+ 1 backup backup      32768 Mär 29 09:29 00000.openhab-dir-007
-rw-rw----+ 1 backup backup   16857088 Mär 29 09:29 00001.openhab._etc.0
-rw-rw----+ 1 backup backup  370219008 Mär 29 09:30 00002.openhab._var_lib_openhab.0
-rw-rw----+ 1 backup backup   22673408 Mär 29 09:30 00003.openhab._boot.0
-rw-rw----+ 1 backup backup 1839450239 Mär 29 09:55 00004.openhab._dev_mmcblk0.0
[18:13:29] root@openhabianpi:/volatile/backup/slots/slot7# head -14 *001*
AMANDA: SPLIT_FILE 20180329091738 openhab /etc  part 1/-1  lev 0 comp N program /bin/tar
DLE=<<ENDDLE
<dle>
  <program>GNUTAR</program>
  <disk>/etc</disk>
  <level>0</level>
  <auth>BSDTCP</auth>
  <record>YES</record>
  <index>YES</index>
  <datapath>AMANDA</datapath>
</dle>
ENDDLE
To restore, position tape at start of file and run:
        dd if=<tape> bs=32k skip=1 | /bin/tar -xpGf - ...
[18:14:49] root@openhabianpi:/volatile/backup/slots/slot7# dd if=00001.openhab._etc.0 bs=32k skip=1 | tar tvf -
drwxr-xr-x root/root      2139 2018-03-29 08:50 ./
drwxr-xr-x root/root        15 2018-03-26 17:23 ./.java/
drwxr-xr-x root/root        35 2018-03-26 17:23 ./.java/.systemPrefs/
drwxr-xr-x root/root        31 2018-03-26 17:20 ./PackageKit/
drwxr-xr-x root/root        85 2018-03-26 17:23 ./X11/
drwxr-xr-x root/root         9 2018-03-26 17:23 ./X11/Xreset.d/

...

[18:14:49] root@openhabianpi:/volatile/backup/slots/slot7# dd if=00004.openhab._dev_mmcblk0.0 bs=32k skip=1 | zcat | dd of=/volatile/temp/restore_file


...
```
