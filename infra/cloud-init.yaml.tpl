#cloud-config
# Server bootstrap — installs Docker and clones the repo on first boot.
# After provisioning, SSH in, create /opt/group-b/.env, then run docker compose up -d.

packages:
  - git
  - curl

runcmd:
  - curl -fsSL https://get.docker.com | sh
  - systemctl enable docker
  - systemctl start docker
  - usermod -aG docker ubuntu
  - git clone https://github.com/Cooper-Cooperson/Group-B.git /opt/group-b
