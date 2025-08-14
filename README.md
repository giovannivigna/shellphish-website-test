# shellphish-website-test

This repository contains the website for the Shellphish hacking collective.

## Website

The website is published using GitHub Pages and can be accessed at:
- **GitHub Pages URL**: `https://[your-username].github.io/shellphish-website-test/`
- **Local Development**: Open `docs/index.html` in your browser

## Structure

- `docs/` - Website files (HTML, CSS, images)
- `docs/assets/` - Static assets (CSS, images)
- `docs/4526a11e1d7dd99530870d9cf5a459c0/` - Private photo galleries (the dirname is the result of "echo hacking | md5sum")
- `make_gallery.sh` - Script to generate photo galleries
- `make_members.sh` - Script to generate member pages

## Development

To work on the website locally:
1. Clone this repository
2. Open `docs/index.html` in your browser
3. Make changes to the files in the `docs/` directory
4. Commit and push changes to GitHub

The website will automatically update when changes are pushed to the main branch.
