

Gem::Specification.new do |s|
  s.name = "stl_tool"
  s.version = "0.0.0"
  s.executables << "stl_tool"
  s.default_executable = "stl_tool"

  s.author = "Aeva Palecek"
  s.description = %q{A tool for parsing and analyzing 3D models.}
  s.summary = %q{A tool for parsing and analyzing 3D models.}
  s.files = ["lib/stl_tool.rb", "bin/stl_tool"]
  s.require_paths = ["lib"]
  
  s.license = "LGPLv3"
end
