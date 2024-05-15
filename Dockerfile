FROM debian

WORKDIR /usr/src/app

RUN apt update && apt install -y shellcheck
