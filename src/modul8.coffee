bundle = require './bundle.coffee'
_      = require 'underscore'
{exists} = require './utils'

#process.chdir(self.options['working directory']);
environment = process.env.NODE_ENV or 'development'
envCurrent = 'all'

subCurrent = 'None'

obj = {} # changed by all objects below

Modul8 = (@sub = 'None')->

Modul8::__defineGetter__ 'environmentMatches', ->
  environment is envCurrent or envCurrent is 'all'

# since the way we move between class instances might leave more methods exposed than we need, catch bad usage here and warn
Modul8::subclassMatches = (subclass, method) ->
  hasMatch = @sub is subclass
  console.warn("Ignoring an invalid call to "+subclass+"::"+method+" after having broken out from the "+subclass+" subclass") if !hasMatch
  hasMatch

#subclass methods must call @subclassMatches
Modul8::removeSubClassMethods = ->
  @sub = 'None'

Modul8::in = (env) ->
  # allow this to retain current sub-class
  envCurrent = env
  @

Modul8::before = (fn) ->
  @removeSubClassMethods()
  obj.pre.push fn if @environmentMatches
  @

Modul8::after = (fn) ->
  @removeSubClassMethods()
  obj.post.push fn if @environmentMatches
  @

Modul8::register = (ext, compiler) ->
  @removeSubClassMethods()
  obj.compilers[ext] = compiler if @environmentMatches
  @


Modul8::set = (key, val) ->
  @removeSubClassMethods()
  return @ if !(key of obj.options)
  obj.options[key] = val if @environmentMatches
  @


start = (entry) ->
  obj =
    data        : {}
    arbiters    : {}
    domains     : {}
    mainDomain  : 'app'
    pre         : []
    post        : []
    ignoreDoms  : []
    compilers   : {}
    entryPoint  : entry ? 'main.coffee'
    options     :
      namespace   : 'M8'
      domloader   : false
      logging     : false
      force       : false

  new Modul8()





Modul8::data = (input) ->
  return @ if !@environmentMatches
  obj.data[key] = val for key,val of input if input
  new Data()

Data = ->
Data:: = new Modul8('Data')


Data::add = (key, val) ->
  return @ if !@subclassMatches('Data','add')
  obj.data[key] = val if @environmentMatches
  @



Modul8::domains = (input) ->
  return @ if !@environmentMatches
  obj.domains[key] = val for key,val of input if input # cant simply call add as order unspecified for objects
  new Domains()

Domains = ->
Domains:: = new Modul8('Domains')

Domains::add = (key, val, primary) ->
  return @ if !@subclassMatches('Domains','add')
  if @environmentMatches
    obj.domains[key] = val
    if !obj.hasMainDomain
      obj.hasMainDomain = true
      obj.mainDomain = key # first domain called with add will become main
  @



Modul8::libraries = (list, dir, target) ->
  return @ if !@environmentMatches
  obj.libFiles = list if list
  obj.libDir = dir if dir
  obj.libsOnlyTarget = target if target
  new Libraries()

Libraries = ->
Libraries:: = new Modul8('Libraries')

Libraries::list = (list) ->
  return @ if !@subclassMatches('Libraries','list')
  obj.libFiles = list if @environmentMatches
  @

Libraries::path = (dir) ->
  return @ if !@subclassMatches('Libraries','path')
  obj.libDir = dir if @environmentMatches
  @

Libraries::target = (target) ->
  return @ if !@subclassMatches('Libraries','target')
  obj.libsOnlyTarget = target if @environmentMatches
  @




Modul8::analysis = ->
  return @ if !@environmentMatches
  new Analysis()

Analysis = ->
Analysis:: = new Modul8('Analysis')

Analysis::output = (target) ->
  return @ if !@subclassMatches('Analysis','output')
  obj.treeTarget = target if @environmentMatches
  @

Analysis::prefix = (prefix) ->
  return @ if !@subclassMatches('Analysis','prefix')
  obj.domPrefix = prefix if @environmentMatches
  @

Analysis::suffix = (suffix) ->
  return @ if !@subclassMatches('Analysis','suffix')
  obj.extSuffix = suffix if @environmentMatches
  @

Analysis::hide = (domain) ->
  return @ if !@subclassMatches('Analysis','suffix')
  if @environmentMatches
    domains = if _.isArray(domain) then domain else [domain]
    obj.ignoreDoms.push d for d in domains
  @

Modul8::arbiters = (arbObj) ->
  return @ if !@environmentMatches
  arb = new Arbiters()
  arb.add(key, val) for key,val of arbObj if arbObj
  arb

Arbiters = ->
Arbiters:: = new Modul8('Arbiters')

Arbiters::add = (name, globs) ->
  return @ if !@subclassMatches('Arbiters','add')
  return @ if !@environmentMatches
  if globs and globs instanceof Array
    obj.arbiters[name] = globs
  else if globs
    obj.arbiters[name] = [globs]
  else
    obj.arbiters[name] = [name]
  @


Modul8::compile = (target) ->
  @removeSubClassMethods()
  return @ if !@environmentMatches
  obj.target = target
  sanityCheck(obj)
  bundle(obj)
  @ # keep chaining in case there are subsequent calls chained on in different environments

sanityCheck = (o) ->
  if !o.domains
    throw new Error("modul8 requires domains specified - got "+JSON.stringify(o.domains))

  if !exists(o.domains[o.mainDomain] + o.entryPoint)
    throw new Error("modul8 requires the entryPoint to be contained in the first domain - could not find: "+o.domains[o.mainDomain] + o.entryPoint)

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

  for d in obj.ignoreDoms
    throw new Error("modul8::analysis cannot ignore the main #{obj.mainDomain} domain") if obj.mainDomain is d

  for key, data_fn of obj.data
    throw new Error("modul8::data got a value supplied for #{name} which is not a function") if !_.isFunction(data_fn)

  return

module.exports = start

if module is require.main
  modul8 =
    minifier:->
    testcutter:->
  start('app.cs')
    .set('domloader', (code) -> code)
    .set('namespace', 'QQ')
    .set('logging', true)
    .register('.cs', (code) -> coffee.compile(code))
    .before(modul8.testcutter)
    #.set('compiler', {extension:'.coca', fn: (fileName) -> (js)}) # not worth it yet.
    #.set('working directory', path) # maybe do this to avoid having to prefix dir+ on almost all API inputs
    .libraries()
      .list(['jQuery.js','history.js'])
      .path('/app/client/libs/')
      .target('dm-libs.js')
    .arbiters()
      .add('jQuery', ['$','jQuery'])
      .add('Spine')
    .arbiters({
      'underscore', '_'
    })
    .domains()
      .add('app', '/app/client/')
      .add('shared', '/app/shared/')
    .data()
      .add('models', -> '{modeldata:{getssenttoclient}}')
      .add('versions', -> '{users/view:[0.2.5]}')
    .analysis()
      .prefix(true)
      .suffix(false)
      .in('development')
        .output(console.log)
      .in('production')
        .output('filepath!')
    .in('all')
      .after(modul8.minifier) # breaks out of subclass
      .compile('dm.js')

