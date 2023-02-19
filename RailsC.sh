#!/bin/bash

############################################################################
# Script Name  : RailsC
# Description  : A CLI tool to help you start a new rails app with docker-compose fast
# Version      : 1.1.0
# Author       : AhmedKamal20 ( Ahmed Kamal )
# Email        : ahmed.kamal200@gmail.com
# Dependencies : docker-compose readlink basename pushd popd read sudo sleep
############################################################################

set -e
sudo -v

TESTING=false
ForceDisableNode=true
RED='\e[1;31m'; GRE='\e[1;32m'; BLU='\e[1;34m'; YEL='\e[1;33m'; NCO='\e[0m';

# Help Message
if [ $# -lt 1 ]; then
  echo -e "\n${RED}No/Wrong arguments supplied${NCO}\n"
  echo -e "${YEL}RailsC${NCO} - A CLI tool to help you start a new rails app fast\n"
  echo -e "${GRE}Format:${NCO} RailsC <PATH> <LOCAL DOMAIN> [<RAILS OPTIONS>]\n"
  echo -e "${BLU}PATH:${NCO} The desired folder name for the Rails app"
  echo -e "${BLU}LOCAL DOMAIN:${NCO} Domain to use with Nginx reverse proxy, Default is <AppName>.io"
  echo -e "${BLU}RAILS OPTIONS:${NCO} Options to use for Rails new Apps, Default is --database=postgresql\n"
  echo -e "${YEL}e.g.${NCO} RailsC ~/apps/myApp example.com \"--force --database=postgresql\"\n"

  exit 1
fi

RubyVersion="3.2.1" # https://www.ruby-lang.org/en/downloads/
RailsVersion="7.0.4.2" # https://rubygems.org/gems/rails/versions
PostgresVersion="14.7" # https://www.postgresql.org/docs/release/
NodeVersion="16" # https://nodejs.org/en/about/releases/
DefaultOptions="--database=postgresql --skip-test --skip-system-test --skip-bootsnap -m ./template.rb"
ScriptDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
RepoPath=$(readlink -f "${1}")
AppName=$(basename "${RepoPath}" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')

if [ -z "${2}" ]; then
  AppDomain=$(echo "${AppName}" | tr '.' '-' | awk '{print $1".io"}')
else
  AppDomain="${2}"
fi

if [ -z "${3}" ]; then
  RailsOptions="${DefaultOptions}"
else
  RailsOptions="${3}"
fi

if [[ ${RailsOptions} == *api* ]] || [[ ${ForceDisableNode} = true ]]; then
  NodeEnabled=false
else
  NodeEnabled=true
fi

function log {
  echo -e "${GRE}✔${NCO} $1"
}

function f_run {
  echo -e "${RED}\$${NCO} $*"
  "$@"
}

function run {
  echo -e "${RED}\$${NCO} $*"
  if [[ $TESTING == false ]]; then
    "$@"
  fi
}

echo -e "${GRE}\n\nCreating New Rails App as follow:${NCO}"
echo -e "${BLU}AppName:${NCO} ${AppName}"
echo -e "${BLU}RepoPath:${NCO} ${RepoPath}"
echo -e "${BLU}RailsOptions:${NCO} ${RailsOptions}"
echo -e "${BLU}RubyVersion:${NCO} ${RubyVersion}"
echo -e "${BLU}RailsVersion:${NCO} ${RailsVersion}"
echo -e "${BLU}PostgresVersion:${NCO} ${PostgresVersion}"
echo -e "${BLU}NodeEnabled?:${NCO} ${NodeEnabled}"
echo -e "${RED}Starting...${NCO}"

function overwrite_railsc {
  run pushd "${RepoPath}"
  run docker-compose run --rm --entrypoint '' app rails db:drop
  run docker-compose down
  # run docker-compose down -v
  run popd
  read -p "Are you sure you want to remove ${RepoPath}? [YyNn] " yn
  case $yn in
    [Yy]* ) run sudo rm -rf "${RepoPath}";;
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

f_run mkdir -p "${RepoPath}"
f_run cd "${RepoPath}"

# Creating Initial Files

cat > ./Dockerfile.dev << ENDOFFILE
FROM ruby:${RubyVersion}

ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=DontWarn

RUN curl -sL https://deb.nodesource.com/setup_${NodeVersion}.x | bash -
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

RUN gem update --system
RUN gem update bundler

COPY entrypoint.dev.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

EXPOSE 3000

CMD ["bin/dev"]
ENDOFFILE
log "Dockerfile Created"

cat > ./docker-compose.yml << ENDOFFILE
services:

  reverse:
    image: "jwilder/nginx-proxy"
    container_name: "${AppName}-reverse"
    ports:
      - 80:80
      - 443:443
    volumes:
      - /var/run/docker.sock:/tmp/docker.sock:ro

  app:
    build:
      context: .
      dockerfile: Dockerfile.dev
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
      $([[ $NodeEnabled = true ]] && echo "- ${AppName}-app-node-modules-dir:/usr/src/app/node_modules:delegated")
      $([[ $NodeEnabled = true ]] && echo "- ${AppName}-app-yarn-cache-dir:/usr/src/yarn:delegated")
    depends_on:
      - "db"
    environment:
      VIRTUAL_HOST: "app.${AppDomain}"
      RAILS_ENV: "development"
      NODE_ENV: "development"
      $([[ $NodeEnabled = true ]] && echo "YARN_CACHE_FOLDER: '/usr/src/yarn'")
      HOST: "app.${AppDomain}"
      PORT: "3000"
      PGHOST: "db"
      PGPORT: "5432"
      PGUSER: "postgres"
      PGPASSWORD: "postgres"
      REDIS_URL: "redis://redis:6379/1"

  sidekiq:
    image: "${AppName}-app"
    hostname: "sidekiq"
    domainname: "${AppDomain}"
    container_name: "${AppName}-sidekiq"
    networks:
      default:
        aliases:
          - "sidekiq.${AppDomain}"
    volumes:
      - ./:/usr/src/app
      - ${AppName}-app-bundler-dir:/usr/local/bundle
      $([[ $NodeEnabled = true ]] && echo "- ${AppName}-app-node-modules-dir:/usr/src/app/node_modules:delegated")
      $([[ $NodeEnabled = true ]] && echo "- ${AppName}-app-yarn-cache-dir:/usr/src/yarn:delegated")
    depends_on:
      - "app"
      - "redis"
    command: "bundle exec sidekiq"
    entrypoint: ''
    environment:
      VIRTUAL_HOST: "sidekiq.${AppDomain}"
      RAILS_ENV: "development"
      NODE_ENV: "development"
      $([[ $NodeEnabled = true ]] && echo "YARN_CACHE_FOLDER: '/usr/src/yarn'")
      HOST: "app.${AppDomain}"
      PORT: "3000"
      PGHOST: "db"
      PGPORT: "5432"
      PGUSER: "postgres"
      PGPASSWORD: "postgres"
      REDIS_URL: "redis://redis:6379/1"

  mailcatcher:
    image: "schickling/mailcatcher:latest"
    hostname: "mailcatcher"
    domainname: "${AppDomain}"
    container_name: "${AppName}-mailcatcher"
    networks:
      default:
        aliases:
          - "mailcatcher.${AppDomain}"
    depends_on:
      - "app"
    environment:
      VIRTUAL_HOST: "mailcatcher.${AppDomain}"
      VIRTUAL_PORT: "1080"

  db:
    image: "postgres:${PostgresVersion}-alpine"
    hostname: "db"
    domainname: "${AppDomain}"
    container_name: "${AppName}-db"
    restart: "always"
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

  adminer:
    image: "adminer:latest"
    hostname: "adminer"
    domainname: "${AppDomain}"
    container_name: "${AppName}-adminer"
    restart: "always"
    networks:
      default:
        aliases:
          - "adminer.${AppDomain}"
    depends_on:
      - "db"
    environment:
      VIRTUAL_HOST: "adminer.${AppDomain}"

  redis:
    image: "redis:alpine"
    hostname: "redis"
    domainname: "${AppDomain}"
    container_name: "${AppName}-redis"
    restart: "always"
    networks:
      default:
        aliases:
          - "redis.${AppDomain}"

  commander:
    image: "rediscommander/redis-commander:latest"
    hostname: "commander"
    domainname: "${AppDomain}"
    container_name: "${AppName}-commander"
    restart: "always"
    networks:
      default:
        aliases:
          - "commander.${AppDomain}"
    depends_on:
      - "redis"
    environment:
      VIRTUAL_HOST: "commander.${AppDomain}"
      REDIS_HOSTS: "local:redis:6379,local:redis:6379:15"

volumes:
  ${AppName}-db-data:
  ${AppName}-db-logs:
  ${AppName}-app-bundler-dir:
  $([[ $NodeEnabled = true ]] && echo "${AppName}-app-node-modules-dir:")
  $([[ $NodeEnabled = true ]] && echo "${AppName}-app-yarn-cache-dir:")
ENDOFFILE
log "DockerCompose file Created"

cat > ./entrypoint.dev.sh << ENDOFFILE
#!/bin/bash
set -e

# Remove a potentially pre-existing server.pid for Rails.
rm -f tmp/pids/server.pid

echo 'Installing Ruby Dependencies'
bundle check || bundle install

rails log:clear
rails tmp:clear

$([[ $NodeEnabled = true ]] && echo "
echo 'Installing JS Dependencies'
yarn install
")

# Do the pending migrations.
if psql -lqt | cut -d \| -f 1 | grep -qw app_development; then
  rails db:migrate
elif [[ -f 'db/schema.rb' ]]; then
  rails db:setup
else
  rails db:create db:migrate db:seed
fi

# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "\$@"
ENDOFFILE
log "Entrypoint Script Created"

log "Coping the template files to the app directory"
cp ${ScriptDir}/template.rb ${RepoPath}/template.rb

# Start Building the Project

log "Building the docker images"
run docker-compose build

log "Initializing the Rails App"
log "rails new . ${RailsOptions}"
run docker-compose run --rm --entrypoint '' app bash -c "gem install rails -v ${RailsVersion} && rails new . ${RailsOptions}"
run docker-compose down

log "Changing the owner to current user"
run sudo chown -R "$USER":"$(id -gn "$USER")" .

log "Starting the docker services"
run docker-compose up -d

if [[ $TESTING == false ]]; then
  log "Wating For Rails to be UP"
  spinner="/|\\-/|\\-"
  while [ ! -f db/schema.rb ]; do
    for i in $(seq 0 7)
    do
      echo -n "${spinner:$i:1}"
      echo -en "\010"
      sleep 0.5
    done
  done
fi

log "Changing the owner to current user"
run sudo chown -R "$USER":"$(id -gn "$USER")" .

# log "Creating an Initial commit"
# run git add .
# run git commit -m 'Initial commit'

echo -e "${RED}=-=-==-=-=-=-=-=-=-=${NCO}"
echo -e "${RED}Done${NCO}"
echo -e "${RED}=-=-==-=-=-=-=-=-=-=${NCO}"
echo -e "Rails App Installed In ${RepoPath}"
echo -e "Rails App Runs at http://app.${AppDomain}/"
echo -e "Adminer Runs at http://adminer.${AppDomain}/"
echo -e "Commander Runs at http://commander.${AppDomain}/"
echo -e "MailCatcher Runs at http://mailcatcher.${AppDomain}/"
echo -e "${RED}=-=-==-=-=-=-=-=-=-=${NCO}"
echo -e "Add This to your hosts file \n\

127.0.0.1 app.${AppDomain} \n\
127.0.0.1 mailcatcher.${AppDomain} \n\
127.0.0.1 commander.${AppDomain} \n\
127.0.0.1 adminer.${AppDomain}"
echo -e "${RED}=-=-==-=-=-=-=-=-=-=${NCO}"
