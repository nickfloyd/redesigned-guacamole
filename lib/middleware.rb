require_relative 'event'

module Middleware
  class Watchdog
    def initialize(app)
      @app = app
    end
  
    def call(env)
      # Grab the client TCPSocket (here we assume a Puma server).
      socket = env["puma.socket"] # or env["unicorn.socket"]
  
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
end