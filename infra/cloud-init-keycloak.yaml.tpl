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
        keycloak:
          image: quay.io/keycloak/keycloak:${KEYCLOAK_VERSION}
          command: start
          environment:
            KEYCLOAK_ADMIN: ${KEYCLOAK_ADMIN}
            KEYCLOAK_ADMIN_PASSWORD: ${KEYCLOAK_PASSWORD}
          ports:
            - "8080:8080"
          restart: unless-stopped
          volumes:
            - keycloak_data:/opt/keycloak/data
      volumes:
        keycloak_data:

runcmd:
  - docker compose -f /opt/keycloak/docker-compose.yml up -d