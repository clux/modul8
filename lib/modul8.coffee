bundle = require './bundle.coffee'
_      = require 'underscore'
{exists, domainSplit} = require './utils'

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

# before and after calls will allow anything in, but we throw if any not fn at compile
Modul8::before = (fn) ->
  @removeSubClassMethods()
  obj.pre.push fn if @environmentMatches
  @

Modul8::after = (fn) ->
  @removeSubClassMethods()
  obj.post.push fn if @environmentMatches
  @

Modul8::use = (inst) ->
  @removeSubClassMethods()

  if !inst.name or !_.isFunction(inst.name)
    throw new Error("modul8 plugins require a name method")

  name = inst.name()+''
  if !name
    throw new Error("plugin to modul8 gave non-existant name from its name method")

  if inst.data and _.isFunction(inst.data)
    data = inst.data()
    if !data
      throw new Error("modul8 plugin registering to #{name} retuned bad/missing value from its data method")

    @data().add(name, data, _.isString(data)) # if strings are passed from plugins, we assume they are serialized (otherwise plugin usage seems unnecessary)

  if inst.domain and _.isFunction(inst.domain)
    dom = inst.domain()
    if !dom
      throw new Error("modul8 plugin registering to #{name} retuned bad/missing value from its domain method")
    @domains().add(name, dom)

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
  [dom, file] = domainSplit(entry) # will throw if unresolvable
  obj =
    data        : {}
    arbiters    : {}
    domains     : {'app' : dom}
    pre         : []
    post        : []
    ignoreDoms  : []
    compilers   : {}
    entryPoint  : file
    options     :
      namespace   : 'M8'
      domloader   : false
      logging     : 'ERROR'
      force       : false

  new Modul8()





Modul8::data = (input) ->
  return @ if !@environmentMatches
  dt = new Data()
  return dt if !input
  dt.add(key, val) for key,val of input if _.isObject(input)
  dt

Data = ->
Data:: = new Modul8('Data')


Data::add = (key, val, serialized=false) ->
  return @ if !@subclassMatches('Data','add')
  return @ if !@environmentMatches
  if key and val
    key += '' # force string
    if serialized
      # assume the users know what they are doing
      obj.data[key] = val+''
    else if _.isFunction(val)
      # we can serialize functions directly like their definition, but they will not have closure state from the server
      obj.data[key] = val.toString()+'()' # self-execute on the client
    else #
      obj.data[key] = JSON.stringify(val)

  @

# cant have both 1: 'new Date()' functionality AND 2: '1233' functionality - no way to tell them apart
# option a) allow 2, and disable 1 (unless you can write it in terms of a function)
# option b) disallow 2 completeley, and maintain current behaviour => bad, people will pass in strings..
#started()


Modul8::domains = (input) ->
  return @ if !@environmentMatches
  dom = new Domains()
  dom.add(key, val) for key,val of input if input and _.isObject(input)
  dom

Domains = ->
Domains:: = new Modul8('Domains')

Domains::add = (key, val) ->
  return @ if !@subclassMatches('Domains','add')
  obj.domains[key] = val if @environmentMatches
  if key is 'app'
    throw new Error("modul8 reserves the 'app' domain for application code where the entry point resides")
  @



Modul8::libraries = (list, dir, target) ->
  return @ if !@environmentMatches
  libs = new Libraries()
  libs.list(list) if list
  libs.path(dir) if dir
  libs.target(target) if target
  libs


Libraries = ->
Libraries:: = new Modul8('Libraries')

Libraries::list = (list) ->
  return @ if !@subclassMatches('Libraries','list')
  obj.libFiles = list if @environmentMatches and _.isArray(list)
  @

#Probably bad idea, libPath linked up to lib list, can change this though
#but if we use add, then it has to add after the list call has taken place..
#Libraries::add = (lib) -> #TODO: good idea? for data plugins - if useful, then should also add arbiters for plugins
#  return @ if !@subclassMatches('Libraries','add')
#  obj.libFiles.push(lib+'')
#  @

Libraries::path = (dir) ->
  return @ if !@subclassMatches('Libraries','path')
  obj.libDir = dir+'' if @environmentMatches
  @

Libraries::target = (target) ->
  return @ if !@subclassMatches('Libraries','target')
  obj.libsOnlyTarget = target if @environmentMatches
  @




Modul8::analysis = (target, prefix, suffix, hide) ->
  return @ if !@environmentMatches
  ana = new Analysis()
  ana.output(target) if target
  ana.prefix(prefix) if prefix
  ana.suffix(suffix) if suffix
  ana.hide(hide) if hide
  ana

Analysis = ->
Analysis:: = new Modul8('Analysis')

Analysis::output = (target) ->
  return @ if !@subclassMatches('Analysis','output')
  obj.treeTarget = target if @environmentMatches
  @

Analysis::prefix = (prefix) ->
  return @ if !@subclassMatches('Analysis','prefix')
  obj.domPrefix = !!prefix if @environmentMatches
  @

Analysis::suffix = (suffix) ->
  return @ if !@subclassMatches('Analysis','suffix')
  obj.extSuffix = !!suffix if @environmentMatches
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
  if arbObj
    arb.add(key, val) for key,val of arbObj if _.isObject(arbObj)
    arb.add(v) for v in arbObj if _.isArray(arbObj)
  arb

Arbiters = ->
Arbiters:: = new Modul8('Arbiters')

Arbiters::add = (name, globs) ->
  return @ if !@subclassMatches('Arbiters','add')
  return @ if !@environmentMatches
  if globs and _.isArray(globs)
    obj.arbiters[name] = globs
  else if globs
    obj.arbiters[name] = [globs+'']
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

  if !exists(o.domains['app'] + o.entryPoint)
    throw new Error("modul8 requires the entryPoint to be contained in the app domain - could not find: "+o.domains['app'] + o.entryPoint) # can remove this soon

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
    throw new Error("modul8::analysis cannot ignore the app domain") if 'app' is d

  return

module.exports = start

if module is require.main
  modul8 =
    minifier:->
    testcutter:->
  start('app.cs')
    .set('domloader', (code) -> code)
    .set('namespace', 'QQ')
    .set('logging', 'INFO')
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

