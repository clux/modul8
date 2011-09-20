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


#This is good, but need define available somewhere on the browser: i can either attach it to app_name.modules, app_name, or window

defineWrap = (code) ->
  'define(function(require, exports, module) {'+code+'});'

compile = (fileName) ->
  switch path.extname(fileName)
    when '.js'
      fs.readFileSync(fileName, 'utf8')
    when '.coffee'
      coffee.compile(fs.readFileSync(fileName, 'utf8'),{bare:true}) # all coffee files must be wrapped later
    else
      throw new Error("file: #{fileName} does not have a valid javascript/coffeescript extension")

pullData = (parser, name) -> # parser interface
  throw new Error("#{name}_parser is not a function") if not parser instanceof Function
  parser()

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
  pullData    : pullData
  cjsWrap     : cjsWrap
  anonWrap    : anonWrap
  jQueryWrap  : jQueryWrap
  listToTree  : listToTree
