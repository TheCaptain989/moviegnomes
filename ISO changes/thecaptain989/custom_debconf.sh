#!/bin/sh

# This is a debconf-compatible script
. /usr/share/debconf/confmodule

# Create the template file
cat >/tmp/moviegnomes.template <<EOF
### Splash screens
Template: moviegnomes/title
Type: text
Description: TheCaptain989's Movie Gnomes (ALPHA RELEASE)

Template: moviegnomes/splash
Type: note
Description: Welcome to TheCaptain989's Movie Gnomes Installation
 This is a custom Debian Linux install designed to provide and configure all the necessary
 tools to fully automate the management of your movie, TV, and music library.
 These tools include Docker and containers for: SABnzbd, Radarr, Sonarr, Bazarr, Lidarr, and Kodi
 .
 Capabilities include:
  - Manage your library via the web browser on your phone
  - Add movies you want to your IMDB Watchlist to have them automatically downloaded
  - Get the best quality movies available, rename them and keep them tidy
  - Automatically strip out unwanted audio and subtitle streams
  - Automatically download missing subtitles, and clean downloaded subs
  - Automatically convert downloaded FLAC music tracks to 320Kbps MP3s
  - Automatically update your existing Kodi database with added movies, TV shows, and music

Template: moviegnomes/splash2
Type: note
Description: Required Services
 This installation does require the use of internet services, a place to store downloaded content,
 and database. The default list is included below, but you may add, remove, or change these post install.
 .
 Required:
  - A media library location (e.g. NAS)
  - A shared Kodi database hostname, port, username, and password
    (https://kodi.wiki/view/MySQL/Setting_up_Kodi) 
  - A Newshosting username and password (https://www.newshosting.com/)
  - An NZBgeek API key (https://nzbgeek.info/)
  - A GingaDADDY API key (https://www.gingadaddy.com/)
  - An IMDB Watchlist ID (https://www.imdb.com/)
  - A Subscene login (https://subscene.com/)
  - An Opensubtitles login (https://www.opensubtitles.org/)
 .
 You be asked for this information on the next screens.

Template: moviegnomes/splash3
Type: note
Description: URLs to Know
 To access the various applications running in the Docker containers, and to make configuration
 changes post install, use the URLs below:
  SABnzbd: http://moviegnomes:8080/
  Radarr: http://moviegnomes:7878/
  Sonarr: http://moviegnomes:8989/
  Bazarr: http://moviegnomes:6767/
  Lidarr: http://moviegnomes:8686/
  Kodi: http://moviegnomes:8085/
 .
 You can manage the Debian host by using Webmin, or login to the Debian OS using the consle or SSH.  The username is 'user',
 and the password and root password are included in the accompanying documentation.
 .
 Webmin: https://moviegnomes:10000/

### Newshosting questions
Template: moviegnomes/news/title
Type: text
Description: Newshosting.com Credentials

Template: moviegnomes/news/user
Type: string
Description: Enter your Newshosting.com username
 Your Newshosting.com credentials are used by SABnzbd. This can be changed later
 in the SZBnzbd configuration post install.

Template: moviegnomes/news/pass
Type: password
Description: Enter your Newshosting.com password

### Indexer questions
Template: moviegnomes/indexer/title
Type: text
Description: NZB Indexer API Keys

Template: moviegnomes/indexer/key1
Type: string
Description: Enter your NZBgeek API key
 Your NZBgeek.info API key is used by Radarr, Sonarr, and Lidarr. This can be changed
 later in the various configurations post install.
 .
 EX: abcdef0123456789abcdef0123456789

Template: moviegnomes/indexer/key2
Type: string
Description: Enter your GingaDADDY API key
 Your GingaDADDY.com API key is used by Sonarr. This can be changed
 later in the Sonarr configuration post install.
 .
 EX: abcdef0123456789abcdef0123456789

### IMDB questions
Template: moviegnomes/imdb/title
Type: text
Description: IMDB List ID

Template: moviegnomes/imdb/list
Type: string
Description: Enter your IMDB List ID
 Your IMDB.com Watchlist ID is used by Radarr to auto add movies. This can be changed
 later in the Radarr configuration post install.
 .
 EX: ur1234567
 .
 NOTE: The Watchlist must be marked as publicly readable!

### Kodi questions
Template: moviegnomes/kodi/title
Type: text
Description: Kodi Database Info

Template: moviegnomes/kodi/host
Type: string
Description: Enter your database hostname
 Your Kodi database is an existing MySQL or MariaDB used to store all Kodi library data.
 This can be changed later by manually editing the /docker/kodi/userdata/advancedsettings.xml file post install.
 .
 Enter the server hostname that contains the Kodi database.

Template: moviegnomes/kodi/port
Type: string
Default: 3306
Description: Enter your database port
 Enter the server port number that Kodi should use to connect to the database.

Template: moviegnomes/kodi/user
Type: string
Default: kodi
Description: Enter your database username
 Enter the username that Kodi should use to connect to the database.

Template: moviegnomes/kodi/pass
Type: password
Description: Enter your database password
 Enter the password that Kodi should use to connect to the database.

### Library questions
Template: moviegnomes/library/title
Type: text
Description: Library Information

Template: moviegnomes/library/moviepath
Type: string
Description: Enter the fully qualified path to your movie library
 This is the fully qualified path to your movies the way Kodi accesses it. Use Linux path format!
 This can be changed later by manually editing the following files post install:
  /docker/kodi/userdata/sources.xml
  /docker/kodi/userdata/mediasources.xml
  /docker/kodi/userdata/passwords.xml
  /etc/fstab
 .
 EX: smb://my_nas/videos/Movies/

Template: moviegnomes/library/tvpath
Type: string
Description: Enter the fully qualified to your TV show library
 This is the fully qualified path to your TV shows the way Kodi accesses it.
 .
 EX: smb://my_nas/videos/TV/

Template: moviegnomes/library/musicpath
Type: string
Description: Enter the fully qualified to your music library
 This is the fully qualified path to your music the way Kodi accesses it.
 .
 EX: smb://my_nas/Music/

### Bazarr questions
Template: moviegnomes/subs/title
Type: text
Description: Subtitle Services

Template: moviegnomes/subs/subscene/user
Type: string
Description: Enter your Subscene username
 Your Subscene.com login is used by Bazarr. This can be changed
 later in the Bazarr configuration post install.

Template: moviegnomes/subs/subscene/pass
Type: password
Description: Enter your Subscene password

Template: moviegnomes/subs/opensub/user
Type: string
Description: Enter your OpenSubtitles username
 Your OpenSubtitles.org login is used by Bazarr. This can be changed
 later in the Bazarr configuration post install.

Template: moviegnomes/subs/opensub/pass
Type: password
Description: Enter your OpenSubtitles password
EOF

# Load the template
db_x_loadtemplatefile /tmp/moviegnomes.template thecaptain989

# Show splash screens
db_settitle moviegnomes/title
db_input critical moviegnomes/splash
db_input critical moviegnomes/splash2
db_go
db_input critical moviegnomes/splash3
db_go

# Ask Library questions
db_settitle moviegnomes/library/title
db_input critical moviegnomes/library/moviepath
db_input critical moviegnomes/library/tvpath
db_input critical moviegnomes/library/musicpath
db_go

# Ask Kodi questions
db_settitle moviegnomes/kodi/title
db_input critical moviegnomes/kodi/host
db_input critical moviegnomes/kodi/port
db_input critical moviegnomes/kodi/user
db_input critical moviegnomes/kodi/pass
db_go

# Ask Newshosting questions
db_settitle moviegnomes/news/title
db_input critical moviegnomes/news/user
db_input critical moviegnomes/news/pass
db_go

# Ask Indexer questions
db_settitle moviegnomes/indexer/title
db_input critical moviegnomes/indexer/key1
db_input critical moviegnomes/indexer/key2
db_go

# Ask IMDB questions
db_settitle moviegnomes/imdb/title
db_input critical moviegnomes/imdb/list
db_go

# Ask Subtitle questions
db_settitle moviegnomes/subs/title
db_input critical moviegnomes/subs/subscene/user
db_input critical moviegnomes/subs/subscene/pass
db_input critical moviegnomes/subs/opensub/user
db_input critical moviegnomes/subs/opensub/pass
db_go
