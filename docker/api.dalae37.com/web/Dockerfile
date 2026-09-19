# syntax=docker/dockerfile:1

FROM nginx:1.31.0-alpine

# Image metadata
LABEL org.opencontainers.image.title="web-api-dalae37-com" \
      org.opencontainers.image.description="Web server for api.dalae37.com" \
      org.opencontainers.image.source="https://github.com/DaLae37/Infrastructure"

# Prepare Nginx directories
RUN rm -f /etc/nginx/conf.d/default.conf \
    && mkdir -p \
        /tmp/client_temp \
        /tmp/proxy_temp \
    && chown -R nginx:nginx \
        /usr/share/nginx/html \
        /tmp

# Copy Nginx configuration
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/templates/ /etc/nginx/templates/
COPY nginx/snippets/ /etc/nginx/snippets/

# Runtime environment
ENV HTTP_PORT=10080 \
    HTTPS_PORT=10443 \
    API_HOST=sport-api-dalae37-com \
    API_PORT=80

# Restrict envsubst to application-specific environment variables only
ENV NGINX_ENVSUBST_FILTER="^(HTTP_PORT|HTTPS_PORT|API_HOST|API_PORT)$"

# Network
EXPOSE 10080 10443

# Health check
HEALTHCHECK \
    --interval=30s \
    --timeout=5s \
    --start-period=5s \
    --retries=3 \
    CMD wget -q -T 2 -O /dev/null "http://127.0.0.1:${HTTP_PORT}/healthz" || exit 1
