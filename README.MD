# Rails compose
A script to fastly bootstrap a docker/docker-compose environment for rails application.

## Usage
* `RailsC <PATH> [<LOCAL DOMAIN>] [<RAILS OPTIONS>]`
  ```
  PATH: The desired folder name for the Rails app
  LOCAL DOMAIN: Domain to use with Nginx reverse proxy, Default is App name
  RAILS OPTIONS: Options to use for Rails new Apps, Default is --database=postgresql
  ```
## Examples
* `RailsC.sh ~/path/to/app example.io "--force --database=postgresql"`
* `RailsC.sh ./myApp example.io`
* `RailsC.sh exampleApp`

## Logs
* `docker-compose logs -f`

## Backup database
* `docker exec -t db pg_dump -U postgres -d app_development > app_development_$(date +%d-%m-%Y"_"%H_%M_%S).sql`

### To Restore database
* `cat app_development.sql | docker exec -i db psql -U postgres -d app_development`

## To Migrate
* `docker-compose exec app rails db:migrate`

## Bundle Install
* `docker-compose exec app bundle install`

## TODO
* Add Rails template
