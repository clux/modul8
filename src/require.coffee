# This file is compiled and pre-pended to the #{target}.js
base = _modul8RequireConfig
ns = window[base.namespace] # a couple of helpers will be exported globally
domains = base.domains # array of used domain names

# construct our storage container
exports = {}
exports[name] = {} for name in domains # initialize domains
exports.data = ns.data # move data domain from input requireConfig to our exports object
delete ns.data # then hide data from defined modules
exports.M8 = {} # public API is exported onto this domain
exports.external = {} # public API can export onto this domain

# delete globals and create arbiters and arbitermaps
arbiters = []
for name, ary of base.arbiters
  arbiters.push name
  a = window[name]
  delete window[glob] for glob in ary
  exports.M8[name] = a


makeRequire = (dom, pathName) -> # each (path, domain) gets its own unique require function to help resolving
  DomReg = /^(.*)::/
  isRelative = (reqStr) -> reqStr[0...2] is './'

  (reqStr) ->
    console.log("#{dom}:#{pathName} <- #{reqStr}") if base.logging
    if isRelative(reqStr)
      # relative require: only look through the current domain
      scannable = [dom]
      reqStr = toAbsPath(dom, pathName, reqStr[2...])
    else if DomReg.test(reqStr)
      # domain specific require: only look at the specified domain
      scannable = [reqStr.match(DomReg)[1]]
      reqStr = reqStr.split('::')[1]
    else if reqStr in arbiters
      # not relative or domain specific, check next most common: old globals
      scannable = ['M8'] # will automatically resolve if we are in here
    else
      # absolute require: scan all actual paths, but favour current.
      # NB: disallow cross-domain absolutes to lookup the data/external/M8 domains - else analysis() fail
      scannable = [dom].concat domains.filter((e) -> e isnt dom)

    reqStr = reqStr.split('.')[0] # ignore extensions if exists

    return exports[o][reqStr] for o in scannable when exports[o][reqStr]
    console.error("Unable to resolve require for: #{reqStr}") if base.logging
    null

toAbsPath = (domain, pathName, relReqStr) ->
  folders = pathName.split('/')[0...-1] # slice away the filename
  while relReqStr[0...3] is '../'
    folders = folders[0...-1] # slice away the top folder at each iteration
    relReqStr = relReqStr[3...] # continue parsing the string
  folders.concat(relReqStr.split('/')).join('/') # take the remaining path and make the string

# fine to declare it in here to make use of
ns.define = (name, domain, fn) -> # needed by outer
  # fn = (require, module and exports) -> ...
  fn(makeRequire(domain, name), module={}, exports[domain][name] = {})
  if module.exports
    delete exports[domain][name] # need to properly override if this is to work
    exports[domain][name] = module.exports
  return



# Public API

# Debug Helpers
ns.inspect = (domain) ->
  console.log(exports[domain])
  return

ns.domains = ->
  domains.concat(['external']) # only hides the data and M8 domains

ns.require = makeRequire(base.main,'CONSOLE')

# Live Extensions (requirable and namespace reference available)
exports.M8.data = ns.data = (name, exported) ->
  delete exports.data[name] if exports.data[name] # otherwise cant overwrite
  exports.data[name] = exported if exported
  return

exports.M8.external = ns.external = (name, exported) ->
  delete exports.exernal[name] if exports.external[name] # otherwise cant overwrite
  exports.extenal[name] = exported if exported
  return
