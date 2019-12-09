FROM ruby:2.3.0
COPY . /code/
WORKDIR /code
RUN gem install bundler
RUN bundle install
COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s /usr/local/bin/docker-entrypoint.sh / # backwards compat
ENTRYPOINT ["docker-entrypoint.sh"]
