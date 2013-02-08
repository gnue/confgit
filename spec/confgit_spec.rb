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
		it "repo"
		it "repo REPO"
		it "repo -d REPO"
		it "repo -D REPO"
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
