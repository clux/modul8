fs          = require 'fs'
path        = require 'path'
codeAnalyis = require './analysis'
{compile, exists} = require './utils'

# helpers
pullData = (parser, name) -> # parser interface
  throw new Error("modul8::data got a value supplied for #{name} which is not a function") if not parser instanceof Function
  parser()

jQueryWrap = (code) -> # default DOMLoadWrap
  '$(function(){'+code+'});'

anonWrap = (code) ->
  '(function(){'+code+'})();'


compose = (funcs) ->
 ->
    args = [].slice.call(arguments)
    for fn in [funcs.length-1..0]
      args = [fn.apply(@, args)]
    args[0]

bundle = (codeList, ns, o) ->
  l = []
  # 0. attach libs if we didnt want to split them into a separate file
  if !o.libsOnlyTarget and o.libDir and o.libFiles
    l.push (compile(o.libDir+file,false) for file in o.libFiles).join('\n') # concatenate lib files as is - safetywrap .coffee files

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

  # 4. Apply all pre-processing middleware here
  mw = if o.pre then compose(o.pre) else (a) -> a

  # 4.a) include non-main CommonJS modules (these should be independent on both the App and the DOM)
  l.push (defineWrap(name.split('.')[0], domain, mw(compile(o.domains[domain] + name))) for [name, domain] in codeList when domain isnt o.mainDomain).join('\n')

  # 4.b) include main CommonJS modules (these will be wait for DOMContentLoaded and and should contain main application code)
  l.push o.DOMLoadWrap((defineWrap(name.split('.')[0], domain, mw(compile(o.domains[domain] + name))) for [name, domain] in codeList when domain is o.mainDomain).join('\n'))

  l.join '\n'

module.exports = (o) ->
  if !o.domains
    throw new Error("modul8 requires domains specified. Got "+JSON.stringify(o.domains))
  o.entryPoint ?= 'main.coffee'
  o.mainDomain ?= 'app'
  if !exists(o.domains[o.mainDomain]+o.entryPoint)
    throw new Error("modul8 requires the entryPoint to be contained in the first domain. Could not find: "+o.domains[o.mainDomain]+o.entryPoint)
  if o.domains.data
    throw new Error("modul8 reserves the 'data' domain for pulled in code")

  o.namespace ?= 'M8'
  o.DOMLoadWrap ?= jQueryWrap

  ca = codeAnalyis(o.entryPoint, o.domains, o.mainDomain, o.localTests)

  if o.target
    o.minifier ?= minify
    throw new Error("modul8 requires a function as a minifier") if !o.minifier instanceof Function

    c = bundle(ca.sorted(), o.namespace, o)
    mw = if o.post then compose(o.post) else (a) -> (a)
    c = mw(c)
    fs.writeFileSync(o.target, c)

    if o.libsOnlyTarget and o.libDir and o.libFiles # => libs where not included in above bundle
      #TODO: only write this file if it hasnt changed!!!
      libs = (compile(o.libDir+file, false) for file in o.libFiles).join('\n') # concatenate libs as is - safetywrap .coffee files
      libs = mw(c)
      fs.writeFileSync(o.libsOnlyTarget, libs)

  if o.treeTarget or o.logTree
    tree = ca.printed(o.extSuffix, o.domPrefix)
    fs.writeFileSync(o.treeTarget, tree) if o.treeTarget
    console.log tree if o.logTree

  return
