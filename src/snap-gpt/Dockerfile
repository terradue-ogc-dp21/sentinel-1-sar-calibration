FROM ubuntu:20.04

USER root

SHELL ["/bin/bash", "-c"]

ENV BASH_ENV=~/.bashrc                                          \
    MAMBA_ROOT_PREFIX=/srv/conda                                \
    PATH=/srv/conda/envs/env_snap/bin:/srv/conda/envs/env_snap/snap/bin:$PATH 

ADD environment.yml /tmp/environment.yml

# Install basic commands and mamba
RUN apt-get update && \
    apt-get install -y ca-certificates wget ttf-dejavu file bash bzip2 libgfortran5  && \
    wget -qO- https://micromamba.snakepit.net/api/micromamba/linux-64/latest | tar -xvj bin/micromamba --strip-components=1 && \
    ./micromamba shell init -s bash -p ~/micromamba  && \
    apt-get clean autoremove --yes  && \
    rm -rf /var/lib/{apt,dpkg,cache,log}  && \
    cp ./micromamba /usr/bin  && \
    micromamba create -f /tmp/environment.yml && \
    rm -fr /srv/conda/pkgs                                                                                                  && \
    rm -fr /tmp/*

# allows removing the --no-read-only CWL runner flag
ADD snap.properties ${MAMBA_ROOT_PREFIX}/envs/env_snap/snap/etc/snap.properties

RUN mv /srv/conda/envs/env_snap/snap/.snap /tmp/.snap

# clean-up
RUN rm -fr /srv/conda/envs/env_snap/snap/snap/update/backup && \
    rm -fr /srv/conda/envs/env_snap/snap/s1tbx/update/backup && \
    rm -fr /srv/conda/envs/env_snap/snap/s2tbx/update/backup && \
    rm -rf /srv/conda/envs/env_snap/snap/s3tbx/update/backup && \
    rm -fr /srv/conda/envs/env_snap/snap/rstb/update/backup 


