FROM ruby:2.7.2

COPY Gemfile .
RUN bundle install

#COPY *.rb .

EXPOSE 3000

CMD ruby app.rb -s puma

