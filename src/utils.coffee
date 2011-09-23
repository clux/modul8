# code wrapper helpers
jQueryWrap = (code) ->
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


listToTree = (list) -> # create the object tree from input list of files
  moduleScan = (o, partial) ->
    f = partial[0]
    o[f] = {} if !o[f]?
    return if partial.length is 1
    moduleScan(o[f], partial[1..])
  obj = {}
  moduleScan(obj, file.replace(/\..*/,'').split('/')) for file in list
  obj

module.exports =
  compile     : compile
  cjsWrap     : cjsWrap
  anonWrap    : anonWrap
  jQueryWrap  : jQueryWrap
  listToTree  : listToTree
