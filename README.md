# Tiemenwaterreus.com

Hugo based website / blog.

## Deploying
Normally a deploy is as easy as pushing to origin/master but as we're running Hugo @ master with updated Chroma dependency we have to build manually.

This is as easy as:

- `hugo --minify`
- `netlify deploy --prod`
