deploy:
	hugo --minify
	netlify deploy --prod
