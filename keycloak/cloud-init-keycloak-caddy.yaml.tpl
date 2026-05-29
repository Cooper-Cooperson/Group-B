#cloud-config
package_update: true
package_upgrade: true

packages:
  - docker.io
  - docker-compose

write_files:
  - path: /opt/keycloak/docker-compose.yml
    permissions: '0644'
    owner: root:root
    content: |
      version: '3.8'
      services:
        keycloak:
          image: quay.io/keycloak/keycloak:25.0
          command: start-dev --http-port=8080 --hostname-strict=false --hostname-strict-https=false
          environment:
            KEYCLOAK_ADMIN: ${KEYCLOAK_ADMIN}
            KEYCLOAK_ADMIN_PASSWORD: ${KEYCLOAK_PASSWORD}
        ports:
          - "8080:8080"
        restart: always

        caddy:
          image: caddy:latest
          volumes:
            - /opt/keycloak/Caddyfile:/etc/caddy/Caddyfile
          ports:
            - "80:80"
            - "443:443"
          restart: always

  - path: /opt/keycloak/Caddyfile
    permissions: '0644'
    owner: root:root
    content: |
      :80 {
        reverse_proxy 127.0.0.1:8080
      }

runcmd:
  - mkdir -p /opt/keycloak
  - chown -R root:root /opt/keycloak
  - systemctl enable docker
  - systemctl start docker
  - sleep 5
  - docker-compose -f /opt/keycloak/docker-compose.yml up -d
  - echo "Keycloak + Caddy deployment completed" >> /var/log/keycloak-init.log