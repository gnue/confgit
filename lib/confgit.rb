require "confgit/version"
require "confgit/repo"
require "confgit/cli"


module Confgit
	def self.run(argv = ARGV, options = {})
		CLI.run(argv, options)
	end
end
