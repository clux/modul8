fs          = require 'fs'
path        = require 'path'
codeAnalyis = require './analysis'
{compile, exists} = require './utils'

# helpers
pullData = (parser, name) -> # parser interface
  throw new Error("modul8::data got a value supplied for #{name} which is not a function") if not parser instanceof Function
  parser()

jQueryWrap = (code) -> # default domloader
  '$(function(){'+code+'});'

anonWrap = (code) ->
  '(function(){'+code+'})();'


compose = (funcs) ->
 ->
    args = [].slice.call(arguments)
    for i in [funcs.length-1..0]
      fn = funcs[i]
      if !fn instanceof Function
        throw new Error("modul8::middeware must consist of functions got: #{fn}")
      args = [fn.apply(@, args)]
    args[0]

bundle = (codeList, ns, domload, mw, o) ->
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

  # 4. Each compiled file result gets passed to (pre-processing) middleware, before the result is definewrapped
  harvest = (domain, onlyThis) ->
    for [name, domain] in codeList when (domain is o.mainDomain) == onlyThis
      code = compile(o.domains[domain] + name)
      basename = name.split('.')[0]
      defineWrap(basename, domain, mw(code))

  # 4.a) include non-main CommonJS modules (these should be independent on both the App and the DOM)
  l.push harvest(o.mainDomain, false).join('\n')

  # 4.b) include main CommonJS modules (these will be wait for DOMContentLoaded and and should contain main application code)
  l.push domload(harvest(o.mainDomain, true).join('\n'))

  l.join '\n'


module.exports = (o) ->
  #console.log "from bundle:",o
  if !o.domains
    throw new Error("modul8 requires domains specified. Got "+JSON.stringify(o.domains))
  o.entryPoint ?= 'main.coffee'
  o.mainDomain ?= 'app'
  if !exists(o.domains[o.mainDomain]+o.entryPoint)
    throw new Error("modul8 requires the entryPoint to be contained in the first domain. Could not find: "+o.domains[o.mainDomain]+o.entryPoint)
  if o.domains.data
    throw new Error("modul8 reserves the 'data' domain for pulled in code")

  for fna in o.pre
    throw new Error("modul8 requires a function as pre-processing plugin") if !fna instanceof Function
  for fnb in o.post
    throw new Error("modul8 requires a function as post-processing plugin") if !fnb instanceof Function

  namespace = o.options?.namespace ? 'M8'
  domloader = o.options?.domloader ? jQueryWrap
  premw = if o.pre then compose(o.pre) else (a) -> a
  postmw = if o.post then compose(o.post) else (a) -> (a)

  ca = codeAnalyis(o.entryPoint, o.domains, o.mainDomain, premw)

  if o.target

    c = bundle(ca.sorted(), namespace, domloader, premw, o)
    c = postmw(c)
    fs.writeFileSync(o.target, c)

    if o.libsOnlyTarget and o.libDir and o.libFiles # => libs where not included in above bundle
      #TODO: only write this file if it hasnt changed!!!
      libs = (compile(o.libDir+file, false) for file in o.libFiles).join('\n') # concatenate libs as is - safetywrap .coffee files
      libs = postmw(c)
      fs.writeFileSync(o.libsOnlyTarget, libs)

  if o.treeTarget
    tree = ca.printed(o.extSuffix, o.domPrefix)
    if o.treeTarget instanceof Function
      o.treeTarget(tree)
    else
      fs.writeFileSync(o.treeTarget, tree) if o.treeTarget

  return
