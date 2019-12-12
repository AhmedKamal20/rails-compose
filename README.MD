## Usage
* `RailsC.sh PATH PORT_PREFIX RAILS_OPTIONS`
* `RailsC.sh ~/path/to/app 30 "--force --database=postgresql"`

## Logs
* `docker-compose logs -f`

## Backup database
* `docker exec -t db pg_dump -U postgres -d app_development > app_development_$(date +%d-%m-%Y"_"%H_%M_%S).sql`

### To Restore database
* `cat app_development.sql | docker exec -i db psql -U postgres -d app_development`

## To Migrate
* `docker-compose exec rails rails db:migrate`

## Bundle Install
* `docker-compose exec rails bundle install`
