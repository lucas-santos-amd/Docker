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

docker run \
    -it \
    -d \
    --network host \
    -p 8888:8888 \
    --name "${container_name}" \
    --device /dev/kfd \
    --device /dev/dri \
    --mount "type=bind,source=${HOME},target=/triton_dev/home" \
    --mount "type=bind,source=${HOME}/.ssh,target=/${USER_NAME}/.ssh,readonly" \
    "${IMAGE_NAME}"
 