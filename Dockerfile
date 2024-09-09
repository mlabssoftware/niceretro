FROM rubylang/ruby:2.3.8-bionic

RUN apt-get update && apt-get install -y gcc cpp g++ make libpq-dev

COPY . /code/

WORKDIR /code

RUN gem install bundler -v 2.0.2

RUN bundle install

COPY docker-entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

RUN ln -s /usr/local/bin/docker-entrypoint.sh / # backwards compat

ENTRYPOINT ["docker-entrypoint.sh"]
