#!/usr/bin/env sh

# abort on errors
set -e

# build
npm run build

# navigate into the build output directory
cd dist

git init
git add -A
git commit -m 'deploy'

git push -f https://ad440deploy@ad440-web-app.scm.azurewebsites.net:443/ad440-web-app.git master

cd -