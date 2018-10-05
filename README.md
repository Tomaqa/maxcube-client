# eQ3/ELV Max! Cube TCP client

## Announcement

**Project migrated to GitLab** in 8/2018.

This software still has not been tested against real Cube gateway, simply because the developer does not have one. Owners of these devices are welcome to use this software, and asked to report discovered bugs to GitLab.

## Download

Ruby [gem](https://rubygems.org/gems/maxcube-client)

[GitLab](https://gitlab.com/Tomaqa/maxcube-client) repository

*[GitHub](https://github.com/Tomaqa/maxcube-client) old archived repository used until 8/2018*

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'maxcube-client'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install maxcube-client

## Usage

Run `bin/maxcube-client help` and follow instructions. This script starts either TCP or UDP client. UDP client is used only for device discovery purposes yet.

You can also run `bin/console`, if you want to to handle objects yourself.

Yet there are sample servers: `bin/sample_server` (TCP) and `bin/sample_socket` (UDP), but only with very basic features. However, they can be used to try simple connection with client.

## Documentation

Project is documented using YARD.

MAX! Cube protocol itself is not documented here though.
You should have a look [here](https://github.com/Bouni/max-cube-protocol),
where I derived vast of specifications from.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitLab at https://gitlab.com/Tomaqa/maxcube-client.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
