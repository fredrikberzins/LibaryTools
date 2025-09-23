#!/bin/bash

OUTPUT_PATH="<Output Path>" # /srv/dev-disk-by-uuid-ad776723-ad62-454d-bc94-60ff1a1bb499/film_nas/movies
LOG_PATH="<Log path>" # /srv/dev-disk-by-uuid-ad776723-ad62-454d-bc94-60ff1a1bb499/film_nas/post_process.log
TORRENT_PATH="$1"
echo "$(date) - post_process.sh started with $1" >> $LOG_PATH

/usr/bin/filebot -script fn:amc \
    --output $OUTPUT_PATH \
    --action move "$TORRENT_PATH" \
    --def "movieFormat={n} ({y}) {['imdb-'+imdbid]}/{n} ({y}) {['imdb-'+imdbid]} - [{vf} {channels}] {tags} {[subt]}" \
    --conflict override

# cleanup if a directory is left over
if [ -d "$TORRENT_PATH" ]; then
    rm -rf "$TORRENT_PATH"
fi
