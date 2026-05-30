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

      echo "[INFO] Starting OPENSSL installation."  
      apt-get install openssl
      
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
            --https-port=8443
            --https-certificate-file=/opt/keycloak/certs/cert.pem
            --https-certificate-key-file=/opt/keycloak/certs/key.pem
          environment:
            KEYCLOAK_ADMIN: ${KEYCLOAK_ADMIN}
            KEYCLOAK_ADMIN_PASSWORD: ${KEYCLOAK_PASSWORD}
          ports:
            - "8443:8443"
          volumes:
            - /opt/keycloak/certs:/opt/keycloak/certs
          restart: always

runcmd:
  - bash /usr/local/bin/install-docker.sh
  - mkdir -p /opt/keycloak/certs
  - cd /opt/keycloak/certs
  - openssl genpkey -algorithm RSA -out key.pem -pkeyopt rsa_keygen_bits:2048
  - openssl req -new -key key.pem -out cert.csr -subj "/CN=keycloak.local"
  - openssl x509 -req -days 365 -in cert.csr -signkey key.pem -out cert.pem
  - chmod 600 key.pem
  - docker-compose -f /opt/keycloak/docker-compose.yml up -d
  - echo "Keycloak HTTPS deployment completed" >> /var/log/keycloak-init.log
