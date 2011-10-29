path        = require 'path'
fs          = require 'fs'
coffee      = require 'coffee-script'
dir         = fs.realpathSync()

# infer abs domain path and file name from path relative to dir
domainSplit = (relPath) ->
  if path.existsSync(relPath)
    epath = relPath
  else #TODO: this doesnt actually seem necessary
    epath = path.join(dir, relPath)
    if !path.existsSync epath
      throw new Error("modul8: cannot resolve #{relPath} (#{epath})")

  file = relPath.split('/')[-1...][0] # get last element of split
  dom = epath.split(file)[0]
  #a = dom.split('/')
  #a.pop() if a[a.length-1] is '' # appdom may end in a slash causing this to be empty
  #name = a[a.length-1]
  [dom, file]

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
    stat = fs.statSync(file)
    return not stat.isDirectory()
  catch e
    return false


module.exports = {
  makeCompiler
  exists
  read
  domainSplit
}
