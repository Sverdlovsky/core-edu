FROM docker.io/library/node:25.8.1-alpine3.23 AS build

WORKDIR /srv/web

COPY package-lock.json .
COPY package.json .

RUN npm ci

COPY svelte.config.js .
COPY tsconfig.json .
COPY vite.config.ts .
COPY static static
COPY src src

RUN npm run build


FROM docker.io/library/nginx:1.29.6-alpine3.23

COPY --from=build /srv/web/build /var/www/html/default

COPY nginx.conf /etc/nginx/templates/default.conf.template

