path = require 'path'
{exists, read} = require './utils'


# criterion for whether string is absolute (and should be joined with various domain paths to test for existence)
# if this fails, we assume a string is relative and join it with extraPath
isAbsolute = (reqStr) ->
  reqStr is '' or path.normalize(reqStr) is reqStr


# ignorelist regex check and filter fn to be used on each detective result
domainIgnoresReg = /^data(?=::)|^external(?=::)|^M8(?=::)|^npm(?=::)/
domainReg = /^([\w]*)::/
isLegalRequire = (reqStr) ->
  return true if domainIgnoresReg.test(reqStr)
  if domainReg.test(reqStr) and !isAbsolute(stripDomain(reqStr))
    throw new Error("modul8 resolver found illegal require string combining domain prefix + relative: #{reqStr}")
  true

# take out domain prefix from request string if exists
stripDomain = (reqStr) ->
  ary = reqStr.split('::')
  ary[ary.length-1]

# exists helper for locate
makeFinder = (exts) ->
  (base, req) ->
    for ext in exts
      attempt = path.join(base, req+ext)
      if exists(path.join(base, req+ext))
        #console.log attempt+' found!', base
        return req+ext
    return false

# returns the entry point of an npm module
npmResolve = (absReq, name, silent) ->
  # folder must exist
  if !path.existsSync(absReq) # will look for folder name
    throw new Error('modul8 resolver could not resolve desired npm module: '+name) if !silent
    return false
  jsonPath = path.join(absReq, 'package.json')
  # package.json must exist
  if !exists(jsonPath)
    throw new Error('modul8 resolver cannot include npm module '+name+' without a package.json file') if !silent
    return false
  # it must be parsable
  try
    package = JSON.parse(read(jsonPath))
  catch e
    throw new Error('npm path has an unparsable package.json') if !silent
    return false
  # package.json exists and is valid => node_module found
  package.browserMain or package.main or 'index'

# resolver constructor
Resolver = (@domains, @arbiters, @exts) ->
  @finder = makeFinder(@exts)
  return

# new absolutize path (needs domain paths now)
toAbsPath = (reqStr, extraPath, domain) -> # extraPath is path.normalize of reqStr \ path.baseName
  if domainReg.test(reqStr)
    domain = reqStr.match(domainReg)[1]
    if !isAbsolute(reqStr)
      # illegal to use relative requires when specifying domain
      throw new Error("modul8 does not allow relative requires to a domain #{reqStr}")
    reqStr = stripDomain(reqStr) # TODO: path.normalize ? (breaks domain::)
    [reqStr, domain]
  else if isAbsolute(reqStr)
    if domain is 'npm'
      # npm absolute require, must be another npm module or something incompatible
      if reqStr in ['path', 'util', 'sys', 'fs'] # fs, path, util, sys usage will fail, so we throw here
        throw new Error("modul8 cannot require server side npm module #{reqStr}")
      [path.join(extraPath, 'node_modules', reqStr), 'npm']
    else
      [reqStr, null]
  else # relative
    [path.join(extraPath, reqStr), domain] # TODO: normalize reqStr first?


# new locater
Resolver::locate = (reqStr, currentPath, currentDomain) ->
  #console.log reqStr, currentPath, currentDomain
  [absReq, foundDomain] = toAbsPath(reqStr, currentPath, currentDomain)
  #console.log foundDomain, absReq

  if domainIgnoresReg.test(reqStr)
    switch foundDomain
      when 'data', 'external'
        return [absReq, foundDomain, true]
      when 'M8'
        return [absReq, 'M8', true] if absReq of @arbiters # arbiter or API require
        throw new Error("modul8 resolver could not require non-existent arbiter: #{reqStr} (from #{currentDomain})")
      when 'npm'
        npmMain = npmResolve(absReq, reqStr, false) # npmResolve throws if it fails in this case
        return [found, 'npm', false] if found = @finder(npmMain, '') # allow AltJs only modules if languages are registered
        throw new Error("modul8 resolver could not require invalid npm module with lying package.json: #{reqStr}")

  else
    if foundDomain and !@domains[foundDomain]
      throw new Error("modul8 resolver could not require from an unconfigured domain: #{foundDomain}")
    if foundDomain is 'app' and currentDomain isnt 'app'
      throw new Error("modul8 does not allow other domains to reference the app domain. required from #{currentDomain}")
    #if foundDomain isnt currentDomain and currentDomain isnt 'app'
    #  throw new Error("modul8 only allows the app domain to do cross-domain requires - #{currentDomain} tries to require from #{foundDomain}")


    if foundDomain
      result = @scan(absReq, [foundDomain])
      return result if result
      console.log 'i am failing', result, absReq, reqStr
      throw new Error("modul8 resolver failed to resolve require('#{reqStr}') in #{foundDomain} for extensions #{@exts[1...].join(', ')}")

    # must do the global require dance
    # arbiters first, then npm modules, then all domains

    if absReq of @arbiters
      return [absReq, 'M8', true] # in case of collisions with normal domains, if not relative, arbiters must have priority over any domains, hence this line

    npmMain = npmResolve(absReq, reqStr, true)
    if foundDomain is null and npmMain
      return [found, 'npm', false] if found = @finder(npmMain, '')
      throw new Error("modul8 could not require invalid npm module with lying package.json: #{reqStr}")
    else if foundDomain is 'npm' # sandboxes the npm domain to self
      throw new Error("modul8 can not implicitly require an npm module without a package.json #{reqStr}")


    # absolute require of some sort, check all custom domains starting with current
    scannable = [currentDomain].concat(name for name of @domains when name isnt currentDomain)
    result = @scan(absReq, scannable)
    return result if result
    throw new Error("modul8 resolver failed to resolve require('#{reqStr}') from #{currentDomain} - looked in #{scannable} for extensions #{@exts[1...].join(', ')}")



Resolver::scan = (absReq, scannable) ->
  #console.log '@scan', absReq, scannable
  if absReq[-1...] in ['/', '\\']
    absReq = path.join(absReq, 'index')  # allow trailing slashes to indicate folder
    noTryFolder = true


  for dom in scannable
    # req ends in valid filename ?
    #console.log 'checking '+dom,  @finder(@domains[dom], absReq)
    return [found, dom, false] if found = @finder(@domains[dom], absReq)

    # req ends in valid folder ?
    continue if noTryFolder # already done this test
    return [found, dom, false] if found = @finder(@domains[dom], path.join(absReq, 'index'))
  return false

module.exports = {
  isLegalRequire
  Resolver
}
