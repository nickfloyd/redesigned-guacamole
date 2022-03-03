FROM ruby:2.7.2

COPY Gemfile .
COPY Gemfile.lock .

RUN bundle install

COPY *.rb .

EXPOSE 3000

CMD ruby app.rb -s puma

