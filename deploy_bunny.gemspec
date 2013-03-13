Gem::Specification.new do |gem|
  gem.authors       = ["Taras Kunch"]
  gem.email         = ["tkunch@rebbix.com"]

  description       = %q{Set of capistrano recipes to deploy different applications.}
  gem.description   = description
  gem.summary       = description

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.name          = "deploy_bunny"
  gem.version       = '0.0.1'

  gem.add_dependency("capistrano")
end
