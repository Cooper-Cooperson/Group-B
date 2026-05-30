#cloud-config
package_update: true
package_upgrade: true

packages:
  - docker.io
  - docker-compose

write_files:
  - path: /usr/local/bin/install-docker.sh
    permissions: '0755'
    owner: root:root
    content: |
      #!/bin/bash
      set -e

      echo "[INFO] Updating apt..."
      apt-get update -y || (sleep 5 && apt-get update -y)

      echo "[INFO] Installing Docker..."
      apt-get install -y docker.io || (sleep 5 && apt-get install -y docker.io)

      echo "[INFO] Installing docker-compose..."
      apt-get install -y docker-compose || (sleep 5 && apt-get install -y docker-compose)

      echo "[INFO] Enabling Docker service..."
      systemctl enable docker
      systemctl start docker

      echo "[INFO] Docker installation complete."  

  - path: /opt/keycloak/docker-compose.yml
    permissions: '0644'
    owner: root:root
    content: |
      version: '3.8'
      services:
        keycloak:
          image: quay.io/keycloak/keycloak:${KEYCLOAK_VERSION}
          command: start-dev --http-port=8080 --hostname-strict=false --hostname-strict-https=false
          environment:
            KEYCLOAK_ADMIN: ${KEYCLOAK_ADMIN}
            KEYCLOAK_ADMIN_PASSWORD: ${KEYCLOAK_PASSWORD}
          ports:
            - "8080:8080"
          restart: always

runcmd:
  - echo "[INFO] Running Docker installer..." >> /var/log/keycloak-init.log
  - bash /usr/local/bin/install-docker.sh >> /var/log/keycloak-init.log 2>&1
  - mkdir -p /opt/keycloak
  - chown -R root:root /opt/keycloak
  - sleep 5
  - docker-compose -f /opt/keycloak/docker-compose.yml up -d
  - echo "[INFO] Keycloak deployment completed." >> /var/log/keycloak-init.log
