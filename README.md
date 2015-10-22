# [Languages](http://libraries.io/rubygems/languages)

Just the language names and colors extracted from [github-lingust](https://github.com/github/linguist), avoiding the heavy dependencies like `charlock_holmes` which doesn't install well on heroku.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'languages'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install languages

## Usage

```ruby
Languages::Language['ruby'] #=> <Languages::Language name=Ruby color=#701516>

Languages::Language.all #=> [#<Languages::Language name=ActionScript color=#e3491a>, ..]

Languages::Language.by_extension('.rb')  #=> <Languages::Language name=Ruby color=#701516>
```

## Testing

Run the tests with:

    $ bundle exec rake

## Contributing

1. Fork it ( https://github.com/librariesio/languages/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
