require "confgit/version"
require "confgit/repo"
require "confgit/cli"


module Confgit
	def self.run(argv = ARGV)
		CLI.run(argv)
	end
end
