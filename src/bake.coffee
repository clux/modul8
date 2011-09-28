fs          = require 'fs'
path        = require 'path'
codeAnalyis = require './codeanalysis'
{compile, exists} = require './utils'
{uglify, parser} = require 'uglify-js'

# helpers
pullData = (parser, name) -> # parser interface
  throw new Error("parser for #{name} is not a function") if not parser instanceof Function
  parser()

minify = (code) -> # minify function, this can potentially also be passed in if we require alternative compilers..
  uglify.gen_code(uglify.ast_squeeze(uglify.ast_mangle(parser.parse(code))))

jQueryWrap = (code) -> # default DOMLoadWrap
  '$(function(){'+code+'});'

anonWrap = (code) ->
  '(function(){'+code+'})();'

# IF we call them SpineAjax we must require SpineAjax
# IF we call them Spine.Ajax we must require Spine.Ajax (which may lead people to believe we can require Spine and reference Spine.Ajax which simply isnt true)
# SOLN: either:
#   1. include them in order as libraries and add an arbiter for the whole of spine (since we technically use it as one)
#   2. explicitly require submodules of spine at the same time as spine was required => order gets correct
# 2. however comes with the problem of having these spine submodules having a particular name!

bundle = (codeList, ns, o) ->
  l = []
  d = o.domains
  # 0. attach libs if we didnt want to split them into a separate file
  if !o.libsOnlyTarget and o.libDir and o.libFiles
    l.push (compile(o.libDir+file) for file in o.libFiles).join('\n') # concatenate lib files as is

  # 1. construct the namespace object
  nsObj = {} # TODO: userLocals
  nsObj[name] = {} for [name, path] in o.domains
  nsObj.data = {}
  l.push "var #{ns} = #{JSON.stringify(nsObj)};"

  # 2. pull in data from parsers
  l.push "#{ns}.data.#{name} = #{pullData(pull_fn,name)};" for name, pull_fn of o.data

  # 3. attach require code
  requireConfig =
    namespace : ns
    domains   : dom for [dom, path] in o.domains
    fallback  : o.fallBackFn # if our require fails, give a name to a globally defined fn here that
  l.push "var requireConfig = #{JSON.stringify(requireConfig)};"
  l.push anonWrap(compile(__dirname + '/require.coffee'))

  # 4. include CommonJS compatible code in the order they have to be defined - wrap each file in a define function for relative requires
  defineWrap = (exportName, domain, code) -> "#{ns}.define('#{exportName}','#{domain}',function(require, module, exports){#{code}});"
  domMap = {}
  domMap[name] = path for [name,path] in o.domains

  # 4.a) include non-client CommonJS modules (these should be independant on the App and the DOM)
  l.push (defineWrap(name, domain, compile(domMap[domain] + name)) for [name, domain] in codeList when domain isnt 'client').join('\n')

  # 4.b) include compiled files from codeList in correct order
  l.push o.DOMLoadWrap((defineWrap(name, 'client', compile(domMap.client + name)) for [name, domain] in codeList when domain is 'client').join('\n'))


  l.join '\n'

module.exports = (o) ->
  if !o.domains
    throw new Error("brownie needs valid basePoint and domains. Got "+JSON.stringify(o.domains))
  o.basePoint ?= 'app.coffee'
  clientDom = path for [name, path] in o.domains when name is 'client'
  if !o.domains.length > 0 or !exists(clientDom+o.basePoint)
    throw new Error("brownie needs a client domain, and the basePoint to be contained in the client domain. Tried: "+clientDom+o.basePoint)
  hasData = false
  for [name,path] in o.domains when name is 'data'
    hasData = true
    break
  if hasData
    throw new Error("brownie reserves the 'data' domain for pulled in code")

  o.namespace ?= 'Brownie'
  o.DOMLoadWrap ?= jQueryWrap

  ca = codeAnalyis(o.basePoint, o.domains, o.localTests)

  if o.target
    c = bundle(ca.sorted(), o.namespace, o)
    if o.minify
      if o.minifier
        throw new Error("brownie requires a function as a minifier") if !o.minifier instanceof Function
        c = o.minifier(c)
      else
        c = minify(c)
    fs.writeFileSync(o.target, c)

    if o.libsOnlyTarget and o.libDir and o.libFiles # => libs where not included in above bundle
      libs = (compile(o.libDir+file) for file in o.libFiles).join('\n') # concatenate libs as is
      libs = minify(libs) if o.minifylibs
      fs.writeFileSync(o.libsOnlyTarget, libs)

  if o.treeTarget or o.logTree
    tree = ca.printed(o.extSuffix, o.domPrefix)
    fs.writeFileSync(o.treeTarget, tree) if o.treeTarget
    console.log tree if o.logTree

