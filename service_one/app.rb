require "sinatra"
require "faraday"

configure { set :server, :puma }
set :port, 3001
set :bind, '0.0.0.0'

# Add middleware here

faraday = Faraday.new(url: "http://localhost:3002") do |f|
  f.request :url_encoded
  f.adapter :net_http # or :httpclient, :excon, :typhoeus, etc
end

############## Service to service endpoints ##############

# / represents a request that will always return 200
# get '/' do
#   [200, {}, ["Success\n"]]
# end

get '/' do
  resp = faraday.get('/')
  [200, {}, [resp.body]]
end

get '/sleephop' do

  ms = params["ms"].to_i

  if ms.zero?
    [400, {}, ["Invalid or missing `ms` parameter.\n"]]
  end

  resp = faraday.get('/sleep', ms: ms)
  [200, {}, [resp.body]]
end

############## Chaos endpoints ##############

# /throw will raise a StandardError.
get '/throw' do
  content_type "text/plain"
  raise "Boom!"

  [200,{}, ["Invalid, this should've raised an error.\n"]]
end

# /sleep sleeps the thread for the specified number of
# milliseconds. can be used to simulate a slow response or even a timeout
#
# @param ms [Numeric] The duration (in milliseconds) to sleep for.
get '/sleep' do
  content_type "text/plain"

  ms = params["ms"].to_i

  if ms.zero?
    [400, {}, ["Invalid or missing `ms` parameter.\n"]]
  else
    Kernel.sleep(ms / 1000.0)

    [200, {}, ["Service 1 woke up after: #{ms}ms.\n"]]
  end
end

# /kill sends the specific signal to the current process, by default
# SIGINT. SIGTERM is used by {stop} and {restart}.
#
# Can be used to simulate graceful or ungraceful termination.
get '/kill' do
  content_type "text/plain"
  signal = params["signal"]

  if signal.empty?
    [400, {}, ["Missing or empty `signal` parameter. valid values are: SIGINT and SIGTERM\n"]]
  else
    Process.kill(signal, Process.pid)
    [200, {}, ["Signalled #{signal} to the current process.\n"]]
  end
end
