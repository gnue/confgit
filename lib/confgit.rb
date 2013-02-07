require "confgit/version"
require "confgit/confgit"


module Confgit
	def self.run(argv = ARGV)
		CLI.run(argv)
	end
end
