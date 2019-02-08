## Installation

* `docker-compose build`
* `docker-compose run --rm rails-api rails new . --force --api --skip-bundle --database=postgresql`
* `sudo chown -R akamal:akamal .`
* `docker-compose up -d`

### If you have a database dump file
* `docker-compose exec rails-api rails db:create`
* `cat app_development.sql | docker exec -i rails-db psql -U postgres -d app_development`

### If you want to start a fresh server
* `docker-compose exec rails-api rails db:create db:migrate`

## Logs
* `docker-compose logs -f`

## Backup database
* `docker exec -t rails-db pg_dump -U postgres -d app_development > app_development_$(date +%d-%m-%Y"_"%H_%M_%S).sql`

## Bundle Install
* `docker-compose exec rails-api bundle install`

### OR
* `docker-compose restart rails-api`
