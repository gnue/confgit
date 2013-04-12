# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'confgit/version'

Gem::Specification.new do |gem|
  gem.name          = "confgit"
  gem.version       = Confgit::VERSION
  gem.authors       = ["gnue"]
  gem.email         = ["gnue@so-kukan.com"]
  gem.description   = %q{Config files management tool with git}
  gem.summary       = %q{Config files management tool with git}
  gem.homepage      = "https://github.com/gnue/confgit"

  gem.files         = `git ls-files`.split($/) + %w(REVISION)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.required_ruby_version = '>= 1.9.0'

  # dependency
  gem.add_dependency('i18n')
  gem.add_dependency('json')

  # for development
  gem.add_development_dependency('minitest')
  gem.add_development_dependency('turn')

  gem.post_install_message = %Q{
    ==================
    This software requires 'git'.
    Also optional softwares 'tree' and 'tig'.

    If you are using the bash-completion

      $ cp `gem env gemdir`/gems/confgit-#{gem.version}/etc/bash_completion.d/confgit $BASH_COMPLETION_DIR

    ==================
  }
end
