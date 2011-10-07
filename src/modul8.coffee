bundle = require('./bundle.coffee')


#process.chdir(self.options['working directory']);
currEnv = process.env.NODE_ENV or 'development'


obj = {} # changed by all objects below

Modul8 = ->

Modul8::__defineGetter__ 'environmentMatches', ->
  if @_env
    return currEnv is @_env or @_env is 'all'
  true


Modul8::in = (env) ->
  @_env = env
  @

Modul8::before = (fn) ->
  obj.pre.push fn if @environmentMatches
  @

Modul8::after = (fn) ->
  obj.post.push fn if @environmentMatches
  @


Modul8::set = (key, val) ->
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
Data:: = new Modul8()


Data::add = (key, val) ->
  obj.data[key] = val if @environmentMatches
  @



Modul8::domains = () ->
  return @ if !@environmentMatches
  new Domains()

Domains = () ->
Domains:: = new Modul8()

Domains::add = (key, val, primary) ->
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
Libraries:: = new Modul8()

Libraries::list = (list) ->
  obj.libFiles = list if @environmentMatches
  @

Libraries::target = (target) ->
  obj.libsOnlyTarget = target if @environmentMatches
  @

Libraries::path = (dir) ->
  obj.libDir = dir if @environmentMatches
  @



Modul8::analysis = () ->
  return @ if !@environmentMatches
  new Analysis()

Analysis = ->
Analysis:: = new Modul8()

Analysis::output = (target) ->
  obj.treeTarget = target if @environmentMatches
  @

Analysis::prefix = (prefix) ->
  obj.domPrefix = prefix if @environmentMatches
  @

Analysis::suffix = (suffix) ->
  obj.extSuffix = suffix if @environmentMatches
  @



Modul8::arbiters = () ->
  return @ if !@environmentMatches
  new Arbiters()

Arbiters = ->
Arbiters:: = new Modul8()

Arbiters::add = (name, globs) ->
  return @ if !@environmentMatches
  if globs and globs.length #TODO: better array testing
    obj.arbiters[name] = globs
  else if globs
    obj.arbiters[name] = [globs]
  else
    obj.arbiters[name] = [name]
  @


Modul8::compile = (target) ->
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
    .before(modul8.testcutter)
    #.set('compiler', {extension:'.coca', fn: (fileName) -> (js)}) # not worth it yet.
    #.set('working directory', path)
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
      .add('models', '{modeldata:{getssenttoclient}}')
      .add('versions', '{users/view:[0.2.5]}')
    .in('development')
      .after(modul8.minifier)
      .analysis()
        .output(console.log)
        .prefix(true)
        .suffix(false)
    .in('all')

      .compile('dm.js')

