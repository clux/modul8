path        = require 'path'
fs          = require 'fs'
coffee      = require 'coffee-script'
# code wrapper helpers
jQueryWrap = (code) ->
  #TODO: this needs a more generic function for handling DOMLoaded fn depending on library
  # If no library, need to write a simple fn here, (it only needs to wrap app code)
  '$(function(){'+code+'});'

anonWrap = (code) ->
  '(function(){'+code+'})();'

cjsWrap = (code, exportLocation) ->
  # So we can attach properties on exports
  start = "var exports = #{exportLocation}, module = {};"
  # If we defined this then we either wanted to define the whole export object at once, or to export a non-object, so overwrite
  end = "if (module.exports) {#{exportLocation} = module.exports;}"
  (start + code + end)

#cjs wrap used to use this, now i dont think i need it anymore
commonjs = (file, baseDir, baseName) ->
  code = compile(baseDir+'/'+file).replace(/\n.*require.main[\w\W]*$/, '')  # ignore the if require.main {} part - CHEAPLY chucks end of file (only solution atm)
  anonWrap(cjsWrap(code, "#{@appName}.#{baseName}.#{file.split(path.extname(file))[0].replace(/\//,'.')}")) # take out extension and replace /->. to find tree


compile = (fileName) ->
  switch path.extname(fileName)
    when '.js'
      fs.readFileSync(fileName, 'utf8')
    when '.coffee'
      coffee.compile(fs.readFileSync(fileName, 'utf8'),{bare:true}) # all coffee files must be wrapped later
    else
      throw new Error("file: #{fileName} does not have a valid javascript/coffeescript extension")

# these two assume people dont mess with Object.prototype
objCount = (obj) ->
  i = 0
  i++ for own key of obj
  i

objFirst = (obj) ->
  return key for key of obj
  return null

# simple fs extension to check if a file exists [used to verify require calls' validity]
exists = (file) ->
  try
    fs.statSync(file)
    return true
  catch e
    return false

module.exports =
  compile     : compile
  objCount    : objCount
  objFirst    : objFirst
  exists      : exists
  cjsWrap     : cjsWrap
  anonWrap    : anonWrap
  jQueryWrap  : jQueryWrap

if module is require.main
  console.log JSON.stringify listToTree(['/home/e/repos/dmjs/app/client/app.coffee', '/home/e/repos/dmjs/app/client/controllers/user.coffee'], '/home/e/repos/dmjs/app/')
