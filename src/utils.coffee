path        = require 'path'
fs          = require 'fs'
coffee      = require 'coffee-script'


# fs shortcut
read = (name) -> fs.readFileSync(name, 'utf8')

# internal compile shortcut
compile = (file, bare=true) ->
  switch path.extname(file)
    when '.js'
      read(file)
    when '.coffee'
      coffee.compile(read(file),{bare}) # all coffee files that eludes M8.define must get the standard safety wrapper to encapsulate private variables
    else
      throw new Error("file: #{file} does not have a valid javascript/coffeescript extension")

# simple fs extension to check if a file exists [used to verify require calls' validity]
exists = (file) ->
  try
    fs.statSync(file)
    return true
  catch e
    return false


module.exports = {
  compile
  exists
  read
}
