#!/usr/bin/env coffee

# Module dependencies

fs      = require('fs')
path    = require('path')
program = require('../node_modules/commander')
modul8  = require('../')
utils   = require('../lib/utils')
dir     = fs.realpathSync()
{basename, dirname, resolve, join} = path

# parsers
hashMap = (val) ->
  out = {}
  for e in (val.split('#') or [])
    [k,v] = e.split('=')
    out[k] = v
  out

hashDouble = (val) ->
  out = {}
  for e in (val.split('#') or [])
    [k,v] = e.split('=')
    out[k] = v?.replace(/\[/,'').replace(/\]/,'').split(',')
  out

# options

program
  .version(modul8.version)
  .option('-z, --analyze', 'analyze dependencies instead of compiling')
  .option('-p, --domains name=path', 'specify require domains', hashMap)
  .option('-d, --data key=path', 'attach json parsed data from path to data::key', hashMap)

  .option('-b, --libraries path=[lib1,lib2]', 'concatenate libraries in front of the standard output in the given order', hashDouble)
  .option('-a, --arbiters shortcut=[glob,glob2]', 'specify arbiters shortcut for list of globals', hashDouble)
  .option('-g, --plugins path=[arg,arg2]', 'load in plugins from path using array of simple constructor arguments', hashDouble)

  .option('-l, --logging <level>', 'set the logging level')
  .option('-n, --namespace <name>', 'specify the target namespace used in the compiled file')
  .option('-w, --wrapper <fnName>', 'name of wrapping domloader function')
  .option('-t, --testcutter', 'enable pre-processing of files to cut out local tests and their dependencies')
  .option('-m, --minifier', 'enable uglifyjs post-processing')

program.on '--help', ->
  console.log('  Examples:')
  console.log('')
  console.log('    # analyze application dependencies from entry point')
  console.log('    $ modul8 app/entry.js -z')
  console.log('')
  console.log('    # compile application from entry point')
  console.log('    $ modul8 app/entry.js > output.js')
  console.log('')
  console.log('    # specify extra domains')
  console.log('    $ modul8 app/entry.js -p shared=shared/#bot=bot/')
  console.log('')
  console.log('    # specify arbiters')
  console.log('    $ modul8 app/entry.js -a jQuery=[$,jQuery]#Spine')
  console.log('')
  console.log('    # wait for the DOM using the jQuery function')
  console.log('    $ modul8 app/entry.js -w jQuery')
  console.log('')
  console.log('    # specify plugins')
  console.log('    $ modul8 app/entry.js -g m8-templation:[template_path,.jade]')
  console.log('')

program.parse(process.argv)

# first arg must be entry
entry = program.args[0]
if !entry
  console.error("usage: modul8 entry [options]")
  console.log("or modul8 -h for help")
  process.exit()

# convenience processing of plugins and data input
console.log program.plugins
return
plugins = {}
data = {}
for name,optry of program.plugins
  #try
  #console.log name
  P = require(name).Plugin # will throw - requires name to be a resolvable path
  P.apply(inst={}, optAry)
  plugins.push inst
  #catch e
  #  throw new Error(name+' not a requirable plugin')

for k,p of program.data
  if not p or not path.existsSync p
    console.error("invalid data usage: value must be a path to a file")
    process.exit()
  data[k] = fs.readFileSync(p, 'utf8')

null for libPath,libs of program.libraries

i_d = (a) -> a

modul8(entry)
  .domains(program.domains)
  .data(data)
  .analysis(if program.analyze then console.log else false)
  .arbiters(program.arbiters)
  .libraries(libs or [], libPath)
  .set('namespace', program.namespace ? 'M8')
  .set('logging', program.logging ? 'ERROR') # if not set, do like default server behaviour
  .before(if program.testcutter then modul8.testcutter else i_d)
  .after(if program.minifier then modul8.minifier else i_d)
  .set('domloader', program.wrapper)
  .set('force', true) # always rebuild when using this
  .compile(if program.analyze then false else console.log)

