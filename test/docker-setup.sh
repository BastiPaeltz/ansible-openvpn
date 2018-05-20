#!/bin/bash

set -eo pipefail

if  [ ! -z ${docker_build_image} ]
then
  docker build --rm=true --file=test/Dockerfile.${distribution}-${version} --tag=${distribution}-${version}:ansible .
fi

for ((i=1; i<=${docker_concurrent_containers}; i++))
do
    # Run the container
    container_id=$(docker run ${run_opts} ${distribution}-${version}:ansible "${init}")
    container_ip=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${container_id})
    docker ps

    # Get the IP of the container and add it to the inventory
    echo "$(echo ${container_id} | cut -c1-13) ansible_host=${container_ip} ansible_user=docker ansible_become=yes ansible_become_pass=password" >> test/docker-inventory
done