_           = require 'underscore'
fs          = require 'fs'
path        = require 'path'
codeAnalyis = require './analysis'
{makeCompiler, exists, read} = require './utils'

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


collisionCheck = (codeList) ->
  for [dom, file] in codeList
    uid = dom+'::'+file.split('.')[0]
    for [d,f] in codeList when (dom isnt d and file isnt f)
      uidi = d+'::'+f.split('.')[0]
      if uid is uidi
        throw new Error("modul8: does not support requiring of two files of the same name on the same path with different extensions: #{dom}::#{file} and #{d}::{#f} ")
  return

# main packager
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
    logging   : !!o.options.logging
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
  forceUpdate = mustCompile(o.target, o)

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
    throw new Error("modul8 requires a function as pre-processing plugin") if !_.isFunction(fna)
  for fnb in o.post
    throw new Error("modul8 requires a function as post-processing plugin") if !_.isFunction(fnb)

  namespace = o.options?.namespace ? 'M8'
  domloader = o.options?.domloader ? makeDOMWrap(namespace, 'jQuery' of o.arbiters)
  premw = if o.pre.length > 0 then _.compose.apply({}, o.pre) else _.identity
  postmw = if o.post.length > 0 then _.compose.apply({}, o.post) else _.identity
  useLog = o.options.logging and !_.isFunction(o.target) # dont log if we output result to console.log for instance

  compile = makeCompiler(o.compilers) # will throw if reusing extensions or invalid compile functions
  exts = ['','.js','.coffee'].concat(ext for ext of o.compilers)
  ca = codeAnalyis(o.entryPoint, o.domains, o.mainDomain, premw, o.arbiters, compile, exts, o.ignoreDoms ? [])


  if o.treeTarget # do tree before collisionCheck (so that we can identify what triggers collision)
    tree = ca.printed(o.extSuffix, o.domPrefix)
    if _.isFunction(o.treeTarget)
      o.treeTarget(tree)
    else
      fs.writeFileSync(o.treeTarget, tree)

  if o.target
    codelist = ca.sorted()
    collisionCheck(codelist)

    mTimesApp = {}
    for [domain,file] in codelist
      mTimesApp[domain+'::'+file] = fs.statSync(o.domains[domain]+file).mtime.valueOf()

    appUpdated = mTimeCheck(o.target, mTimesApp, 'app', useLog)

    c = bundle(codelist, namespace, domloader, premw, compile, o)
    c = postmw(c)

    return o.target(c) if _.isFunction(o.target) # pipe output to fn without libs for now

    if o.libDir and o.libFiles

      mTimesLibs = {}
      for file in o.libFiles
        mTimesLibs[file] = fs.statSync(o.libDir+file).mtime.valueOf()

      libsUpdated = mTimeCheck(o.libsOnlyTarget, mTimesLibs, if o.libsOnlyTarget then 'libs' else 'app', useLog)

      if libsUpdated or (appUpdated and !o.libsOnlyTarget) or forceUpdate
        # necessary to do this work if libs changed
        # but also if app changed and we write it to the same file
        libs = (compile(o.libDir+file, false) for file in o.libFiles).join('\n') # concatenate libs as is - safetywrap any .coffee files
        libs = postmw(libs)

      if o.libsOnlyTarget and libsUpdated
        fs.writeFileSync(o.libsOnlyTarget, libs)
        libsUpdated = false # no need to take this state into account anymore since they are written separately
      else if !o.libsOnlyTarget
        c = libs + c
    else
      libsUpdated = false # no need to take lib state into account anymore since they dont exist

    if libsUpdated or appUpdated or forceUpdate
      # write target if there were any changes relevant to this file
      fs.writeFileSync(o.target, c)
      #console.log 'writing app! bools: libsUp='+libsUpdated+', appUp='+appUpdated+', force='+forceUpdate

  return

mustCompile = (file, o) ->
  return true if !file or _.isFunction(file)
  tempName = path.basename(file).split(path.extname(file))[0]
  cfgStorage = __dirname+'/../states/'+tempName+'_cfg.json'
  cfg = if exists(cfgStorage) then JSON.parse(read(cfgStorage)) else {}
  return false if _.isEqual(cfg, JSON.parse(JSON.stringify(o))) #o must to mimic parse/stringify movement to pass
  fs.writeFileSync(cfgStorage, JSON.stringify(o))
  true

mTimeCheck = (file, mTimes, type, log) ->
  return if file instanceof Function
  tempName = path.basename(file).split(path.extname(file))[0]
  mStorage = __dirname+'/../states/'+type+'_'+tempName+'.json'
  mTimesOld = if exists(mStorage) then JSON.parse(read(mStorage)) else {}

  fs.writeFileSync(mStorage, JSON.stringify(mTimes)) # update state
  mTimesUpdated(mTimes, mTimesOld, type, log)

mTimesUpdated = (mTimes, mTimesOld, type, log) ->
  for file,mtime of mTimes
    if !(file of mTimesOld)
      console.log "compiling #{type}: file(s) added" if log
      return true
    if mTimesOld[file] isnt mtime
      console.log "compiling #{type}: file(s) modified" if log
      return true
  for file of mTimesOld
    if !(file of mTimes)
      console.log "compiling #{type}: file(s) removed" if log
      return true
  false
