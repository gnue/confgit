require 'minitest/autorun'
require 'minitest/spec'

begin
	require 'turn'

	Turn.config.format = :progress
rescue LoadError
end
