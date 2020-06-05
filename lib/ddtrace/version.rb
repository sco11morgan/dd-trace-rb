module Datadog
  module VERSION
    MAJOR = 0
    MINOR = 42
    PATCH = 0
    PRE = 'qless'

    STRING = [MAJOR, MINOR, PATCH, PRE].compact.join('.')

    MINIMUM_RUBY_VERSION = '2.0.0'.freeze
  end
end
