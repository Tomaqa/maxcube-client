require 'date'
require 'time'
require 'pathname'
require 'ipaddr'

require 'pp'

require 'maxcube/version'

# Root project module that contains only project-related utilities
module MaxCube
  # Gets path to project root directory
  # @return [String] path to project root directory
  def self.root_dir
    File.dirname __dir__
  end

  # Gets path to +bin/+ project directory with executables
  # @return [String] path to +bin/+ project directory
  def self.bin_dir
    File.join(root_dir, 'bin')
  end

  # Gets path to +lib/+ project directory with Ruby source files
  # @return [String] path to +lib/+ project directory
  def self.lib_dir
    File.join(root_dir, 'lib')
  end

  # Gets path to +data/+ project directory
  # with input/output data for clients and servers
  # @return [String] path to +data/+ project directory
  def self.data_dir
    File.join(root_dir, 'data')
  end
end
