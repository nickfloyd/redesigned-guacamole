# Pseudo code / Prototype of cancellation in ruby

Note: as a point of experimentation and to make this solution more portable - a [prototype gem](https://github.com/nickfloyd/cancellation) has been made and is used as a reference for this project. This gem should contain all of the infrastructure bits (types, middleware, and methods) that support cancellation distribution. 

Because this is an experiment / prototype this source is fairly unstable and might have a few in flight changes as it gets worked on.

### RUN 

----

#### For Puma

1. `$ cd service_puma`
2. `$ bundle install`
3. `$ ruby app.rb`

Kill with: `ctrl + c`


Alternatively docker can be used (there is currently a bug with the way the remote gem is being added):

`$ docker build -f Dockerfile --iidfile iid . && docker run -w $(pwd) -p 3000:3000 -v $(pwd):$(pwd) $(cat iid)`  

`$ chrome http://localhost:3000/slow`

Kill with: `docker kill $(docker ps -q)`

----
#### For unicorn

1. `$ cd service_unicorn`
2. `$ ./start_unicorn`

Kill with: `ctrl + c`


Alternatively docker can be used:

`$ docker build -f Dockerfile --iidfile iid . && docker run -w $(pwd) -p 3001:3001 -v $(pwd):$(pwd) $(cat iid)`  

`$ chrome http://localhost:3001/slow`

Kill with: `./stop_docker_unicorn`

----
### SCENARIOS

For Puma

1. `$ chrome http://localhost:3000/slow`
2. `$ chrome http://localhost:3000/delegate` - this will make a request to /slow
3. Now that the request is running you can close the browser, stop execution, etc...
4. Note in the console (where `ruby app.rb` was executed) - you'll see a message stating `delegation cancelled`


For Unicorn

1. `$ chrome http://localhost:3001/slow`
2. `$ chrome http://localhost:3001/delegate` - this will make a request to /slow
3. Now that the request is running you can close the browser, stop execution, etc...
4. Note in the console (where `ruby app.rb` was executed) - you'll see a message stating `delegation cancelled`

----

### NOTE / THOUGHTS  
This is a collection of thoughts and todos to dive a bit more on.  

----
#### Handling cancellations in ActiveRecord / MySQL
----

There is a great gem put together by @CGA1123 called [shed](https://github.com/CGA1123/shed/blob/main/ruby/lib/shed/active_record.rb) that does a great job at addressing deadline propagation.  

He uses a MySQL optimizer hint. `MAX_EXECUTION_TIME` specifically.

This makes sense in terms of duration deltas where there is a deadline being considered. I don't think this translates well with cancellation propagation - where client disconnects are the trigger.

[client.close](https://rubydoc.info/gems/mysql2/0.3.13/Mysql2/Client#close-instance_method) might be a good alternative to this.

> Immediately disconnect from the server, normally the garbage collector will disconnect automatically when a connection is no longer needed. Explicitly closing this will free up server resources sooner than waiting for the garbage collector.

Borrowing from the shed implementation, it can be approached in the same way only when a client disconnect is detected we explicitly close the connection when ActiveRecord/MySQL is in the request chain.

----

#### Graceful cancellations with Faraday
----

The current implementation in both the puma and unicorn services use a hammer of sorts to deal with faraday.  

Cancellation occurs because we throw in the with_cancel wrapper if a disconnect happens.

Faraday's lowest-level middleware, [NetHTTP](https://github.com/github/faraday/blob/master/lib/faraday/adapter/net_http.rb#L38-L29), would need to be modified so that if the cancel event is signaled, [finish](https://ruby-doc.org/stdlib-3.1.0/libdoc/net/rdoc/Net/HTTP.html#method-i-finish) is called on the [http connection](https://github.com/github/faraday/blob/master/lib/faraday/adapter/net_http.rb#L29), causing the socket to be closed and [perform_request](https://github.com/github/faraday/blob/master/lib/faraday/adapter/net_http.rb#L37) to fail with an exception. 

TODO: This needs to be prototyped via fork and gem ref change to use that fork.  

----