FROM ruby:2.7.2

COPY Gemfile .
COPY Gemfile.lock .

RUN bundle install

COPY . .

EXPOSE 3000

CMD ./start_local

