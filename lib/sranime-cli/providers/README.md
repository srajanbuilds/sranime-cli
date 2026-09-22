# Provider Plugins

Place custom provider scripts here. Each provider must be a POSIX shell script
that defines the following functions:

- `<name>_search <query>` — Print search results as `id\tname` per line
- `<name>_episodes <id>` — Print episode list as `ep_id\tep_no` per line
- `<name>_m3u8 <ep_no> <mode>` — Resolve streaming links; must set: `links`, `sub_link`, `mal_id`, `refr`

See the built-in hianime provider in the main `sranime-cli` script for reference.
