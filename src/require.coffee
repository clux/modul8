app = window[requireConfig.namespace]
domains = app[d] for d in requireConfig.domains
isRelative = (reqStr) -> reqStr[0...2] is './'

makeRequire = (domain, pathName) -> # each module gets its own unique require function based on where it is to be able to resolve better
  (reqStr) ->
    if isRelative(reqStr)
      reqStr = resolveRelative(domain, pathName, reqStr[2...])
      scannable = [domain] # relatives should only search one domain
    else
      scannable = [domain].concat domains.filter((e) -> e isnt domain) # means this domain is scanned first
    return o[reqStr] if o[reqStr] for o in orderedDomains
    console.error("Unable to resolve require for: #{reqStr}")
    return

toAbsPath = (domain, pathName, relReqStr) ->
  folders = pathName.split('/')[0...-1] # slice away the filename
  while relReqStr[0...3] is '../'
    folders = folders[0...-1] # slice away the top folder every time it is required
    relReqStr = relReqStr[3...]
  folders.concat(relReqStr.split('/')).join('/') # take the remaining path and make the string


app.define = (exportName, domain, fn) -> # pass in a fn that expects require, module and exports, this will create/refer these objects/fns correctly
  domain = app[domain]
  domain[exportName] = {} if !domain[exportName]
  module = {}
  fn(makeRequire(domain, exportName), module, domain[exportName])
  domain[exportName] = module.exports if module.exports

