#!/bin/bash

###################################################################
# Script Name  : RailsC
# Description  : A CLI tool to help you start a new rails app fast
# Version      : 1.0.0
# Author       : AhmedKamal20
# Email        : ahmed.kamal200@gmail.com
###################################################################

set -e
sudo -v

RED='\e[1;31m'; GRE='\e[1;32m'; BLU='\e[1;34m'; YEL='\e[1;33m'; NCO='\e[0m';

function help {
  echo -e "\n${RED}No/Wrong arguments supplied${NCO}\n"
  echo -e "${YEL}RailsC${NCO} - A CLI tool to help you start a new rails app fast\n"
  echo -e "${GRE}Format:${NCO} RailsC [PATH] [PORT PREFIX] [RAILS OPTIONS]\n"
  echo -e "${BLU}PATH:${NCO} Include The Repo Folder Name, Default is Current Folder"
  echo -e "${BLU}PORT PREFIX:${NCO} 30 OR 60, UsedAs 3030,3080 for Services, Default is 30"
  echo -e "${BLU}RAILS OPTIONS:${NCO} Option to use for Rails new Apps, Default is \"--skip-bundle --database=postgresql\"\n"
  echo -e "${YEL}e.g.${NCO} RailsC ~/apps/myApp 30 \"--force --skip-bundle --database=postgresql\"\n"
}

function log {
  echo -e "${GRE}✔${NCO} $1"
}

function overwrite_railsc {
  pushd "${RepoPath}"
  docker-compose down -v
  popd
  read -p "Are you sure you want to remove ${RepoPath}?" yn
  case $yn in
    [Yy]* ) echo "sudo rm -rf ${RepoPath}"; sudo rm -rf "${RepoPath}";;
    [Nn]* ) exit;;
    * ) echo "Please answer yes or no."; exit;;
  esac
}

if [ $# -lt 2 ]; then
  help
  exit 1
fi

Testing=false
RepoPath=$(readlink -f "${1}")
AppName=$(basename "${RepoPath}")
AppName=$(echo ${AppName// /-} | tr '[:upper:]' '[:lower:]')
RailsPort="${2}30"
WebPackerPort="${2}35"
AdminerPort="${2}80"
RailsOptions="${3}"
if [[ ${3} == *api* ]]; then
  WebPackerEnabled=false
else
  WebPackerEnabled=true
fi

RubyVersion="2.6.5"
RailsVersion="6.0.1"
PostgresVersion="9.4"

echo -e "${GRE}\n\nCreating New Rails App as follow:${NCO}"
echo -e "${BLU}AppName:${NCO} ${AppName}"
echo -e "${BLU}RepoPath:${NCO} ${RepoPath}"
echo -e "${BLU}RailsPort:${NCO} ${RailsPort}"
echo -e "${BLU}AdminerPort:${NCO} ${AdminerPort}"
echo -e "${BLU}RailsOptions:${NCO} ${RailsOptions}"
echo -e "${BLU}RubyVersion:${NCO} ${RubyVersion}"
echo -e "${BLU}RailsVersion:${NCO} ${RailsVersion}"
echo -e "${BLU}PostgresVersion:${NCO} ${PostgresVersion}"
echo -e "${RED}Starting...${NCO}"

if [[ -d ${RepoPath} && $Testing == false ]]; then
  read -p "The Path is Existed Already, Do you wish to overwrite it?" yn
  case $yn in
    [Yy]* ) overwrite_railsc;;
    [Nn]* ) exit;;
    * ) echo "Please answer yes or no."; exit;;
  esac
fi

mkdir -p "${RepoPath}"
cd "${RepoPath}"

# Creating Initial Files

cat > ./Dockerfile << ENDOFFILE
FROM ruby:${RubyVersion}

ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=DontWarn

RUN curl -sL https://deb.nodesource.com/setup_8.x | bash -
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \\
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update -qq \\
    && apt-get install -y --no-install-recommends \\
    postgresql-client \\
    nodejs \\
    yarn

WORKDIR /usr/src/app

COPY Gemfile /usr/src/app/Gemfile
COPY Gemfile.lock /usr/src/app/Gemfile.lock
$([[ $WebPackerEnabled = true ]] && echo "COPY package.json /usr/src/app/package.json")
$([[ $WebPackerEnabled = true ]] && echo "COPY yarn.lock /usr/src/app/yarn.lock")

RUN bundle install
$([[ $WebPackerEnabled = true ]] && echo "RUN yarn install")

COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

EXPOSE ${RailsPort}
$([[ $WebPackerEnabled = true ]] && echo "EXPOSE ${WebPackerPort}")

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "${RailsPort}"]
ENDOFFILE
log "Dockerfile Created"

cat > ./docker-compose.yml << ENDOFFILE
version: '2.0'

services:

  rails:
    build: .
    image: "${AppName}-rails"
    hostname: "rails"
    container_name: "${AppName}-rails"
    tty: true
    stdin_open: true
    volumes:
      - ./:/usr/src/app
    depends_on:
      - db
    ports:
      - ${RailsPort}:${RailsPort}$([[ $WebPackerEnabled = true ]] && echo -e "\n      - ${WebPackerPort}:${WebPackerPort}")
    environment:
      RAILS_ENV: "development"
      NODE_ENV: "development"
      HOST: "localhost"
      PORT: "${RailsPort}"
      PGHOST: "db"
      PGPORT: "5432"
      PGUSER: "postgres"
      PGPASSWORD: "postgres"

  db:
    image: postgres:${PostgresVersion}-alpine
    hostname: "db"
    container_name: "${AppName}-db"
    restart: always
    environment:
      POSTGRES_USER: "postgres"
      POSTGRES_PASSWORD: "postgres"
    volumes:
      - ${AppName}-db-data:/var/lib/postgresql/data
      - ${AppName}-db-logs:/var/log/postgresql

  adminer:
    image: adminer:latest
    restart: always
    hostname: "adminer"
    container_name: "${AppName}-adminer"
    ports:
      - ${AdminerPort}:8080

volumes:
  ${AppName}-db-data:
  ${AppName}-db-logs:
ENDOFFILE
log "DockerCompose file Created"

cat > ./entrypoint.sh << ENDOFFILE
#!/bin/bash
set -e

# Remove a potentially pre-existing server.pid for Rails.
rm -f tmp/pids/server.pid

echo -e "Installing Ruby Dependencies"
bundle install
$([[ $WebPackerEnabled = true ]] && echo "
if [[ -d 'config/webpack' ]]; then
  echo 'Installing JS Dependencies'
  yarn install
else
  echo 'Installing Webpacker'
  rails webpacker:install
fi")

# Do the pending migrations.
if psql -lqt | cut -d \| -f 1 | grep -qw app_development; then
  rails db:migrate
else
  rails db:create db:migrate db:seed
fi
$([[ $WebPackerEnabled = true ]] && echo -e "\n./bin/webpack-dev-server &")

# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "\$@"
ENDOFFILE
log "Entrypoint Script Created"

cat > ./Gemfile << ENDOFFILE
source 'https://rubygems.org'
gem 'rails', '~> ${RailsVersion}'
ENDOFFILE
log "Gemfile Created"

cat > ./package.json << ENDOFFILE
{
  "name": "${AppName}",
  "version": "1.0.0",
  "private": true
}
ENDOFFILE
log "Package.json Created"

touch ./Gemfile.lock
log "Gemfile Lock Created"

touch ./yarn.lock
log "Yarn Lock Created"

# Start Building the Project

if [[ $Testing == false ]]; then
  log "Building the docker images"
  docker-compose build

  log "Initializing the Rails App"
  docker-compose run --rm --no-deps --entrypoint "" rails rails new . ${RailsOptions}

  log "Changing the Owner to Current User"
  sudo chown -R $USER:$(id -gn $USER) .

  log "Rebuilding the docker images"
  docker-compose build

  log "Starting the docker services"
  docker-compose up -d

  log "Wating For Webpacker"
  spinner="/|\\-/|\\-"
  while [ ! -f db/schema.rb ]; do
    for i in `seq 0 7`
    do
      echo -n "${spinner:$i:1}"
      echo -en "\010"
      sleep 0.5
    done
  done

  log "Changing the Owner to Current User"
  sudo chown -R $USER:$(id -gn $USER) .

  log "Creating an Initial commit"
  git add .
  git commit -m "Initial commit"
fi

echo -e "${RED}Done${NCO}"
echo -e "Rails App Installed In ${RepoPath}"
echo -e "Rails App Runs at http://localhost:${RailsPort}/"
echo -e "Adminer Runs at http://localhost:${AdminerPort}/"
