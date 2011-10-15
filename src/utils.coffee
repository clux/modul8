path        = require 'path'
fs          = require 'fs'
coffee      = require 'coffee-script'


# fs shortcut
read = (name) -> fs.readFileSync(name, 'utf8')

# compile factory
makeCompiler = (external={}) ->
  # sanity
  for key,fn of external
    if key in ['','.js','.coffee']
      throw new Error("modul8: cannot re-register #{key} extension")
    if !(fn instanceof Function) or !(fn("").constructor is String)
      throw new Error("modul8: registered compiler must be a fn returning a string")

  (file, bare=true) ->
    ext = path.extname(file)
    raw = read(file)
    return raw if ext is '.js'
    return coffee.compile(raw, {bare}) if ext is '.coffee'
    return fn(raw, bare) for key,fn of external when key is ext # compile to js languages must take two params, read input and bare bool - bare only if safety wrapping done by default
    throw new Error("modul8: requested file #{file} does not have a valid javascript, coffeescript or externally registered extension")


# simple fs extension to check if a file exists [used to verify require calls' validity]
exists = (file) ->
  try
    fs.statSync(file)
    return true
  catch e
    return false


module.exports = {
  makeCompiler
  exists
  read
}
