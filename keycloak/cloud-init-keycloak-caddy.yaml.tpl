#cloud-config
package_update: true
package_upgrade: true

write_files:
  - path: /usr/local/bin/install-docker.sh
    permissions: '0755'
    owner: root:root
    content: |
      #!/bin/bash
      set -e
      apt-get update -y
      apt-get install -y docker.io docker-compose
      systemctl enable docker
      systemctl start docker

  - path: /opt/keycloak/docker-compose.yml
    permissions: '0644'
    owner: root:root
    content: |
      version: '3.8'
      services:
        keycloak:
          image: quay.io/keycloak/keycloak:${KEYCLOAK_VERSION}
          command: >
            start-dev
            --http-port=8080
            --hostname=${KEYCLOAK_HOSTNAME}
            --hostname-strict=false
            --hostname-strict-https=false
            --proxy-headers=xforwarded
            --features=hostname:v1
          environment:
            KEYCLOAK_ADMIN: ${KEYCLOAK_ADMIN}
            KEYCLOAK_ADMIN_PASSWORD: ${KEYCLOAK_PASSWORD}
          volumes:
            - keycloak_data:/opt/keycloak/data
          ports:
            - "8080:8080"
          networks:
            - keycloaknet
          restart: always

        caddy:
          image: caddy:latest
          ports:
            - "80:80"
            - "443:443"
          volumes:
            - /opt/keycloak/Caddyfile:/etc/caddy/Caddyfile
            - caddy_data:/data
            - caddy_config:/config
          networks:
            - keycloaknet
          restart: always

      volumes:
        keycloak_data:
        caddy_data:
        caddy_config:

      networks:
        keycloaknet:

  - path: /opt/keycloak/Caddyfile
    permissions: '0644'
    owner: root:root
    content: |
      {
        email admin@suitit.tech
      }

      ${KEYCLOAK_HOSTNAME} {
        reverse_proxy keycloak:8080 {
          header_up X-Forwarded-For {remote_host}
          header_up X-Forwarded-Proto https
          header_up X-Forwarded-Host {host}
          header_up X-Forwarded-Port 443
          header_up Forwarded "proto=https;host={host};port=443"
        }
      }

runcmd:
  - bash /usr/local/bin/install-docker.sh
  - docker-compose -f /opt/keycloak/docker-compose.yml up -d
  - echo "Keycloak + Caddy deployment completed" >> /var/log/keycloak-init.log
