How to backup your openHABian server using Amanda
=================================================

# Intro
## The need for recovery
First, make yourself aware how important a comprehensive backup and recovery concept is.
Yes, this text is the README on the backup software part for openHABian that you're reading, but take a couple of minutes to
read and think about recovery in a generic sense first. This might avoid a LOT of frustration.

So you have your smart home working thanks to openHAB(ian).... but what if a component of your system fails ?
First thing is: you need spare hardware of EVERY component that needs to work for your smart home to work.
Think of EVERY relevant component and not just the obvious ones. Think of your Internet router, switch, server, NAS and required
addons such as a ZWave or 433MHz radio or WiFi USB stick, proper power supplies and the SD card writer.
Now think of a recovery concept for each of these components: what do you have to do if it fails ?

If the SD card in your Pi fails because of SD corruption (a very common problem), you need to have a PREinstalled, at least
somewhat current clone SD card to contain all your current OS packages, including all helper programs you might be using (such
as say mosquitto or any scripts you might have installed yourself), and your matching CURRENT openHAB config, and more.
If you believe "in case of SD card crash, I'll simply reinstall my server from scratch", then think first!
How long will that take you? Are you even capable of doing that ? Will the latest version of openHABian/Linux packages be 
guaranteed to work with each other and with your hardware ?
Do you REALLY remember all the parts and places of your system where you configured something related to your server/home
network and smart home ? If you're honest to yourself, the answer will often be "NO".
Yes, you can get your smart home back up working somehow, but it will take several hours, and it will not be a complete
restoration of all features and setups you used to have in operation before the crash.

**One specific word of WARNING:**
If you run a ZWave network like many openHAB users do, think what you need to do if the controller breaks and you need to
replace it. A new controller has a different Home ID, so all of your devices will not talk to it unless you re-include all of them (and
to physically access devices in quite a number of cases means you need to open your walls !!) And even if you have easy access,
it can take many hours, even more so if it's dark and your ... no I'm NOT joking, and I'm not overdoing things.
This is what happened to several people, and it can happen to you, too. We have seen people be so frustrated that they gave up
on openHAB or smart home altogether because of this.
For RaZberry/zwave.me USB stick, you can run the Z-Way software to backup and restore the ZWave network data including the
controller. For the Aeon Gen5 stick, there's a Windows tool available for download.
NOTE: you will face the same type of problem if you run a gateway unit to control commercial systems such as a HomeMatic CCU or Insteon
controller.
Remember Murphy's law: When your system fails and you need to restore your system for the first time, you'll notice your backup
is broken. So dive into and ensure you have a working restore procedure and don't just believe it'll work BUT TEST IT, and
repeat every now and then.

### SD card issues
As there's many many ways of operating a server, we can obviously only support a specific subset of all possible modes.
The most common setup for a openHAB smart home server is to run a Raspberry Pi off its internal SD card, so we provide a backup
concept for that one. But it will also work on most other SBCs (single board computers) and modified configurations (such as if
you moved your OS or parts thereof).

**Another word of WARNING:**
To move your system off the internal SD card does NOT solve SD corruption problems or increase reliability in any other way.
SD cards and USB sticks use the same technology. And SSDs and HDDs still can get corrupted as well, and they can crash, too.
You may or may not have or want to use Internet / cloud services for various reasons (privacy, bandwidth, cost), so we provide
you with one solution that is designed to run on local hardware only. We provide a config to use a directory as the backup
destination. This can be a directory mounted from your NAS (if you have one), a USB-attached storage stick, hard drive, or other
device. We also provide a config to store your most important data on Amazon Web Services if you are not afraid of that.
We believe this will cover most openHAB backup use cases.
NOTE: don't use CIFS (Windows sharing). If you have a NAS, use NFS instead. It does not work with CIFS because of issues with symlinks,
and it doesn't make sense to use a Windows protocol to share a disk from a UNIX server (all NAS) to a UNIX client (openHABian) at all.
If you don't have a NAS, DON'T use your Windows box as the storage server. Attach a USB stick to your Pi instead for storage.
There's many more possible configurations, the software is very flexible and you can tailor it to your own needs if those offers
do not match your needs. You could even use it to backup all of your servers (if any) and desktop PCs, including Windows
machines. Either way, it's not one-or-the-other, you can run multiple configs in parallel. But in any case, you will need to
have a clone SD card with your CURRENT config.

Now all that being said, let's turn to what what you're here for: how to accomplish the software side of backup and restoration.

## Some Amanda background
Best is to read up on and understand some of the basic Amanda concepts over at http://www.amanda.org.
That's not a mandatory step but it will probably help you understand a couple of things better.
The world of UNIX and backup IS complex and in the end, there's no way to fully hide that from a user.
Here's a couple of those concepts, but this is not a comprehensive list. I cannot understand the system for you,
that's something you have to accomplish on your own. Read and understand the Amanda docs.

* It's helpful to know that Amanda was originally built to use magnetic tape changer libraries as backup storage in professional
data center installations. It can operate multiple tape drives in parallel, and the tapes used to be commonly stored in what's
called a 'slot' inside the tape library cabinet.
* The default dumpcycle for a openHABian install is 2 weeks. Amanda will run a 'level 0' dump (that means to backup EVERYTHING)
once in a dumpcycle and will run 'level 1' dumps for the rest of the time (that means to only backup files that have CHANGED
since the last level 0 dump was done, also called an 'incremental' backup).
* Typically, for a backup system to use this methodology, you need the amount of storage to be 2-3 times as large as the amount
of data to be backed up. The number of tapes and their capacity (both of which are sort of artificially set when you store to a
filesystem) determines how long your storage capacity will last until Amanda starts to overwrite old backups. 
By asking you to enter the total size of the storage area, the Amanda installation routine will compute the maximum amount of 
data that Amanda will store into each tape subdirectory as (storage size) divided by (number of tapes, 15 by default).
The ability to backup to a directory was added later, but the 'slot', 'drive' and 'tape' concepts were kept. That's why here,
as a deployment inside openHABian, we will have 'virtual' tapes and slots which are implemented as subdirectories (one for each
'tape') and filesystem links (two by default config, drive0 and drive1) to point to a virtual tape.
If you have the drive1 link point to the slot3 directory, it effectively means that tape 3 is currently inserted in drive 1).
* Amanda was built on top of UNIX and makes use of its user and rights system, so it is very useful and you are requested to
familiarize yourself with that. As a general good UNIX practice, you shouldn’t use functional users such as “backup” (the OS
uses functional users to execute tasks with specific access rights) for administration tasks. Use your personal user instead
(that you have created that at the beginning of your openHABian installation or "openhabian" by default).
Installation tasks including post-package-installation changes (edits) of the Amanda config files, require to use the `root`
user. Any ordinary user (such as your personal one) can execute commands on behalf of root (and with root permission) by
prepending "sudo " to the command.

# Installation
## Storage preparation
Now once you read up on all of this and feel you have understood this stuff, the next step will NOT be hit that 'Amanda install' 
menu option in openHABian (no, we're not there yet) but to prepare your storage.
HEADS UP: You need to "create" (or "provide", actually) your storage BEFORE you install Amanda.
That is, you have to mount the USB stick or disk from your NAS to a directory that is LOCAL to your openHABian box.
Specifically for Windows users: if you are not familiar with the UNIX filesystem concept and what it means 'to mount' storage,
read up on it NOW. A generic (German language) intro can be found at http://www.pc-erfahrung.de/linux/linux-mounten.html.)
Google is your friend, but it'll give a lot of answers, each to vary slightly depending on the Linux variant or use case.
Make sure you ask specific questions such as “how to mount a NAS disk on a raspbian raspberry pi”.
So NOW, prepare your storage by creating a directory somewhere and by then mounting the USB device or disk you've previously
exported (= shared, i.e. made available for mounting) on that directory. This is your mountpoint.

Here's examples how to mount a NAS (to have the DNS name "nas" and IP address 192.168.1.100) and two partitions from an attached
USB stick identified as /dev/sda (Linux ext4 and Windows VFAT filesystems).

HEADS UP: These are just EXAMPLES. Device and directory names will be different on your system.
Do not deploy these commands unless you are fully aware what they will do to your system, using a command with a wrong device 
name can destroy your system.


### NAS mount example

```
----- EXAMPLE ONLY ----- Don't use unless you understand what these commands do ! ----- EXAMPLE ONLY ----- 
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
----- EXAMPLE ONLY ----- Don't use unless you understand what these commands do ! ----- EXAMPLE ONLY ----- 
```

### USB storage mount example

Note that this is showing two alternative versions, for FAT16/FAT32 filesystems (i.e. the original MS-DOS and the improved
Windows filesystems that you usually use for USB sticks) and another version to use the ext4 native Linux filesystem. You can 
use ext4 on a stick or USB-attached hard drive.
Either way, you just need one or the other.

```
----- EXAMPLE ONLY ----- Don't use unless you understand what these commands do ! ----- EXAMPLE ONLY ----- 
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
root@pi:/# mkexfatfs /dev/sda1
mkexfatfs 1.1.0
Creating... done.
Flushing... done.
File system created successfully.
root@pi:/#
root@pi:/home/pi# mkdir -p /storage/usbstick-linux /storage/usbstick-msdos
root@pi:/home/pi# echo "/dev/sda8     /storage/usbstick-linux    ext4     defaults,noatime  0       1" >> /etc/fstab
root@pi:/home/pi# echo "/dev/sda1     /storage/usbstick-msdos    vfat     noatime,noauto,user,uid=backup  0       1" >> /etc/fstab
root@pi:/home/pi# mount /storage/usbstick-linux
root@pi:/home/pi# mount /storage/usbstick-msdos
root@pi:/home/pi# df -k /storage/usbstick-linux /storage/usbstick-msdos
Filesystem     1K-blocks    Used Available  Use% Mounted on
/dev/sda8       13403236 8204144   4495196   65% /storage/usbstick-linux 
/dev/sda1       13403236 9018464   3680876   72% /storage/usbstick-msdos
root@pi:/home/pi#
----- EXAMPLE ONLY ----- Don't use unless you understand what these commands do ! ----- EXAMPLE ONLY -----
```

## Software installation

Next (but only AFTER you successfully mounted/prepared your storage !), install Amanda using the openHABian menu.
When you start the Amanda installation from the openHABian menu, the install routine will create a directory/link structure in
the directory you tell it. Your local user named "backup" will need to have write access there. Amanda install routine should do
that for you, but it only CAN do it for you if you created/mounted it before you ran the installation.

Installation will ask you a couple of questions.
* "What's the directory to store backups into?"
Here you need to enter the _local_ directory of your openHABian box, also known as _the mount point_. This is where you have
mounted your USB storage or NAS disk share (which in above example for the NAS is `/storage/server` and for the usb stick is
either `/storage/usbstick-linux` or `/storage/usbstick-msdos`).
* "How much storage do you want to dedicate to your backup in megabytes ? Recommendation: 2-3 times the amount of data to be
backed up."
Amanda will use at most this number of megabytes in total as its storage for backup.
If you choose to include the raw device in the backup cycle (next question), that means you should enter 3 times the size of
your SD disk NOW. If you choose not to include it (or selected the AWS S3 variant which omits raw SD backups per default), it's
a lot less data and you need to estimate it by adding up the size of the config directories that are listed in the `disklist` 
file. If you don't have any idea, enter 1024 (= 1 GByte). You can change it in the Amanda config file at any later time.
* "Backup raw SD card ?" (not asked if you selected AWS S3 storage)
Answer "yes" if you want to create raw disk backups of your SD card. This is only recommended if your SD card is 8GB or less in
size, otherwise the backup can take too long. You can always add/remove this by editing `${confdir}/disklist` at a later time.

All of your input will be used to create the initial Amanda config files, but you are free to change them later on.
HEADS UP: if you re-run the install routine, it will OVERWRITE the config files at any time so if you make changes there,
remember these changes and store them elsewhere, too.
Once you're done installing openHABian and Amanda, proceed to the usage guide chapter below.

Finally, another HEADS UP: The first thing you should do after your first backup run ended successfully is to create a clone of
your active server SD card by restoring the backup to a blank SD card as shown below as an `amfetchdump` example for recovery of a
raw device's contents. `/dev/mmcblk0` is the Pi's internal SD reader device, and from an Amanda perspective, this is a raw
device to be backed up to have that same name.
You will have two Amanda config directories (located in `/etc/amanda`) called `openhab-dir` and `openhab-AWS` if you choose to
setup both of them.
If any of your Amanda backup or recovery runs fails (which might well be the case particularly if you try to use the S3 backup),
you should try getting it to work following the guides and knowledge base available on the Web at http://www.amanda.org/.
There's online documentation including tutorials and FAQs at http://wiki.zmanda.com/index.php/User_documentation.
In case you come across inherent problems or improvements, please let us (openHABian authors) know through a GitHub issue, but
please don't expect us to guide you through Amanda, which is a rather complex system, and we're basically just users only, too.


# Operating Amanda - a (yes, very brief) usage guide

The overall config is to be found in `/etc/amanda/openhab-<config>/amanda.conf`.
You are free to change this file, but doing so is at your own risk.
You can specify files, directories and raw devices (such as HDD partitions or SD cards) that you want to be backed up in
`/etc/amanda/openhab-<config>/disklist`. You are free to add more lines here to have Amanda also take backup of other
directories of yours.

Note: the raw SD card backup was left out for the AWS S3 config, as that would require a lot of bandwidth and runtime.

openHABian setup routine will create cron entries in `/etc/cron.d/amanda` to start all backups every night at 01:00AM, and to
run a check at 06:00PM. 

## Backup

Find below a terminal session log of a manually started backup run.
It's showing the three most important commands to use. They all can be started as user _backup_ only, interactively or via cron, 
and you always need to specify the config to use. You can have multiple backup configs in parallel use.

The `amcheck` command is meant to remind you to put in the right removeable storage medium such as a tape or SD card,
but for the AWS and local/NAS-mounted directory based backup configs, we don't have removable media. So don't get confused,
`amcheck` is not a required step.

The `amdump` command will start the backup run itself. 
The result will be mailed to you (if your mail system was properly configured which is currently not the case with openHABian).

You can run `amreport <config>` at any time to see a report on the last backup run for that config.

**Reminder:** you have to be logged in as the `backup` user. To accomplish that, you can also login as your ordinary user and
use the `sudo` (execute commands with superuser privileges) and `su` (switch user) commands as shown below.

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
    planner: Adding new disk pi:/etc/openhab2.
    planner: Adding new disk pi:/var/lib/openhab2/persistence.
    planner: Adding new disk pi:/var/lib/openhab2/zwave.
    planner: WARNING: no history available for pi:/var/lib/openhab2/zwave; guessing that size will be 1000000 KB
    planner: WARNING: no history available for pi:/var/lib/openhab2/persistence; guessing that size will be 1000000 KB
    planner: WARNING: no history available for pi:/etc/openhab2; guessing that size will be 1000000 KB
    taper: Slot 3 without label can be labeled
    taper: tape openhab-openhab-dir-001 kb 8141884 fm 4 [OK]
    big estimate: pi /etc/openhab2 0
                    est: 1000032k    out 259820k
    big estimate: pi /var/lib/openhab2/persistence 0
                    est: 1000032k    out 48720k
    big estimate: pi /var/lib/openhab2/zwave 0
                    est: 1000032k    out 1370k


  DUMP SUMMARY:
                                                                       DUMPER STATS   TAPER STATS
  HOSTNAME     DISK                          L  ORIG-kB  OUT-kB  COMP%  MMM:SS   KB/s MMM:SS   KB/s
  -------------------------------------------- ----------------------- -------------- -------------
  pi           /dev/mmcblk0                  0 15645696 7831974   50.1   78:01 1673.2  77:59 1673.9  
  pi           /etc/openhab2                 0   259820  259820     --    0:32 8077.0   0:34 7641.8
  pi           /var/lib/openhab2/persistence 0    48720   48720     --    0:11 4501.6   0:13 3747.7
  pi           /var/lib/openhab2/zwave       0     1370    1370     --    0:01 1156.1   0:01 1370.0

  (brought to you by Amanda version 3.3.6)
```

## Restore

### Restoring a file

To restore a file, you need to use the `amrecover` command as the `root` user.
Note that since Amanda is designed to restore ANY file of the system, you are required to run `amrecover` as the root user to
have the appropriate file access rights.

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

To restore a raw disk partition, you need to use `amfetchdump` command. Unlike `amdump`, you have to run amfetchdump as user backup, though.
Here’s another terminal session log to use `amfetchdump` to first retrieve the backup image from your backup storage to image called
`openhabianpi-image` on `/server/temp/`

**Reminder:** you have to be logged in as the `backup` user. 

```
backup@pi:/server/temp$ amfetchdump -p openhab-dir pi /dev/mmcblk0 > /server/temp/openhabianpi-image
 1 volume(s) needed for restoration
  The following volumes are needed: openhab-openhab-dir-001
  Press enter when ready
```

Before you actually press enter, you should get ready, by opening another terminal window and letting Amanda know in which slot the required
tape is (you can do this also before starting the `amfetchdump` command). You have to find the slot yourself by checking their content. Once
you find out the requested file (probably starting with `00000.`), you redirect amanda to use the slot which contains the file (e.g. slot 1)
using this:

```
backup@pi:/server/temp$ amtape openhab-dir slot 1
slot   1: time 20170322084708 label openhab-openhab-dir-001
changed to slot 1
```

Finally you can go back to the first terminal window and press Enter. Amanda will automatically pick up the other files if the backup
consists of more than one file.

```
amfetchdump: 4: restoring split dumpfile: date 20170322084708 host pi disk /dev/mmcblk0 part 1/UNKNOWN lev 0 comp N program APPLICATION
  927712 kb
```

You can also provide amfetchdump with the date of the backup that you want to restore by adding the date parameter (format e.g. 20180327)
like this:

```
backup@pi:/server/temp$ amfetchdump -p openhab-dir pi /dev/mmcblk0 > /server/temp/openhabianpi-image 20180327
```

This line also shows how to restore this image file to a SD card from Linux. In this example, we have an external SD card writer with a
(blank) SD card attached to /dev/sdd.

```
backup@pi:/server/temp$ dd bs=4M if=/server/temp/openhabianpi-image of=/dev/sdd
```

You could also move that temporary recovered image file to your Windows PC that has a card writer, rename the file to have a .raw extension,
and use Etcher or other tool in order to write the image to the card.


### A final word on when things have gone badly wrong...

and your SD card to contain the Amanda database is broken: don't give up!
Whenever you use a directory as the storage area, openHABian Amanda by default creates a copy of its config and index files (to know what's
stored where) in your storage directory once a day (see `/etc/cron.d/amanda`). So you can reinstall openHABian including Amanda from scratch
and copy back those files. Even if you fail to recover your index files, you can still access the files in your storage area. Backed-up
directories are stored as tar files with a header, here's an example how to decode them:

```
[18:13:29] root@openhabianpi:/volatile/backup/slots/slot7# ls -l
insgesamt 2196552
-rw-rw----+ 1 backup backup      32768 Mär 29 09:29 00000.openhab-dir-007
-rw-rw----+ 1 backup backup   16857088 Mär 29 09:29 00001.openhab._etc.0
-rw-rw----+ 1 backup backup  370219008 Mär 29 09:30 00002.openhab._var_lib_openhab2.0
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
[18:14:49] root@openhabianpi:/volatile/backup/slots/slot7# dd if=00001.openhab._etc.0 bs=32k skip=1|tar tvf -
drwxr-xr-x root/root      2139 2018-03-29 08:50 ./
drwxr-xr-x root/root        15 2018-03-26 17:23 ./.java/
drwxr-xr-x root/root        35 2018-03-26 17:23 ./.java/.systemPrefs/
drwxr-xr-x root/root        31 2018-03-26 17:20 ./PackageKit/
drwxr-xr-x root/root        85 2018-03-26 17:23 ./X11/
drwxr-xr-x root/root         9 2018-03-26 17:23 ./X11/Xreset.d/
drwxr-xr-x root/root        13 2018-03-26 17:23 ./X11/Xresources/
drwxr-xr-x root/root       217 2018-03-26 17:23 ./X11/Xsession.d/
drwxr-xr-x root/root         1 2017-07-18 09:38 ./X11/xkb/
drwxr-xr-x root/root      2380 2018-03-29 08:26 ./alternatives/

...
```
