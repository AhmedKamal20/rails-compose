FROM ruby:2.6.3

RUN apt-get update -qq && apt-get install -y postgresql-client
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash - && apt-get install -y nodejs

WORKDIR /usr/src/app

COPY Gemfile /usr/src/app/Gemfile
COPY Gemfile.lock /usr/src/app/Gemfile.lock

RUN bundle install

COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

EXPOSE 3000

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
