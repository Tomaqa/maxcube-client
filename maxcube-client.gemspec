
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "maxcube/version"

Gem::Specification.new do |spec|
  spec.name          = "maxcube-client"
  spec.version       = MaxCube::VERSION
  spec.authors       = ["Tomáš Kolárik"]
  spec.email         = ["tomaqa@gmail.com"]

  spec.summary       = %q{Terminal client for eQ3/ELV MAX! Cube devices written in Ruby.}
  spec.homepage      = "https://github.com/Tomaqa/maxcube-client"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.metadata['yard.run'] = 'yard'

  spec.required_ruby_version = '>= 2.2'

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 0.50"
  spec.add_development_dependency "yard", "~> 0.9"
end
