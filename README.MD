## Installation

* `docker-compose build`
* `docker-compose run --rm rails-api rails new . --force --api --skip-bundle --database=postgresql`
* `sudo chown -R akamal:akamal .`
* `docker-compose build` Again, To Cache Gems.
* `docker-compose up -d`
* Add one of those if you want Quick CSS style.

`<link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/yegor256/tacit@gh-pages/tacit-css.min.css"/>`

`<link rel="stylesheet" href="https://cdn.rawgit.com/Chalarangelo/mini.css/v3.0.1/dist/mini-default.min.css">`

### If you have a database dump file
* `cat app_development.sql | docker exec -i rails-db psql -U postgres -d app_development`

## Logs
* `docker-compose logs -f`

## Backup database
* `docker exec -t rails-db pg_dump -U postgres -d app_development > app_development_$(date +%d-%m-%Y"_"%H_%M_%S).sql`

## to Migrate
* `docker-compose exec rails-api rails db:migrate`

## Bundle Install
* `docker-compose exec rails-api bundle install`

### OR
* `docker-compose restart rails-api`
