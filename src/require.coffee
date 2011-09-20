# this can easily be made into a commonjs compatible module if that is nicer
makeRequire = (app_name) ->
  (what, domain='client') ->
    o = window[app_name]
    return o.modules[what] if !(/\//).test(what) and domain is 'client' and o.modules[what] # search base level requires iin modules domain first
    o = o[domain]
    for part in what.split('/')
      if o isnt undefined
        o = o[part]
      else
        break
    console.error("Unable to resolve require to #{app_name}.#{domain}.#{what.replace(/\//,'.')}") if o is undefined
    o

window.require = makeRequire(requireAppName) #requireAppName is attached to window
window.shared = (what) -> require(what, 'shared')
#window.server = (what) -> require(what, 'server')
window.internal = (what) -> require(what, 'internal')


#POSSIBLE:

#FNWRAP with .call(this):
app = @[requireAppName]
domains = [app.modules, app.client, app.shared]

makeRequire = (domain, pathName) -> # each module gets its own unique require function based on where it is to be able to resolve better
  (reqStr) ->
    orderedDomains = [domain].concat domains.filter((e) -> e isnt domain) # means this domain is scanned first, else order is preserved
    return resolveRelative(domain, pathName, reqStr[2..]) if reqStr[0..1] is './' # relative requires must begin with './'
    for d in orderedDomains
      r = resolveAbs(o, reqStr)
      return r if r isnt undefined
    console.error("Unable to resolve require for: #{str}")
    null

resolveAbs = (o, reqStr) ->
  for part in reqStr.split('/')
    if o isnt undefined
      o = o[part]
    else
      break
  o
resolveRelative = (domain, pathName, relReqStr) ->
  folders = pathName.split('/')[0...-1] # slice away the filename
  while relReqStr[0..2] is '../'
    folders = folders[0...-1] # slice away the top folder every time it is required
    relReqStr = relReqStr[3..]
  path = folders.concat(relReqStr.split('/')).join('/') # take the remaining path and make the string
  resolveAbs(domain, path)



define = (fn, fileName, domain) ->
  exports = app[domain][fileName] #could work, define calls would be structured anyway
  module = {}
  fn(makeRequire(domain, fileName), module, exports)
  app.client = module.exports if module.exports

exports.define = define # require this via what? it is needed on the server as well...
