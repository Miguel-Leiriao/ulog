# ulog.gemspec
require_relative "lib/ulog/version"

Gem::Specification.new do |s|
  s.name        = "ulog"
  s.version     = Ulog::VERSION
  s.summary     = "Compact, uniform and tamper-evident logging system"
  s.description = "Ulog is a lightweight and standardized logging toolkit."
  s.authors     = ["Miguel Leirião"]
  s.email       = ["59800862+Miguel-Leiriao@users.noreply.github.com"]
  s.files       = Dir["lib/**/*", "bin/*", "README.md", "LICENSE"]
  s.bindir      = "bin"
  s.executables = ["ulog"]
  s.license     = "MIT"
  s.required_ruby_version = ">= 3.0"
end
