require 'escape_utils'
require 'yaml'

module Languages
  # Language names that are recognizable by GitHub. Defined languages
  # can be highlighted, searched and listed under the Top Languages page.
  #
  # Languages are defined in `lib/languages.yml`.
  class Language
    @languages       = []
    @index           = {}
    @name_index      = {}
    @alias_index     = {}
    @extension_index = {}

    # Valid Languages types
    TYPES = [:data, :markup, :programming, :prose]

    # Detect languages by a specific type
    #
    # type - A symbol that exists within TYPES
    #
    # Returns an array
    def self.by_type(type)
      all.select { |h| h.type == type }
    end

    # Detect languages by a specific extension
    #
    # extension - An extension for the file (.ruby)
    #
    # Returns an array
    def self.by_extension(extension)
      @extension_index[extension.downcase]
    end

    # Internal: Create a new Language object
    #
    # attributes - A hash of attributes
    #
    # Returns a Language object
    def self.create(attributes = {})
      language = new(attributes)

      @languages << language

      # All Language names should be unique. Raise if there is a duplicate.
      if @name_index.key?(language.name)
        raise ArgumentError, "Duplicate language name: #{language.name}"
      end

      # Language name index
      @index[language.name.downcase] = @name_index[language.name.downcase] = language

      language.aliases.each do |name|
        # All Language aliases should be unique. Raise if there is a duplicate.
        if @alias_index.key?(name)
          raise ArgumentError, "Duplicate alias: #{name}"
        end

        @index[name.downcase] = @alias_index[name.downcase] = language
      end

      language.extensions.each do |extension|
        if extension !~ /^\./
          raise ArgumentError, "Extension is missing a '.': #{extension.inspect}"
        end

        @extension_index[extension] ||= []
        @extension_index[extension] << language
      end

      language.interpreters.each do |interpreter|
        @interpreter_index[interpreter] << language
      end

      language.filenames.each do |filename|
        @filename_index[filename] << language
      end

      language
    end

    # Public: Get all Languages
    #
    # Returns an Array of Languages
    def self.all
      @languages
    end

    # Public: Look up Language by its proper name.
    #
    # name - The String name of the Language
    #
    # Examples
    #
    #   Language.find_by_name('Ruby')
    #   # => #<Language name="Ruby">
    #
    # Returns the Language or nil if none was found.
    def self.find_by_name(name)
      name && @name_index[name.downcase]
    end

    # Public: Look up Language by one of its aliases.
    #
    # name - A String alias of the Language
    #
    # Examples
    #
    #   Language.find_by_alias('cpp')
    #   # => #<Language name="C++">
    #
    # Returns the Language or nil if none was found.
    def self.find_by_alias(name)
      name && @alias_index[name.downcase]
    end

    # Public: Look up Language by its name.
    #
    # name - The String name of the Language
    #
    # Examples
    #
    #   Language['Ruby']
    #   # => #<Language name="Ruby">
    #
    #   Language['ruby']
    #   # => #<Language name="Ruby">
    #
    # Returns the Language or nil if none was found.
    def self.[](name)
      name && @index[name.downcase]
    end

    # Public: A List of popular languages
    #
    # Popular languages are sorted to the top of language chooser
    # dropdowns.
    #
    # This list is configured in "popular.yml".
    #
    # Returns an Array of Languages.
    def self.popular
      @popular ||= all.select(&:popular?).sort_by { |lang| lang.name.downcase }
    end

    # Public: A List of non-popular languages
    #
    # Unpopular languages appear below popular ones in language
    # chooser dropdowns.
    #
    # This list is created from all the languages not listed in "popular.yml".
    #
    # Returns an Array of Languages.
    def self.unpopular
      @unpopular ||= all.select(&:unpopular?).sort_by { |lang| lang.name.downcase }
    end

    # Public: A List of languages with assigned colors.
    #
    # Returns an Array of Languages.
    def self.colors
      @colors ||= all.select(&:color).sort_by { |lang| lang.name.downcase }
    end

    # Internal: Initialize a new Language
    #
    # attributes - A hash of attributes
    def initialize(attributes = {})
      # @name is required
      @name = attributes[:name] || raise(ArgumentError, "missing name")

      # Set type
      @type = attributes[:type] ? attributes[:type].to_sym : nil
      if @type && !TYPES.include?(@type)
        raise ArgumentError, "invalid type: #{@type}"
      end

      @color = attributes[:color]

      # Set aliases
      @aliases = [default_alias_name] + (attributes[:aliases] || [])

      # Load the TextMate scope name or try to guess one
      @tm_scope = attributes[:tm_scope] || begin
        context = case @type
                  when :data, :markup, :prose
                    'text'
                  when :programming, nil
                    'source'
                  end
        "#{context}.#{@name.downcase}"
      end

      @ace_mode = attributes[:ace_mode]
      @wrap = attributes[:wrap] || false

      # Set legacy search term
      @search_term = attributes[:search_term] || default_alias_name

      # Set extensions or default to [].
      @extensions = attributes[:extensions] || []
      @interpreters = attributes[:interpreters]   || []
      @filenames  = attributes[:filenames]  || []

      # Set popular, and searchable flags
      @popular    = attributes.key?(:popular)    ? attributes[:popular]    : false
      @searchable = attributes.key?(:searchable) ? attributes[:searchable] : true

      # If group name is set, save the name so we can lazy load it later
      if attributes[:group_name]
        @group = nil
        @group_name = attributes[:group_name]

      # Otherwise we can set it to self now
      else
        @group = self
      end
    end

    # Public: Get proper name
    #
    # Examples
    #
    #   # => "Ruby"
    #   # => "Python"
    #   # => "Perl"
    #
    # Returns the name String
    attr_reader :name

    # Public: Get type.
    #
    # Returns a type Symbol or nil.
    attr_reader :type

    # Public: Get color.
    #
    # Returns a hex color String.
    attr_reader :color

    # Public: Get aliases
    #
    # Examples
    #
    #   Language['C++'].aliases
    #   # => ["cpp"]
    #
    # Returns an Array of String names
    attr_reader :aliases

    # Deprecated: Get code search term
    #
    # Examples
    #
    #   # => "ruby"
    #   # => "python"
    #   # => "perl"
    #
    # Returns the name String
    attr_reader :search_term

    # Public: Get the name of a TextMate-compatible scope
    #
    # Returns the scope
    attr_reader :tm_scope

    # Public: Get Ace mode
    #
    # Examples
    #
    #  # => "text"
    #  # => "javascript"
    #  # => "c_cpp"
    #
    # Returns a String name or nil
    attr_reader :ace_mode

    # Public: Should language lines be wrapped
    #
    # Returns true or false
    attr_reader :wrap

    # Public: Get extensions
    #
    # Examples
    #
    #   # => ['.rb', '.rake', ...]
    #
    # Returns the extensions Array
    attr_reader :extensions

    # Public: Get interpreters
    #
    # Examples
    #
    #   # => ['awk', 'gawk', 'mawk' ...]
    #
    # Returns the interpreters Array
    attr_reader :interpreters

    # Public: Get filenames
    #
    # Examples
    #
    #   # => ['Rakefile', ...]
    #
    # Returns the extensions Array
    attr_reader :filenames

    # Deprecated: Get primary extension
    #
    # Defaults to the first extension but can be overridden
    # in the languages.yml.
    #
    # The primary extension can not be nil. Tests should verify this.
    #
    # This method is only used by app/helpers/gists_helper.rb for creating
    # the language dropdown. It really should be using `name` instead.
    # Would like to drop primary extension.
    #
    # Returns the extension String.
    def primary_extension
      extensions.first
    end

    # Public: Get URL escaped name.
    #
    # Examples
    #
    #   "C%23"
    #   "C%2B%2B"
    #   "Common%20Lisp"
    #
    # Returns the escaped String.
    def escaped_name
      EscapeUtils.escape_url(name).gsub('+', '%20')
    end

    # Internal: Get default alias name
    #
    # Returns the alias name String
    def default_alias_name
      name.downcase.gsub(/\s/, '-')
    end

    # Public: Get Language group
    #
    # Returns a Language
    def group
      @group ||= Language.find_by_name(@group_name)
    end

    # Public: Is it popular?
    #
    # Returns true or false
    def popular?
      @popular
    end

    # Public: Is it not popular?
    #
    # Returns true or false
    def unpopular?
      !popular?
    end

    # Public: Is it searchable?
    #
    # Unsearchable languages won't by indexed by solr and won't show
    # up in the code search dropdown.
    #
    # Returns true or false
    def searchable?
      @searchable
    end

    # Public: Return name as String representation
    def to_s
      name
    end

    def ==(other)
      eql?(other)
    end

    def eql?(other)
      equal?(other)
    end

    def hash
      name.hash
    end

    def inspect
      "#<#{self.class} name=#{name} color=#{color}>"
    end
  end

  popular = YAML.load_file(File.expand_path("../popular.yml", __FILE__))

  languages = YAML.load_file(File.expand_path("../languages.yml", __FILE__))

  languages.each do |name, options|
    Language.create(
      :name              => name,
      :color             => options['color'],
      :type              => options['type'],
      :aliases           => options['aliases'],
      :tm_scope          => options['tm_scope'],
      :ace_mode          => options['ace_mode'],
      :wrap              => options['wrap'],
      :group_name        => options['group'],
      :searchable        => options.fetch('searchable', true),
      :search_term       => options['search_term'],
      :popular           => popular.include?(name),
      :extensions        => options['extensions']
    )
  end
end
