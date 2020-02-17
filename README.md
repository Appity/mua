# Mua

An asynchronous mail user agent (MUA) library built on
[Ruby Async](https://github.com/socketry/async).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mua'
```

And then execute:

```shell
bundle install
```

Or install it yourself as:

```shell
gem install mua
```

## Usage

There's a number of examples in `bin/` as well as demonstration of the various
features in `spec/unit/`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then,
run `rake spec` to run the tests. You can also run `bin/console` for an
interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`, and then
run `bundle exec rake release`, which will create a git tag for the version,
push git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Debugging

### TLS Certificates and Connectivity

The `openssl` command-line tool has features that make testing `STARTTLS`
implemetations fairly straight-forward:

```shell
openssl s_client -connect localhost:1025 -starttls smtp
```

Where `localhost:1025` is the target server being tested.

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/tadman/asmail. This project is intended to be a safe,
welcoming space for collaboration, and contributors are expected to adhere to
the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Asmail project’s codebases, issue trackers, chat
rooms and mailing lists is expected to follow the
[code of conduct](https://github.com/postageapp/mua/blob/master/CODE_OF_CONDUCT.md).
