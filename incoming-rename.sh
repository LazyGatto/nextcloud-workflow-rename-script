#!/bin/bash
#
# Rename script for NextCloud Workflow external scripts
#
# by LazyGatto 2021-07-20
#
# https://github.com/nextcloud/workflow_script#placeholders
#
# call /opt/test.sh -e %e -n %n -o %o
#
# Placeholder	Description		example value
# %e		the event type		create, update or rename
# %i		file id			142430
# %a		actor's user id		bob
# %o		owner's user id		alice
# %n		nextcloud-relative path	alice/files/Pictures/Wonderland/20180717_192103.jpg

# https://docs.nextcloud.com/server/19/developer_manual/client_apis/WebDAV/basic.html
# Moving files and folders (rfc4918)
# A file or folder can be moved by sending a MOVE request to the file or folder and specifying the destination in the Destination header as full url.
# MOVE remote.php/dav/files/user/path/to/file
# Destination: https://cloud.example/remote.php/dav/files/user/new/location

NC_USER=ncadmin
NC_PASSWORD=password

# Timestamp to add in the beggining of filename
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")

# NO ending slash!
NC_SCHEME=http
NC_HOST=127.0.0.1

url_var() {
  # URL encode string and optionally store in shell variable
  # https://www.unix.com/shell-programming-and-scripting/277083-url-encoding-string-using-sed.html
  # usage: url_var <string> [var]

  local LC_ALL=C
  local encoded=""
  local i c

  for (( i=0 ; i<${#1} ; i++ )); do
     c=${1:$i:1}
     case "$c" in
        [a-zA-Z0-9/_.~-] ) encoded="${encoded}$c" ;;
        * ) printf -v encoded "%s%%%02x" "$encoded" "'${c}" ;;
     esac
  done
  [ $# -gt 1 ] &&
     printf -v "$2" "%s" "${encoded}" ||
     printf "%s\n" "${encoded}"
}

# no need to change this as it hardcoded on NC part
NC_WEBDAV_PATH="remote.php/dav/files"

while getopts e:n:o: option
do
case "${option}"
in
    e) EVENT=${OPTARG};;
    n) NC_RELATIVE_FILEPATH=${OPTARG};;
    o) OWNER=${OPTARG};;
esac
done

#
# Cut 2 first folders from nc relative path as they goes in wrong order for webdav access
#
CUTTED_FILEPATH=$(echo $NC_RELATIVE_FILEPATH | cut -d "/" -f3-)
NC_WEBDAV_URL=${NC_SCHEME}"://"${NC_HOST}"/"${NC_WEBDAV_PATH}"/"${OWNER}"/"

SOURCE_FILE_WEBDAV=${NC_WEBDAV_URL}$(url_var "${CUTTED_FILEPATH}")

#
# Contruct needed path vars
#
SOURCE_FILENAME=$(basename "$CUTTED_FILEPATH")
SOURCE_FILEDIR=$(dirname "$CUTTED_FILEPATH")

TARGET_FILENAME=${SOURCE_FILEDIR}"/"${TIMESTAMP}"_"${SOURCE_FILENAME}

TARGET_FILE_WEBDAV=${NC_WEBDAV_URL}$(url_var "${TARGET_FILENAME}")

curl --user "${NC_USER}:${NC_PASSWORD}" -X MOVE --header "Destination:${TARGET_FILE_WEBDAV}" "${SOURCE_FILE_WEBDAV}"

echo "$(date +"%Y.%m.%d %H:%M:%s") File was renamed: $NC_RELATIVE_FILEPATH, Owner: $OWNER, New filename: $TARGET_FILENAME" >> /var/www/nextcloud/incoming_rename.log
