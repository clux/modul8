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


compile = (fileName) ->
  switch path.extname(fileName)
    when '.js'
      fs.readFileSync(fileName, 'utf8')
    when '.coffee'
      coffee.compile(fs.readFileSync(fileName, 'utf8'),{bare:true}) # all coffee files must be wrapped later
    else
      throw new Error("file: #{fileName} does not have a valid javascript/coffeescript extension")


listToTree = (list, base) -> # create the object tree from input list of files
  obj = {}
  moduleScan = (o, partial) ->
    f = partial[0]
    o[f] = {} if !o[f]?
    return if partial.length is 1
    moduleScan(o[f], partial[1..])
  for file in list

    file = spl[1] if (spl = file.split(base)).length > 0
    moduleScan(obj, file.replace(/\..*/,'').split('/'))
  obj

module.exports =
  compile     : compile
  cjsWrap     : cjsWrap
  anonWrap    : anonWrap
  jQueryWrap  : jQueryWrap
  listToTree  : listToTree


if module is require.main
  console.log JSON.stringify listToTree(['/home/e/repos/dmjs/app/client/app.coffee', '/home/e/repos/dmjs/app/client/controllers/user.coffee'], '/home/e/repos/dmjs/app/')
