require 'sinatra'

set :port, 3000
set :bind, '0.0.0.0'

get '/' do
  "get is done."
end

get '/timeout' do
  sleep(SLEEP_SECONDS)
  SLEEP_SECONDS.to_s
end

get '/disconnect' do
  "TODO: Implement disconnect"
end
