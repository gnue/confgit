require File.expand_path('../spec_helper', __FILE__)
require 'confgit'


describe Confgit do
	def confgit(*argv)
		begin
			Confgit.run(argv)
		rescue SystemExit => err
			@abort = err.inspect
		end
	end

	before do
		require 'tmpdir'

		@hostname = `hostname`.chop
		@home = ENV['HOME']
		ENV['HOME'] = @tmpdir = Dir.mktmpdir
	end

	describe "repo" do
		it "repo" do
			out, err = capture_io { confgit 'repo' }
			out.must_equal "* #{@hostname}\n"
		end

		it "repo REPO" do
			name = '_foo_'
			out, err = capture_io {
				confgit 'repo', name
				confgit 'repo'
			}

			out.must_equal <<-EOD.gsub(/^\t+/,'')
				* #{name}
				  #{@hostname}
			EOD
		end

		it "repo -d REPO (not current)" do
			name1 = '_foo_'
			name2 = '_bar_'
			out, err = capture_io {
				confgit 'repo', name1
				confgit 'repo', name2
				confgit 'repo', '-d', name1
				confgit 'repo'
			}

			out.must_equal <<-EOD.gsub(/^\t+/,'')
				* #{name2}
				  #{@hostname}
			EOD
		end

		it "repo -d REPO (current)" do
			name = '_foo_'
			out, err = capture_io {
				confgit 'repo', name
				confgit 'repo', '-d', name
				@abort == "'#{name}' is current repository!\n"
				confgit 'repo'
			}

			out.must_equal <<-EOD.gsub(/^\t+/,'')
				* #{name}
				  #{@hostname}
			EOD
		end

		it "repo -D REPO" do
			name = '_foo_'
			out, err = capture_io {
				confgit 'repo', name
				confgit 'repo', '-D', name
				confgit 'repo'
			}

			out.must_equal "* #{@hostname}\n"
		end
	end

	describe "root" do
		it "root" do
			out, err = capture_io { confgit 'root' }
			out.must_equal "/\n"
		end

		it "root PATH" do
			path = ENV['HOME']

			confgit 'root', path
			out, err = capture_io { confgit 'root' }
			out.must_equal "#{path}\n"
		end

		it "root -d" do
			path = ENV['HOME']

			confgit 'root', path
			confgit 'root', '-d'
			out, err = capture_io { confgit 'root' }
			out.must_equal "/\n"
		end
	end

	describe "add" do
		it "add FILE"
	end

	describe "rm" do
		it "rm FILE"
		it "rm -rf DIR"
	end

	describe "backup" do
		it "backup"
	end

	describe "restore" do
		it "restore"
	end

	describe "git" do
		it "commit -a"
	end

	describe "utilities" do
		it "tree"
		it "tig"
		it "path"
		it "list"
	end

	after do
		FileUtils.remove_entry_secure @tmpdir
		ENV['HOME'] = @home
	end
end
