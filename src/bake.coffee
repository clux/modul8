fs          = require 'fs'
path        = require 'path'
codeAnalyis = require './codeanalysis'
{compile, exists, cutTests} = require './utils'
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
  # 0. attach libs if we didnt want to split them into a separate file
  if !o.libsOnlyTarget and o.libDir and o.libFiles
    l.push (compile(o.libDir+file) for file in o.libFiles).join('\n') # concatenate lib files as is

  # 1. construct the namespace object
  nsObj = {} # TODO: userLocals
  nsObj[name] = {} for name of o.domains
  nsObj.data = {}
  l.push "var #{ns} = #{JSON.stringify(nsObj)};"

  # 2. pull in data from parsers
  l.push "#{ns}.data.#{name} = #{pullData(pull_fn,name)};" for name, pull_fn of o.data

  # 3. attach require code
  requireConfig =
    namespace : ns
    domains   : name for name of o.domains
    main      : o.mainDomain
  l.push "var requireConfig = #{JSON.stringify(requireConfig)};"
  l.push anonWrap(compile(__dirname + '/require.coffee'))

  # 4. include CommonJS compatible code in the order they have to be defined - wrap each file in a define function for relative requires
  defineWrap = (exportName, domain, code) -> "#{ns}.define('#{exportName}','#{domain}',function(require, module, exports){#{code}});"

  # 4. CommonJS compatible code may include tests inside each file. If it does, remove it.
  tc = if o.localTests then cutTests else (a) -> a

  # 4.a) include non-main CommonJS modules (these should be independent on both the App and the DOM)
  l.push (defineWrap(name.split('.')[0], domain, tc(compile(o.domains[domain] + name))) for [name, domain] in codeList when domain isnt o.mainDomain).join('\n')

  # 4.b) include main CommonJS modules (these will be wait for DOMContentLoaded and and should contain main application code)
  l.push o.DOMLoadWrap((defineWrap(name.split('.')[0], domain, tc(compile(o.domains[domain] + name))) for [name, domain] in codeList when domain is o.mainDomain).join('\n'))

  l.join '\n'

module.exports = (o) ->
  if !o.domains
    throw new Error("brownie needs domains parameter. Got "+JSON.stringify(o.domains))
  o.entryPoint ?= 'main.coffee'
  o.mainDomain ?= 'app'
  if !exists(o.domains[o.mainDomain]+o.entryPoint)
    throw new Error("brownie needs a mainDomain, and the entryPoint to be contained in this domain. Tried: "+o.domains[o.mainDomain]+o.entryPoint)
  if o.domains.data
    throw new Error("brownie reserves the 'data' domain for pulled in code")

  o.namespace ?= 'Brownie'
  o.DOMLoadWrap ?= jQueryWrap

  ca = codeAnalyis(o.entryPoint, o.domains, o.mainDomain, o.localTests)

  if o.target
    o.minifier ?= minify
    throw new Error("brownie requires a function as a minifier") if !o.minifier instanceof Function

    c = bundle(ca.sorted(), o.namespace, o)
    c = o.minifier(c) if o.minify
    fs.writeFileSync(o.target, c)

    if o.libsOnlyTarget and o.libDir and o.libFiles # => libs where not included in above bundle
      libs = (compile(o.libDir+file) for file in o.libFiles).join('\n') # concatenate libs as is
      libs = o.minifier(libs) if o.minifylibs
      fs.writeFileSync(o.libsOnlyTarget, libs)

  if o.treeTarget or o.logTree
    tree = ca.printed(o.extSuffix, o.domPrefix)
    fs.writeFileSync(o.treeTarget, tree) if o.treeTarget
    console.log tree if o.logTree

