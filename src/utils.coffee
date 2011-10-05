path        = require 'path'
fs          = require 'fs'
coffee      = require 'coffee-script'


read = (name) -> fs.readFileSync(name, 'utf8')

# internal compile shortcut
compile = (fileName, bare=true) ->
  switch path.extname(fileName)
    when '.js'
      read(fileName)
    when '.coffee'
      coffee.compile(read(fileName),{bare}) # all coffee files must be wrapped later by default (libs get extra wrapper)
    else
      throw new Error("file: #{fileName} does not have a valid javascript/coffeescript extension")

# simple fs extension to check if a file exists [used to verify require calls' validity]
exists = (file) ->
  try
    fs.statSync(file)
    return true
  catch e
    return false


module.exports =
  compile     : compile
  exists      : exists
  read        : read

