require 'minitest/autorun'
require 'minitest/spec'

puts nil, "=== TOOLS"
system %q(git --version)
system %q(tree --version)
puts "===", nil

begin
	require 'turn'

	Turn.config.format = :progress
rescue LoadError
end
