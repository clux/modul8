_           = require 'underscore'
fs          = require 'fs'
crypto      = require 'crypto'
path        = require 'path'
codeAnalyis = require './analysis'
{makeCompiler, exists, read} = require './utils'

# helpers
anonWrap = (code) ->
  '(function(){'+code+'})();'

makeWrapper = (ns, fnstr, hasArbiter) ->
  location = if hasArbiter then ns+".require('M8::#{fnstr}')" else fnstr
  selfexec = if !fnstr then '()' else '' # if fnstr is '' or was false'd -> we use a self executing anon fn
  (code) -> location+'(function(){'+code+'})'+selfexec+';'

# creates a unique filename to use for the serializers
# uniqueness based on execution path, target.js and targetlibs.js - should be sufficient
makeGuid = (vals) ->
  vals.push fs.realpathSync()
  str = (v+'' for v in vals).join('_')
  crypto.createHash('md5').update(str).digest("hex")

# analyzer will find files of specified ext, but these may clash on client
verifyCollisionFree = (codeList) ->
  for [dom, file] in codeList
    uid = dom+'::'+file.split('.')[0]
    for [d,f] in codeList when (dom isnt d and file isnt f) # dont check self
      uidi = d+'::'+f.split('.')[0]
      if uid is uidi
        throw new Error("modul8: does not support requiring of two files of the same name on the same path with different extensions: #{dom}::#{file} and #{d}::{#f} ")
  return

logLevels =
  error   : 1
  warn    : 2
  info    : 3
  debug   : 4

# checks whether serialized options object corresponds to the one we passed in
isOptionsChanged = (guid, o, log) ->
  cfgStorage = __dirname+'/../states/'+guid+'_cfg.json'
  cfg = if exists(cfgStorage) then JSON.parse(read(cfgStorage)) else {}
  return false if _.isEqual(cfg, JSON.parse(JSON.stringify(o))) #o must to mimic parse/stringify movement to pass
  fs.writeFileSync(cfgStorage, JSON.stringify(o))
  console.log 'modul8: updated settings - recompiling' if !_.isEqual(cfg, {}) and log
  true

# checks mTimes for a list of [dom, file] where dom is in domains
mTimeCheck = (guid, fileList, doms, type, log) ->
  mTimes = {}
  mTimes[d+'::'+f] = fs.statSync(doms[d]+f).mtime.valueOf() for [d, f] in fileList
  mStorage = __dirname+'/../states/'+guid+'_'+type+'.json'
  mTimesOld = if exists(mStorage) then JSON.parse(read(mStorage)) else {}

  fs.writeFileSync(mStorage, JSON.stringify(mTimes)) # update state
  if _.isEqual(mTimesOld, {})
    console.log 'modul8: first compile of '+type if log
    return true
  mTimesUpdated(mTimes, mTimesOld, type, log)

# returns whether the serialized mTimes object is out of date
mTimesUpdated = (mTimes, mTimesOld, type, log) ->
  for file,mtime of mTimes
    if !(file of mTimesOld)
      console.log 'modul8: files added to '+type if log
      return true
    if mTimesOld[file] isnt mtime
      console.log 'modul8: files updated in '+type if log
      return true
  for file of mTimesOld
    if !(file of mTimes)
      console.log 'modul8: files removed from '+type if log
      return true
  false


# main packager
bundleApp = (codeList, ns, domload, compile, o) ->
  l = []

  # 1. construct the global namespace object
  l.push "window.#{ns} = {data:{}};"

  # 2. pull in data from parsers (force result to string if it isnt already)
  l.push "#{ns}.data.#{name} = #{pull_fn()};" for name, pull_fn of o.data

  # 3. attach require code
  config =
    namespace : ns
    domains   : name for name of o.domains
    arbiters  : o.arbiters
    logging   : logLevels[(o.options.logging+'').toLowerCase()] ? 0

  l.push anonWrap( read(__dirname+'/require.js')
    .replace(/__VERSION__/, JSON.parse(read(__dirname+'/../package.json')).version)
    .replace(/__REQUIRECONFIG__/, JSON.stringify(config))
  )

  # 4. include CommonJS compatible code in the order they have to be defined - defineWrap each module
  defineWrap = (exportName, domain, code) ->
    "#{ns}.define('#{exportName}','#{domain}',function(require, module, exports){#{code}});"

  # 5. filter function split code into app code and non-app code
  harvest = (onlyMain) ->
    for [domain, name] in codeList when (domain is 'app') == onlyMain
      code = o.before(compile(o.domains[domain] + name)) # middleware applied to code first
      basename = name.split('.')[0] # take out extension on the client (we throw if collisions requires have happened on the server)
      defineWrap(basename, domain, code)


  # 6.a) include modules not on the app domain
  l.push harvest(false).join('\n')

  # 6.b) include modules on the app domain, and hold off execution till DOMContentLoaded fires
  l.push domload(harvest(true).join('\n'))

  # 7. Use a closure to encapsulate the public and private require/define API as well as all export data
  anonWrap('\n'+l.join('\n')+'\n')


module.exports = (o) ->
  guid = makeGuid([o.target, o.libsOnlyTarget])
  forceUpdate = isOptionsChanged(guid, o) or o.options.force # force option (using CLI)

  ns = o.options.namespace ? 'M8'

  domloader = _dl = o.options.domloader
  domloader = makeWrapper(ns, _dl or '', (_dl or '') of o.arbiters) if !_dl or !_.isFunction(_dl) # force into string if not a fn

  o.before = if o.pre.length > 0 then _.compose.apply({}, o.pre) else _.identity
  o.after = if o.post.length > 0 then _.compose.apply({}, o.post) else _.identity

  compile = makeCompiler(o.compilers) # will throw if reusing extensions or invalid compile functions
  o.exts = ['','.js','.coffee'].concat(ext for ext of o.compilers)

  ca = codeAnalyis(o, compile)

  if o.treeTarget # do tree before collisionCheck (so that we can identify what triggers collision) + works better with CLI
    tree = ca.printed(o.extSuffix, o.domPrefix)
    if _.isFunction(o.treeTarget)
      o.treeTarget(tree)
    else
      fs.writeFileSync(o.treeTarget, tree)

  if o.target
    codelist = ca.sorted()
    verifyCollisionFree(codelist)

    useLog = o.options.logging and !_.isFunction(o.target) # dont log anything from server if we output result to console
    level = logLevels[(o.options.logging+'').toLowerCase()] ? 0

    appUpdated = mTimeCheck(guid, codelist, o.domains, 'app', useLog and level >= 4)

    c = bundleApp(codelist, ns, domloader, compile, o)
    c = o.after(c)

    return o.target(c) if _.isFunction(o.target) # pipe output to fn without libs for now

    if o.libDir and o.libFiles

      libsUpdated = mTimeCheck(guid, (['libs', f] for f in o.libFiles), {libs: o.libDir}, 'libs', useLog and level >= 4)

      if libsUpdated or (appUpdated and !o.libsOnlyTarget) or forceUpdate
        # necessary to do this work if libs changed
        # but also if app changed and we write it to the same file
        libs = (compile(o.libDir+file, false) for file in o.libFiles).join('\n') # concatenate libs as is - safetywrap any .coffee files
        libs = o.after(libs)

      if o.libsOnlyTarget and libsUpdated
        fs.writeFileSync(o.libsOnlyTarget, libs)
        console.warn 'modul8: compiling separate libs' if useLog and level >= 2
        libsUpdated = false # no need to take this state into account anymore since they are written separately
      else if !o.libsOnlyTarget
        c = libs + c
    else
      libsUpdated = false # no need to take lib state into account anymore since they dont exist

    if appUpdated or (libsUpdated and !o.libsOnlyTarget) or forceUpdate
      # write target if there were any changes relevant to this file
      console.warn 'modul8: compiling' if useLog and level >= 2
      fs.writeFileSync(o.target, c)
      #console.log 'writing app! bools: libsUp='+libsUpdated+', appUp='+appUpdated+', force='+forceUpdate

  return
