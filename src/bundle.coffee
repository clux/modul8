fs          = require 'fs'
path        = require 'path'
codeAnalyis = require './analysis'
{compile, exists} = require './utils'

# helpers
pullData = (parser, name) -> # parser interface
  throw new Error("modul8::data got a value supplied for #{name} which is not a function") if not parser instanceof Function
  parser()

makeDOMWrap = (ns, jQueryArbiter=false) ->
  location = if jQueryArbiter then ns+".require('M8::jQuery')" else "jQuery"
  (code) ->
    location+'(function(){'+code+'});' # use jQuery to be no-conflict compatible and arbiter compatible

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

  # 1. construct the global namespace object
  l.push "window.#{ns} = {data:{}};"

  # 2. pull in data from parsers
  l.push "#{ns}.data.#{name} = #{pullData(pull_fn,name)};" for name, pull_fn of o.data

  # 3. attach require code
  config =
    namespace : ns
    domains   : name for name of o.domains
    arbiters  : o.arbiters
    main      : o.mainDomain
  l.push "var _modul8RequireConfig = #{JSON.stringify(config)};"
  l.push anonWrap(compile(__dirname + '/require.coffee'))

  # 4. prepare to include CommonJS compatible code in the order they have to be defined - wrap each file in a define function for relative requires
  defineWrap = (exportName, domain, code) -> "#{ns}.define('#{exportName}','#{domain}',function(require, module, exports){#{code}});"

  # 5. Each compiled file result gets passed to (pre-processing) middleware, before the result is definewrapped
  harvest = (domain, onlyThis) ->
    for [name, domain] in codeList when (domain is o.mainDomain) == onlyThis
      code = compile(o.domains[domain] + name)
      basename = name.split('.')[0]
      defineWrap(basename, domain, mw(code)) # middleware applied to code first

  # 6.a) include non-main CommonJS modules (these should be independent on both the App and the DOM)
  l.push harvest(o.mainDomain, false).join('\n')

  # 6.b) include main CommonJS modules (these will be wait for DOMContentLoaded and and should contain main application code)
  l.push domload(harvest(o.mainDomain, true).join('\n'))

  # 7. Use a closure to encapsulate the public and private require/define API as well as all export data
  anonWrap('\n'+l.join('\n')+'\n')


module.exports = (o) ->
  #console.log "from bundle:",o
  if !o.domains
    throw new Error("modul8 requires domains specified. Got "+JSON.stringify(o.domains))
  o.entryPoint ?= 'main.coffee'
  o.mainDomain ?= 'app'
  if !exists(o.domains[o.mainDomain]+o.entryPoint)
    throw new Error("modul8 requires the entryPoint to be contained in the first domain. Could not find: "+o.domains[o.mainDomain]+o.entryPoint)

  if o.domains.data
    throw new Error("modul8 reserves the 'data' domain for pulled in data")
  if o.domains.external
    throw new Error("modul8 reserves the 'external' domain for externally loaded code")
  if o.domains.M8
    throw new Error("modul8 reserves the 'M8' domain for its internal API")

  for fna in o.pre
    throw new Error("modul8 requires a function as pre-processing plugin") if !fna instanceof Function
  for fnb in o.post
    throw new Error("modul8 requires a function as post-processing plugin") if !fnb instanceof Function


  namespace = o.options?.namespace ? 'M8'
  domloader = o.options?.domloader ? makeDOMWrap(namespace, 'jQuery' of o.arbiters)
  premw = if o.pre and o.pre.length > 0 then compose(o.pre) else (a) -> a
  postmw = if o.post and o.post.length > 0 then compose(o.post) else (a) -> (a)

  ca = codeAnalyis(o.entryPoint, o.domains, o.mainDomain, premw, o.arbiters)

  if o.target

    c = bundle(ca.sorted(), namespace, domloader, premw, o)
    c = postmw(c)

    if o.libDir and o.libFiles
      libs = (compile(o.libDir+file, false) for file in o.libFiles).join('\n') # concatenate libs as is - safetywrap any .coffee files
      libs = postmw(libs) #TODO: always apply postmw to libs? it is only a minifier atm..
      if o.libsOnlyTarget
        fs.writeFileSync(o.libsOnlyTarget, libs) #TODO: only write this file if it hasnt changed!!!
      else
        c = libs + c

    fs.writeFileSync(o.target, c)

  if o.treeTarget
    tree = ca.printed(o.extSuffix, o.domPrefix)
    if o.treeTarget instanceof Function
      o.treeTarget(tree)
    else
      fs.writeFileSync(o.treeTarget, tree)

  return
