>My friend and I were talking about films, when I pulled out my smartphone and my friend looked puzzled.
After explaining that I was adding the movie we just discussed to my library, my friend replied, _“Well, we can’t
all have movie gnomes.”_

Now everyone can.

# TheCaptain989’s Movie Gnomes Build **(ALPHA RELEASE)**
A VMware virtual machine with everything you need to manage your movie, TV, and music library.

Though it is a Debian Linux VM, it is meant to be run on Windows.  No Linux experience or virtual machine experience necessary!
The entire thing can be managed via the web browser on your host.

__Capabilities include:__
  - Manage your library via the web browser on your phone
  - Add movies you want to your IMDB Watchlist to have them automatically downloaded
  - Get the video and music quality you want
  - Automatically rename and organize your library
  - Automatically strip out unwanted audio and subtitle streams from movies
  - Automatically download missing subtitles and clean downloaded subs
  - Automatically convert downloaded FLAC music tracks to 320Kbps MP3s
  - Automatically update your existing Kodi database with added movies, TV shows, and music

## Requirements
There are a few prerequisites.  Most of these are optional and the configuration can be changed after install.  Absolutely
required options are marked with an asterisk (*).
  - A media library location* (e.g. NAS)
  - A [shared Kodi database](https://kodi.wiki/view/MySQL/Setting_up_Kodi)
  - A [Newshosting](https://www.newshosting.com/) account
  - An [NZBgeek](https://nzbgeek.info/) account
  - A [GingaDADDY](https://www.gingadaddy.com/) account
  - An [IMDB](https://www.imdb.com/) account
  - A [Subscene](https://subscene.com/) account
  - An [Opensubtitles](https://www.opensubtitles.org/) account

# Installation Instructions
You need to download VMware Player and a couple of files.  Then run the installation.

1. Gather the various login credentials, API keys, etc. required by the installation (see above)
1. Download and install [VMware Workstation Player](https://www.vmware.com/go/getplayer-win) *(tested with v15.5)*  
**NOTE:** If you had/have Hyper-V or Windows Sandbox installed, you'll need to
[disable Windows Device Credential Guard](https://communities.vmware.com/thread/604906 "VMware community page")
for VMware Player to function properly.
1. Download [Movie Gnomes VMware VMX.zip](https://github.com/TheCaptain989/moviegnomes/releases/download/v0.2/Movie.Gnomes.VMware.VMX.zip) and extract it where you want the
virtual machine to run from
1. Download [moviegnomes-0.2.iso](https://github.com/TheCaptain989/moviegnomes/releases/download/v0.2/moviegnomes-0.2.iso) and place it the `\Movie Gnomes` directory created during step 2
1. To create the virtual machine and start the installation, run:  
`"C:\Program Files (x86)\VMware\VMware Player\vmplayer.exe" "<vm_path>\Movie Gnomes\Movie Gnomes.vmx"`
1. Switch to the VM console and complete the guided, automated, Debian installation.
1. After the VM boots into Gnome, let it run for a few minutes to complete the install.
1. Access the various management URLs to complete any configuration.  At a minimum you'll want to import your existing libraries.  
    *Primary portals:*
    Tool | Access URL | Description
    --- | --- | ---
    Radarr | http://moviegnomes:7878/ | *Movie management*
    Sonarr | http://moviegnomes:8989/ | *TV show management*
    Lidarr | http://moviegnomes:8686/ | *Music management*
    Bazarr | http://moviegnomes:6767/ | *Subtitle management*

    *Lesser used portals:*
    Tool | Access URL | Description
    --- | --- | ---
    SABnzbd | http://moviegnomes:8080/ | *NNTP client*
    Kodi-headless | http://moviegnomes:8085/ | *Media manager*
    Webmin | https://moviegnomes:10000/ | *OS management*

---
# FAQ
### Exactly what are 'Movie Gnomes'?
This is a customized and preseeded Debian 10.3 Linux installation CD that includes Docker containers for several popular community
media library tools. The Linux OS is configured to be self-maintaining.  It should require no regular manual maintenance.

The Docker containers are downloaded at installation time to ensure the latest versions. They are configured with inter-linking
APIs and in a way that makes things easy to maintain, and they are self-updating.

Also included is a VMware template configured with the minimum recommended resources to run the OS and all containers, thus
making 'Movie Gnomes' portable.

**NOTE:** No "black level" changes were made to anything.  No source code was installed in Debian, only packages from known
repositories are downloaded and installed.  The containers themselves are left untouched.  There is some database editing, but
it was coded in such as way as to try to be as future proof as possible.  Even the latest version of a badly needed Kodi add-on
is downloaded live.

### Do I have to use VMware?
No. The ISO should mount and boot in any virtualization hypervisor environment.

### Do I have to use Debian?
Not necessarily.  If you prefer another Linux distro, feel free to download the preseeds and script files and customize your own
installation CD.  Though untested, I expect Ubuntu should work with very few script changes.  Other distros may require extensive
script editing.

**NOTE:** You never have to touch Linux to use Movie Gnomes. It just serves as the substrate upon which everything is built.

### Do I have to use Kodi?
No! If you have something else, simply remove the Kodi configuration on the *Connect* tab in Radarr, Sonarr, and Lidarr and add
another connection of your choice, like Plex, for example.

### Do I have to have a SQL database?
No. However, if you use Kodi in a multi-device environment (e.g. on multiple Amazon Fire sticks) you really *really* should consider
it. You'll thank me.  
If you still aren't using a SQL database, disable all the Kodi links and shutdown the kodi-headless container. It's only
purpose in life is to update that database.

### Do I have to use *(blank)* service?
Not at all. Are you subscribed to another news service? Add it and remove Newshosting. Have three other indexers? Add them.

### Okay, I installed it.  Now what?
If you have an existing media library, you should visit your Radarr, Sonarr, and Lidarr portals and bulk import your libraries.
Be prepared for some change, as renaming may be required.  If your library doesn't import, make sure to read the various
[Setup Guide](https://github.com/Radarr/Radarr/wiki/Setup-Guide#folder-structure-and-root-folders
"Radarr Setup Guide - Folder Structure and Root Folders") wikis for each media management tool.

If you are starting a new library, start adding movies or TV shows!

### I'm overwhelmed. This is too much!
It's not that bad, really.  You'll get it in no time.  Everything has been designed to be self-maintaining and most of the
configuration decisions have been made for you.

Start small by visiting your [Radarr portal](http://moviegnomes:7878/) and try adding a movie.

### How does all this work?
Magic

### I don't like the way *(blank)* is configured.
After initial install, this setup is yours. Change it, mold it, extend it.

### What this is NOT!
'Movie Gnomes' does not contain any copyrighted material nor is it a media library. By itself it provides no access to any media.

---
# Credits
This would not have been possible without the following:

https://www.vmware.com/products/workstation-player/workstation-player-evaluation.html  
https://www.docker.com/  
https://www.debian.org/  
[Debian 10.3 CD](https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-10.3.0-amd64-netinst.iso)  
https://hub.docker.com/r/linuxserver/sabnzbd  
https://hub.docker.com/r/thecaptain989/radarr  
https://hub.docker.com/r/linuxserver/sonarr  
https://hub.docker.com/r/linuxserver/bazarr  
https://hub.docker.com/r/thecaptain989/lidarr  
https://hub.docker.com/r/linuxserver/kodi-headless  
https://kodi.wiki/view/MySQL/Setting_up_Kodi  
https://www.newshosting.com/  
https://nzbgeek.info/  
https://www.imdb.com/  
