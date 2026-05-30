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
          command: start-dev --http-port=8080
          environment:
            KEYCLOAK_ADMIN: ${KEYCLOAK_ADMIN}
            KEYCLOAK_ADMIN_PASSWORD: ${KEYCLOAK_PASSWORD}
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
            - /opt/keycloak/certs:/opt/keycloak/certs
          networks:
            - keycloaknet  
          restart: always
          
  - path: /opt/keycloak/Caddyfile
    permissions: '0644'
    owner: root:root
    content: |
      :443 {
      tls /opt/keycloak/certs/cert.pem /opt/keycloak/certs/key.pem
      reverse_proxy keycloak:8080 
      }   

runcmd:
  - bash /usr/local/bin/install-docker.sh
  # Create certificate directory
  - mkdir -p /opt/keycloak/certs
  # Generate PKCS#8 private key
  - openssl genpkey -algorithm RSA -out /opt/keycloak/certs/key.pem -pkeyopt rsa_keygen_bits:2048
  # Create CSR
  - openssl req -new -key /opt/keycloak/certs/key.pem -out /opt/keycloak/certs/cert.csr -subj "/CN=keycloak.local"
  # Self-sign certificate
  - openssl x509 -req -days 365 -in /opt/keycloak/certs/cert.csr -signkey /opt/keycloak/certs/key.pem -out /opt/keycloak/certs/cert.pem
  # Set permissions
  - chmod 600 /opt/keycloak/certs/key.pem
  - chmod 644 /opt/keycloak/certs/cert.pem

  # Start Keycloak + Caddy
  - docker-compose -f /opt/keycloak/docker-compose.yml up -d
  - echo "Keycloak + Caddy HTTPS deployment completed" >> /var/log/keycloak-init.log
