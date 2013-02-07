require "confgit/version"
require "confgit/confgit"


module Confgit
	def self.run(argv = ARGV)
		Repo.run(argv)
	end
end
