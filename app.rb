
# Run with:
# $ docker build -f Dockerfile --iidfile iid . && docker run -w $(pwd) -p 3000:3000 -v $(pwd):$(pwd) $(cat iid)
# $ chrome http://localhost:3000/slow &

# Stop with
# $ docker kill $(docker ps -q)

require 'sinatra'
require 'faraday'
require 'faraday/net_http'

set :port, 3000
set :bind, '0.0.0.0'

get '/slow' do
  # Do a slow (but cancellable) operation.
  sleepy = Thread.current
  with_cancel(-> { sleepy.wakeup; puts "sleep cancelled" }) do
    puts "begin slow operation"
    sleep 5
    puts "slow operation done"
  end

  "ok" # response
end

# The /delegate endpoint makes an HTTP request to the /slow endpoint.
# When it is cancelled, the outgoing HTTP request is aborted leading
# to prompt cancellation of the /slow handler.
get '/delegate' do
  puts "/delegate, calling /slow"

  # Thread.raise is a sledgehammer of a way to cancel Faraday---similar to Timeout::timeout(5) { ... }.
  # TODO: implement graceful async cancellation in Faraday.
  cur = Thread.current
  response = with_cancel(-> { puts "delegation cancelled"; cur.raise Exception.new "Faraday request cancelled" }) do
    Faraday.get('http://localhost:3000/slow')
  end
  "/slow responded with " + response.body.to_s
end

# --- infrastructure ---

# CancelMiddleware allows handler threads to use with_cancel to ensure that
# blocking operations are cancelled if the requesting client disconnects.
class CancelMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    # Grab the client TCPSocket (here we assume a Puma server).
    socket = env["puma.socket"]

    # Create a cancellation event for this request.
    cancel = Event.new

    # Save it in the request thread.
    Thread.current[:cancel] = cancel

    # Start watchdog thread to abort handler if socket is closed.
    watchdog = Thread.new {
      # Wait for Puma TCPSocket to become readable.
      puts "select"
      IO.select([socket], [], [])

      # Completion of the select may occur for several reasons.
      # - Client disconnected. A follow-up socket.sysread(1) would fail with EOFError.
      # - Client shutdown the write half of the connection. (No client actually does this.)
      # - Client sent a pipelined HTTP 1.1 request. We don't support pipelining.
      #   All three cases above should result in the cancellation event.
      # - Client sent non-HTTP data to be consumed by an endpoint that uses socket hijacking.
      #   Do we use this mechanism (perhaps for websockets)?
      #   Can we detect that an endpoint has enabled hijacking from state changes in env hash?
      #   This is the only case that should not lead to cancellation.
      # The select may fail to return if this thread is killed by the watchdog.
      # Each of these cases needs testing, both for Puma and Unicorn.

      puts "cancel"
      cancel.broadcast
    }

    begin
      # Call main request handler
      @app.call(env)
    ensure
      # Call off the watchdog when the handler completes.
      watchdog.kill
      watchdog.join
    end
  end
end

use CancelMiddleware

# A simple waitable one-time event.
# TODO: does this exist in a library?
class Event
  def initialize
    @mu = Mutex.new
    @done = false
    @cv = ConditionVariable.new # for "done" condition
  end

  # broadcast causes the event to occur.
  def broadcast
    @mu.synchronize {
      @done = true
      @cv.broadcast
    }
  end

  # wait puts the current thread to sleep until the event occurs.
  def wait
    @mu.synchronize {
      while !@done
        @cv.wait(@mu)
      end
    }
  end

  # fired? reports whether the event has occurred.
  def fired?
    @mu.synchronize { @done }
  end
end



# with_cancel evaluates 'block', and calls 'abort' in another
# thread if the thread-local cancel event occurs before or during
# (or possibly even shortly after) the call is complete.
# The abort and block procedures must be safe to call concurrently.
#
# Use this around any potentially slow operation that
# supports asynchronous cancellation.
def with_cancel(abort, &block)
  mu = Mutex.new # TODO: does Ruby have an AtomicBoolean?
  done = false

  cancel = Thread.current[:cancel] # TODO crash if not present
  
  # The watchdog thread may be killed at any moment.
  watchdog = Thread.new do
    cancel.wait
    abort.call unless mu.synchronize { done }
  end
  block.call
ensure
  mu.synchronize { done = true }
  watchdog.kill
  watchdog.join
end
