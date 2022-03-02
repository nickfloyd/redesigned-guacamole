module Middleware
  # A simple waitable one-time event.
 # TODO: does this exist in a library?
 # TODO: Privatize the event
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
end