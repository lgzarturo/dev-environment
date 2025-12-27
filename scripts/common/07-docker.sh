#!/usr/bin/env bash

# -----------------------------------------------------------------------------
##? Docker common functions
#?? 1.0.0
##?
##? Require:
##?   docker
##? Usage:
##?   source 07-docker.sh
#docs::eval "$@"
# -----------------------------------------------------------------------------

### Docker Functions

# Bash into running container
docker_bash() {
    # Bash into running container
    docker exec -it $(docker ps -aqf "name=$1") /bin/bash;
}

# Get IP address of a container
docker_ispect() {
    for container in "$@"; do
        docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" "${container}";
    done
}

# Stop running containers
docker_stop() {
    if [ $# -eq 0 ]; then
        docker stop $(docker ps -aq --no-trunc);
    else
        for container in "$@"; do
            docker stop $(docker ps -aq --no-trunc | grep ${container});
        done
    fi
}

# Remove stopped containers
docker_rm_containers() {
    if [ $# -eq 0 ];then
        docker rm $(docker ps -aq --no-trunc);
    else
        for container in "$@"; do
            docker rm $(docker ps -aq --no-trunc | grep ${container});
        done
    fi
}

# Remove dangling images
docker_rm_images() {
    if [ $# -eq 0 ]; then
        docker rmi $(docker images --filter 'dangling=true' -aq --no-trunc);
    else
        for container in "$@"; do
            docker rmi $(docker images --filter 'dangling=true' -aq --no-trunc | grep ${container});
        done
    fi
}

# Tag and push an image to a repository
docker_push() {
    docker tag $1 $1
    docker push $1
}