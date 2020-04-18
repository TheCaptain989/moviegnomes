>My friend and I were talking about films, when I pulled out my smartphone and my friend looked puzzled.
After explaining that I was adding the movie we just discussed to my library, my friend replied, _“Well, we can’t
all have movie gnomes.”_

Now everyone can.

# TheCaptain989’s Movie Gnomes Build **(ALPHA RELEASE)**
A VMware virtual machine with everything you need to manage your movie, TV, and music library.

Though it is a Debian Linux VM, it is meant to be run on Windows.  No Linux experience or virtual machine experience necessary!
The entire thing can be managed via the web browser on your host.

__Capabilities include:__
  - Manage your library via any web browser, even your phone
  - Add movies you want to your IMDB Watchlist to have them automatically downloaded
  - Automatically rename and organize your library
  - Automatically strip out unwanted audio and subtitle streams from movies
  - Automatically download missing subtitles and clean downloaded subs
  - Automatically convert downloaded FLAC music tracks to 320Kbps MP3s
  - Automatically update your Kodi database with added movies, TV shows, and music

## Requirements
There are a few prerequisites.  Most of these are optional and the configuration can be changed after install.  Absolutely
required options are marked with an asterisk (\*).
  - A media library location\* (e.g. NAS)
  - A [Newshosting](https://www.newshosting.com/) account
  - An [NZBgeek](https://nzbgeek.info/) account
  - A [GingaDADDY](https://www.gingadaddy.com/) account
  - An [IMDB](https://www.imdb.com/) account
  - A [Subscene](https://subscene.com/) account
  - An [Opensubtitles](https://www.opensubtitles.org/) account
  - A [shared Kodi database](https://kodi.wiki/view/MySQL/Setting_up_Kodi) **_or_** you can use the MariaDB in provided by MovieGnomes


# Installation Instructions
You need to download VMware Player and one ZIP file, and then run the installation.  A summary of steps is below, and see
the [Wiki](https://github.com/TheCaptain989/moviegnomes/wiki/Installation "MovieGnomes installation wiki") for more detailed steps.

1. Gather the various login credentials, API keys, etc. required by the installation (see above)
2. Download and install [VMware Workstation Player](https://www.vmware.com/go/getplayer-win)
3. Download [Movie Gnomes VMX.zip](https://github.com/TheCaptain989/moviegnomes/releases/download/v0.4-alpha/Movie.Gnomes.VMX.zip)
and extract it where you want the virtual machine to run from
4. To create the virtual machine and start the installation, run:  
  `"C:\Program Files (x86)\VMware\VMware Player\vmplayer.exe" "<vm_path>\Movie Gnomes\Movie Gnomes.vmx"`  
  Replacing the `<vm_path>` with the directory where you unzipped everything.
5. Switch to the VM console and complete the guided, automated, Debian installation.
6. After the VM boots into Gnome, let it run for about 5 minutess to complete the install.
7. Access the various management URLs to complete any configuration.  At a minimum you'll want to import your existing libraries.  
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

# More information
See the [Wiki](https://github.com/TheCaptain989/moviegnomes/wiki) for more information

---
# Credits
This would not have been possible without the following:

[VMware Workstation 15 Player](https://www.vmware.com/products/workstation-player/workstation-player-evaluation.html)  
[Docker](https://www.docker.com/)  
[Debian](https://www.debian.org/)  
[SABnzbd](https://sabnzbd.org/)  
[Radarr](https://radarr.video/)  
[Sonarr](https://sonarr.tv/)  
[Bazarr](https://www.bazarr.media/)  
[Lidarr](https://lidarr.audio/)  
[Kodi](https://kodi.tv/)  
[MariaDB](https://mariadb.org/)  
[linuxserver.io](https://www.linuxserver.io/)  
[Newshosting](https://www.newshosting.com/)  
[NZBgeek](https://nzbgeek.info/)  
[IMDB](https://www.imdb.com/)  
