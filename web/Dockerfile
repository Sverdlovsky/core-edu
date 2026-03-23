FROM docker.io/library/node:25.8.1-alpine3.23 AS build

WORKDIR /srv/root

COPY root/package-lock.json .
COPY root/package.json .

RUN npm ci

COPY root/src .
COPY root/static .
COPY root/svelte.config.js .
COPY root/tsconfig.json .
COPY root/vite.config.ts .

RUN npm run build


WORKDIR /srv/learn

COPY learn/package-lock.json .
COPY learn/package.json .

RUN npm ci

COPY learn/src .
COPY learn/static .
COPY learn/svelte.config.js .
COPY learn/tsconfig.json .
COPY learn/vite.config.ts .

RUN npm run build



FROM docker.io/library/nginx:1.29.6-alpine3.23

COPY --from=build /srv/root/build /var/lib/www/html/root
COPY --from=build /srv/learn/build /var/lib/www/html/learn

COPY nginx.conf /etc/nginx/templates/default.conf.template

