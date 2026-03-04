FROM nginx:alpine

# Add metadata labels
LABEL maintainer="devops@example.com" \
      app="mario" \
      version="1.0.0"

# Copy static files (assuming mario game files are in current directory)
COPY . /usr/share/nginx/html/

# Configure nginx to run on port 8080 instead of 80 (non-privileged)
RUN sed -i 's/listen  .*/listen 8080;/' /etc/nginx/conf.d/default.conf && \
    sed -i 's/listen  \[::\]:80;/listen [::]:8080;/' /etc/nginx/conf.d/default.conf

# Change ownership to nginx user
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid && \
    chown -R nginx:nginx /etc/nginx/conf.d

# Switch to non-root user
USER nginx

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8080/ || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
