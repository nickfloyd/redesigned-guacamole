FROM ruby:2.7.2

WORKDIR /app
COPY . .

RUN bundle install

EXPOSE 3000

CMD ruby app.rb -s puma

