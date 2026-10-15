FROM nginx:stable-alpine
COPY index.html /usr/share/nginx/html/index.html
COPY healthz /usr/share/nginx/html/healthz
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 CMD wget -q -O /dev/null http://127.0.0.1/healthz || exit 1
