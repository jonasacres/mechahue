require 'json'
require 'rest-client'

dir = File.dirname(__FILE__)
manual = [
  "hub.rb",
  "resources/resource.rb",
  "updates/update.rb"
].map { |p| File.join(dir, p) }
manual.each { |lib| require lib }

Dir.glob(File.join(dir, "*.rb")).sort.each do |lib|
  require lib
end

all_scripts = Dir
  .glob(File.join(dir, "**/*.rb"))
  .sort

all_scripts.each do |lib|
  require lib
end
