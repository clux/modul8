app = window[requireNamespace]
domains = [app.modules, app.client, app.shared]

makeRequire = (domain, pathName) -> # each module gets its own unique require function based on where it is to be able to resolve better
  (reqStr) ->
    orderedDomains = [domain].concat domains.filter((e) -> e isnt domain) # means this domain is scanned first, else order is preserved
    return resolveRelative(domain, pathName, reqStr[2...]) if reqStr[0...2] is './' # relative requires must begin with './'
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
  while relReqStr[0...3] is '../'
    folders = folders[0...-1] # slice away the top folder every time it is required
    relReqStr = relReqStr[3...]
  path = folders.concat(relReqStr.split('/')).join('/') # take the remaining path and make the string
  out = resolveAbs(domain, path)
  console.error("Unable to resolve require for: #{relReqStr}, looking in domain: #{domain} relative to path: #{pathName}") if !out
  out


app.define = (exportName, domain, fn) -> # pass in a fn that expects require, module and exports, this will create/refer these objects/fns correctly
  domain = app[domain]
  domain[exportName] = {} if !domain[exportName]
  module = {}
  fn(makeRequire(domain, exportName), module, domain[exportName])
  domain[exportName] = module.exports if module.exports

