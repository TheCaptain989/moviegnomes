#!/bin/sh

# Leaned on these docs heavily
#  https://manpages.debian.org/buster/debconf-doc/debconf-devel.7.en.html
#  http://www.fifi.org/doc/debconf-doc/tutorial.html

# This is a debconf-compatible script
. /usr/share/debconf/confmodule

# This conf script is capable of backing up
db_capb backup

# Create the template file
cat >/tmp/moviegnomes.dat <<EOF
### Splash screens
Template: moviegnomes/title
Type: title
Description: TheCaptain989's Movie Gnomes (ALPHA RELEASE)

Template: moviegnomes/splash
Type: note
Description: Welcome to TheCaptain989's Movie Gnomes Installation
 This is a custom Debian Linux install designed to provide and configure all the necessary
 tools to fully automate the management of your movie, TV, and music library.
 These tools include Docker and containers for SABnzbd, Radarr, Sonarr, Bazarr, Lidarr, and Kodi
 .
 Capabilities include:
  - Manage your library via any web browser, even your phone
  - Add movies to your IMDB Watchlist to have them automatically downloaded
  - Rename your videos and keep them tidy
  - Automatically strip out unwanted audio and subtitle streams
  - Automatically download missing subtitles and clean downloaded subs
  - Automatically convert downloaded FLAC music tracks to MP3s
  - Automatically update your Kodi database with added movies, TV shows, and music

Template: moviegnomes/splash2
Type: note
Description: Required Services
 This installation requires the use of internet services and a place to store downloaded content.
 Exactly what is required is dependent upon which components you select.
 The default services list is included below, but you may add, remove, or change these post install.
 .
 Requirements:
  - A media library location (e.g. NAS or your local PC)
  - A shared Kodi database hostname, port, username, and password
    (https://kodi.wiki/view/MySQL/Setting_up_Kodi) 
  - A Newshosting login (https://www.newshosting.com/)
  - An NZBgeek API key (https://nzbgeek.info/)
  - A GingaDADDY API key (https://www.gingadaddy.com/)
  - An IMDB Watchlist ID (https://www.imdb.com/)
  - A Subscene login (https://subscene.com/)
  - An Opensubtitles login (https://www.opensubtitles.org/)
 .
 You will be asked for this information on the next screens.

Template: moviegnomes/splash3
Type: note
Description: URLs to Know
 To access the various applications running in the Docker containers after install, and to make configuration
 changes, use the URLs below:
  SABnzbd: http://moviegnomes:8080/
  Radarr: http://moviegnomes:7878/
  Sonarr: http://moviegnomes:8989/
  Bazarr: http://moviegnomes:6767/
  Lidarr: http://moviegnomes:8686/
  Kodi: http://moviegnomes:8085/
 .
 You can manage the Debian host by using Webmin, or login to the Debian OS using the console or SSH.  The username is 'user',
 and the password, as well as the root password, are included in the accompanying documentation.
 .
 Webmin: https://moviegnomes:10000/

### Components questions
Template: moviegnomes/components/title
Type: title
Description: Movie Gnomes Components

Template: moviegnomes/components/select
Type: multiselect
Choices: SABnzbd - Usenet downloader,Radarr - Movie manager and NZB scraper,Sonarr - TV show manager and NZB scraper,Bazarr - Subtitle manager and downloader,Lidarr - Music manager and NZB scraper,Kodi Headless - Media library manager,MariaDB - Media library database
Choices-C: SABnzbd,Radarr,Sonarr,Bazarr,Lidarr,Kodi,MySQL
Default: SABnzbd,Radarr,Sonarr,Bazarr,Lidarr,Kodi
Description: Select the containers you want to install
 Some more information about the containers:
 .
  - SABnzbd is used by Radarr, Sonarr, and Lidarr to download NZB files.
  - Bazarr requires either Radarr or Sonarr.
  - Kodi Headless requires a SQL database, but it can use an existing one.
  - MariaDB is a media library database used by Kodi Headless (NOTE: not a container). Only select this if you don't already have your own database.

### Newshosting questions
Template: moviegnomes/news/title
Type: title
Description: Newshosting.com Credentials

Template: moviegnomes/news/user
Type: string
Description: Enter your Newshosting.com username
 Your Newshosting.com credentials are used by SABnzbd. This can be changed later
 in the SZBnzbd configuration after install.

Template: moviegnomes/news/pass
Type: password
Description: Enter your Newshosting.com password

Template: moviegnomes/news/hidden
Type: string
Description: NOT TO BE DISPLAYED

### Indexer questions
Template: moviegnomes/indexer/title
Type: title
Description: NZB Indexer API Keys

Template: moviegnomes/indexer/key1
Type: string
Description: Enter your NZBgeek API key
 Your NZBgeek.info API key is used by Radarr, Sonarr, and Lidarr. This can be changed
 later in the various configurations after install.
 .
 EX: abcdef0123456789abcdef0123456789

Template: moviegnomes/indexer/key2
Type: string
Description: Enter your GingaDADDY API key
 Your GingaDADDY.com API key is used by Sonarr. This can be changed
 later in the Sonarr configuration after install.
 .
 EX: abcdef0123456789abcdef0123456789

### IMDB questions
Template: moviegnomes/imdb/title
Type: title
Description: IMDB List ID

Template: moviegnomes/imdb/list
Type: string
Description: Enter your IMDB List ID
 Your IMDB.com Watchlist ID is used by Radarr to auto add movies. This can be changed
 later in the Radarr configuration after install.
 .
 EX: ur1234567
 .
 NOTE: The Watchlist must be marked as publicly readable!

### Kodi questions
Template: moviegnomes/kodi/title
Type: title
Description: Kodi Database Info

Template: moviegnomes/kodi/host
Type: string
Description: \${DBDESCSHORT}
 \${DBDESCLONG}
 .
 Kodi Headless will use this information to connect to the database.

Template: moviegnomes/kodi/port
Type: string
Default: 3306
Description: Enter your database port

Template: moviegnomes/kodi/user
Type: string
Default: kodi
Description: Enter your database username
 Kodi Headless will use these credentials to connect to the database.
 ${DBUSER}

Template: moviegnomes/kodi/pass
Type: password
Description: Enter your database password

Template: moviegnomes/kodi/hidden
Type: string
Description: NOT TO BE DISPLAYED

### Library questions
Template: moviegnomes/library/title
Type: title
Description: Library Information

Template: moviegnomes/library/user
Type: string
Description: Enter your media library username
 These credentials will be used to connect the Debian host and Kodi to your media libraries.
 NOTE: The same username and password will be used for all libraries
 (movie, TV, music).
 .
 Also note, this username should have read-write access to the libraries.

Template: moviegnomes/library/pass
Type: password
Description: Enter your media library password

Template: moviegnomes/library/hidden
Type: string
Description: NOT TO BE DISPLAYED

Template: moviegnomes/library/videopath
Type: string
Default: smb://
Description: Enter the path to your video library
 This is the fully qualified path to your videos in Linux path format. This will be used to access both movies and TV shows.
 .
 This can be changed later by manually editing the following files post install:
  /docker/kodi/userdata/sources.xml
  /docker/kodi/userdata/mediasources.xml
  /docker/kodi/userdata/passwords.xml
  /etc/fstab
 .
 EX: smb://my_nas/Videos/

Template: moviegnomes/library/musicpath
Type: string
Default: smb://
Description: Enter the path to your music library
 This is the fully qualified path to your music files.
 .
 EX: smb://my_nas/Music/

### Bazarr questions
Template: moviegnomes/subs/title
Type: title
Description: Subtitle Services

Template: moviegnomes/subs/subscene/user
Type: string
Description: Enter your Subscene username
 Your Subscene.com login is used by Bazarr. This can be changed
 later in the Bazarr configuration after install.

Template: moviegnomes/subs/subscene/pass
Type: password
Description: Enter your Subscene password

Template: moviegnomes/subs/subscene/hidden
Type: string
Description: NOT TO BE DISPLAYED

Template: moviegnomes/subs/opensub/user
Type: string
Description: Enter your OpenSubtitles username
 Your OpenSubtitles.org login is used by Bazarr. This can be changed
 later in the Bazarr configuration after install.

Template: moviegnomes/subs/opensub/pass
Type: password
Description: Enter your OpenSubtitles password

Template: moviegnomes/subs/opensub/hidden
Type: string
Description: NOT TO BE DISPLAYED

### Errors
Template: moviegnomes/error/title
Type: title
Description: Invalid Selection

Template: moviegnomes/error/bazarr
Type: error
Description: Selection Error
 Bazarr requires either Radarr or Sonarr to also be installed.
 .
 Please correct your selections.

Template: moviegnomes/error/sql
Type: error
Description: Selection Error
 MariaDB doesn't make sense without Kodi.
 .
 Please correct your selections.

Template: moviegnomes/warning/title
Type: title
Description: Possible Selection Error

Template: moviegnomes/warning/sab
Type: error
Description: Did you make a mistake?
 You selected one of the managers (Radarr, Sonarr, or Lidarr) without selecting SABnzbd.
 This is valid if you have your own download client you'd like to configure, but is unusual.
 .
 The use of SABnzbd is highly encouraged due to the automatic cross-container configuration that MovieGnomes
 does, including API keys and drive mappings. Manually setting this up is an advanced topic and one of the most
 common causes of errors and user frustration.
EOF

# Load the template
db_x_loadtemplatefile /tmp/moviegnomes.dat thecaptain989

# Setting these in case we're only using the adv-preseed.cfg (manual install chosen)
db_set netcfg/get_hostname moviegnomes
db_set netcfg/get_domain ""

# Main
STATE=1
while [ "$STATE" != 0 -a "$STATE" != 11 ]; do
  case "$STATE" in
  1)
    # Show splash screens
    db_settitle moviegnomes/title
    db_input critical moviegnomes/splash
    db_input critical moviegnomes/splash2
  ;;

  2)
    # Break it up a little
    db_input critical moviegnomes/splash3
  ;;

  3)
    # Select components
    db_settitle moviegnomes/components/title
    db_input critical moviegnomes/components/select
  ;;

  4)
    # Ask Library questions
    db_settitle moviegnomes/library/title
    db_input critical moviegnomes/library/videopath
    db_input critical moviegnomes/library/musicpath
    db_input critical moviegnomes/library/user
    db_input critical moviegnomes/library/pass
  ;;

  5)
    if [ "$KODI" = 1 ]; then
      # Ask Kodi questions
      if [ "$SQL" = 0 ]; then
        db_subst moviegnomes/kodi/host DBDESCSHORT "Enter your database hostname"
        db_subst moviegnomes/kodi/host DBDESCLONG "Your Kodi database is an existing MySQL or MariaDB used to store all Kodi library data.
This can be changed later by manually editing the /docker/kodi/userdata/advancedsettings.xml file after install."
      else
        db_subst moviegnomes/kodi/host DBDESCSHORT "The hostname of the MovieGnomes server"
        db_subst moviegnomes/kodi/host DBDESCLONG "Configure the MariaDB installation here. The hostname entered here must be the same as the Debian server.
Accept the default if you are unsure."
        db_subst moviegnomes/kodi/user DBUSER "This database user will be created."
        # Check if 
        db_get moviegnomes/kodi/host
        if [ "$RET" = "" ]; then
          db_get netcfg/get_hostname
          db_set moviegnomes/kodi/host $RET
        fi
      fi
      db_settitle moviegnomes/kodi/title
      db_input critical moviegnomes/kodi/host
      db_input critical moviegnomes/kodi/port
      db_input critical moviegnomes/kodi/user
      db_input critical moviegnomes/kodi/pass
    fi
  ;;

  6)
    if [ "$SAB" = 1 ]; then
      # Ask Newshosting questions
      db_settitle moviegnomes/news/title
      db_input critical moviegnomes/news/user
      db_input critical moviegnomes/news/pass
    fi
  ;;

  7)
    if [ "$RADARR" = 1 -o "$SONARR" = 1 -o "$LIDARR" = 1 ]; then
      # Ask Indexer questions
      db_settitle moviegnomes/indexer/title
      db_input critical moviegnomes/indexer/key1
      db_input critical moviegnomes/indexer/key2
    fi
  ;;

  8)
    if [ "$RADARR" = 1 ]; then
      # Ask IMDB questions
      db_settitle moviegnomes/imdb/title
      db_input critical moviegnomes/imdb/list
    fi
  ;;

  9)
    if [ "$BAZARR" = 1 ]; then
      # Ask Subtitle questions
      db_settitle moviegnomes/subs/title
      db_input critical moviegnomes/subs/subscene/user
      db_input critical moviegnomes/subs/subscene/pass
      db_input critical moviegnomes/subs/opensub/user
      db_input critical moviegnomes/subs/opensub/pass
    fi
  ;;
  esac

  # Uses the return code from db_go to decide to move backwards or forwards
  if db_go; then
    # Additional logic to get the selected components
    if [ "$STATE" = 3 ]; then
      db_get moviegnomes/components/select
      SELECT=$RET
      # Possible options
      # SELECT=SABnzbd,Radarr,Sonarr,Bazarr,Lidarr,Kodi,MySQL
      SAB=0; RADARR=0; SONARR=0; BAZARR=0; LIDARR=0; KODI=0; SQL=0
      while read VALUE; do
        [ "$VALUE" = "SABnzbd" ] && SAB=1
        [ "$VALUE" = "Radarr" ] && RADARR=1
        [ "$VALUE" = "Sonarr" ] && SONARR=1
        [ "$VALUE" = "Bazarr" ] && BAZARR=1
        [ "$VALUE" = "Lidarr" ] && LIDARR=1
        [ "$VALUE" = "Kodi" ] && KODI=1
        [ "$VALUE" = "MySQL" ] && SQL=1
      done <<EOF
# Has to be done this way. If you use a pipe any variable modifications don't survive the resulting subshell
$(echo "$SELECT" | tr ',' '\n' | sed -e 's/^[[:space:]]*//')
EOF
    fi
    
    # Invalid selections
    if [ "$BAZARR" = 1 -a "$RADARR" != 1 -a "$SONARR" != 1 ]; then
      db_settitle moviegnomes/error/title
      db_input critical moviegnomes/error/bazarr
      db_go
      STATE=$(($STATE - 1))
    elif [ "$SQL" = 1 -a "$KODI" != 1 ]; then
      db_settitle moviegnomes/error/title
      db_input critical moviegnomes/error/sql
      db_go
      STATE=$(($STATE - 1))
    elif [ "$SAB" != 1 ] && [ "$RADARR" = 1 -o "$SONARR" = 1 -o "$LIDARR" = 1 ]; then
      db_settitle moviegnomes/warning/title
      db_input critical moviegnomes/warning/sab
      db_go
    fi

    STATE=$(($STATE + 1))
  else
    STATE=$(($STATE - 1))
  fi
done

# This is cheap, but templates with Type: password are not stored in questions.dat
db_get moviegnomes/news/pass
db_set moviegnomes/news/hidden $RET
db_get moviegnomes/kodi/pass
db_set moviegnomes/kodi/hidden $RET
db_get moviegnomes/library/pass
db_set moviegnomes/library/hidden $RET
db_get moviegnomes/subs/subscene/pass
db_set moviegnomes/subs/subscene/hidden $RET
db_get moviegnomes/subs/opensub/pass
db_set moviegnomes/subs/opensub/hidden $RET
