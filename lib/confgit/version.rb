module Confgit
	LONG_VERSION = File.read(File.expand_path('../../../VERSION', __FILE__)).chomp
	VERSION = LONG_VERSION.gsub(/-.*$/, '')
end
