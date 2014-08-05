# reqflow

[![Build Status](https://secure.travis-ci.org/projecthydra-labs/reqflow.png)](http://travis-ci.org/projecthydra-labs/reqflow)

Simple, self-aware, requirements based workflow manager based on Redis/Resque.

Reqflow lets you define workflows based on actions that define their own 
prerequisites. Actions whose prerequisites are met can be queued in parallel 
with one another.

## Installation

Add this line to your application's Gemfile:

    gem 'reqflow'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install reqflow

## Contributing

1. Fork it ( https://github.com/mbklein/reqflow/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
