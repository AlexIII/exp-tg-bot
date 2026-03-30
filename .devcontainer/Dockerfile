FROM debian:bookworm

ARG USER=developer
ARG DEBIAN_FRONTEND=noninteractive
RUN apt update \
    && apt install -y --no-install-recommends sudo git zsh curl wget ca-certificates build-essential sqlite3 \
    && mkdir -p /etc/apt/keyrings \
    && wget -qO- https://binaries2.erlang-solutions.com/GPG-KEY-pmanager.asc | tee /etc/apt/keyrings/erlang.asc \
    && echo "deb [signed-by=/etc/apt/keyrings/erlang.asc] https://binaries2.erlang-solutions.com/debian bookworm-esl-erlang-27 contrib" | tee /etc/apt/sources.list.d/erlang.list \
    && apt update \
    && apt install -y esl-erlang \
    && apt clean \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*

ENV GLEAM_VERSION=1.15.2

RUN <<EOT
    curl -OL https://github.com/gleam-lang/gleam/releases/download/v${GLEAM_VERSION}/gleam-v${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz
    tar -xzf gleam-v${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz
    rm gleam-v${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz
    mv gleam /usr/local/bin/
EOT

RUN useradd -m -s /usr/bin/zsh ${USER} \
    && echo "${USER} ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/${USER} \
    && chmod 0440 /etc/sudoers.d/${USER}


USER ${USER}
ARG HOME=/home/${USER}
ARG ZSH=${HOME}/.oh-my-zsh
ARG ZSH_CUSTOM=${ZSH}/custom
WORKDIR ${HOME}


RUN <<EOT
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    mkdir -p ${ZSH_CUSTOM}
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting
    sed -i.bak 's/plugins=(\(.*\))/plugins=(\1 zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc
EOT


ARG SPACESHIP_REMOTE=https://github.com/spaceship-prompt/spaceship-prompt.git
RUN <<EOT
    git clone ${SPACESHIP_REMOTE} ${ZSH_CUSTOM}/themes/spaceship-prompt --depth=1
    ln -s ${ZSH_CUSTOM}/themes/spaceship-prompt/spaceship.zsh-theme ${ZSH_CUSTOM}/themes/spaceship.zsh-theme
    sed -i 's|ZSH_THEME="robbyrussell"|ZSH_THEME="spaceship"|g' .zshrc
EOT

RUN <<EOT
    sh -c "$(curl -OL https://s3.amazonaws.com/rebar3/rebar3)"
    chmod +x rebar3
    ./rebar3 local install
    rm rebar3
    echo 'export PATH="$HOME/.cache/rebar3/bin:$PATH"' >> ~/.zshrc
EOT
