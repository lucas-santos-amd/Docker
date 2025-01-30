#!/bin/bash

### Source config
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "${script_dir}/config.sh"

### Set container name
container_name="${IMAGE_NAME}"
container_name_suffix=${1}

if [ -n "${container_name_suffix}" ]; then
    container_name="${container_name}_${container_name_suffix}"
fi

docker exec -it "${container_name}" bash