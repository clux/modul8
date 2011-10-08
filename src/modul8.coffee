bundle = require('./bundle.coffee')


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


Modul8::set = (key, val) ->
  @removeSubClassMethods()
  return @ if !(key in ['namespace', 'logging', 'domloader'])
  obj.options[key] = val if @environmentMatches
  @


start = (entry) ->
  obj =
    namespace   : 'M8'
    data        : {}
    arbiters    : {}
    domains     : {}
    pre         : []
    post        : []
    options     : {}
    entryPoint  : entry
  new Modul8()





Modul8::data = () ->
  return @ if !@environmentMatches
  new Data()

Data = () ->
Data:: = new Modul8('Data')


Data::add = (key, val) ->
  return @ if !@subclassMatches('Data','add')
  obj.data[key] = val if @environmentMatches
  @



Modul8::domains = () ->
  return @ if !@environmentMatches
  new Domains()

Domains = () ->
Domains:: = new Modul8('Domains')

Domains::add = (key, val, primary) ->
  return @ if !@subclassMatches('Domains','add')
  if @environmentMatches
    obj.domains[key] = val
    if !obj.hasDomains
      obj.hasDomains = true
      obj.mainDomain = key
  @



Modul8::libraries = () ->
  return @ if !@environmentMatches
  new Libraries()

Libraries = ->
Libraries:: = new Modul8('Libraries')

Libraries::list = (list) ->
  return @ if !@subclassMatches('Libraries','list')
  obj.libFiles = list if @environmentMatches
  @

Libraries::target = (target) ->
  return @ if !@subclassMatches('Libraries','target')
  obj.libsOnlyTarget = target if @environmentMatches
  @

Libraries::path = (dir) ->
  return @ if !@subclassMatches('Libraries','path')
  obj.libDir = dir if @environmentMatches
  @



Modul8::analysis = () ->
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



Modul8::arbiters = () ->
  return @ if !@environmentMatches
  new Arbiters()

Arbiters = ->
Arbiters:: = new Modul8('Arbiters')

Arbiters::add = (name, globs) ->
  return @ if !@subclassMatches('Arbiters','add')
  return @ if !@environmentMatches
  if globs and globs.length #TODO: better array testing
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
  bundle(obj)
  @ # keep chaining in case there are subsequent calls chained on in different environments


module.exports = start

if module is require.main
  modul8 =
    minifier:->
    testcutter:->
  start('app.cs')
    .set('domloader', (code) -> code)
    .set('namespace', 'QQ')
    .set('logging', true)
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

