#cloud-config
package_update: true
packages:
  - docker.io
  - docker-compose

write_files:
  - path: /opt/keycloak/docker-compose.yml
    permissions: "0644"
    content: |
      version: "3.9"
      services:
        caddy:
          image: caddy:2
          restart: unless-stopped
          ports:
            - "80:80"
            - "443:443"
          volumes:
            - ./Caddyfile:/etc/caddy/Caddyfile
            - caddy_data:/data
            - caddy_config:/config
        keycloak:
          image: quay.io/keycloak/keycloak:${KEYCLOAK_VERSION}
          command: start
          environment:
            KEYCLOAK_ADMIN: ${KEYCLOAK_ADMIN}
            KEYCLOAK_ADMIN_PASSWORD: ${KEYCLOAK_PASSWORD}
            KC_PROXY: edge
            KC_HOSTNAME: ${KEYCLOAK_HOSTNAME}
          restart: unless-stopped
          ports:
            - "8080:8080"
      volumes:
        caddy_data:
        caddy_config:

  - path: /opt/keycloak/Caddyfile
    permissions: "0644"
    content: |
      {
        email ${LETSENCRYPT_EMAIL}
      }

      ${KEYCLOAK_HOSTNAME} {
        reverse_proxy keycloak:8080
      }

runcmd:
  - docker compose -f /opt/keycloak/docker-compose.yml up -d
