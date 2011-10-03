path        = require 'path'
fs          = require 'fs'
coffee      = require 'coffee-script'


read = (name) -> fs.readFileSync(name, 'utf8')

# internal compile shortcut
compile = (fileName) ->
  switch path.extname(fileName)
    when '.js'
      read(fileName)
    when '.coffee'
      coffee.compile(read(fileName),{bare:true}) # all coffee files must be wrapped later
    else
      throw new Error("file: #{fileName} does not have a valid javascript/coffeescript extension")

# simple fs extension to check if a file exists [used to verify require calls' validity]
exists = (file) ->
  try
    fs.statSync(file)
    return true
  catch e
    return false


# avoids pulling in test dependencies and test code
cutTests = (code) ->
  #TODO:? this can eventually use burrito if popular, but for now this is fine.
  code.replace(/\n.*require.main[\w\W]*$/, '')


module.exports =
  compile     : compile
  exists      : exists
  cutTests    : cutTests
  read        : read

