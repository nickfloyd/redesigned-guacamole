require 'sinatra'

configure { set :server, :puma }

set :port, 3002
set :bind, '0.0.0.0'

get '/' do
  [200, {}, ["Success\n"]]
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

    [200, {}, ["Service 2 woke up after: #{ms}ms.\n"]]
  end
end