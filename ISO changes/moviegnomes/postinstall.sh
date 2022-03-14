#!/bin/sh

# Copy our firstboot.sh script into place, make is executable
cp /cdrom/moviegnomes/firstboot.sh /target/root
chmod +x /target/root/firstboot.sh

# Create a service that will run our firstboot.sh script
cat > /target/etc/init.d/firstboot <<EOF
#!/bin/sh
### BEGIN INIT INFO
# Provides:          firstboot.sh
# Required-Start:    \$local_fs \$network \$syslog
# Required-Stop:     \$local_fs \$network \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: A prep script that runs once
# Description:       A script for TheCaptain989's Movie Gnomes build
### END INIT INFO

cd /root ; /usr/bin/nohup bash -x /root/firstboot.sh &
EOF

# Install the firstboot service
chmod +x /target/etc/init.d/firstboot
chroot /target update-rc.d firstboot defaults

exit 0
