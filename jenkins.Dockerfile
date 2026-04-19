FROM jenkins/jenkins:lts

# Switch to root to install Docker CLI and avoid socket permission issues for local testing
USER root

RUN apt-get update && \
    apt-get install -y docker.io

# We remain as root here solely so Jenkins can use the mounted docker.sock without permission errors
