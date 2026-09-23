# דירוג הפסטיגלים של מאיה ומאיר

A static site (GitHub Pages) plus a Supabase database for the ratings.

- `index.html`: the whole app
- `catalog.json`: the 2003-2010 Festigals (details from Hebrew Wikipedia, songs from the official albums)
- `covers/`: album covers
- `config.js`: Supabase URL and anon key
- `supabase/schema.sql`: tables, read-only access, and family-code-protected write functions

## Setup

1. Create a Supabase project. In SQL Editor, paste `supabase/schema.sql`, replace `CHANGE_ME` with the family code, and run it.
2. Put the Project URL and anon/publishable key in `config.js`.
3. Push to GitHub and enable Pages (branch `main`, folder `/`).

## Changing the family code

In Supabase SQL Editor: `update app_secret set code = 'new-code' where id = 1;`
Every phone will be asked for the new code on its next save.
