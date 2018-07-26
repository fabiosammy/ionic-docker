FROM ubuntu:18.04
MAINTAINER fabiosammy <fabiosammy@gmail.com>

# Install apt based dependencies required to run Rails as
# well as RubyGems. As the Ruby image itself is based on a
# Debian image, we use apt-get to install those.
RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  openssh-server \
  bison \
  libgdbm-dev \
  locales \
  mysql-client \
  postgresql-client \
  sqlite3 \
  nodejs \
  npm \
  sudo \
  cmake \
  graphviz \
  curl \
  gnupg2 

RUN apt-get install -y ca-certificates \
  && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
  && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN apt-get update \
  && apt-get install -y yarn \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN yarn global add cordova \
  && yarn global add ionic

# Use en_US.UTF-8 as our locale
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# skip installing gem documentation
# RUN mkdir -p /usr/local/etc && { echo 'install: --no-document'; echo 'update: --no-document'; } >> /usr/local/etc/gemrc

# SSH config
RUN mkdir /var/run/sshd \
  && sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
  && echo "export VISIBLE=now" >> /etc/profile \
  && echo 'root:root' | chpasswd

ENV NOTVISIBLE "in users profile"
ENV HOME=/home/devel
ENV APPS=/var/www

# ADD an user
RUN adduser --disabled-password --gecos '' devel \
  && usermod -a -G sudo devel \
  && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
  && echo 'devel:devel' | chpasswd

# Configure the main working directory. This is the base
# directory used in any further RUN, COPY, and ENTRYPOINT
# commands.
RUN mkdir -p $HOME \
  && mkdir -p $APPS \
  && chown -R devel:devel $HOME \
  && chown -R devel:devel $APPS

USER devel:devel
WORKDIR $APPS

# Copy the main application.
COPY . ./

# Copy the Gemfile as well as the Gemfile.lock and install
# the RubyGems. This is a separate step so the dependencies
# will be cached unless changes to one of those two files
# are made.
#COPY Gemfile Gemfile.lock ./
#RUN bundle install --retry 5

# Expose port 3000 to the Docker host, so we can access it
# from the outside.
EXPOSE 22
EXPOSE 8100
EXPOSE 35729
EXPOSE 53703

# The main command to run when the container starts. Also
# tell the Rails dev server to bind to all interfaces by
# default.
CMD ["/usr/bin/sudo", "/usr/sbin/sshd", "-D"]

