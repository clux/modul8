app = window[requireConfig.namespace]
domains = requireConfig.domains
fallback = app.fallback
DataReg = /^data::/
isRelative = (reqStr) -> reqStr[0...2] is './'

makeRequire = (domain, pathName) -> # each module gets its own unique require function based on where it is to be able to resolve better
  (reqStr) ->
    if DataReg.test(reqStr)
      data = reqStr.replace(DataReg,'')
      return app.data[data] if app.data[data]
      console.error("Unable to resolve data require for data")
    if (isRel = isRelative(reqStr))
      reqStr = resolveRelative(domain, pathName, reqStr[2...])
    scannable = if isRel then [domain] else [domain].concat domains.filter((e) -> e isnt domain) # look through current first (and only current if relative)
    return o[reqStr] if o[reqStr] for o in scannable # return first found on our domains
    return fallback(reqStr) if fallback and 'Function' is typeof fallback # else what external require could find
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

