FROM ubuntu

RUN apt-get update && apt-get install -y git curl build-essential \
	&& rm -rf /var/lib/apt/lists/* \
  && git clone https://github.com/asdf-vm/asdf.git ~/.asdf --depth 1 --single-branch --branch v0.10.2 \
  && echo '. $HOME/.asdf/asdf.sh' >> ~/.bashrc \
  && echo '. $HOME/.asdf/completions/asdf.bash' >> ~/.bashrc

WORKDIR /root
