_           = require 'underscore'
fs          = require 'fs'
path        = require 'path'
codeAnalyis = require './analysis'
logule      = require 'logule'
Persister   = require './persist'
{makeCompiler, exists, read} = require './utils'

# helpers
anonWrap = (code) ->
  "(function(){\n#{code}\n}());"

makeWrapper = (ns, fnstr, hasArbiter) ->
  return anonWrap if !fnstr
  location = if hasArbiter then ns+".require('M8::#{fnstr}')" else fnstr
  (code) -> location+"(function(){\n"+code+"\n});"

# analyzer will find files of specified ext, but these may clash on client
verifyCollisionFree = (codeList) ->
  for [dom, file] in codeList
    uid = dom+'::'+file.split('.')[0]
    for [d,f] in codeList when dom isnt d or file isnt f # dont check self
      uidi = d+'::'+f.split('.')[0]
      if uid is uidi
        throw new Error("modul8: does not support requiring of two files of the same name on the same path with different extensions: #{dom}::#{file} and #{d}::{#f} ")
  return

# main packager
bundleApp = (codeList, ns, domload, compile, before, o) ->
  l = []

  # 1. construct the global namespace object
  l.push "window.#{ns} = {data:{}};"

  # 2. pull in data from parsers (force result to string if it isnt already)
  l.push "#{ns}.data.#{name} = #{json};" for name, json of o.data

  # 3. attach require code
  config =
    namespace : ns
    domains   : Object.keys(o.domains)
    arbiters  : o.arbiters
    logging   : o.logLevel

  l.push anonWrap( read(__dirname+'/require.js')
    .replace(/__VERSION__/, JSON.parse(read(__dirname+'/../package.json')).version)
    .replace(/__REQUIRECONFIG__/, JSON.stringify(config))
  )

  # 4. include CommonJS compatible code in the order they have to be defined - defineWrap each module
  defineWrap = (exportName, domain, code) ->
    "#{ns}.define('#{exportName}','#{domain}',function(require, module, exports){\n#{code}\n});"

  # 5. filter function split code into app code and non-app code
  harvest = (onlyMain) ->
    for [domain, name] in codeList when (domain is 'app') == onlyMain
      code = before(compile(o.domains[domain] + name)) # middleware applied to code first
      basename = name.split('.')[0] # take out extension on the client (we throw if collisions requires have happened on the server)
      defineWrap(basename, domain, code)


  # 6.a) include modules not on the app domain
  l.push "\n// shared code\n"
  l.push harvest(false).join('\n')

  # 6.b) include modules on the app domain, and hold off execution till DOMContentLoaded fires
  l.push "\n// app code - safety wrap\n\n"
  l.push domload(harvest(true).join('\n'))

  # 7. Use a closure to encapsulate the public and private require/define API as well as all export data
  anonWrap(l.join('\n'))


module.exports = (o) ->
  useLog = o.options.logging and !_.isFunction(o.target) # dont log anything from server if we output result to console
  log = if o.logger then o.logger else logule.sub('modul8')
  # keep API log level compatible
  log.suppress('debug') if !useLog or o.logLevel < 4
  log.suppress('info', 'warn') if !useLog or o.logLevel < 2

  persist = new Persister([o.target, o.libsOnlyTarget], o.options.persist, log.get('debug'))
  forceUpdate = o.options.force or persist.optionsModified(o)
  forceUpdate |= (o.target and !_.isFunction(o.target) and !exists(o.target)) # also forceUpdate if target deleted or does not exist

  ns = o.options.namespace
  domwrap = o.options.domloader or '' # force into string if not function or falsy
  domwrap = makeWrapper(ns, domwrap, domwrap of o.arbiters) if !domwrap or !_.isFunction(domwrap) # else use (empty?) str to make wrapper

  before = if o.pre.length > 0 then _.compose.apply({}, o.pre) else _.identity
  after = if o.post.length > 0 then _.compose.apply({}, o.post) else _.identity

  compile = makeCompiler(o.compilers) # will throw if reusing extensions or invalid compile functions

  ca = codeAnalyis(o, before, compile)

  if o.treeTarget # do tree before collisionCheck (so that we can identify what triggers collision) + works better with CLI
    tree = ca.printed(o.extSuffix, o.domPrefix)
    if _.isFunction(o.treeTarget)
      o.treeTarget(tree)
    else
      fs.writeFileSync(o.treeTarget, tree)

  if o.target
    codelist = ca.sorted()
    verifyCollisionFree(codelist)

    appUpdated = persist.filesModified(codelist, o.domains, 'app')

    c = after(bundleApp(codelist, ns, domwrap, compile, before, o))

    if o.libDir and o.libFiles
      libsUpdated = persist.filesModified((['libs', f] for f in o.libFiles), {libs: o.libDir}, 'libs')

      if libsUpdated or (appUpdated and !o.libsOnlyTarget) or forceUpdate
        # necessary to do this work if libs changed
        # but also if app changed and we write it to the same file
        libs = after((compile(o.libDir+file, false) for file in o.libFiles).join('\n')) # concatenate libs as is - safetywrap any .coffee files

      if o.libsOnlyTarget and libsUpdated and not _.isFunction(o.libsOnlyTarget)
        fs.writeFileSync(o.libsOnlyTarget, libs)
        log.info 'compiling separate libs'
        libsUpdated = false # no need to take this state into account anymore since they are written separately
      else if _.isFunction(o.libsOnlyTarget)
        o.libsOnlyTarget(libs)
      else if !o.libsOnlyTarget
        c = libs + c
    else
      libsUpdated = false # no need to take lib state into account anymore since they dont exist

    if _.isFunction(o.target)
      return o.target(c)

    if appUpdated or (libsUpdated and !o.libsOnlyTarget) or forceUpdate
      # write target if there were any changes relevant to this file
      log.info 'compiling app'
      fs.writeFileSync(o.target, c)
  return
