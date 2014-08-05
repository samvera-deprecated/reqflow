# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'reqflow/version'

Gem::Specification.new do |spec|
  spec.name          = "reqflow"
  spec.version       = Reqflow::VERSION
  spec.authors       = ["Michael Klein"]
  spec.email         = ["mbklein@gmail.com"]
  spec.summary       = %q{Simple, self-aware, requirements based workflow manager based on Redis/Resque.}
  spec.description   = %q{Reqflow lets you define workflows based on actions that define their own prerequisites. Actions whose prerequisites are met can be queued in parallel with one another.}
  spec.homepage      = "https://github.com/projecthydra-labs/reqflow"
  spec.license       = "Apache2"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "redis"
  spec.add_dependency "resque"
  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "fakeredis"
end
