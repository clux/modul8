zombie    = require 'zombie'
assert    = require 'assert'
fs        = require 'fs'
rimraf    = require 'rimraf'
coffee    = require 'coffee-script'
detective = require 'detective'
utils     = require './../src/utils'    # hook in to this
analysis  = require './../src/analysis' # hook in to this
resolver  = require './../src/resolver' # hook in to this
modul8    = require './../index.js' # public interface
dir       = __dirname

{isLegalRequire, Resolver} = resolver

makeApp = ->
  # clean out old directory
  try rimraf.sync(dir+'/modified')
  catch e
  fs.mkdirSync(dir+'/modified', 0755)
  for p in options.paths
    fs.mkdirSync(dir+'/modified/'+p, 0755)

  l = []
  for i in [0...3]
    fs.writeFileSync(options.paths.libs+i+'.js', "(function(){window.#{i} = 'ok';})();")
    fs.writeFileSync(options.paths.app+i+'.js', "module.exports = 'ok';")
    fs.writeFileSync(options.paths.shared+i+'.js', "module.exports = 'ok';")
    l.push "exports.app_#{i} = require('#{i}');"
    l.push "exports.shared_#{i} = require('shared::#{i}');"
    #l.push "exports.libs_#{i} = require('M8::#{i}');" #TODO: also verify that this works
  fs.writeFileSync(dir+'/modified/app/entry.js', l.join('\n'))

options =
  paths :
    app      : dir+'/modified/app/'
    shared   : dir+'/modified/shared/'
    libs     : dir+'/modified/libs/'

compile = (useLibs, libsTarget) ->
  modul8('entry.js')
    #.analysis().output(console.log).suffix(true)
    .libraries()
      .list(if useLibs then ['0','1','2'] else false)
      .path(options.paths.libs)
      .target(libsTarget) # i.e if we pass null, or nothing, we will compile together with outmod.js
    .domains()
      .add('app', options.paths.app)
      .add('shared', options.paths.shared)
    .compile(dir+'/output/outmod.js')

modify = (domain, num) ->
  file = options.domains[domain]+num+'.js'
  fs.writeFileSync(file, read(file)+' ') # add whitespace

exports["test compile#modified"] = ->
  #makeApp()
  #compile()

  ###TestPlan
  for each file and path
    0. read mtimes
    1. compile
    2. verify that file has NOT changed (always)
    3. modify a file
    4. compile
    5. verify that app file has changed (if it should)

  do above for cases:
   1. without libs modifying app files
   2. with libs modifying app files
   3. with libs, libsOnlyTarget modifying app files
   4. with libs modifying lib files
   5. with libs, libsOnlyTarget modifying lib files
  ###
  #for name, path of options.paths
  #  modifyingLibs = name is 'libs'
  #  for i in [0...3]
  #    compile()


  testCount = 0
  console.log 'compile#modified - completed:', testCount

