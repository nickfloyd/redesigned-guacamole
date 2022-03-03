#!/usr/bin/env puma
# frozen_string_literal: true
threads_count = ENV.fetch('PUMA_THREADS') { 10 }.to_i
threads threads_count, threads_count

preload_app!

# Change to a rack config if needed
rackup DefaultRackup

port ENV.fetch('PORT') { 3000 }
workers ENV.fetch('WORKERS') { 2 }.to_i