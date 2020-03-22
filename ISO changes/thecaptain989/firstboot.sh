#!/bin/bash

# Only meant to run once during the very first system boot, to be
# executed from the firstboot service, that is created by the postinstall.sh script

# Expected to run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root." 
   exit 1
fi

# Not expected to be run interactively
if [[ ! $(tty) =~ "not a tty" ]]; then
   echo "Not expected to be running on a terminal."
   exit 1
fi

### Functions
# Smarter way to read XML documents
read_xml () {
  local IFS=\>
  read -d \< XML_ENTITY XML_CONTENT
}
# Safe way to get answers to questions asked during install. No quoting necessary.
extract_answer () {
  echo `awk -F "\n" -v RS="" -v pat="Name: $1" '$0~pat {sub(/.*Value: /,"");sub(/\n.*$/,"");print $0}' /var/log/installer/cdebconf/questions.dat`
}

### Variables
DOCKER_ROOT=/docker
VIDEO_ROOT=/videos
MUSIC_ROOT=/music
SABNZBD_ROOT=$DOCKER_ROOT/sabnzbd
RADARR_ROOT=$DOCKER_ROOT/radarr
SONARR_ROOT=$DOCKER_ROOT/sonarr
BAZARR_ROOT=$DOCKER_ROOT/bazarr
LIDARR_ROOT=$DOCKER_ROOT/lidarr
KODI_ROOT=$DOCKER_ROOT/kodi
CLEANSUBS_PATH="https://raw.githubusercontent.com/TheCaptain989/bazarr-cleansubs/master"
THETVDB_PATH="http://mirrors.kodi.tv/addons/leia/metadata.tvdb.com/"
TZ=`cat /etc/timezone`  # Only in Debian and derivatives
NEWS_USER=$(extract_answer "moviegnomes/news/user")
NEWS_PASS=$(extract_answer "moviegnomes/news/pass")
NZBGEEK_KEY=$(extract_answer "moviegnomes/indexer/key1")
GINGA_KEY=$(extract_answer "moviegnomes/indexer/key2")
IMDB_LIST_ID=$(extract_answer "moviegnomes/imdb/list")
DB_HOST=$(extract_answer "moviegnomes/kodi/host")
DB_PORT=$(extract_answer "moviegnomes/kodi/port")
DB_USER=$(extract_answer "moviegnomes/kodi/user")
DB_PASS=$(extract_answer "moviegnomes/kodi/pass")
LIB_MOVIEPATH=$(extract_answer "moviegnomes/library/moviepath")
LIB_TVPATH=$(extract_answer "moviegnomes/library/tvpath")
LIB_MUSICPATH=$(extract_answer "moviegnomes/library/musicpath")
SUBS1_USER=$(extract_answer "moviegnomes/subs/subscene/user")
SUBS1_PASS=$(extract_answer "moviegnomes/subs/subscene/pass")
SUBS2_USER=$(extract_answer "moviegnomes/subs/opensub/user")
SUBS2_PASS=$(extract_answer "moviegnomes/subs/opensub/pass")

### Basic Linux changes
# Add Normal User to sudoers
usermod -aG sudo user
# Modify .bashrc
echo "alias ll='ls -la --color=auto'" >>/root/.bashrc
echo "alias ll='ls -la --color=auto'" >>/home/user/.bashrc
# Set automatic upgrades
echo "unattended-upgrades unattended-upgrades/enable_auto_updates boolean true" | debconf-set-selections
apt-get -y install unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades
apt-get -y update
# Install webmin
curl -fsSL http://www.webmin.com/jcameron-key.asc | sudo apt-key add - && \
add-apt-repository -y "deb http://download.webmin.com/download/repository sarge contrib #Webmin repository" && \
apt-get -y update && \
apt-get -y install webmin

### Install Docker
# Tried doing this in the preseed and it failed miserably
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add - && \
add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable #Docker repository for Debian 10" && \
apt-get -y update && \
apt-get -y install docker-ce docker-ce-cli containerd.io

# Check for failure
if [ $? -ne 0 ]; then exit $?; fi

### Prepare file system for Docker containers
# Shared directories and mount points
mkdir -p $VIDEO_ROOT/#recycle
mkdir -p $MUSIC_ROOT/#recycle
chown -R root:user $VIDEO_ROOT/#recycle
chown -R root:user $MUSIC_ROOT/#recycle
# SABnzbd
useradd -u 1009 -g user -s /bin/bash -m -c "SABnzbd service account" sabnzbd
mkdir -p $SABNZBD_ROOT/config
mkdir -p $SABNZBD_ROOT/downloads
mkdir -p $SABNZBD_ROOT/downloads/music
mkdir -p $SABNZBD_ROOT/downloads/tv
mkdir -p $SABNZBD_ROOT/downloads/movies
chown -R sabnzbd:user $SABNZBD_ROOT
setfacl -R -m u::rwx,g::rwx $SABNZBD_ROOT
setfacl -R -d -m u::rwx,g::rwx $SABNZBD_ROOT
# Radarr
useradd -u 1010 -g user -s /bin/bash -m -c "Radarr service account" radarr
mkdir -p $RADARR_ROOT
mkdir -p $VIDEO_ROOT/movies
chown -R radarr:user $RADARR_ROOT
chown -R radarr:user $VIDEO_ROOT/movies
setfacl -m u::rwx,g::rwx $RADARR_ROOT
setfacl -d -m u::rwx,g::rwx $RADARR_ROOT
setfacl -m u::rwx,g::rwx $VIDEO_ROOT/movies
setfacl -d -m u::rwx,g::rwx $VIDEO_ROOT/movies
# Sonarr
useradd -u 1011 -g user -s /bin/bash -m -c "Sonarr service account" sonarr
mkdir -p $SONARR_ROOT
mkdir -p $VIDEO_ROOT/tv
chown -R sonarr:user $SONARR_ROOT
chown -R sonarr:user $VIDEO_ROOT/tv
setfacl -m u::rwx,g::rwx $SONARR_ROOT
setfacl -d -m u::rwx,g::rwx $SONARR_ROOT
setfacl -m u::rwx,g::rwx $VIDEO_ROOT/tv
setfacl -d -m u::rwx,g::rwx $VIDEO_ROOT/tv
# Bazarr
useradd -u 1012 -g user -s /bin/bash -m -c "Bazarr service account" bazarr
mkdir -p $BAZARR_ROOT
chown -R bazarr:user $BAZARR_ROOT
setfacl -m u::rwx,g::rwx $BAZARR_ROOT
setfacl -d -m u::rwx,g::rwx $BAZARR_ROOT
# Lidarr
useradd -u 1013 -g user -s /bin/bash -m -c "Lidarr service account" lidarr
mkdir -p $DOCKER_ROOT/lidarr
mkdir -p $MUSIC_ROOT
chown -R lidarr:user $DOCKER_ROOT/lidarr
chown -R lidarr:user $MUSIC_ROOT
setfacl -m u::rwx,g::rwx $DOCKER_ROOT/lidarr
setfacl -d -m u::rwx,g::rwx $DOCKER_ROOT/lidarr
setfacl -m u::rwx,g::rwx $MUSIC_ROOT
setfacl -d -m u::rwx,g::rwx $MUSIC_ROOT
# Kodi
useradd -u 1014 -g user -s /bin/bash -m -c "Kodi service account" kodi
mkdir -p $KODI_ROOT
chown -R kodi:user $KODI_ROOT:
setfacl -m u::rwx,g::rwx $KODI_ROOT
setfacl -d -m u::rwx,g::rwx $KODI_ROOT

# Check for failure
if [ $? -ne 0 ]; then exit $?; fi

# Install cifs-utils package to allow SMB/CIFS mounts
apt-get -y install cifs-utils
# Create everything fstab needs
cat >/root/.smbcredentials <<EOF
username=$DB_USER
password=$DB_PASS
EOF
# Edit fstab
echo "${LIB_MOVIEPATH#*:} $VIDEO_ROOT/movies cifs credentials=/root/.smbcredentials,users,ro 0 0" >>/etc/fstab
echo "${LIB_TVPATH#*:} $VIDEO_ROOT/tv cifs credentials=/root/.smbcredentials,users,rw 0 0" >>/etc/fstab
echo "${LIB_MUSICPATH#*:} $MUSIC_ROOT cifs credentials=/root/.smbcredentials,users,ro 0 0" >>/etc/fstab
# Mount new file systems
mount -a

# Check for failure
RET=$?
if [ $RET -ne 0 ]; then
  echo "ERROR: Error $RET mounting file system. Script halted."
  exit $RET
fi

### Create Docker containers
# Install and run SABnzbd container
docker pull linuxserver/sabnzbd &&
docker create \
  --name=sabnzbd \
  -h sabnzbd \
  -e PUID=1009 \
  -e PGID=1000 \
  -e TZ=$TZ \
  -p 8080:8080 \
  -v $SABNZBD_ROOT/config:/config \
  -v $SABNZBD_ROOT/downloads:/downloads \
  --restart unless-stopped \
  --tty \
  linuxserver/sabnzbd &&
docker start sabnzbd
# Install and run Radarr container
docker pull thecaptain989/radarr &&
docker create \
  --name=radarr \
  -h radarr \
  -e PUID=1010 \
  -e PGID=1000 \
  -e TZ=$TZ \
  -p 7878:7878 \
  -v $RADARR_ROOT:/config \
  -v $VIDEO_ROOT/movies:/movies \
  -v $VIDEO_ROOT/#recycle:/#recycle \
  -v $SABNZBD_ROOT/downloads:/downloads \
  --restart unless-stopped \
  --tty \
  thecaptain989/radarr &&
docker start radarr
# Install and run Sonarr container
docker pull linuxserver/sonarr &&
docker create \
  --name=sonarr \
  -h sonarr \
  -e PUID=1011 \
  -e PGID=1000 \
  -e TZ=$TZ \
  -p 8989:8989 \
  -v $SONARR_ROOT:/config \
  -v $VIDEO_ROOT/tv:/tv \
  -v $VIDEO_ROOT/#recycle:/#recycle \
  -v $SABNZBD_ROOT/downloads:/downloads \
  --restart unless-stopped \
  --tty \
  linuxserver/sonarr &&
docker start sonarr
# Install and run Bazarr container
docker pull linuxserver/bazarr &&
docker create \
  --name=bazarr \
  -h bazarr \
  -e PUID=1012 \
  -e PGID=1000 \
  -e TZ=$TZ \
  -p 6767:6767 \
  -v $BAZARR_ROOT:/config \
  -v $VIDEO_ROOT/tv:/tv \
  -v $VIDEO_ROOT/movies:/movies \
  --restart unless-stopped \
  --tty \
  linuxserver/bazarr &&
docker start bazarr
 Install and run Lidarr container
docker pull thecaptain989/lidarr &&
docker create \
  --name=lidarr \
  -h lidarr \
  -e PUID=1013 \
  -e PGID=1000 \
  -e TZ=$TZ \
  -p 8686:8686 \
  -v $LIDARR_ROOT:/config \
  -v $MUSIC_ROOT/#recycle:/#recycle \
  -v $MUSIC_ROOT:/music \
  -v $SABNZBD_ROOT/downloads:/downloads \
  --restart unless-stopped \
  --tty \
  thecaptain989/lidarr &&
docker start lidarr
docker pull linuxserver/kodi-headless &&
docker create \
  --name=kodi-headless \
  -h kodi-headless \
  -e PUID=1014 \
  -e PGID=1000 \
  -e TZ=$TZ \
  -p 8085:8080 \
  -v $KODI_ROOT:/config/.kodi \
  --restart unless-stopped \
  --tty \
  linuxserver/kodi-headless &&
docker start kodi-headless

# Check for failure
if [ $? -ne 0 ]; then exit $?; fi

## Sqlite3
# Sqlite needed so many times, let's just install it temporarily
apt-get -y install sqlite3

### Configure container applications
## SABnzbd
docker stop sabnzbd
# Edit the configuration file
sed -ri '/^notified_new_skin *=/ s/[0-9]+/2/
/^host_whitelist *=/ s/,? *(moviegnomes)? *$/, moviegnomes/
/^permissions *=/ s/""|[0-9]+/775/
/^download_free *=/ s/=.*/= 5G/
/^no_dupes *=/ s/[0-9]+/2/
/^ignore_samples *=/ s/[0-9]+/1/
/^sanitize_safe *=/ s/[0-9]+/1/
/^direct_unpack_tested *=/ s/[0-9]+/1/
/^direct_unpack *=/ s/[0-9]+/1/
/^no_series_dupes *=/ s/[0-9]+/2/
/^download_dir *=/ s/=.*$/= \/downloads\/incomplete/
/^complete_dir *=/ s/=.*$/= \/downloads/
/^history_retention *=/ s/=.*$/= 90d/' $SABNZBD_ROOT/config/sabnzbd.ini
cat >>$SABNZBD_ROOT/config/sabnzbd.ini <<EOF
[servers]
[[news.newshosting.com]]
username = $NEWS_USER
priority = 0
enable = 1
displayname = news.newshosting.com
name = news.newshosting.com
ssl_ciphers = ""
notes = ""
connections = 25
ssl = 1
host = news.newshosting.com
timeout = 60
ssl_verify = 2
send_group = 0
password = $NEWS_PASS
optional = 0
port = 563
retention = 0
[categories]
[[*]]
priority = 0
pp = 3
name = *
script = None
newzbin = ""
order = 0
dir = ""
[[movies]]
priority = -100
pp = ""
name = movies
script = Default
newzbin = ""
order = 0
dir = movies
[[tv]]
priority = -100
pp = ""
name = tv
script = Default
newzbin = ""
order = 0
dir = tv
[[audio]]
priority = -100
pp = ""
name = audio
script = Default
newzbin = ""
order = 0
dir = music
EOF
# Extract the SABnzbd API key for use later
SABNZBD_KEY=`awk '/^api_key/ {print $3}' $SABNZBD_ROOT/config/sabnzbd.ini`
docker start sabnzbd

## Radarr
docker stop radarr
# Keeping this note for legacy learning
# Shutdown just the Radarr service, keeping the container running so we can use SQLite to export and import the database
#docker exec radarr s6-svc -d /var/run/s6/services/radarr
# Update the database
sqlite3 $RADARR_ROOT/nzbdrone.db "UPDATE QualityDefinitions SET MinSize=11.8,MaxSize=127.2 WHERE Title='HDTV-1080p' OR Title='WEBDL-1080p';
UPDATE QualityDefinitions SET MinSize=13.4,MaxSize=147.9 WHERE Title='Bluray-1080p' OR Title='Remux-1080p';
UPDATE Profiles SET Cutoff=7,Items=replace('[\\\n  {\\\n    \"quality\": 0,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 24,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 25,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 26,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 27,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 29,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 28,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 1,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 2,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 23,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 8,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 20,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 21,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 4,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 5,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 6,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 9,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 3,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 7,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 30,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 16,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 18,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 19,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 31,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 22,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 10,\\\n    \"allowed\": false\\\n  }\\\n]','\\\n',char(10)) WHERE Name='Any';
UPDATE Profiles SET Cutoff=19,Items=replace('[\\\n  {\\\n    \"quality\": 0,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 24,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 25,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 26,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 27,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 29,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 28,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 1,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 2,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 23,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 8,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 20,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 21,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 4,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 5,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 6,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 9,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 3,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 7,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 30,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 16,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 18,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 19,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 31,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 22,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 10,\\\n    \"allowed\": false\\\n  }\\\n]','\\\n',char(10)) WHERE Name='Ultra-HD';
UPDATE Profiles SET Cutoff=7,Items=replace('[\\\n  {\\\n    \"quality\": 0,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 24,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 25,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 26,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 27,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 29,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 28,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 1,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 2,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 23,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 8,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 20,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 21,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 4,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 5,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 6,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 9,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 3,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 7,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 30,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 16,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 18,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 19,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 31,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 22,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 10,\\\n    \"allowed\": false\\\n  }\\\n]','\\\n',char(10)) WHERE Name='HD - 720p\/1080p';
INSERT INTO Config(Key,Value) VALUES('cleanupmetadataimages','False');
INSERT INTO Config(Key,Value) VALUES('recyclebin','/#recycle/movies/');
INSERT INTO Config(Key,Value) VALUES('importextrafiles','True');
INSERT INTO Config(Key,Value) VALUES('extrafileextensions','srt,jpg');
INSERT INTO Config(Key,Value) VALUES('autodownloadpropers','False');
INSERT INTO RootFolders(Path) VALUES('/movies/');
INSERT INTO Indexers(Name,Implementation,Settings,ConfigContract,EnableRss,EnableSearch) VALUES('NZBgeek','Newznab',replace('{\\\n  \"baseUrl\": \"https://api.nzbgeek.info\",\\\n  \"multiLanguages\": [],\\\n  \"apiKey\": \"$NZBGEEK_KEY\",\\\n  \"categories\": [\\\n    2000,\\\n    2010,\\\n    2020,\\\n    2030,\\\n    2040,\\\n    2045,\\\n    2050,\\\n    2060\\\n  ],\\\n  \"animeCategories\": [],\\\n  \"removeYear\": false,\\\n  \"searchByTitle\": false\\\n}','\\\n',char(10)),'NewznabSettings',1,1);
INSERT INTO DownloadClients(Enable,Name,Implementation,Settings,ConfigContract) VALUES(1,'MovieGnomes SABnzbd','Sabnzbd',replace('{\\\n  \"host\": \"moviegnomes\",\\\n  \"port\": 8080,\\\n  \"apiKey\": \"$SABNZBD_KEY\",\\\n  \"movieCategory\": \"movies\",\\\n  \"recentMoviePriority\": -100,\\\n  \"olderMoviePriority\": -100,\\\n  \"useSsl\": false\\\n}','\\\n',char(10)),'SabnzbdSettings');
INSERT INTO Restrictions(Required,Preferred,Ignored,Tags) VALUES(NULL,NULL,'3D','[]');
INSERT INTO Notifications(Name,OnGrab,OnDownload,Settings,Implementation,ConfigContract,OnUpgrade,Tags,OnRename) VALUES('MovieGnomes Kodi',0,1,replace('{\\\n  \"host\": \"moviegnomes\",\\\n  \"port\": 8085,\\\n  \"username\": \"kodi\",\\\n  \"password\": \"\",\\\n  \"displayTime\": 5,\\\n  \"notify\": false,\\\n  \"updateLibrary\": true,\\\n  \"cleanLibrary\": true,\\\n  \"alwaysUpdate\": false\\\n}','\\\n',char(10)),'Xbmc','XbmcSettings',1,'[]',0);
INSERT INTO Notifications(Name,OnGrab,OnDownload,Settings,Implementation,ConfigContract,OnUpgrade,Tags,OnRename) VALUES('Remux movie',0,1,replace('{\\\n  \"path\": \"/usr/local/bin/striptracks.sh\",\\\n  \"arguments\": \":eng:jpn:und :eng\"\\\n}','\\\n',char(10)),'CustomScript','CustomScriptSettings',1,'[]',0);
INSERT INTO NetImport(Enabled,Name,Implementation,ConfigContract,Settings,EnableAuto,RootFolderPath,ShouldMonitor,ProfileId,MinimumAvailability,Tags) VALUES(1,'IMDb List','RadarrLists','RadarrSettings',replace('{\\\n  \"apiurl\": \"https://api.radarr.video/v2\",\\\n  \"path\": \"/imdb/list?listId=$IMDB_LIST_ID\"\\\n}','\\\n',char(10)),1,'/movies/',1,6,3,'[]');
INSERT INTO NamingConfig(MultiEpisodeStyle,RenameEpisodes,ReplaceIllegalCharacters,StandardMovieFormat,MovieFolderFormat,ColonReplacementFormat) VALUES(0,1,1,'{Movie Title} ({Release Year})','{Movie Title} ({Release Year})',1);
"
# Edit the configuration file
sed -i '/<\/Branch>$/ a\
  <LaunchBrowser>False<\/LaunchBrowser>' $RADARR_ROOT/config.xml
# Extract the Radarr API key for use later
while read_xml; do [[ $XML_ENTITY = "ApiKey" ]] && RADARR_KEY=$XML_CONTENT; done < $RADARR_ROOT/config.xml
docker start radarr

## Sonarr
docker stop sonarr
# Update the database
sqlite3 $SONARR_ROOT/nzbdrone.db "UPDATE QualityDefinitions SET MinSize=16.2,MaxSize=156.4 WHERE Title='HDTV-1080p' OR Title='WEBDL-1080p' OR Title='Bluray-1080p';
UPDATE Profiles SET Cutoff=7,Items=replace('[\\\n  {\\\n    \"quality\": 0,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 1,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 2,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 8,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 4,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 9,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 10,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 5,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 6,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 3,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 7,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 16,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 18,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 19,\\\n    \"allowed\": false\\\n  }\\\n]','\\\n',char(10)) WHERE Name='Any';
UPDATE Profiles SET Cutoff=8,Items=replace('[\\\n  {\\\n    \"quality\": 0,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 1,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 2,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 8,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 4,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 9,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 10,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 5,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 6,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 3,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 7,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 16,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 18,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 19,\\\n    \"allowed\": false\\\n  }\\\n]','\\\n',char(10)) WHERE Name='SD';
UPDATE Profiles SET Cutoff=6,Items=replace('[\\\n  {\\\n    \"quality\": 0,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 1,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 8,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 2,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 4,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 9,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 10,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 5,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 6,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 3,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 7,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 16,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 18,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 19,\\\n    \"allowed\": false\\\n  }\\\n]','\\\n',char(10)) WHERE Name='HD-720p';
UPDATE Profiles SET Cutoff=7,Items=replace('[\\\n  {\\\n    \"quality\": 0,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 1,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 8,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 2,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 4,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 10,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 5,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 6,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 9,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 3,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 7,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 16,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 18,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 19,\\\n    \"allowed\": false\\\n  }\\\n]','\\\n',char(10)) WHERE Name='HD-1080p';
UPDATE Profiles SET Cutoff=19,Items=replace('[\\\n  {\\\n    \"quality\": 0,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 1,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 8,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 2,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 4,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 9,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 10,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 5,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 6,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 3,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 7,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 16,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 18,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 19,\\\n    \"allowed\": true\\\n  }\\\n]','\\\n',char(10)) WHERE Name='Ultra-HD';
UPDATE Profiles SET Cutoff=7,Items=replace('[\\\n  {\\\n    \"quality\": 0,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 1,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 8,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 2,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 4,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 10,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 5,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 6,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 9,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 3,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 7,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 16,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 18,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 19,\\\n    \"allowed\": false\\\n  }\\\n]','\\\n',char(10)) WHERE Name='HD - 720p\/1080p';
INSERT INTO Config(Key,Value) VALUES('maximumsize','20000');
INSERT INTO Config(Key,Value) VALUES('cleanupmetadataimages','False');
INSERT INTO Config(Key,Value) VALUES('recyclebin','/#recycle/tv/');
INSERT INTO Config(Key,Value) VALUES('autodownloadpropers','False');
INSERT INTO RootFolders(Path) VALUES('/tv/');
INSERT INTO NamingConfig(MultiEpisodeStyle,RenameEpisodes,StandardEpisodeFormat,DailyEpisodeFormat,SeasonFolderFormat,SeriesFolderFormat,AnimeEpisodeFormat,ReplaceIllegalCharacters) VALUES(2,1,'{Series Title} {season:00}x{episode:00} - {Episode Title}','{Series Title} - {Air-Date} - {Episode Title}','Season {season}','{Series Title}','{Series Title} {season:00}x{episode:00} - {Episode Title}',1);
INSERT INTO Indexers(Name,Implementation,Settings,ConfigContract,EnableRss,EnableSearch) VALUES('GingaDADDY','Newznab',replace('{\\\n  \"baseUrl\": \"https://www.gingadaddy.com/api.php\",\\\n  \"apiPath\": \"/api\",\\\n  \"apiKey\": \"$GINGA_KEY\",\\\n  \"categories\": [\\\n    5030,\\\n    5040\\\n  ],\\\n  \"animeCategories\": [\\\n    5000\\\n  ]\\\n}','\\\n',char(10)),'NewznabSettings',1,1);
INSERT INTO Indexers(Name,Implementation,Settings,ConfigContract,EnableRss,EnableSearch) VALUES('NZBgeek','Newznab',replace('{\\\n  \"baseUrl\": \"https://api.nzbgeek.info\",\\\n  \"apiPath\": \"/api\",\\\n  \"apiKey\": \"$NZBGEEK_KEY\",\\\n  \"categories\": [\\\n    5030,\\\n    5040\\\n  ],\\\n  \"animeCategories\": [\\\n    5070\\\n  ]\\\n}','\\\n',char(10)),'NewznabSettings',1,1);
INSERT INTO DownloadClients(Enable,Name,Implementation,Settings,ConfigContract) VALUES(1,'MovieGnomes SABnzbd','Sabnzbd',replace('{\\\n  \"host\": \"moviegnomes\",\\\n  \"port\": 8080,\\\n  \"apiKey\": \"$SABNZBD_KEY\",\\\n  \"tvCategory\": \"tv\",\\\n  \"recentTvPriority\": -100,\\\n  \"olderTvPriority\": -100,\\\n  \"useSsl\": false\\\n}','\\\n',char(10)),'SabnzbdSettings');
INSERT INTO Restrictions(Required,Preferred,Ignored,Tags) VALUES(NULL,NULL,'DUBBED','[]');
INSERT INTO Notifications(Name,OnGrab,OnDownload,Settings,Implementation,ConfigContract,OnUpgrade,Tags,OnRename) VALUES('MovieGnomes Kodi',0,1,replace('{\\\n  \"host\": \"moviegnomes\",\\\n  \"port\": 8085,\\\n  \"username\": \"kodi\",\\\n  \"displayTime\": 5,\\\n  \"notify\": false,\\\n  \"updateLibrary\": true,\\\n  \"cleanLibrary\": true,\\\n  \"alwaysUpdate\": true\\\n}','\\\n',char(10)),'Xbmc','XbmcSettings',1,'[]',0);
"
# Edit the configuration file
sed -i '/<\/Branch>/ a\
  <LaunchBrowser>False</LaunchBrowser>' $SONARR_ROOT/config.xml
# Extract the Sonarr API key for use later
while read_xml; do [[ $XML_ENTITY = "ApiKey" ]] && SONARR_KEY=$XML_CONTENT; done < $SONARR_ROOT/config.xml
docker start sonarr

## Bazarr
docker stop bazarr
# Update the database
sqlite3 $BAZARR_ROOT/db/bazarr.db "UPDATE table_settings_languages SET enabled=1 WHERE code2='en'"
# Edit configuration file
sed -ri "/^\[general\]/,/^\[.*\]/ {
  s/^(path_mappings *=).*/\1 [['', ''], ['', ''], ['', ''], ['', ''], ['', '']]/
  s/^(path_mappings_movie *=).*/\1 [['', ''], ['', ''], ['', ''], ['', ''], ['', '']]/
  s/^(single_language *=).*/\1 False/
  s/^(use_postprocessing *=).*/\1 True/
  s/^(postprocessing_cmd *=).*/\1 \/config\/cleansubs.sh '{{subtitles}}' ;/
  s/^(use_radarr *=).*/\1 True/
  s/^(use_sonarr *=).*/\1 True/
  s/^(serie_default_enabled *=).*/\1 True/
  s/^(serie_default_language *=).*/\1 ['en']/
  s/^(movie_default_enabled *=).*/\1 True/
  s/^(movie_default_language *=).*/\1 ['en']/
  s/^(upgrade_subs *=).*/\1 False/
  s/^(upgrade_manual *=).*/\1 False/
  s/^(days_to_upgrade_subs *=).*/\1 None/
  s/^(wanted_search_frequency *=).*/\1 24/
  s/^(enabled_providers *=).*/\1 opensubtitles,subscene/
}
/^\[sonarr\]/,/^\[.*\]/ {
  s/^(ip *=).*/\1 moviegnomes/
  s/^(apikey *=).*/\1 $SONARR_KEY/
  s/^(full_update *=).*/\1 Weekly/
  s/^(only_monitored *=).*/\1 True/
}
/^\[radarr\]/,/^\[.*\]/ {
  s/^(ip *=).*/\1 moviegnomes/
  s/^(apikey *=).*/\1 $RADARR_KEY/
  s/^(full_update *=).*/\1 Weekly/
  s/^(only_monitored *=).*/\1 True/
}
/^\[subscene\]/,/^\[.*\]/ {
  s/^(username *=).*/\1 $SUBS1_USER/
  s/^(password *=).*/\1 $SUBS1_PASS/
}
/^\[opensubtitles\]/,/^\[.*\]/ {
  s/^(username *=).*/\1 $SUBS2_USER/
  s/^(password *=).*/\1 $SUBS2_PASS/
}" $BAZARR_ROOT/config/config.ini
# Get Bazarr subtitle script from GitHub
wget -q -P $BAZARR_ROOT $CLEANSUBS_PATH/cleansubs.sh
chown bazarr:user $BAZARR_ROOT/cleansub.sh
docker start bazarr

## Lidarr
docker stop lidarr
#docker start lidarr

## Kodi
# Install The TVDB scraper addon
curl -s $THETVDB_PATH | \
awk 'BEGIN {FS=">"}
/<a href="metadata\.tvdb\.com/ {
  sub(/^.*href="/,"",$3); sub(/".*$/,"",$3)
  Link[++Entries] = $3
  if ($8 ~ /class="date"/) {
    sub(/\<\/.*$/,"",$9)
    Date[Entries] = $9
  }
}
END {
  if (Entries != 0) {
    for (i = 1; i <= Entries; i++)
      if (Date[i] > Newest) {
        Newest = Date[i]
        Download = Link[i]
      }
  }
   print "Downloading add-on "Download" dated "Newest
   Result=system("wget -q '$THETVDB_PATH'"Download)
   if (Result>1) print "ERROR: "Result" downloading \""Download"\""
   else {
     system("unzip -q "Download" -d '$KODI_ROOT'/addons")
     system("rm "Download)
   }
}'
# Let Kodi figure out that the add-on is installed
docker restart kodi-headless && sleep 5 && docker stop kodi-headless
# Update the database
sqlite3 $KODI_ROOT/userdata/Database/Addons27.db "UPDATE installed SET enabled=1 WHERE addonID = 'metadata.tvdb.com'"
# Edit the configuration
sed -i '/<setting id="services.webserver"/ s/ default="true">.*</>true</' $KODI_ROOT/userdata/guisettings.xml
sed -i '/<videodatabase>/,/<\/musicdatabase>/ {
    s/<host>.*<\/host>/<host>'$DB_HOST'<\/host>/
    s/<port>.*<\/port>/<port>'$DB_PORT'<\/port>/
    s/<user>.*<\/user>/<user>'$DB_USER'<\/user>/
    s/<pass>.*<\/pass>/<pass>'$DB_PASS'<\/pass>/
}
/<webserverpassword>/ s/kodi//' $KODI_ROOT/userdata/advancedsettings.xml
# Create missing files (not strictly necessary for headless Kodi, but can be nice)
cat >$KODI_ROOT/userdata/sources.xml <<EOF
<sources>
    <programs>
        <default pathversion="1"></default>
    </programs>
    <video>
        <default pathversion="1"></default>
        <source>
            <name>My Movies</name>
            <path pathversion="1">$LIB_MOVIEPATH</path>
            <allowsharing>true</allowsharing>
        </source>
        <source>
            <name>My TV shows</name>
            <path pathversion="1">$LIB_TVPATH</path>
            <allowsharing>true</allowsharing>
        </source>
    </video>
    <music>
        <default pathversion="1"></default>
        <source>
            <name>My Music</name>
            <path pathversion="1">$LIB_MUSICPATH</path>
            <allowsharing>true</allowsharing>
        </source>
    </music>
</sources>
EOF
cat >$KODI_ROOT/userdata/mediasources.xml <<EOF
<mediasources>
    <network>
        <location id="0">$LIB_MOVIEPATH</location>
        <location id="1">$LIB_TVPATH</location>
        <location id="2">$LIB_MUSICPATH</location>
    </network>
</mediasources>
docker start kodi-headless
EOF
LIB_TOMOVIEPATH=`echo $LIB_MOVIEPATH | sed "s|://|://$DB_USER:$DB_PASS@|"`
LIB_TOTVPATH=`echo $LIB_TVPATH | sed "s|://|://$DB_USER:$DB_PASS@|"`
LIB_TOMUSICPATH=`echo $LIB_MUSICPATH | sed "s|://|@://$DB_USER:$DB_PASS@|"`
cat >$KODI_ROOT/userdata/passwords.xml <<EOF
<passwords>
    <path>
        <from pathversion="1">$LIB_MOVIEPATH</from>
        <to pathversion="1">$LIB_TOMOVIEPATH</to>
    </path>
    <path>
        <from pathversion="1">$LIB_TVPATH</from>
        <to pathversion="1">$LIB_TOTVPATH</to>
    </path>
    <path>
        <from pathversion="1">$LIB_MUSICPATH</from>
        <to pathversion="1">$LIB_TOMUSICPATH</to>
    </path>
</passwords>
EOF
docker start kodi-headless

# Check for failure
if [ $? -ne 0 ]; then exit $?; fi

# Moving this to the end in hopes of fixing the issue where the system graphical login
# screen hangs as boot. Switching to console 2 and back to 1 seems to help.
# Disable system suspend
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

### Cleanup
# Remove installation report (contains passwords entered)
apt-get -y remove installation-report
# SQL not needed anymore
apt-get -y remove sqlite3
# Remove the firstboot service so that it won't run again
update-rc.d firstboot remove
rm /etc/init.d/firstboot
# Remove self
rm $0