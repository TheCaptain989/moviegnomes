#!/bin/bash

#### THIS SCRIPT IS SELF-DELETING ####
# Script that sets up TheCaptain989's MovieGnomes VM
#  https://github.com/TheCaptain989/moviegnomes
# Only meant to run once during the very first system boot, executed by the
# firstboot service, that itself is created by the postinstall.sh script from the ISO
echo "###### Starting TheCaptain989's MovieGnomes Firstboot Script ######"

### Prerequisites
# Expected to run as root
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: This script must be run as root. Halting script." 
  exit 1
fi
# Not expected to be run interactively
if [[ ! $(tty) =~ "not a tty" ]]; then
  echo "ERROR: Not expected to be running on a terminal. Halting script."
  exit 1
fi
# Answers to preseed are located here
if [ ! -f "/var/log/installer/cdebconf/questions.dat" ]; then
  echo "ERROR: Unable to locate cdebconf questions file. Halting script."
  exit 1
fi

### Functions
# Smarter way to read XML documents
function read_xml {
  local IFS=\>
  read -d \< XML_ENTITY XML_CONTENT
}
# Safe way to get answers to questions asked during install. No quoting necessary.
# NOTE: Any templates marked as Type: password do not show up here!
function extract_answer {
  echo $(awk -F "\n" -v RS="" -v pat="Name: $1" '$0~pat {sub(/.*Value: /,"");sub(/\n.*$/,"");print $0}' /var/log/installer/cdebconf/questions.dat)
}
# SED escaping, courtesy of Ed Morton
#  https://stackoverflow.com/questions/29613304/is-it-possible-to-escape-regex-metacharacters-reliably-with-sed
function quoteSubst {
  IFS= read -d '' -r < <(sed -e ':a' -e '$!{N;ba' -e '}' -e 's/[&/\]/\\&/g; s/\n/\\&/g' <<<"$1")
  printf %s "${REPLY%$'\n'}"
}

### Variables
echo "### Setting Variables ###"
TIMEOUT=300
DOCKER_ROOT=/docker
MEDIA_ROOT=/media
SABNZBD_ROOT=$DOCKER_ROOT/sabnzbd
RADARR_ROOT=$DOCKER_ROOT/radarr
SONARR_ROOT=$DOCKER_ROOT/sonarr
BAZARR_ROOT=$DOCKER_ROOT/bazarr
LIDARR_ROOT=$DOCKER_ROOT/lidarr
KODI_ROOT=$DOCKER_ROOT/kodi
CLEANSUBS_PATH="https://raw.githubusercontent.com/TheCaptain989/bazarr-cleansubs/master"
THETVDB_PATH="http://mirrors.kodi.tv/addons/matrix/metadata.tvdb.com/"
TZ=$(cat /etc/timezone)   # Only in Debian and derivatives
TZ=${TZ:-$(timedatectl | awk '/Time zone:/ {print $3}')}   # To catch everyone else
NEWS_USER=$(extract_answer "moviegnomes/news/user")
NEWS_PASS=$(extract_answer "moviegnomes/news/hidden")
NZBGEEK_KEY=$(extract_answer "moviegnomes/indexer/key1")
GINGA_KEY=$(extract_answer "moviegnomes/indexer/key2")
IMDB_LIST_ID=$(extract_answer "moviegnomes/imdb/list")
DB_HOST=$(extract_answer "moviegnomes/kodi/host")
DB_PORT=$(extract_answer "moviegnomes/kodi/port")
DB_USER=$(extract_answer "moviegnomes/kodi/user")
DB_PASS=$(extract_answer "moviegnomes/kodi/hidden")
LIB_USER=$(extract_answer "moviegnomes/library/user")
LIB_PASS=$(extract_answer "moviegnomes/library/hidden")
LIB_MEDIAPATH=$(extract_answer "moviegnomes/library/mediapath")
LIB_MOVIEDIR=$(extract_answer "moviegnomes/library/moviedir")
LIB_MOVIEDIR=${LIB_MOVIEDIR#/};LIB_MOVIEDIR=${LIB_MOVIEDIR%/}   # Remove leading and trailing backslashes
LIB_TVDIR=$(extract_answer "moviegnomes/library/tvdir")
LIB_TVDIR=${LIB_TVDIR#/};LIB_TVDIR=${LIB_TVDIR%/}   # Remove leading and trailing backslashes
LIB_MUSICDIR=$(extract_answer "moviegnomes/library/musicdir")
LIB_MUSICDIR=${LIB_MUSICDIR#/};LIB_MUSICDIR=${LIB_MUSICDIR%/}   # Remove leading and trailing backslashes
SUBS1_USER=$(extract_answer "moviegnomes/subs/subscene/user")
SUBS1_PASS=$(extract_answer "moviegnomes/subs/subscene/hidden")
SUBS2_USER=$(extract_answer "moviegnomes/subs/opensub/user")
SUBS2_PASS=$(extract_answer "moviegnomes/subs/opensub/hidden")
COMPONENTS=$(extract_answer "moviegnomes/components/select")
while read VALUE; do
  [ "$VALUE" = "SABnzbd" ] && INST_SAB=1 && continue
  [ "$VALUE" = "Radarr" ] && INST_RADARR=1 && continue
  [ "$VALUE" = "Sonarr" ] && INST_SONARR=1 && continue
  [ "$VALUE" = "Bazarr" ] && INST_BAZARR=1 && continue
  [ "$VALUE" = "Lidarr" ] && INST_LIDARR=1 && continue
  [ "$VALUE" = "Kodi" ] && INST_KODI=1 && continue
  [ "$VALUE" = "MySQL" ] && INST_SQL=1 && continue
done <<EOF
# Has to be done this way. If you use a pipe the variables cannot be modified in the resulting subshell
$(echo "$COMPONENTS" | tr ',' '\n' | sed -e 's/^[[:space:]]*//')
EOF

### Basic Linux changes
echo "### Setting up Linux environment and installing base packages ###"
# Add Normal User to sudoers
usermod -aG sudo $(getent passwd 1000 | cut -d':' -f1)
# Modify .bashrc
echo "alias ll='ls -la --color=auto'" >>/root/.bashrc
echo "alias ll='ls -la --color=auto'" >>/home/$(getent passwd 1000 | cut -d':' -f1)/.bashrc
# Set automatic upgrades
echo "unattended-upgrades unattended-upgrades/enable_auto_updates boolean true" | debconf-set-selections
apt-get -y install unattended-upgrades
RET=$?; [ "$RET" != 0 ] && echo "WARNING[$RET]: Unable to install the unattended upgrades" || echo "INFO: Installed unattended upgrades"
dpkg-reconfigure -f noninteractive unattended-upgrades
# Increase volume
amixer -qD pulse sset Master 50%
RET=$?; [ "$RET" != 0 ] && echo "WARNING[$RET]: Unable to set Pulse volume" || echo "INFO: Set Pulse volume to 50%"
# Install Docker
apt-get -y update
# Tried doing this in the preseed and it failed miserably, so here it is
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add - && \
add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable #Docker repository for Debian 10" && \
apt-get -y update && \
apt-get -y install docker-ce docker-ce-cli containerd.io
RET=$?; [ "$RET" != 0 ] && { echo "ERROR[$RET]: Unable to install Docker. Halting." && exit 1; } || echo "INFO: Installed Docker (apt-key warning is normal)"
# SQLite3 needed so many times, let's just install it temporarily
apt-get -y install sqlite3
RET=$?; [ "$RET" != 0 ] && { echo "ERROR[$RET]: Unable to install SQLite3. Halting." && exit 1; } || echo "INFO: Installed SQLite3"
# Add Docker container log rotation
cat >/etc/docker/daemon.json <<EOF
{
"log-driver": "json-file",
"log-opts": {
   "max-size": "20m",
   "max-file": "3"
   }
}
EOF
# Restart Docker after changes
systemctl restart docker

### Install cifs-utils package to allow SMB/CIFS mounts
apt-get -y install cifs-utils
RET=$?
if [ "$RET" = 0 ]; then
  echo "INFO: Installed cifs-utils"
  # Create everything fstab needs
  cat >/root/.smbcredentials <<EOF
username=$LIB_USER
password=$LIB_PASS
EOF
  # Edit fstab; crazy bash parameter expansion gymnastics needed
  [ "$INST_RADARR" = 1 -o "$INST_SONARR" = 1 -o "$INST_LIDARR" = 1 ] && mkdir -p "$MEDIA_ROOT" && echo "$(X=${LIB_MEDIAPATH#*:};echo ${X// /\\040}) ${MEDIA_ROOT// /\\040} cifs credentials=/root/.smbcredentials,users,rw,uid=1000,gid=1000,noperm 0 0" >>/etc/fstab
  # Mount new file systems
  mount -a
  # Requested by fstab
  systemctl daemon-reload
  RET=$?; [ "$RET" != 0 ] && echo "WARNING[$RET]: Unable to mount network drive(s) with given credentials" || echo "INFO: Mounted network drive(s) ${LIB_MEDIAPATH#*:}"
else
  echo "WARNING[$RET]: Unable to install cifs-utils"
fi

### SABnzbd
if [ "$INST_SAB" = 1 ]; then
  echo "### Installing SABnzbd ###"
  # Prepare the filesystem for container
  useradd -u 1009 -g user -s /bin/bash -m -c "SABnzbd service account" sabnzbd
  mkdir -p "$SABNZBD_ROOT/config"
  chown -R sabnzbd:user "$SABNZBD_ROOT"
  setfacl -R -m u::rwx,g::rwx "$SABNZBD_ROOT"
  setfacl -R -d -m u::rwx,g::rwx "$SABNZBD_ROOT"
  if [ "$INST_RADARR" = 1 -o "$INST_SONARR" = 1 -o "$INST_LIDARR" = 1 ] && [ ! -d "$MEDIA_ROOT/#downloads" ]; then
    mkdir -p "$MEDIA_ROOT/#downloads/"
    chown -R sabnzbd:user "$MEDIA_ROOT/#downloads/"
    setfacl -R -m u::rwx,g::rwx "$MEDIA_ROOT/#downloads/"
    setfacl -R -d -m u::rwx,g::rwx "$MEDIA_ROOT/#downloads/"
  fi
  # Install and run container
  docker pull linuxserver/sabnzbd && \
  docker create \
    --name=sabnzbd \
    -h sabnzbd \
    -e PUID=1009 \
    -e PGID=1000 \
    -e TZ="$TZ" \
    -p 8080:8080 \
    -v "${SABNZBD_ROOT%/}/config":/config \
    -v "${MEDIA_ROOT%/}":"${MEDIA_ROOT%/}" \
    --restart unless-stopped \
    --tty \
    linuxserver/sabnzbd && \
  docker start sabnzbd
  RET=$?; [ "$RET" != 0 ] && echo "ERROR[$RET]: Unable to install SABnzbd container" || echo "INFO: Installed SABnzbd container"
  # Get start time of container
  CONTAINER_START=$(docker logs -t sabnzbd | grep -m 1 -F '[cont-init.d] executing container initialization scripts...' | cut -f 1 -d ' ')
  # Wait up to $TIMEOUT seconds for container to boot and create configuration files
  for i in $(seq 1 $TIMEOUT)
  do
    # Check container logs for sign that container is ready to go
    if [ -z "$(docker logs --since "$CONTAINER_START" sabnzbd | grep -m 1 'Sending notification: SABnzbd - SABnzbd .* started')" ]; then
      sleep 1
      continue
    else
      # Give it a beat, just because
      sleep 1
      break
    fi
  done
  [ "$i" = "$TIMEOUT" ] && echo "WARNING: Timed out after $i seconds waiting for container to fully start. An unconfigured container may be running." || {
    echo "INFO: Waited $i seconds for SABnzbd container to fully start."
    # Check that configuration files are present after all this waiting
    if [ -s "$SABNZBD_ROOT/config/sabnzbd.ini" ]; then
      docker stop sabnzbd
      # Edit the configuration file
      sed -ri "/^notified_new_skin *=/ s/[0-9]+/2/
      /^host_whitelist *=/ s/,? *($HOSTNAME)? *$/, $HOSTNAME/
      /^permissions *=/ s/\"\"|[0-9]+/775/
      /^download_free *=/ s/=.*/= 5G/
      /^no_dupes *=/ s/[0-9]+/2/
      /^ignore_samples *=/ s/[0-9]+/1/
      /^sanitize_safe *=/ s/[0-9]+/1/
      /^direct_unpack_tested *=/ s/[0-9]+/1/
      /^direct_unpack *=/ s/[0-9]+/1/
      /^no_series_dupes *=/ s/[0-9]+/2/
      /^download_dir *=/ s|=.*$|= /downloads/incomplete|
      /^complete_dir *=/ s|=.*$|= /downloads|
      /^history_retention *=/ s/=.*$/= 90d/" $SABNZBD_ROOT/config/sabnzbd.ini
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
dir = "$MEDIA_ROOT/#downloads/$LIB_MOVIEDIR"
[[tv]]
priority = -100
pp = ""
name = tv
script = Default
newzbin = ""
order = 0
dir = "$MEDIA_ROOT/#downloads/$LIB_TVDIR"
[[music]]
priority = -100
pp = ""
name = music
script = Default
newzbin = ""
order = 0
dir = "$MEDIA_ROOT/#downloads/$LIB_MUSICDIR"
EOF
      # Extract the SABnzbd API key for use later
      SABNZBD_KEY=$(awk '/^api_key/ {print $3}' $SABNZBD_ROOT/config/sabnzbd.ini)
      docker start sabnzbd
      echo "INFO: Configured SABnzbd container"
    else
      echo "WARNING: SABnzdb container started, but config files not found. An unconfigured container may be running."
    fi
  }
fi

### Radarr
if [ "$INST_RADARR" = 1 ]; then
  echo "### Installing Radarr ###"
  # Prepare the filesystem for container
  useradd -u 1010 -g user -s /bin/bash -m -c "Radarr service account" radarr
  mkdir -p "$RADARR_ROOT"
  chown -R radarr:user "$RADARR_ROOT"
  setfacl -m u::rwx,g::rwx "$RADARR_ROOT"
  setfacl -d -m u::rwx,g::rwx "$RADARR_ROOT"
  if [ ! -d "$MEDIA_ROOT/$LIB_MOVIEDIR" ]; then
    mkdir -p "$MEDIA_ROOT/$LIB_MOVIEDIR"
    chown -R radarr:user "$MEDIA_ROOT/$LIB_MOVIEDIR"
    setfacl -m u::rwx,g::rwx "$MEDIA_ROOT/$LIB_MOVIEDIR"
    setfacl -d -m u::rwx,g::rwx "$MEDIA_ROOT/$LIB_MOVIEDIR"
  fi
  # Create Recycle Bin if it doesn't exist
  [ ! -d "$MEDIA_ROOT/#recycle/$LIB_MOVIEDIR" ] && mkdir -p "$MEDIA_ROOT/#recycle/$LIB_MOVIEDIR" && chown -R radarr:user "$MEDIA_ROOT/#recycle/$LIB_MOVIEDIR"
  # Install and run container
  docker pull linuxserver/radarr && \
  docker create \
    --name=radarr \
    -h radarr \
    -e PUID=1010 \
    -e PGID=1000 \
    -e TZ="$TZ" \
    -e DOCKER_MODS=linuxserver/mods:radarr-striptracks \
    -p 7878:7878 \
    -v $RADARR_ROOT:/config \
    -v $MEDIA_ROOT:$MEDIA_ROOT \
    --restart unless-stopped \
    --tty \
    linuxserver/radarr && \
  docker start radarr
  RET=$?; [ "$RET" != 0 ] && echo "ERROR[$RET]: Unable to install Radarr container" || echo "INFO: Installed Radarr container"
  # Get start time of container
  CONTAINER_START=$(docker logs -t radarr | grep -m 1 -F '[cont-init.d] executing container initialization scripts...' | cut -f 1 -d ' ')
  # Wait up to $TIMEOUT seconds for container to boot and create configuration files
  for i in $(seq 1 $TIMEOUT)
  do
    # Check container logs for sign that container is ready to go
    if [ -z "$(docker logs --since "$CONTAINER_START" radarr | grep -m 1 -F '[Info] Microsoft.Hosting.Lifetime: Content root path: /app/radarr/bin')" ]; then
      sleep 1
      continue
    else
      # Give it a beat, just because
      sleep 1
      break
    fi
  done
  [ "$i" = "$TIMEOUT" ] && echo "WARNING: Timed out after $i seconds waiting for container to fully start. An unconfigured container may be running." || {
    echo "INFO: Waited $i seconds for Sonarr container to fully start."
    # Check that configuration files are present after all this waiting
    if [ -s "$RADARR_ROOT/radarr.db" -a -s "$RADARR_ROOT/config.xml" ]; then
      docker stop radarr
      # Keeping this note for legacy learning
      # Shutdown just the Radarr service, keeping the container running so we can use SQLite to export and import the database
      #docker exec radarr s6-svc -d /var/run/s6/services/radarr
      # Update the database
      sqlite3 $RADARR_ROOT/radarr.db "UPDATE QualityDefinitions SET MinSize=2 WHERE Title='Bluray-480p' OR Title='WEBRip-480p'  OR Title='WEBDL-480p' OR Title='DVD-R' OR Title='DVD' OR Title='SDTV';
      UPDATE QualityDefinitions SET MinSize=3 WHERE Title='Bluray-576p';
      UPDATE QualityDefinitions SET MinSize=7,MaxSize=130 WHERE Title='Bluray-720p' OR Title='WEBRip-720p'  OR Title='WEBDL-720p' OR Title='HDTV-720p';
      UPDATE QualityDefinitions SET MinSize=10,PreferredSize=122,MaxSize=155 WHERE Title='HDTV-1080p' OR Title='WEBDL-1080p'  OR Title='WEBRip-1080p';
      UPDATE QualityDefinitions SET MinSize=15,PreferredSize=140,MaxSize=170 WHERE Title='Bluray-1080p' OR Title='Remux-1080p';
      UPDATE QualityDefinitions SET MinSize=35 WHERE Title='HDTV-2160p' OR Title='WEBDL-2160p' OR Title='WEBRip-2160p' OR Title='Bluray-2160p' OR Title='Remux-2160p' OR Title='BR-DISK' OR Title='Raw-HD';
      UPDATE Profiles SET Cutoff=7,UpgradeAllowed=1,Items=replace('[\\\n  {\\\n    \"quality\": 0,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 24,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 25,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 26,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 27,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 29,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 28,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 1,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 2,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 23,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"id\": 1000,\\\n    \"name\": \"WEB 480p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 12,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      },\\\n      {\\\n        \"quality\": 8,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      }\\\n    ],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 20,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 21,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 4,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"id\": 1001,\\\n    \"name\": \"WEB 720p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 14,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      },\\\n      {\\\n        \"quality\": 5,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      }\\\n    ],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 6,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 9,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"id\": 1002,\\\n    \"name\": \"WEB 1080p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 15,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      },\\\n      {\\\n        \"quality\": 3,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      }\\\n    ],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 7,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 30,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 16,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"id\": 1003,\\\n    \"name\": \"WEB 2160p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 17,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      },\\\n      {\\\n        \"quality\": 18,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      }\\\n    ],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 19,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 31,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 22,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 10,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  }\\\n]','\\\n',char(10)) WHERE Name='Any';
      INSERT INTO Profiles(Name,Cutoff,Items,Language,FormatItems,UpgradeAllowed,MinFormatScore,CutoffFormatScore) VALUES('Ultra-HD+',16,replace('[\\\n  {\\\n    \"quality\": 0,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 24,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 25,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 26,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 27,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 29,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 28,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 1,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 2,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 23,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1000,\\\n    \"name\": \"WEB 480p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 12,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      },\\\n      {\\\n        \"quality\": 8,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      }\\\n    ],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 20,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 21,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 4,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1001,\\\n    \"name\": \"WEB 720p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 14,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      },\\\n      {\\\n        \"quality\": 5,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      }\\\n    ],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 6,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 9,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1002,\\\n    \"name\": \"WEB 1080p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 15,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      },\\\n      {\\\n        \"quality\": 3,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      }\\\n    ],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 7,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 30,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 16,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"id\": 1003,\\\n    \"name\": \"WEB 2160p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 17,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      },\\\n      {\\\n        \"quality\": 18,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      }\\\n    ],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 19,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 31,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 22,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 10,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  }\\\n]','\\\n',char(10)),1,'[]',1,0,0);
      INSERT INTO Profiles(Name,Cutoff,Items,Language,FormatItems,UpgradeAllowed,MinFormatScore,CutoffFormatScore) VALUES('Foreign 720p/1080p',7,replace('[\\\n  {\\\n    \"quality\": 0,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 24,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 25,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 26,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 27,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 29,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 28,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 1,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 2,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 23,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"id\": 1000,\\\n    \"name\": \"WEB 480p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 12,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      },\\\n      {\\\n        \"quality\": 8,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      }\\\n    ],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 20,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 21,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 4,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"id\": 1001,\\\n    \"name\": \"WEB 720p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 14,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      },\\\n      {\\\n        \"quality\": 5,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      }\\\n    ],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 6,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 9,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"id\": 1002,\\\n    \"name\": \"WEB 1080p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 15,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      },\\\n      {\\\n        \"quality\": 3,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      }\\\n    ],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 7,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 30,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 16,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1003,\\\n    \"name\": \"WEB 2160p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 17,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      },\\\n      {\\\n        \"quality\": 18,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      }\\\n    ],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 19,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 31,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 22,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 10,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  }\\\n]','\\\n',char(10)),-1,'[]',1,0,0);
      UPDATE Profiles SET Cutoff=7,UpgradeAllowed=1,Items=replace('[\\\n  {\\\n    \"quality\": 0,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 24,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 25,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 26,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 27,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 29,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 28,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 1,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 2,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 23,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1000,\\\n    \"name\": \"WEB 480p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 12,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      },\\\n      {\\\n        \"quality\": 8,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      }\\\n    ],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 20,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 21,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 4,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"id\": 1001,\\\n    \"name\": \"WEB 720p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 14,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      },\\\n      {\\\n        \"quality\": 5,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      }\\\n    ],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 6,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 9,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"id\": 1002,\\\n    \"name\": \"WEB 1080p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 15,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      },\\\n      {\\\n        \"quality\": 3,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      }\\\n    ],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 7,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 30,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 16,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1003,\\\n    \"name\": \"WEB 2160p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 17,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      },\\\n      {\\\n        \"quality\": 18,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      }\\\n    ],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 19,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 31,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 22,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 10,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  }\\\n]','\\\n',char(10)) WHERE Name='HD - 720p/1080p';
      INSERT INTO Config(Key,Value) VALUES('cleanupmetadataimages','False');
      INSERT INTO Config(Key,Value) VALUES('recyclebin','$MEDIA_ROOT/#recycle/$LIB_MOVIEDIR/');
      INSERT INTO Config(Key,Value) VALUES('recyclebincleanupdays','30');
      INSERT INTO Config(Key,Value) VALUES('importextrafiles','True');
      INSERT INTO Config(Key,Value) VALUES('extrafileextensions','.srt,.jpg');
      INSERT INTO RootFolders(Path) VALUES('$MEDIA_ROOT/$LIB_MOVIEDIR/');
      INSERT INTO Indexers(Name,Implementation,Settings,ConfigContract,EnableRss,EnableAutomaticSearch,EnableInteractiveSearch) VALUES('NZBgeek','Newznab',replace('{\\\n  \"baseUrl\": \"https://api.nzbgeek.info\",\\\n  \"multiLanguages\": [],\\\n  \"apiKey\": \"$NZBGEEK_KEY\",\\\n  \"categories\": [\\\n    2000,\\\n    2010,\\\n    2020,\\\n    2030,\\\n    2040,\\\n    2045,\\\n    2050,\\\n    2060\\\n  ],\\\n  \"animeCategories\": [],\\\n  \"removeYear\": false,\\\n  \"searchByTitle\": false\\\n}','\\\n',char(10)),'NewznabSettings',1,1,1);
      INSERT INTO Restrictions(Required,Preferred,Ignored,Tags) VALUES(NULL,NULL,'3D','[]');
      INSERT INTO Notifications(Name,OnGrab,OnDownload,Settings,Implementation,ConfigContract,OnUpgrade,Tags,OnRename,OnHealthIssue,IncludeHealthWarnings,OnMovieDelete) VALUES('Remux movie',0,1,replace('{\\\n  \"path\": \"/usr/local/bin/striptracks.sh\",\\\n}','\\\n',char(10)),'CustomScript','CustomScriptSettings',1,'[]',0,0,0,0);
      INSERT INTO ImportLists(Enabled,Name,Implementation,ConfigContract,Settings,EnableAuto,RootFolderPath,ShouldMonitor,ProfileId,MinimumAvailability,Tags,SearchOnAdd) VALUES(1,'IMDb List','IMDbListImport','IMDbListSettings',replace('{\\\n  \"listId\": \"$IMDB_LIST_ID\"\\\n}','\\\n',char(10)),1,'$MEDIA_ROOT/$LIB_MOVIEDIR',1,6,3,'[]',1);
      INSERT INTO NamingConfig(MultiEpisodeStyle,ReplaceIllegalCharacters,StandardMovieFormat,MovieFolderFormat,ColonReplacementFormat,RenameMovies) VALUES(0,1,'{Movie Title} ({Release Year})','{Movie Title} ({Release Year})',1,1);
      $([ "$INST_SAB" = 1 ] && echo "INSERT INTO DownloadClients(Enable,Name,Implementation,Settings,ConfigContract) VALUES(1,'MovieGnomes SABnzbd','Sabnzbd','{  \"host\": \"$HOSTNAME\",  \"port\": 8080,  \"apiKey\": \"$SABNZBD_KEY\",  \"movieCategory\": \"movies\",  \"recentMoviePriority\": -100,  \"olderMoviePriority\": -100,  \"useSsl\": false}','SabnzbdSettings');")
      $([ "$INST_KODI" = 1 ] && echo "INSERT INTO Notifications(Name,OnGrab,OnDownload,Settings,Implementation,ConfigContract,OnUpgrade,Tags,OnRename,OnHealthIssue,IncludeHealthWarnings,OnMovieDelete,OnMovieFileDelete,OnMovieFileDeleteForUpgrade) VALUES('MovieGnomes Kodi',0,1,'{  \"host\": \"$HOSTNAME\",  \"port\": 8085,  \"username\": \"kodi\",  \"password\": \"\",  \"displayTime\": 5,  \"notify\": false,  \"updateLibrary\": true,  \"cleanLibrary\": true,  \"alwaysUpdate\": false}','Xbmc','XbmcSettings',1,'[]',1,0,0,1,1,1);")
      "
      RET=$?; [ "$RET" != 0 ] && echo "WARNING[$RET]: SQL error editing Radarr database"
      # Edit the configuration file
      sed -i '/<\/Branch>$/ a  <LaunchBrowser>False<\/LaunchBrowser>' $RADARR_ROOT/config.xml
      # Extract the Radarr API key for use later
      while read_xml; do [[ $XML_ENTITY = "ApiKey" ]] && RADARR_KEY=$XML_CONTENT; done < $RADARR_ROOT/config.xml
      docker start radarr
      echo "INFO: Configured Radarr container"
    else
      echo "WARNING: Radarr container started, but config files not found. An unconfigured container may be running."
    fi
  }
fi

### Sonarr
if [ "$INST_SONARR" = 1 ]; then
  echo "### Installing Sonarr ###"
  # Prepare the filesystem for container
  useradd -u 1011 -g user -s /bin/bash -m -c "Sonarr service account" sonarr
  mkdir -p "$SONARR_ROOT"
  mkdir -p "$MEDIA_ROOT/$LIB_TVDIR"
  chown -R sonarr:user "$SONARR_ROOT"
  setfacl -m u::rwx,g::rwx "$SONARR_ROOT"
  setfacl -d -m u::rwx,g::rwx "$SONARR_ROOT"
  if [ ! -d "$MEDIA_ROOT/$LIB_TVDIR" ]; then
    mkdir -p "$MEDIA_ROOT/$LIB_TVDIR"
    chown -R radarr:user "$MEDIA_ROOT/$LIB_TVDIR"
    setfacl -m u::rwx,g::rwx "$MEDIA_ROOT/$LIB_TVDIR"
    setfacl -d -m u::rwx,g::rwx "$MEDIA_ROOT/$LIB_TVDIR"
  fi
  # Create Recycle Bin if it doesn't exist
  [ ! -d "$MEDIA_ROOT/#recycle/$LIB_TVDIR" ] && mkdir -p "$MEDIA_ROOT/#recycle/$LIB_TVDIR" && chown -R sonarr:user "$MEDIA_ROOT/#recycle/$LIB_TVDIR"
  # Install and run container
  docker pull linuxserver/sonarr && \
  docker create \
    --name=sonarr \
    -h sonarr \
    -e PUID=1011 \
    -e PGID=1000 \
    -e TZ="$TZ" \
    -e DOCKER_MODS=linuxserver/mods:radarr-striptracks \
    -p 8989:8989 \
    -v $SONARR_ROOT:/config \
    -v $MEDIA_ROOT:$MEDIA_ROOT \
    --restart unless-stopped \
    --tty \
    linuxserver/sonarr &&
  docker start sonarr
  RET=$?; [ "$RET" != 0 ] && echo "ERROR[$RET]: Unable to install Sonarr container" || echo "INFO: Installed Sonarr container"
  # Get start time of container
  CONTAINER_START=$(docker logs -t sonarr | grep -m 1 -F '[cont-init.d] executing container initialization scripts...' | cut -f 1 -d ' ')
  # Wait up to $TIMEOUT seconds for container to boot and create configuration files
  for i in $(seq 1 $TIMEOUT)
  do
    # Check container logs for sign that container is ready to go
    if [ -z "$(docker logs --since "$CONTAINER_START" sonarr | grep -m 1 -F '[Info] LanguageProfileService: Setting up default language profiles')" ]; then
      sleep 1
      continue
    else
      # Give it a beat, just because
      sleep 1
      break
    fi
  done
  [ "$i" = "$TIMEOUT" ] && echo "WARNING: Timed out after $i seconds waiting for container to fully start. An unconfigured container may be running." || {
    echo "INFO: Waited $i seconds for Sonarr container to fully start."
    # Check that configuration files are present after all this waiting
    if [ -s "$SONARR_ROOT/sonarr.db" -a -s "$SONARR_ROOT/config.xml" ]; then
      docker stop sonarr
      # Update the database
      sqlite3 $SONARR_ROOT/sonarr.db "UPDATE QualityDefinitions SET MinSize=13,MaxSize=155 WHERE Title='HDTV-1080p' OR Title='WEBRip-1080p' OR Title='WEBDL-1080p' OR Title='Bluray-1080p';
      UPDATE QualityDefinitions SET MinSize=35 WHERE Title='Raw-HD';
      UPDATE QualityDefinitions SET MinSize=5 WHERE Title='HDTV-720p' OR Title='WEBRip-720p' OR Title='WEBDL-720p';
      UPDATE QualityDefinitions SET MinSize=6 WHERE Title='Bluray-720p';
      UPDATE QualityProfiles SET Cutoff=1,Items=replace('[\\\n  {\\\n    \"quality\": 0,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 1,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"id\": 1000,\\\n    \"name\": \"WEB 480p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 12,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      },\\\n      {\\\n        \"quality\": 8,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      }\\\n    ],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 2,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 13,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 4,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 9,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 10,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1001,\\\n    \"name\": \"WEB 720p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 14,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      },\\\n      {\\\n        \"quality\": 5,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      }\\\n    ],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 6,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"id\": 1002,\\\n    \"name\": \"WEB 1080p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 15,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      },\\\n      {\\\n        \"quality\": 3,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      }\\\n    ],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 7,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 20,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 16,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1003,\\\n    \"name\": \"WEB 2160p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 17,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      },\\\n      {\\\n        \"quality\": 18,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      }\\\n    ],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 19,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 21,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  }\\\n]','\\\n',char(10)) WHERE Name='Any';
      UPDATE QualityProfiles SET Cutoff=2,Items=replace('[\\\n  {\\\n    \"quality\": 0,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 1,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"id\": 1000,\\\n    \"name\": \"WEB 480p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 12,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      },\\\n      {\\\n        \"quality\": 8,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      }\\\n    ],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 2,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 13,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 4,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 9,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 10,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1001,\\\n    \"name\": \"WEB 720p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 14,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      },\\\n      {\\\n        \"quality\": 5,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      }\\\n    ],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 6,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1002,\\\n    \"name\": \"WEB 1080p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 15,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      },\\\n      {\\\n        \"quality\": 3,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      }\\\n    ],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 7,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 20,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 16,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1003,\\\n    \"name\": \"WEB 2160p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 17,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      },\\\n      {\\\n        \"quality\": 18,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      }\\\n    ],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 19,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 21,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  }\\\n]','\\\n',char(10)) WHERE Name='SD';
      UPDATE QualityProfiles SET Cutoff=1001,UpgradeAllowed=1,Items=replace('[\\\n  {\\\n    \"quality\": 0,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 1,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1000,\\\n    \"name\": \"WEB 480p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 12,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      },\\\n      {\\\n        \"quality\": 8,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      }\\\n    ],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 2,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 13,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 4,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 9,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 10,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1001,\\\n    \"name\": \"WEB 720p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 14,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      },\\\n      {\\\n        \"quality\": 5,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      }\\\n    ],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 6,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"id\": 1002,\\\n    \"name\": \"WEB 1080p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 15,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      },\\\n      {\\\n        \"quality\": 3,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      }\\\n    ],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 7,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 20,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 16,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1003,\\\n    \"name\": \"WEB 2160p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 17,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      },\\\n      {\\\n        \"quality\": 18,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      }\\\n    ],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 19,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 21,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  }\\\n]','\\\n',char(10)) WHERE Name='HD-720p';
      UPDATE QualityProfiles SET Cutoff=1002,UpgradeAllowed=1,Items=replace('[\\\n  {\\\n    \"quality\": 0,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 1,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1000,\\\n    \"name\": \"WEB 480p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 12,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      },\\\n      {\\\n        \"quality\": 8,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      }\\\n    ],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 2,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 13,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 4,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 9,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 10,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1001,\\\n    \"name\": \"WEB 720p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 14,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      },\\\n      {\\\n        \"quality\": 5,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      }\\\n    ],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 6,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1002,\\\n    \"name\": \"WEB 1080p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 15,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      },\\\n      {\\\n        \"quality\": 3,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      }\\\n    ],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 7,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 20,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 16,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1003,\\\n    \"name\": \"WEB 2160p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 17,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      },\\\n      {\\\n        \"quality\": 18,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      }\\\n    ],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 19,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 21,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  }\\\n]','\\\n',char(10)) WHERE Name='HD-1080p';
      UPDATE QualityProfiles SET Cutoff=1003,UpgradeAllowed=1,Items=replace('[\\\n  {\\\n    \"quality\": 0,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 1,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1000,\\\n    \"name\": \"WEB 480p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 12,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      },\\\n      {\\\n        \"quality\": 8,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      }\\\n    ],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 2,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 13,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 4,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 9,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 10,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1001,\\\n    \"name\": \"WEB 720p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 14,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      },\\\n      {\\\n        \"quality\": 5,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      }\\\n    ],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 6,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1002,\\\n    \"name\": \"WEB 1080p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 15,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      },\\\n      {\\\n        \"quality\": 3,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      }\\\n    ],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 7,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 20,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 16,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"id\": 1003,\\\n    \"name\": \"WEB 2160p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 17,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      },\\\n      {\\\n        \"quality\": 18,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      }\\\n    ],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 19,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 21,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  }\\\n]','\\\n',char(10)) WHERE Name='Ultra-HD';
      UPDATE QualityProfiles SET Cutoff=9,UpgradeAllowed=1,Items=replace('[\\\n  {\\\n    \"quality\": 0,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 1,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1000,\\\n    \"name\": \"WEB 480p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 12,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      },\\\n      {\\\n        \"quality\": 8,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      }\\\n    ],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 2,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 13,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 4,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 10,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1001,\\\n    \"name\": \"WEB 720p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 14,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      },\\\n      {\\\n        \"quality\": 5,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      }\\\n    ],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 6,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 9,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"id\": 1002,\\\n    \"name\": \"WEB 1080p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 15,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      },\\\n      {\\\n        \"quality\": 3,\\\n        \"items\": [],\\\n        \"allowed\": true\\\n      }\\\n    ],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 7,\\\n    \"items\": [],\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"quality\": 20,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 16,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"id\": 1003,\\\n    \"name\": \"WEB 2160p\",\\\n    \"items\": [\\\n      {\\\n        \"quality\": 17,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      },\\\n      {\\\n        \"quality\": 18,\\\n        \"items\": [],\\\n        \"allowed\": false\\\n      }\\\n    ],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 19,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"quality\": 21,\\\n    \"items\": [],\\\n    \"allowed\": false\\\n  }\\\n]','\\\n',char(10)) WHERE Name='HD - 720p/1080p';
      INSERT INTO LanguageProfiles VALUES(3,'Japanese/English',replace('[\\\n  {\\\n    \"language\": 27,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 26,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 0,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 13,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 17,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 14,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 3,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 11,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 18,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 12,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 15,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 24,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 21,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 5,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 9,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 22,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 23,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 20,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 4,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 2,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 19,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 16,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 7,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 6,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 25,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 10,\\\n    \"allowed\": false\\\n  },\\\n  {\\\n    \"language\": 8,\\\n    \"allowed\": true\\\n  },\\\n  {\\\n    \"language\": 1,\\\n    \"allowed\": true\\\n  }\\\n]','\\\n',char(10)),8,0);
      INSERT INTO ReleaseProfiles(Required,Preferred,Ignored,Tags,IncludePreferredWhenRenaming,Enabled,IndexerId,Name) VALUES('[]',replace('[\\\n  {\\\n    \"key\": \"HDR\",\\\n    \"value\": 100\\\n  }\\\n]','\\\n',char(10)),'[]','[]',0,1,0,'HDR');
      INSERT INTO Config(Key,Value) VALUES('maximumsize','20000');
      INSERT INTO Config(Key,Value) VALUES('cleanupmetadataimages','False');
      INSERT INTO Config(Key,Value) VALUES('recyclebin','$MEDIA_ROOT/#recycle/$LIB_TVDIR/');
      INSERT INTO Config(Key,Value) VALUES('recyclebincleanupdays','30');
      INSERT INTO Config(Key,Value) VALUES('importextrafiles','True');
      INSERT INTO Config(Key,Value) VALUES('rsssyncinterval','60');
      INSERT INTO RootFolders(Path) VALUES('$MEDIA_ROOT/$LIB_TVDIR/');
      INSERT INTO Notifications(Name,OnGrab,OnDownload,Settings,Implementation,ConfigContract,OnUpgrade,Tags,OnRename,OnHealthIssue,IncludeHealthWarnings,OnSeriesDelete,OnEpisodeFileDelete,OnEpisodeFileDeleteForUpgrade,OnApplicationUpdate) VALUES('Remux TV show',0,1,replace('{\\\n  \"path\": \"/usr/local/bin/striptracks.sh\"\\\n}','\\\n',char(10)),'CustomScript','CustomScriptSettings',1,'[]',0,0,0,0,0,0,0);
      INSERT INTO NamingConfig(MultiEpisodeStyle,RenameEpisodes,StandardEpisodeFormat,DailyEpisodeFormat,SeasonFolderFormat,SeriesFolderFormat,AnimeEpisodeFormat,ReplaceIllegalCharacters,SpecialsFolderFormat) VALUES(2,1,'{Series Title} {season:00}x{episode:00} - {Episode Title}','{Series Title} - {Air-Date} - {Episode Title}','Season {season}','{Series Title}','{Series Title} {season:00}x{episode:00} - {Episode Title}',1,'Specials');
      INSERT INTO Indexers(Name,Implementation,Settings,ConfigContract,EnableRss,EnableAutomaticSearch,EnableInteractiveSearch) VALUES('GingaDADDY','Newznab',replace('{\\\n  \"baseUrl\": \"https://www.gingadaddy.com/api.php\",\\\n  \"apiPath\": \"/api\",\\\n  \"apiKey\": \"$GINGA_KEY\",\\\n  \"categories\": [\\\n    5030,\\\n    5040\\\n  ],\\\n  \"animeCategories\": [\\\n    5000\\\n  ]\\\n}','\\\n',char(10)),'NewznabSettings',1,1,1);
      INSERT INTO Indexers(Name,Implementation,Settings,ConfigContract,EnableRss,EnableAutomaticSearch,EnableInteractiveSearch) VALUES('NZBgeek','Newznab',replace('{\\\n  \"baseUrl\": \"https://api.nzbgeek.info\",\\\n  \"apiPath\": \"/api\",\\\n  \"apiKey\": \"$NZBGEEK_KEY\",\\\n  \"categories\": [\\\n    5000,\\\n    5020,\\\n    5030,\\\n    5040,\\\n    5045,\\\n    5050,\\\n    5070\\\n  ],\\\n  \"animeCategories\": [\\\n    5070\\\n  ]\\\n}','\\\n',char(10)),'NewznabSettings',1,1,1);
      $([ "$INST_SAB" = 1 ] && echo "INSERT INTO DownloadClients(Enable,Name,Implementation,Settings,ConfigContract) VALUES(1,'MovieGnomes SABnzbd','Sabnzbd',replace('{\\\n  \"host\": \"$HOSTNAME\",\\\n  \"port\": 8080,\\\n  \"apiKey\": \"$SABNZBD_KEY\",\\\n  \"tvCategory\": \"tv\",\\\n  \"recentTvPriority\": -100,\\\n  \"olderTvPriority\": -100,\\\n  \"useSsl\": false\\\n}','\\\n',char(10)),'SabnzbdSettings');")
      $([ "$INST_KODI" = 1 ] && echo "INSERT INTO Notifications(Name,OnGrab,OnDownload,Settings,Implementation,ConfigContract,OnUpgrade,Tags,OnRename,OnHealthIssue,IncludeHealthWarnings,OnSeriesDelete,OnEpisodeFileDelete,OnEpisodeFileDeleteForUpgrade,OnApplicationUpdate) VALUES('MovieGnomes Kodi',0,1,replace('{\\\n  \"host\": \"$HOSTNAME\",\\\n  \"port\": 8085,\\\n  \"username\": \"kodi\",\\\n  \"displayTime\": 5,\\\n  \"notify\": false,\\\n  \"updateLibrary\": true,\\\n  \"cleanLibrary\": true,\\\n  \"alwaysUpdate\": true\\\n}','\\\n',char(10)),'Xbmc','XbmcSettings',1,'[]',1,0,0,1,1,1,0);")
      "
      RET=$?; [ "$RET" != 0 ] && echo "WARNING[$RET]: SQL error editing Sonarr database"
      # Edit the configuration file
      sed -i '/<\/Branch>/ a  <LaunchBrowser>False</LaunchBrowser>' $SONARR_ROOT/config.xml
      # Extract the Sonarr API key for use later
      while read_xml; do [[ $XML_ENTITY = "ApiKey" ]] && SONARR_KEY=$XML_CONTENT; done < $SONARR_ROOT/config.xml
      docker start sonarr
      echo "INFO: Configured Sonarr container"
    else
      echo "WARNING: Sonarr container started, but config files not found. An unconfigured container may be running."
    fi
  }
fi

### Bazarr
if [ "$INST_BAZARR" = 1 ]; then
  echo "### Installing Bazarr ###"
  # Prepare the filesystem for container
  useradd -u 1012 -g user -s /bin/bash -m -c "Bazarr service account" bazarr
  mkdir -p "$BAZARR_ROOT"
  chown -R bazarr:user "$BAZARR_ROOT"
  setfacl -m u::rwx,g::rwx "$BAZARR_ROOT"
  setfacl -d -m u::rwx,g::rwx "$BAZARR_ROOT"
  # Install and run container
  docker pull linuxserver/bazarr && \
  docker create \
    --name=bazarr \
    -h bazarr \
    -e PUID=1012 \
    -e PGID=1000 \
    -e TZ="$TZ" \
    -p 6767:6767 \
    -v $BAZARR_ROOT:/config \
    -v $MEDIA_ROOT:$MEDIA_ROOT \
    --restart unless-stopped \
    --tty \
    linuxserver/bazarr && \
  docker start bazarr
  RET=$?; [ "$RET" != 0 ] && echo "ERROR[$RET]: Unable to install Bazarr container" || echo "INFO: Installed Bazarr container"
  # Get start time of container
  CONTAINER_START=$(docker logs -t bazarr | grep -m 1 -F '[cont-init.d] executing container initialization scripts...' | cut -f 1 -d ' ')
  # Wait up to $TIMEOUT seconds for container to boot and create configuration files
  for i in $(seq 1 $TIMEOUT)
  do
    # Check container logs for sign that container is ready to go
    if [ -z "$(docker logs --since "$CONTAINER_START" bazarr | grep -m 1 -F 'BAZARR is started and waiting for request')" ]; then
      sleep 1
      continue
    else
      # Give it a beat, just because
      sleep 1
      break
    fi
  done
  [ "$i" = "$TIMEOUT" ] && echo "WARNING: Timed out after $i seconds waiting for container to fully start. An unconfigured container may be running." || {
    echo "INFO: Waited $i seconds for Bazarr container to fully start."
    # Check that configuration files are present after all this waiting
    if [ -s "$BAZARR_ROOT/db/bazarr.db" -a -s "$BAZARR_ROOT/config/config.ini" ]; then
      docker stop bazarr
      # Update the database
      sqlite3 $BAZARR_ROOT/db/bazarr.db "UPDATE table_settings_languages SET enabled=1 WHERE code3='eng';
      INSERT INTO table_languages_profiles(profileId,cutoff,items,name,mustContain,mustNotContain) VALUES(1,NULL,'[{\"id\": 1, \"language\": \"en\", \"audio_exclude\": \"False\", \"hi\": \"False\", \"forced\": \"False\"}]','English','[]','[]');
      "
      # Edit configuration file
      sed -ri "/^\[general\]/,/^\[.*\]/ {
        s/^(path_mappings *=).*/\1 []/
        s/^(path_mappings_movie *=).*/\1 []/
        s/^(single_language *=).*/\1 False/
        s/^(use_postprocessing *=).*/\1 True/
        s/^(postprocessing_cmd *=).*/\1 \/config\/cleansubs.sh \"{{subtitles}}\" ;/
        $([ "$INST_RADARR" = 1 ] && echo "s/^(use_radarr *=).*/\1 True/")
        $([ "$INST_SONARR" = 1 ] && echo "s/^(use_sonarr *=).*/\1 True/")
        s/^(serie_default_profile *=).*/\1 1/
        s/^(serie_default_enabled *=).*/\1 True/
        s/^(movie_default_profile *=).*/\1 1/
        s/^(movie_default_enabled *=).*/\1 True/
        s/^(upgrade_subs *=).*/\1 True/
        s/^(upgrade_manual *=).*/\1 False/
        s/^(days_to_upgrade_subs *=).*/\1 30/
        s/^(wanted_search_frequency *=).*/\1 24/
        s/^(enabled_providers *=).*/\1 ['opensubtitles', 'subscene']/
        s/^(page_size *=).*/\1 50/
        s/^(embedded_subs_show_desired *=).*/\1 False/
        s/^(adaptive_searching *=).*/\1 True/
        s/^(upgrade_frequency *=).*/\1 24/
        s/^(wanted_search_frequency_movie *=).*/\1 24/
        s/^(subzero_mods *=).*/\1 remove_HI/
        /^hi_extension *=/ {
          a serie_default_language = ['en']
          a serie_default_hi = False
          a serie_default_forced = False
          a movie_default_language = ['en']
          a movie_default_hi = False
          a movie_default_forced = False
        }
      }
      $([ "$INST_SONARR" = 1 ] && echo "/^\[sonarr\]/,/^\[.*\]/ {
        s/^(ip *=).*/\1 $HOSTNAME/
        s/^(apikey *=).*/\1 $SONARR_KEY/
        s/^(full_update *=).*/\1 Weekly/
        s/^(only_monitored *=).*/\1 True/
      }")
      $([ "$INST_RADARR" = 1 ] && echo "/^\[radarr\]/,/^\[.*\]/ {
        s/^(ip *=).*/\1 $HOSTNAME/
        s/^(apikey *=).*/\1 $RADARR_KEY/
        s/^(full_update *=).*/\1 Weekly/
        s/^(only_monitored *=).*/\1 True/
      }")
      /^\[subscene\]/,/^\[.*\]/ {
        s/^(username *=).*/\1 $(quoteSubst "$SUBS1_USER")/
        s/^(password *=).*/\1 $(quoteSubst "$SUBS1_PASS")/
      }
      /^\[opensubtitles\]/,/^\[.*\]/ {
        s/^(username *=).*/\1 $(quoteSubst "$SUBS2_USER")/
        s/^(password *=).*/\1 $(quoteSubst "$SUBS2_PASS")/
        s/^(ssl *=).*/\1 True/
      }" $BAZARR_ROOT/config/config.ini
      # Get Bazarr subtitle script from GitHub
      wget -q -P "$BAZARR_ROOT" "$CLEANSUBS_PATH/cleansubs.sh" && chown bazarr:user "$BAZARR_ROOT/cleansubs.sh" && chmod +x "$BAZARR_ROOT/cleansubs.sh"
      RET=$?; [ "$RET" != 0 ] && echo "WARNING[$RET]: Unable to download cleansubs.sh for Bazarr" || echo "INFO: Downloaded cleansubs.sh for Bazarr"
      docker start bazarr
      echo "INFO: Configured Bazarr container"
    else
      echo "WARNING: Bazarr container started, but config files not found. An unconfigured container may be running."
    fi
  }
fi

### Lidarr
if [ "$INST_LIDARR" = 1 ]; then
  echo "### Installing Lidarr ###"
  # Prepare the filesystem for container
  useradd -u 1013 -g user -s /bin/bash -m -c "Lidarr service account" lidarr
  mkdir -p "$LIDARR_ROOT"
  chown -R lidarr:user "$LIDARR_ROOT"
  setfacl -m u::rwx,g::rwx "$LIDARR_ROOT"
  setfacl -d -m u::rwx,g::rwx "$LIDARR_ROOT"
  # Create Recycle Bins after mount if they don't exist
  [ ! -d "$MEDIA_ROOT/#recycle/$LIB_MUSICDIR" ] && mkdir -p "$MEDIA_ROOT/#recycle/$LIB_MUSICDIR" && chown -R lidarr:user "$MEDIA_ROOT/#recycle/$LIB_MUSICDIR"
  # Install and run container
  docker pull linuxserver/lidarr && \
  docker create \
    --name=lidarr \
    -h lidarr \
    -e PUID=1013 \
    -e PGID=1000 \
    -e TZ="$TZ" \
    -e DOCKER_MODS=linuxserver/mods:lidarr-flac2mp3 \
    -p 8686:8686 \
    -v $LIDARR_ROOT:/config \
    -v $MEDIA_ROOT:$MEDIA_ROOT \
    --restart unless-stopped \
    --tty \
    linuxserver/lidarr && \
  docker start lidarr
  RET=$?; [ "$RET" != 0 ] && echo "ERROR[$RET]: Unable to install Lidarr container" || echo "INFO: Installed Lidarr container"
  # Get start time of container
  CONTAINER_START=$(docker logs -t lidarr | grep -m 1 -F '[cont-init.d] executing container initialization scripts...' | cut -f 1 -d ' ')
  # Wait up to $TIMEOUT seconds for container to boot and create configuration files
  for i in $(seq 1 $TIMEOUT)
  do
    # Check container logs for sign that container is ready to go
    if [ -z "$(docker logs --since "$CONTAINER_START" lidarr | grep -m 1 -F '[Info] MetadataProfileService: Setting up empty metadata profile')" ]; then
      sleep 1
      continue
    else
      # Give it a beat, just because
      sleep 1
      break
    fi
  done
  [ "$i" = "$TIMEOUT" ] && echo "WARNING: Timed out after $i seconds waiting for container to fully start. An unconfigured container may be running." || {
    echo "INFO: Waited $i seconds for Lidarr container to fully start."
    # Check that configuration files are present after all this waiting
    if [ -s "$LIDARR_ROOT/lidarr.db" -a -s "$LIDARR_ROOT/config.xml" ]; then
      docker stop lidarr
      # Update the database
      sqlite3 $LIDARR_ROOT/lidarr.db "INSERT INTO Config(Key,Value) VALUES('deleteemptyfolders','True');
      INSERT INTO Config(Key,Value) VALUES('maximumsize','2048');
      INSERT INTO Config(Key,Value) VALUES('cleanupmetadataimages','False');
      INSERT INTO Config(Key,Value) VALUES('removefaileddownloads','True');
      INSERT INTO Config(Key,Value) VALUES('writeaudiotags','NewFiles');
      INSERT INTO Config(Key,Value) VALUES('recyclebin','$MEDIA_ROOT/#recycle/$LIB_MUSICDIR');
      INSERT INTO Config(Key,Value) VALUES('recyclebincleanupdays','30');
      INSERT INTO Config(Key,Value) VALUES('rsssyncinterval','60');
      INSERT INTO Config(Key,Value) VALUES('expandalbumbydefault','True');
      INSERT INTO Config(Key,Value) VALUES('scrubaudiotags','True');
      INSERT INTO RootFolders(Path,Name,DefaultMetadataProfileId,DefaultQualityProfileId,DefaultMonitorOption,DefaultTags) VALUES('$MEDIA_ROOT/$LIB_MUSICDIR/','Music',1,1,0,'[]');
      INSERT INTO NamingConfig(ReplaceIllegalCharacters,ArtistFolderFormat,RenameTracks,StandardTrackFormat,MultiDiscTrackFormat) VALUES(1,'{Artist Name}',1,'{Album Title}/{track:00} {Track Title}','{Album Title}/{medium:0}-{track:00} {Track Title}');
      INSERT INTO Indexers(Name,Implementation,Settings,ConfigContract,EnableRss,EnableAutomaticSearch,EnableInteractiveSearch) VALUES('NZBgeek','Newznab',replace('{\\\n  \"baseUrl\": \"https://api.nzbgeek.info\",\\\n  \"apiPath\": \"/api\",\\\n  \"apiKey\": \"$NZBGEEK_KEY\",\\\n  \"categories\": [\\\n    3000,\\\n    3010,\\\n    3030,\\\n    3040\\\n  ]\\\n}','\\\n',char(10)),'NewznabSettings',1,1,1);
      INSERT INTO Notifications(Name,OnGrab,Settings,Implementation,ConfigContract,OnUpgrade,Tags,OnRename,OnReleaseImport,OnHealthIssue,IncludeHealthWarnings,OnDownloadFailure,OnImportFailure,OnTrackRetag) VALUES('FLAC to MP3',0,replace('{\\\n  \"path\": \"/usr/local/bin/flac2mp3.sh\",\\\n  \"arguments\": \"\"\\\n}','\\\n',char(10)),'CustomScript','CustomScriptSettings',1,'[]',0,1,0,0,0,0,0);
      UPDATE QualityProfiles SET Cutoff=1004,UpgradeAllowed=1 WHERE Name='Any';
      $([ "$INST_SAB" = 1 ] && echo "INSERT INTO DownloadClients(Enable,Name,Implementation,Settings,ConfigContract) VALUES(1,'MovieGnomes SABnzbd','Sabnzbd',replace('{\\\n  \"host\": \"$HOSTNAME\",\\\n  \"port\": 8080,\\\n  \"apiKey\": \"$SABNZBD_KEY\",\\\n  \"musicCategory\": \"music\",\\\n  \"recentTvPriority\": -100,\\\n  \"olderTvPriority\": -100,\\\n  \"useSsl\": false\\\n}','\\\n',char(10)),'SabnzbdSettings');")
      $([ "$INST_KODI" = 1 ] && echo "INSERT INTO Notifications(Name,OnGrab,Settings,Implementation,ConfigContract,OnUpgrade,Tags,OnRename,OnReleaseImport,OnHealthIssue,IncludeHealthWarnings,OnDownloadFailure,OnImportFailure,OnTrackRetag) VALUES('MovieGnomes Kodi',0,replace('{\\\n  \"host\": \"$HOSTNAME\",\\\n  \"port\": 8085,\\\n  \"username\": \"kodi\",\\\n  \"password\": \"\",\\\n  \"displayTime\": 5,\\\n  \"notify\": false,\\\n  \"updateLibrary\": true,\\\n  \"cleanLibrary\": true,\\\n  \"alwaysUpdate\": true\\\n}','\\\n',char(10)),'Xbmc','XbmcSettings',1,'[]',1,1,0,0,0,0,0);")
      "
      RET=$?; [ "$RET" != 0 ] && echo "WARNING[$RET]: SQL error editing Lidarr database"
      # Edit the configuration file
      sed -i '/<\/Branch>/ a  <LaunchBrowser>False</LaunchBrowser>' $LIDARR_ROOT/config.xml
      # Extract the Lidarr API key for use later (not used today)
      while read_xml; do [[ $XML_ENTITY = "ApiKey" ]] && LIDARR_KEY=$XML_CONTENT; done < $LIDARR_ROOT/config.xml
      docker start lidarr
      echo "INFO: Configured Lidarr container"
    else
      echo "WARNING: Lidarr container started, but config files not found. An unconfigured container may be running."
    fi
  }
fi

### Kodi
if [ "$INST_KODI" = 1 ]; then
  echo "### Installing Kodi Headless ###"
  # Prepare the filesystem for container
  useradd -u 1014 -g user -s /bin/bash -m -c "Kodi service account" kodi
  mkdir -p "$KODI_ROOT"
  chown -R kodi:user "$KODI_ROOT"
  setfacl -m u::rwx,g::rwx "$KODI_ROOT"
  setfacl -d -m u::rwx,g::rwx "$KODI_ROOT"
  # Install and run container
  docker pull matthuisman/kodi-headless:Matrix && \
  docker create \
    --name=kodi-headless \
    -h kodi-headless \
    -e PUID=1014 \
    -e PGID=1000 \
    -e TZ="$TZ" \
    -p 8085:8080 \
    -v $KODI_ROOT:/config/.kodi \
    --restart unless-stopped \
    --tty \
    matthuisman/kodi-headless:Matrix && \
  docker start kodi-headless
  RET=$?; [ "$RET" != 0 ] && echo "ERROR[$RET]: Unable to install Kodi headless container" || echo "INFO: Installed Kodi headless container"
  # Get start time of container
  CONTAINER_START=$(docker logs -t kodi-headless | grep -m 1 -F '[cont-init.d] executing container initialization scripts...' | cut -f 1 -d ' ')
  # Wait up to $TIMEOUT seconds for container to boot and create configuration files
  for i in $(seq 1 $TIMEOUT)
  do
    # Check container logs for sign that container is ready to go
    if [ -z "$(docker logs --since "$CONTAINER_START" kodi-headless | grep -m 1 -F '[services.d] done.')" ]; then
      sleep 1
      continue
    else
      # Give it a beat, just because
      sleep 1
      break
    fi
  done
  [ "$i" = "$TIMEOUT" ] && echo "WARNING: Timed out after $i seconds waiting for container to fully start. An unconfigured container may be running." || {
    echo "INFO: Waited $i seconds for Kodi container to fully start."
    # Check that configuration files are present after all this waiting
    if [ -s "$KODI_ROOT/userdata/Database/Addons33.db" -a -s "$KODI_ROOT/userdata/guisettings.xml" -a -s "$KODI_ROOT/userdata/advancedsettings.xml" ]; then
      # Install The TVDB scraper addon
      curl -s "$THETVDB_PATH" | \
      awk 'BEGIN {FS=">"}
      # Get a list of available versions from the download page
      /<a href="metadata\.tvdb\.com/ {
        sub(/^.*href="/,"",$3); sub(/".*$/,"",$3)
        Link[++Entries] = $3
        sub(/\<\/.*$/,"",$9)
        Date[Entries] = $9
      }
      END {
        # Find the most recent addon based on the published date
        if (Entries != 0) {
          for (i = 1; i <= Entries; i++)
            if (Date[i] > Newest) {
              Newest = Date[i]
              Download = Link[i]
            }
          Result=system("wget -q '$THETVDB_PATH'"Download)
          if (Result>0) {
            print "ERROR["Result"]: downloading \""Download"\""
          }
          else {
            print "INFO: Downloaded Kodi add-on \""Download"\" dated "Newest
            system("unzip -q "Download" -d '$KODI_ROOT'/addons && rm "Download)
          }
        }
        else {
        }
      }'
      # Restart Kodi to let it figure out that the add-on is installed, then stop it
      docker restart kodi-headless && sleep 5 && docker stop kodi-headless
      # Update the database
      sqlite3 $KODI_ROOT/userdata/Database/Addons33.db "UPDATE installed SET enabled=1 WHERE addonID = 'metadata.tvdb.com'"
      RET=$?; [ "$RET" != 0 ] && echo "WARNING[$RET]: Unable to configure the TV DB Kodi add-on" || echo "INFO: Configured the TV DB Kodi add-on"
      # Edit the configuration
      sed -i '/<setting id="services.webserver"/ s/ default="true">.*</>true</' $KODI_ROOT/userdata/guisettings.xml
      sed -i '/<videodatabase>/,/<\/musicdatabase>/ {
        s|<host>.*</host>|<host>'$(quoteSubst "$DB_HOST")'</host>|
        s|<port>.*</port>|<port>'$(quoteSubst "$DB_PORT")'</port>|
        s|<user>.*</user>|<user>'$(quoteSubst "$DB_USER")'</user>|
        s|<pass>.*</pass>|<pass>'$(quoteSubst "$DB_PASS")'</pass>|
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
            <path pathversion="1">${LIB_MEDIAPATH%/}/$LIB_MOVIEDIR</path>
            <allowsharing>true</allowsharing>
        </source>
        <source>
            <name>My TV Shows</name>
            <path pathversion="1">${LIB_MEDIAPATH%/}/$LIB_TVDIR</path>
            <allowsharing>true</allowsharing>
        </source>
    </video>
    <music>
        <default pathversion="1"></default>
        <source>
            <name>My Music</name>
            <path pathversion="1">${LIB_MEDIAPATH%/}/$LIB_MUSICDIR</path>
            <allowsharing>true</allowsharing>
        </source>
    </music>
</sources>
EOF
      cat >$KODI_ROOT/userdata/mediasources.xml <<EOF
<mediasources>
    <network>
        <location id="0">$LIB_MEDIAPATH</location>
    </network>
</mediasources>
docker start kodi-headless
EOF
      cat >$KODI_ROOT/userdata/passwords.xml <<EOF
<passwords>
    <path>
        <from pathversion="1">$LIB_MEDIAPATH</from>
        <to pathversion="1">${LIB_MEDIAPATH/\/\////${LIB_USER}:${LIB_PASS}@}</to>
    </path>
</passwords>
EOF
      docker start kodi-headless
      echo "INFO: Configured Kodi Headless container"
    else
      echo "WARNING: Kodi container started, but config files not found. An unconfigured container may be running."
    fi
  }
fi

### MariaDB
if [ "$INST_SQL" = 1 ]; then
  echo "### Installing MariaDB SQL server ###"
  apt-get -y install mariadb-server
  RET=$?; [ "$RET" != 0 ] && echo "ERROR[$RET]: Unable to install MariaDB." || echo "INFO: Installed MariaDB"
  # Edit the configuration
  sed -ri "s/#?(port[[:space:]]*=).*$/\1 $DB_PORT/
  s/(bind-address[[:space:]]*=).*$/\1 $(hostname -I | cut -d' ' -f1)/" /etc/mysql/mariadb.conf.d/50-server.cnf
  # Configure the server, create DB user and rights for Kodi
  echo "USE mysql;
  CREATE USER '$DB_USER' IDENTIFIED BY '$DB_PASS';
  GRANT ALL ON *.* TO '$DB_USER';
  FLUSH PRIVILEGES;" | mysql
  RET=$?; [ "$RET" != 0 ] && echo "ERROR[$RET]: Unable to configure the MariaDB SQL server" || echo "INFO: Configured MariaDB SQL server"
  service mariadb restart
  RET=$?; [ "$RET" != 0 ] && echo "ERROR[$RET]: Unable to restart the MariaDB service" || echo "INFO: Restarted the MariaDB service"
fi

### Create Watchtower cronjob to automatically update other containers
# I prefer this way for two reasons:
#  1) Watchtower is not running all the time, needlessly using resources
#  2) Exposing the Docker API to a container all the time is a security risk
# Also looked at Ouroboros, but it is 10x larger than Watchtower
#
# Runs the Watchtower container once weekly and then removes itself
cat >/etc/cron.weekly/watchtower <<EOF
#!/bin/sh

# Weekly cronjob to run Watchtower, which automatically updates installed containers
# Created by firstboot. See /etc/firstboot.log

set -e

docker run --rm \\
  --name watchtower \\
  -t \\
  -v /var/run/docker.sock:/var/run/docker.sock \\
  -e TZ="$TZ" \\
  containrrr/watchtower \\
  --run-once \\
  --cleanup \\
  --stop-timeout 60s | \\
# Remove ANSI escape sequences and CR line termination that Watchtower outputs for some reason
sed -u 's/\x1b\[[0-9;]*[a-zA-Z]//g; s/[[:blank:]]*\x0d$//' | \\
logger -t watchtower --id=$$ -p syslog.info
  
exit 0
EOF
chmod +x /etc/cron.weekly/watchtower
echo "INFO: Created weekly watchtower cronjob"

### Create cronjob to cleanup orphaned downloads
cat >/etc/cron.daily/mg-cleanup <<EOF
#!/bin/sh

# Daily cronjob to cleanup after MovieGnomes.  Includes:
#  - Orphans downloads from SABnzbd

set -e

# Orphaned downloads cleanup
if [ -d "$MEDIA_ROOT/#downloads/" ]; then
  find "$MEDIA_ROOT/#downloads/" -mindepth 1 -depth -mtime 30 -exec bash -c '( echo "Removing: {}" && rm "{}" 2>&1 ) | logger -t mg-cleanup --id=$$ -p syslog.info' \;
fi

exit 0
EOF
chmod +x /etc/cron.daily/mg-cleanup
echo "INFO: Created daily MovieGnomes cleanup cronjob"

### Disable system suspend
# Moving this to the end in hopes of fixing the issue where the system graphical login
# screen hangs as boot. Switching to console 2 and back to 1 seems to help.
echo "### Disabling system sleep and suspend ###"
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
RET=$?; [ "$RET" != 0 ] && echo "WARNING[$RET]: Unable to disable system sleep and suspend" ||  echo "INFO: Disabled system sleep and suspend"
# Suspend messages are still a problem in Gnome
sudo -u $(getent passwd 1000 | cut -d':' -f1) DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus" gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
RET=$?; [ "$RET" != 0 ] && echo "WARNING[$RET]: Unable to disable Gnome system suspend" ||  echo "INFO: Disabled Gnome system suspend"

### Install webmin
# Do this last so the modules don't need to be refreshed, which there's no supported way to do from the command line
curl -fsSL http://www.webmin.com/jcameron-key.asc | sudo apt-key add - && \
add-apt-repository -y "deb http://download.webmin.com/download/repository sarge contrib #Webmin repository" && \
apt-get -y update && \
apt-get -y install webmin
RET=$?; [ "$RET" != 0 ] && echo "WARNING[$RET]: Unable to install webmin" || echo "INFO: Installed webmin (apt-key warning is normal)"
## Create webmin backup job
cat >/etc/webmin/fsdump/276421586475735.dump <<EOF
beforefok=
rsh=/bin/ssh
dir=/docker
label=Gnomes_backup
after=docker start \$(docker ps -aq)
xdev=1
enabled=1
fs=tar
update=0
subject=
email=
tabs=1
ignoreread=0
reverify=0
multi=0
id=276421586475735
weekdays=*
afterfok=
file=/var/backups/moviegnomes-backup.tar.gz
afteraok=1
links=0
months=*
remount=0
gzip=1
pass=
mins=0
hours=16
notape=1
days=1
follow=
before=docker stop \$(docker ps -aq)
extra=
exclude=
EOF
chmod 544 /etc/webmin/fsdump/276421586475735.dump
echo "INFO: Created MovieGnomes webmin backup job"
# Restart Webmin service
sleep 5 && service webmin restart
RET=$?; [ "$RET" != 0 ] && echo "WARNING[$RET]: Unable to restart webmin" || echo "INFO: Webmin service restarted"

### Cleanup
echo "### Cleaning up ###"
# Remove installation report (contains passwords entered)
apt-get -y remove installation-report
RET=$?; [ "$RET" != 0 ] && echo "WARNING[$RET]: Unable to remove the installation report"
# SQL not needed anymore
apt-get -y remove sqlite3
RET=$?; [ "$RET" != 0 ] && echo "WARNING[$RET]: Unable to remove SQLite3"
# Remove the firstboot service so that it won't run again
update-rc.d firstboot remove
rm /etc/init.d/firstboot
# Create an installation report with INFOs, ERRORs, and WARNINGs
echo "INFO: Script completed. Runtime: $(($SECONDS/60))m $(($SECONDS%60))s"   # Unique bash feature
grep -Ei 'firstboot\[[0-9]+\]:[^"'\''](((INFO|ERROR|WARNING)(\[[0-9]*\])?:|###)|/root/firstboot\.sh|sed|awk)' /var/log/syslog >/var/log/firstboot.log
chmod +r /var/log/firstboot.log
# Remove self
rm $0
echo "###### That's all folks! ######"
