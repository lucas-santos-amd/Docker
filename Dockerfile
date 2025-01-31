# Use a imagem base com Python
FROM rocm/pytorch:rocm6.2.3_ubuntu22.04_py3.10_pytorch_release_2.3.0

### Build time variables:
ARG USER_REAL_NAME
ARG USER_EMAIL
ARG USER_ID
ARG USER_NAME
ARG GROUP_ID
ARG GROUP_NAME

### Image metadata:
LABEL org.opencontainers.image.authors="${USER_EMAIL}" \
      org.opencontainers.image.title="Triton development environment of ${USER_REAL_NAME}."

### Environment variables:
    # No warnings when running `pip` as `root`.
ENV PIP_ROOT_USER_ACTION=ignore
ENV TRITON_BUILD_WITH_CCACHE=true

### CREATE GROUP AND USER
RUN if getent group ${GROUP_ID}; then \
        GROUP_NAME=$(getent group ${GROUP_ID} | cut -d: -f1); \
    else \
        groupadd -g ${GROUP_ID} ${GROUP_NAME}; \
    fi && \
    useradd -m -u ${USER_ID} -g ${GROUP_ID} -s /bin/bash -d /triton_dev/chome ${USER_NAME} && \
    #FIXME sudo is not working
    usermod --append --groups sudo,render,video "${USER_NAME}"
    #echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" | tee -a /etc/sudoers > /dev/null

### apt step:
COPY apt_requirements.txt /tmp
    # Update package index.
RUN apt-get --yes update && \
    # Update packages.
    apt-get --yes upgrade && \
    # Install packages.
    sed 's/#.*//;/^$/d' /tmp/apt_requirements.txt \
        | xargs apt-get --yes install --no-install-recommends && \
    # Clean up apt.
    apt-get --yes autoremove && \
    apt-get clean && \
    rm --recursive --force /tmp/apt_requirements.txt /var/lib/apt/lists/*

### Special build of `aqlprofiler` (it's required to use ATT Viewer):
COPY deb/rocm6.2_hsa-amd-aqlprofile_1.0.0-local_amd64.deb /tmp
RUN dpkg --install /tmp/rocm6.2_hsa-amd-aqlprofile_1.0.0-local_amd64.deb && \
    rm --recursive --force /tmp/rocm6.2_hsa-amd-aqlprofile_1.0.0-local_amd64.deb

### pip step:
COPY pip_requirements.txt /tmp
    # Uninstall Triton shipped with PyTorch, we'll compile Triton from source.
RUN pip uninstall --yes triton && \
    # Install pacakges.
    pip install --no-cache-dir --requirement /tmp/pip_requirements.txt && \
    # Install `hip-python` from TestPyPI package index.
    # (it's required for `tune_gemm.py --icache_flush` option)
    pip install --no-cache-dir --index-url https://test.pypi.org/simple hip-python~=6.2 && \
    # Clean up pip.
    rm --recursive --force /tmp/pip_requirements.txt && \
    pip cache purge

### Configure Git:
RUN git config --global user.name "${USER_REAL_NAME}" && \
    git config --global user.email "${USER_EMAIL}" && \
    # Set GitHub SSH hosts as known hosts:
    mkdir --parents --mode 0700 ~/.ssh && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts

### Prepare Triton repository and compile it:
WORKDIR /triton_dev/triton
    # Clone repository:
RUN --mount=type=ssh git clone git@github.com:triton-lang/triton.git . && \
    # Add remotes of interest:
    # git remote add rocm git@github.com:ROCm/triton.git && \
    # git remote add "${USER_NAME}" git@github.com:lucas-santos-amd/triton.git && \
    # git fetch --all --prune && \
    # Checkout branches of interest:
    git checkout main && \
    # Install pre-commit hooks:
    pre-commit install && \
    # Do a "fake commit" to initialize `pre-commit` framework, it takes some
    # time and it's an annoying process...
    git add $(mktemp --tmpdir=.) && \
    git commit --allow-empty-message --message '' && \
    git reset --hard HEAD~ && \
    # Compile triton
    cd /triton_dev/triton/python/ && \
    pip install --verbose .

### Remove build time SSH stuff:
RUN rm --recursive --force /root/.ssh

### Change USER ownership
RUN chown -R ${USER_NAME}:${GROUP_ID} /triton_dev /home /opt /usr/local

### Change USER
USER ${USER_NAME}

### Expose port for Jupyterlab
EXPOSE 8888

### Entrypoint
WORKDIR /triton_dev
ENTRYPOINT [ "bash" ]
