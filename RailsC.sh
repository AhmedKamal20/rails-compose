#!/bin/bash

############################################################################
# Script Name  : RailsC
# Description  : A CLI tool to help you start a new rails app with docker-compose fast
# Version      : 1.0.0
# Author       : AhmedKamal20 ( Ahmed Kamal )
# Email        : ahmed.kamal200@gmail.com
# Dependencies : docker-compose readlink basename pushd popd read sudo sleep
############################################################################

set -e
sudo -v

TESTING=false
ForceDisableWebPack=true

RED='\e[1;31m'; GRE='\e[1;32m'; BLU='\e[1;34m'; YEL='\e[1;33m'; NCO='\e[0m';

# Help Message
if [ $# -lt 2 ]; then
  echo -e "\n${RED}No/Wrong arguments supplied${NCO}\n"
  echo -e "${YEL}RailsC${NCO} - A CLI tool to help you start a new rails app fast\n"
  echo -e "${GRE}Format:${NCO} RailsC [PATH] [PORT PREFIX] [RAILS OPTIONS]\n"
  echo -e "${BLU}PATH:${NCO} Include The Repo Folder Name, Default is Current Folder"
  echo -e "${BLU}PORT PREFIX:${NCO} 30 OR 60, UsedAs 3030,3080 for Services, Default is 30"
  echo -e "${BLU}RAILS OPTIONS:${NCO} Option to use for Rails new Apps, Default is \"${DefaultOptions}\"\n"
  echo -e "${YEL}e.g.${NCO} RailsC ~/apps/myApp 30 \"--force --database=postgresql\"\n"

  exit 1
fi

RubyVersion="2.7.3"
RailsVersion="6.1.3.2"
PostgresVersion="13.3"
DefaultOptions="--database=postgresql"

RepoPath=$(readlink -f "${1}")
AppName=$(basename "${RepoPath}")
AppName=$(echo ${AppName// /-} | tr '[:upper:]' '[:lower:]')
AppDomain="${2}"
RailsPort="3000"
WebPackerPort="3035"
AdminerPort="8080"
CommanderPort="8081"
MailCatcherPort="1080"

if [ -z "${3}" ]; then
  RailsOptions="${DefaultOptions}"
else
  RailsOptions="${3}"
fi

if [[ ${RailsOptions} == *api* ]] || [[ ${ForceDisableWebPack} ]]; then
  WebPackerEnabled=false
else
  WebPackerEnabled=true
fi

function log {
  echo -e "${GRE}✔${NCO} $1"
}

function run {
  echo -e "${RED}\$${NCO} $@"
  if [[ $TESTING == false ]]; then
    $@
  fi
}

echo -e "${GRE}\n\nCreating New Rails App as follow:${NCO}"
echo -e "${BLU}AppName:${NCO} ${AppName}"
echo -e "${BLU}RepoPath:${NCO} ${RepoPath}"
echo -e "${BLU}RailsPort:${NCO} ${RailsPort}"
echo -e "${BLU}AdminerPort:${NCO} ${AdminerPort}"
echo -e "${BLU}CommanderPort:${NCO} ${CommanderPort}"
echo -e "${BLU}MailCatcherPort:${NCO} ${MailCatcherPort}"
echo -e "${BLU}RailsOptions:${NCO} ${RailsOptions}"
echo -e "${BLU}RubyVersion:${NCO} ${RubyVersion}"
echo -e "${BLU}RailsVersion:${NCO} ${RailsVersion}"
echo -e "${BLU}PostgresVersion:${NCO} ${PostgresVersion}"
echo -e "${RED}Starting...${NCO}"


function overwrite_railsc {
  pushd "${RepoPath}"
  docker-compose down -v
  popd
  read -p "Are you sure you want to remove ${RepoPath}? [YyNn] " yn
  case $yn in
    [Yy]* ) echo "sudo rm -rf ${RepoPath}"; sudo rm -rf "${RepoPath}";;
    [Nn]* ) exit;;
    * ) echo "Please answer [YyNn]"; exit;;
  esac
}

if [[ -d ${RepoPath} && $TESTING == false ]]; then
  read -p "The Path is Existed Already, Do you wish to overwrite it? [YyNn] " yn
  case $yn in
    [Yy]* ) overwrite_railsc;;
    [Nn]* ) exit;;
    * ) echo "Please answer [YyNn]"; exit;;
  esac
fi

mkdir -p "${RepoPath}"
cd "${RepoPath}"

# Creating Initial Files

cat > ./Dockerfile << ENDOFFILE
FROM ruby:${RubyVersion}
#FROM rails:${RailsVersion}

ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=DontWarn

RUN curl -sL https://deb.nodesource.com/setup_12.x | bash -
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \\
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update -qq \\
    && apt-get install -y --no-install-recommends \\
    libpq-dev \\
    postgresql-client \\
    poppler-utils \\
    nodejs \\
    yarn

WORKDIR /usr/src/app

COPY Gemfile /usr/src/app/Gemfile
COPY Gemfile.lock /usr/src/app/Gemfile.lock
$([[ $WebPackerEnabled = true ]] && echo "COPY package.json /usr/src/app/package.json")
$([[ $WebPackerEnabled = true ]] && echo "COPY yarn.lock /usr/src/app/yarn.lock")

RUN gem install rails -v ${RailsVersion}

COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

EXPOSE ${RailsPort}
$([[ $WebPackerEnabled = true ]] && echo "EXPOSE ${WebPackerPort}")

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "${RailsPort}"]
ENDOFFILE
log "Dockerfile Created"

cat > ./docker-compose.yml << ENDOFFILE
version: '3'

services:

  reverse:
    image: jwilder/nginx-proxy
    container_name: "${AppName}-reverse"
    ports:
      - 80:80
      - 443:443
    volumes:
      - /var/run/docker.sock:/tmp/docker.sock:ro

  app:
    build: .
    image: "${AppName}-app"
    hostname: "app"
    domainname: "${AppDomain}"
    container_name: "${AppName}-app"
    tty: true
    stdin_open: true
    networks:
      default:
        aliases:
          - "app.${AppDomain}"
    volumes:
      - ./:/usr/src/app
      - ${AppName}-app-bundler-dir:/usr/local/bundle
    depends_on:
      - db
    ports:
      - ${RailsPort}$([[ $WebPackerEnabled = true ]] && echo -e "\n      - ${WebPackerPort}:${WebPackerPort}")
    environment:
      VIRTUAL_HOST: "app.${AppDomain}"
      VIRTUAL_PORT: ${RailsPort}
      RAILS_ENV: "development"
      NODE_ENV: "development"
      HOST: "app.${AppDomain}"
      PORT: ${RailsPort}
      PGHOST: "db.${AppDomain}"
      PGPORT: 5432
      PGUSER: "postgres"
      PGPASSWORD: "postgres"

  db:
    image: postgres:${PostgresVersion}-alpine
    restart: always
    hostname: "db"
    domainname: "${AppDomain}"
    container_name: "${AppName}-db"
    networks:
      default:
        aliases:
          - "db.${AppDomain}"
    volumes:
      - ${AppName}-db-data:/var/lib/postgresql/data
      - ${AppName}-db-logs:/var/log/postgresql
    environment:
      POSTGRES_USER: "postgres"
      POSTGRES_PASSWORD: "postgres"

  mailcatcher:
    image: schickling/mailcatcher:latest
    hostname: "mailcatcher"
    domainname: "${AppDomain}"
    container_name: "${AppName}-mailcatcher"
    networks:
      default:
        aliases:
          - "mailcatcher.${AppDomain}"
    depends_on:
      - app
    ports:
      - ${MailCatcherPort}
    environment:
      VIRTUAL_HOST: "mailcatcher.${AppDomain}"
      VIRTUAL_PORT: ${MailCatcherPort}

  adminer:
    image: adminer:latest
    restart: always
    hostname: "adminer"
    domainname: "${AppDomain}"
    container_name: "${AppName}-adminer"
    networks:
      default:
        aliases:
          - "adminer.${AppDomain}"
    ports:
      - ${AdminerPort}
    environment:
      VIRTUAL_HOST: "adminer.${AppDomain}"

  redis:
    image: redis:alpine
    restart: always
    hostname: "redis"
    domainname: "${AppDomain}"
    container_name: "${AppName}-redis"
    networks:
      default:
        aliases:
          - "redis.${AppDomain}"

  commander:
    image: rediscommander/redis-commander:latest
    restart: always
    hostname: "commander"
    domainname: "${AppDomain}"
    container_name: "${AppName}-commander"
    networks:
      default:
        aliases:
          - "commander.${AppDomain}"
    depends_on:
      - redis
    ports:
      - ${CommanderPort}
    environment:
      VIRTUAL_HOST: "commander.${AppDomain}"
      REDIS_HOSTS: local:redis:6379,local:redis:6379:15

volumes:
  ${AppName}-db-data:
  ${AppName}-db-logs:
  ${AppName}-app-bundler-dir:
ENDOFFILE
log "DockerCompose file Created"

cat > ./entrypoint.sh << ENDOFFILE
#!/bin/bash
set -e

# Remove a potentially pre-existing server.pid for Rails.
rm -f tmp/pids/server.pid

echo -e "Installing Ruby Dependencies"
bundle check || bundle install

rails log:clear
rails tmp:clear

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
elif [[ -f 'db/schema.rb' ]]; then
  rails db:setup
else
  rails db:create db:migrate db:seed
fi
$([[ $WebPackerEnabled = true ]] && echo -e "\n./bin/webpack-dev-server &")

# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "\$@"
ENDOFFILE
log "Entrypoint Script Created"

cat > ./Procfile << ENDOFFILE
web: bundle exec puma -C config/puma.rb
ENDOFFILE
log "Procfile Created"

cat > ./Gemfile << ENDOFFILE
source 'https://rubygems.org'
gem 'rails', '~> ${RailsVersion}'
ENDOFFILE
log "Gemfile Created"

if [[ $WebPackerEnabled = true ]]; then
cat > ./package.json << ENDOFFILE
{
  "name": "${AppName}",
  "version": "0.1.0",
  "private": true
}
ENDOFFILE
log "Package.json Created"
fi

touch ./Gemfile.lock
log "Gemfile Lock Created"

if [[ $WebPackerEnabled = true ]]; then
touch ./yarn.lock
log "Yarn Lock Created"
fi

# Start Building the Project

log "Building the docker images"
run "docker-compose build"

log "Initializing the Rails App"
log "rails new . ${RailsOptions}"
run "docker-compose run --rm --no-deps --entrypoint '' app rails new . ${RailsOptions}"

log "Changing the Owner to Current User"
run "sudo chown -R $USER:$(id -gn $USER) ."

log "Starting the docker services"
run "docker-compose up -d"

if [[ $TESTING == false ]]; then
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
fi

log "Changing the Owner to Current User"
run "sudo chown -R $USER:$(id -gn $USER) ."

log "Creating an Initial commit"
run "git add ."
run "git commit -m 'Initial commit'"

echo -e "${RED}=-=-==-=-=-=-=-=-=-=${NCO}"
echo -e "${RED}Done${NCO}"
echo -e "${RED}=-=-==-=-=-=-=-=-=-=${NCO}"
echo -e "Rails App Installed In ${RepoPath}"
echo -e "Rails App Runs at http://app.${AppDomain}/"
echo -e "Adminer Runs at http://adminer.${AppDomain}/"
echo -e "Commander Runs at http://commander.${AppDomain}/"
echo -e "MailCatcher Runs at http://mailcatcher.${AppDomain}/"
echo -e "${RED}=-=-==-=-=-=-=-=-=-=${NCO}"
echo -e "Change the webpacker port in config/webpacker.yml file \n\

host: app.${AppDomain} \n\
port: ${WebPackerPort} \n\
public: app.${AppDomain}:3035"
echo -e "${RED}=-=-==-=-=-=-=-=-=-=${NCO}"
echo -e "Add This to your development.rb file \n\

config.hosts << 'app.${AppDomain}' \n\
config.web_console.permissions = '172.0.0.0/0' \n\

config.action_mailer.default_url_options = { host: ENV.fetch('FRONT_END_HOST') { 'app.${AppDomain}' }, port: ENV.fetch('FRONT_END_PORT') { $RailsPort } } \n\
config.action_mailer.delivery_method = :smtp \n\
config.action_mailer.perform_deliveries = true \n\
config.action_mailer.default charset: 'utf-8' \n\

config.action_mailer.smtp_settings = { \n\
  address: 'mailcatcher', \n\
  port: 1025, \n\
}"
echo -e "${RED}=-=-==-=-=-=-=-=-=-=${NCO}"
echo -e "Add This to your hosts file \n\

127.0.0.1 app.${AppDomain} \n\
127.0.0.1 mailcatcher.${AppDomain} \n\
127.0.0.1 commander.${AppDomain} \n\
127.0.0.1 adminer.${AppDomain}"
echo -e "${RED}=-=-==-=-=-=-=-=-=-=${NCO}"
