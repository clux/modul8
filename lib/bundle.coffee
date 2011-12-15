_           = require 'underscore'
fs          = require 'fs'
path        = require 'path'
codeAnalyis = require './analysis'
Persister   = require './persist'
type        = require('./type')
logule      = require 'logule'
join        = path.join
dir         = __dirname
{makeCompiler, exists, read, error} = require './utils'

noop = (a) -> a

# helpers
anonWrap = (code) ->
  "(function(){\n#{code}\n}());"

makeWrapper = (ns, fnstr, hasArbiter) ->
  return anonWrap if !fnstr
  location = if hasArbiter then ns+".require('M8::#{fnstr}')" else fnstr
  (code) -> location+"(function(){\n"+code+"\n});"

# analyzer will find files of specified ext, but these may clash on client
verifyCollisionFree = (codeList) ->
  codeList.forEach (pair) ->
    [dom, file] = pair;
    uid = dom+'::'+file.split('.')[0]
    codeList.forEach (inner) ->
      [d, f] = inner;
      return if d is dom and f is file
      uidi = d+'::'+f.split('.')[0]
      if uid is uidi
        error("two files of the same name on the same path will not work on the client: #{dom}::#{file} and #{d}::#{f}")
      return
    return
  return

# main packager
bundleApp = (codeList, ns, domload, compile, before, o) ->
  l = []

  # 1. construct the global namespace object
  l.push "window.#{ns} = {data:{}};"

  # 2. pull in data from parsers (force result to string if it isnt already)
  Object.keys(o.data).forEach (name) ->
    json = o.data[name]
    l.push "#{ns}.data.#{name} = #{json};"

  # 3. attach require code
  config =
    namespace : ns
    domains   : Object.keys(o.domains)
    arbiters  : o.arbiters
    logging   : o.logLevel

  l.push anonWrap( read(join(dir, 'require.js'))
    .replace(/VERSION/, JSON.parse(read(join(dir, '..', 'package.json'))).version)
    .replace(/REQUIRECONFIG/, JSON.stringify(config))
  )

  # 4. include CommonJS compatible code in the order they have to be defined - defineWrap each module
  defineWrap = (exportName, domain, code) ->
    "#{ns}.define('#{exportName}','#{domain}',function(require, module, exports){\n#{code}\n});"

  # 5. filter function split code into app code and non-app code
  harvest = (onlyMain) ->
    return codeList.map( (pair) ->
      [dom, file] = pair
      return if (dom is 'app') != onlyMain
      code = before(compile(join(o.domains[dom], file))) # before fns applied to code as well
      basename = file.split('.')[0] # take out extension on the client (we throw if collisions requires have happened on the server)
      defineWrap(basename, dom, code)
    ).filter( (e) -> !!e )


  # 6.a) include modules not on the app domain
  l.push "\n// shared code\n"
  l.push harvest(false).join('\n')

  # 6.b) include modules on the app domain, and hold off execution till DOMContentLoaded fires
  l.push "\n// app code - safety wrap\n\n"
  l.push domload(harvest(true).join('\n'))

  # 7. Use a closure to encapsulate the public and private require/define API as well as all export data
  anonWrap(l.join('\n'))


module.exports = (o) ->
  useLog = o.options.logging and !type.isFunction(o.target) # dont log anything from server if we output result to console
  log = o.logger

  persist = new Persister([o.target, o.libsOnlyTarget], o.options.persist, log.get('debug'))
  forceUpdate = o.options.force or persist.optionsModified(o)
  forceUpdate |= (o.target and !type.isFunction(o.target) and !exists(o.target)) # also forceUpdate if target deleted or does not exist

  ns = o.options.namespace

  dw = o.options.domloader
  if !type.isFunction(dw) # makeWraper from dw string
    dw = makeWrapper(ns, dw, Object.keys(o.arbiters).indexOf(dw) >= 0)

  before = if o.pre.length > 0 then _.compose.apply({}, o.pre) else noop
  after = if o.post.length > 0 then _.compose.apply({}, o.post) else noop

  compile = makeCompiler(o.compilers) # will throw if reusing extensions or invalid compile functions

  ca = codeAnalyis(o, before, compile)

  if o.treeTarget # do tree before collisionCheck (so that we can identify what triggers collision) + works better with CLI
    tree = ca.printed(o.extSuffix, o.domPrefix)
    if type.isFunction(o.treeTarget)
      o.treeTarget(tree)
    else
      fs.writeFileSync(o.treeTarget, tree)

  if o.target
    codelist = ca.sorted()
    verifyCollisionFree(codelist)

    appUpdated = persist.filesModified(codelist, o.domains, 'app')

    c = after(bundleApp(codelist, ns, dw, compile, before, o))

    if o.libDir and o.libFiles
      libsUpdated = persist.filesModified(o.libFiles.map( (f) -> ['libs', f]), {libs: o.libDir}, 'libs')

      if libsUpdated or (appUpdated and !o.libsOnlyTarget) or forceUpdate
        # necessary to do this work if libs changed
        # but also if app changed and we write it to the same files
        libs = after(o.libFiles.map((file) -> compile(join(o.libDir, file))).join('\n')) # concatenate libs as is - safetywrap any .coffee files

      if o.libsOnlyTarget and libsUpdated and !type.isFunction(o.libsOnlyTarget)
        fs.writeFileSync(o.libsOnlyTarget, libs)
        log.info 'compiling separate libs'
        libsUpdated = false # no need to take this state into account anymore since they are written separately
      else if type.isFunction(o.libsOnlyTarget)
        o.libsOnlyTarget(libs)
      else if !o.libsOnlyTarget
        c = libs + c
    else
      libsUpdated = false # no need to take lib state into account anymore since they dont exist

    if type.isFunction(o.target)
      return o.target(c)

    if appUpdated or (libsUpdated and !o.libsOnlyTarget) or forceUpdate
      # write target if there were any changes relevant to this file
      log.info 'compiling app'
      fs.writeFileSync(o.target, c)
  return
