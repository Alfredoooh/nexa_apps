FROM node:20-slim

RUN apt-get update && \
apt-get install -y --no-install-recommends python3 ca-certificates curl && \
rm -rf /var/lib/apt/lists/*

# yt-dlp: binário único, sempre a versão mais recente no momento do build
RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp && \
chmod a+rx /usr/local/bin/yt-dlp

WORKDIR /app
COPY package.json ./
COPY server.js ./

ENV PORT=10000
EXPOSE 10000

CMD ["node", "server.js"]