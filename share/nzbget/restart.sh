#!/bin/bash

# fixme: restarting during unpack causes failure, find
# a way to restart after unpack has finished

exit 0

# scheduled task to pause the queue and shutdown nzbget
# this is run every 30 minutes to avoid issues with
# smb mounted download folders where unpacking fails
# after lots of file handles have been created, server
# restart is handled automatically by s6

/app/nzbget/nzbget -c /config/nzbget.conf --pause
sleep 2
/app/nzbget/nzbget -c /config/nzbget.conf --quit
