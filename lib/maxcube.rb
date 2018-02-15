require 'date'
require 'pathname'
require 'ipaddr'

require 'pp'

require 'maxcube/version'

module MaxCube
  def self.root_dir
    File.dirname __dir__
  end

  def self.bin_dir
    File.join(root_dir, 'bin')
  end

  def self.lib_dir
    File.join(root_dir, 'lib')
  end

  def self.data_dir
    File.join(root_dir, 'data')
  end
end
