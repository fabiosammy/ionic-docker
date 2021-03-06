FROM ubuntu:18.04
MAINTAINER fabiosammy <fabiosammy@gmail.com>

ENV DEBIAN_FRONTEND=noninteractive \
  ANDROID_HOME=/opt/android-sdk-linux \
  IONIC_VERSION=4.1.0 \
  CORDOVA_VERSION=8.1.1 \
  GRADLE_VERSION=4.5.1 \
  LANG=en_US.UTF-8 \
  LANGUAGE=en_US:en \
  LC_ALL=en_US.UTF-8 \
  NOTVISIBLE="in users profile" \
  HOME=/home/devel \
  APPS=/var/www \
  JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

# Install apt based dependencies required
RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  software-properties-common \
  openssh-server \
  bison \
  libgdbm-dev \
  locales \
  android-sdk \
  openjdk-8-jdk \
  openjdk-8-jre \
  mysql-client \
  postgresql-client \
  sqlite3 \
  nodejs \
  npm \
  sudo \
  cmake \
  graphviz \
  curl \
  lib32z1 \
  lib32ncurses5 \
  lib32stdc++6 \
  unzip \
  gradle \
  git \
  apt-transport-https \
  ca-certificates \
  gnupg2

# Install yarn
RUN apt-get install -y ca-certificates \
  && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
  && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
  && apt-get update \
  && apt-get install -y yarn

# Android required architecture
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --force-yes expect ant wget zipalign libc6-i386 lib32stdc++6 lib32gcc1 lib32ncurses5 lib32z1 qemu-kvm kmod

# Install JAVA oracle
RUN add-apt-repository ppa:webupd8team/java -y \
    && echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections \
    && apt-get update && apt-get -y install oracle-java8-installer

# Install Android SDK
RUN cd /opt \
    && echo ANDROID_HOME="${ANDROID_HOME}" >> /etc/environment \
    && wget --output-document=android-sdk.tgz --quiet http://dl.google.com/android/android-sdk_r24.4.1-linux.tgz \
    && tar xzf android-sdk.tgz \
    && rm -f android-sdk.tgz

# Install Gradle
RUN wget https://services.gradle.org/distributions/gradle-"$GRADLE_VERSION"-bin.zip \
    && mkdir /opt/gradle \
    && unzip -d /opt/gradle gradle-"$GRADLE_VERSION"-bin.zip \
    && rm -rf gradle-"$GRADLE_VERSION"-bin.zip

# Clear apt cache
RUN apt-get autoremove -y \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Set english default language
RUN locale-gen en_US.UTF-8

# Install cordova and ionic
RUN yarn global add cordova@${CORDOVA_VERSION} \
  && yarn global add ionic@${IONIC_VERSION} \
  && ionic config set -g yarn true

# Setup environment
ENV PATH=${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tools:/opt/tools:/opt/gradle/gradle-"$GRADLE_VERSION"/bin

# Install sdk elements
COPY tools /opt/tools
RUN ["/opt/tools/android-accept-licenses.sh", "android update sdk --all --no-ui --filter platform-tools,tools,build-tools-26.0.0,android-26,build-tools-25.0.0,android-25,extra-android-support,extra-android-m2repository,extra-google-m2repository"]
RUN unzip ${ANDROID_HOME}/temp/*.zip -d ${ANDROID_HOME}

# skip installing gem documentation
RUN mkdir -p /usr/local/etc && { echo 'install: --no-document'; echo 'update: --no-document'; } >> /usr/local/etc/gemrc

# SSH config
RUN mkdir /var/run/sshd \
  && sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
  && echo "export VISIBLE=now" >> /etc/profile \
  && echo 'root:root' | chpasswd

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
  && chown -R devel:devel $APPS \
  && chown -R devel. /opt

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
#RUN ionic cordova build android --prod --no-interactive --release

# Expose port 3000 to the Docker host, so we can access it
# from the outside.
EXPOSE 22
EXPOSE 8100
EXPOSE 35729
EXPOSE 53703

# The main command to run when the container starts. Also
# tell the Rails dev server to bind to all interfaces by
# default.
# RUN $ANDROID_HOME/tools/bin/sdkmanager "build-tools;26.0.1" "platforms;android-26"
CMD ["/usr/bin/sudo", "/usr/sbin/sshd", "-D"]
