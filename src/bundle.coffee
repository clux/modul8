fs          = require 'fs'
path        = require 'path'
codeAnalyis = require './analysis'
{makeCompiler, exists} = require './utils'

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
      if !(fn instanceof Function)
        throw new Error("modul8::middeware must consist of functions got: #{fn}")
      args = [fn.apply(@, args)]
    args[0]

collisionCheck = (codeList) ->
  for [dom, file] in codeList
    uid = dom+'::'+file.split('.')[0]
    for [d,f] in codeList when (dom isnt d and file isnt f)
      uidi = d+'::'+f.split('.')[0]
      if uid is uidi
        throw new Error("modul8: too dangerous to require two files of the same name on the same path with different extensions: #{dom}::#{file} and #{d}::{#f} ")

  return

bundle = (codeList, ns, domload, mw, compile, o) ->
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
    logging   : o.logging ? false
    main      : o.mainDomain
  l.push "var _modul8RequireConfig = #{JSON.stringify(config)};"
  l.push anonWrap(compile(__dirname + '/require.coffee'))

  # 4. include CommonJS compatible code in the order they have to be defined - defineWrap each module
  defineWrap = (exportName, domain, code) ->
    "#{ns}.define('#{exportName}','#{domain}',function(require, module, exports){#{code}});"

  # 5. filter function split code into app code and non-app code
  harvest = (onlyMain) ->
    for [domain, name] in codeList when (domain is o.mainDomain) == onlyMain
      code = mw(compile(o.domains[domain] + name)) # middleware applied to code first
      basename = name.split('.')[0] # take out extension on the client (we throw if collisions requires have happened on the server)
      defineWrap(basename, domain, code)

  # 6.a) include modules not on the app domain
  l.push harvest(false).join('\n')

  # 6.b) include modules on the app domain, and hold off execution till DOMContentLoaded fires
  l.push domload(harvest(true).join('\n'))

  # 7. Use a closure to encapsulate the public and private require/define API as well as all export data
  anonWrap('\n'+l.join('\n')+'\n')


module.exports = (o) ->
  if !o.domains
    throw new Error("modul8 requires domains specified. Got "+JSON.stringify(o.domains))
  o.entryPoint ?= 'main.coffee'
  o.mainDomain ?= 'app'
  entry = o.domains[o.mainDomain] + o.entryPoint
  if !exists(entry)
    throw new Error("modul8 requires the entryPoint to be contained in the first domain. Could not find: "+entry)

  if o.domains.data
    throw new Error("modul8 reserves the 'data' domain for pulled in data")
  if o.domains.external
    throw new Error("modul8 reserves the 'external' domain for externally loaded code")
  if o.domains.M8
    throw new Error("modul8 reserves the 'M8' domain for its internal API")

  for fna in o.pre
    throw new Error("modul8 requires a function as pre-processing plugin") if !(fna instanceof Function)
  for fnb in o.post
    throw new Error("modul8 requires a function as post-processing plugin") if !(fnb instanceof Function)


  namespace = o.options?.namespace ? 'M8'
  domloader = o.options?.domloader ? makeDOMWrap(namespace, 'jQuery' of o.arbiters)
  premw = if o.pre and o.pre.length > 0 then compose(o.pre) else (a) -> a
  postmw = if o.post and o.post.length > 0 then compose(o.post) else (a) -> (a)

  compile = makeCompiler(o.compilers) # will throw if reusing extensions or invalid compile functions
  exts = (ext for ext of o.compilers).concat(['','.js','.coffee'])
  ca = codeAnalyis(o.entryPoint, o.domains, o.mainDomain, premw, o.arbiters, compile, exts, o.ignoreDoms ? [])

  if o.treeTarget # do tree before collisionCheck (so that we can identify what triggers collision)
    tree = ca.printed(o.extSuffix, o.domPrefix)
    if o.treeTarget instanceof Function
      o.treeTarget(tree)
    else
      fs.writeFileSync(o.treeTarget, tree)

  if o.target
    codelist = ca.sorted()
    collisionCheck(codelist)

    c = bundle(codelist, namespace, domloader, premw, compile, o)
    c = postmw(c)

    if o.libDir and o.libFiles
      libs = (compile(o.libDir+file, false) for file in o.libFiles).join('\n') # concatenate libs as is - safetywrap any .coffee files
      libs = postmw(libs) #TODO: always apply postmw to libs? it is only a minifier atm..
      if o.libsOnlyTarget
        fs.writeFileSync(o.libsOnlyTarget, libs) #TODO: only write this file if it hasnt changed!!!
      else
        c = libs + c

    fs.writeFileSync(o.target, c)

  return
