# Jellyfin

Runs on portuus at https://media.portuus.de (`hosts/portuus/services/jellyfin.nix`, synix module `jellyfin`).
Data, config and database live on `dpool/data/jellyfin` (`/data/jellyfin`), owned by UID 994 / GID 991.

## Transcoding

Intel Arc A380 (`/dev/dri/renderD128`) via QSV, configured declaratively (`services.jellyfin.hardwareAcceleration`,
`services.jellyfin.transcoding`, `forceEncodingConfig = true`):

- Hardware decoding: H264, HEVC, HEVC 10bit, VC1, VP9, AV1
- Hardware encoding: HEVC, AV1 (low-power encoders)
- Tone mapping, throttling and segment deletion on
- Trickplay images are generated with the GPU

## Settings applied on every start

`jellyfin-config.service` patches the XML config before Jellyfin starts:

- `network.xml`: auto discovery off, remote access on, known proxy `127.0.0.1`,
  local networks `192.168.178.0/24` and `100.64.0.0/10` (tailnet)
- `system.xml`: remote bitrate limit 15 Mbit/s, Quick Connect on, metrics off, trickplay with hardware acceleration
- `branding.xml`: portuus CSS (`assets/branding/jellyfin.css`), login hint, splash screen off

The portuus nginx vhost sets the real client IP from edge (`X-Real-IP`), so remote clients get the bitrate limit.

## Libraries

Only movies and shows. Audiobooks are served by Audiobookshelf (https://books.portuus.de, `/data/audiobooks`).

### Movies

- Directory: `/data/jellyfin/libraries/movies`
- Do not create subdirectories
- Naming scheme: `title.year.file` (lower case ASCII, underscores instead of spaces)
    - For example: `the_matrix.1999.mkv`

### Shows

- Directory: `/data/jellyfin/libraries/shows`
- One directory per show, one subdirectory per season, season and episode numbers as on TheMovieDB
- Naming scheme: `title.year/seasonNN/title.sNNeNN.file`, specials in `specials/title.s00eNN.file`,
  bonus material without metadata in `extras/`
    - For example: `game_of_thrones.2011/season01/game_of_thrones.s01e01.mkv`
- Films that belong to a show (e.g. Initial D Third Stage, Legend 1-3) go into the movies library

## Metadata

TheMovieDB (built in, no account) for movies and shows. If an item is matched wrongly, check the season layout on
TheMovieDB first; anime often numbers seasons differently than the DVDs.

## Users

Accounts are created by the admins in the dashboard. Forgotten password: open Jellyfin from the local network
(`ssh -L 8096:127.0.0.1:8096 p`, then http://localhost:8096), use "Forgot password", read the PIN with
`sudo sh -c 'cat /data/jellyfin/passwordreset*.json'`.
