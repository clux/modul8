{exists, read} = require './utils'
path = require 'path'
fs = require 'fs'


# criteria for whether a require string is relative, rather than absolute
# absolute require strings will scan on the defined require paths (@domains)
#isRelative = (reqStr) ->
#  reqStr[0...2] is './' or reqStr[0...3] is '../'

# ignorelist regex check and filter fn to be used on each detective result
domainIgnoresReg = /^data(?=::)|^external(?=::)|^M8(?=::)/
domainReg = /^([\w]*::)/
isLegalRequire = (reqStr) ->
  return true if domainIgnoresReg.test(reqStr)
  if domainReg.test(reqStr) and isRelative(stripDomain(reqStr)) #TODO: need this test still?
    throw new Error("modul8::analysis found illegal require string combining domain prefix + relative")
  true

# take out domain prefix from request string if exists
stripDomain = (reqStr) -> reqStr.replace(domainReg,'')


# new absolutize path (needs domain paths now)
Resolver::toAbsPath = (name, subFolders, domain) -> # subFolders is path.normalize of reqStr \ path.baseName
  return [stripDomain(name), name.match(domainReg)[1][0...-2]] if domainReg.test(name)
  [path.resolve(@domains[domain], subFolders, name), domain]


# exists helper for locate
makeFinder = (exts) ->
  (path, req) ->
    return req+ext for ext in exts when exists(path+req+ext)
    return false

# returns the entry point of an npm module
npmResolve = (path, name, silent) ->
  if !path.existsSync(path+name) # will look for folder name
    throw new Error('modul8 resolver could not resolve desired npm module: '+name) if !silent
    return
  if !path.existsSync(path+name+'/package.json')
    throw new Error('modul8 resolver cannot include npm module '+name+' without a package.json file') if !silent
    return
  try
    package = JSON.parse(read('path+name+/package.json'))
  catch e
  package?.main ? 'index'


# resolver constructor
Resolver = (@domains, @arbiters, @exts) ->
  @finder = makeFinder(@exts)
  return

# locate location of file from absReq (assumed only called on files that pass isLegalRequire)
Resolver::locate = (reqStr, subFolders, domain) ->
  #console.log reqStr, subFolders, domain
  [absReq, foundDomain] = toAbsPath(reqStr, subFolders, domain)
  #console.log absReq
  absReq = 'index' if absReq is ''


  # sanity
  if !domainIgnoresReg.test(reqStr)
    # do these tests if its not one of the normal domains
    if foundDomain? and !@domains[foundDomain]
      throw new Error("modul8::analysis could not resolve a require for an unconfigured domain: #{foundDomain}")
    if foundDomain is 'app' and domain isnt 'app'
      throw new Error("modul8 does not allow other domains to reference the app domain. required from #{domain}")

  return [absReq, 'data', true] if foundDomain is 'data' # injected data
  return [absReq, 'external', true] if foundDomain is 'external' # externally loaded

  # M8 requires are allowed to happen without prefix (so we must preserve priority carefully)
  if foundDomain is 'M8'
    return [absReq, 'M8', true] if absReq of @arbiters # arbiter or API require
    throw new Error("modul8::analysis could not resolve an arbiter require for #{reqStr} from #{domain} - looked in M8")
  else if !isRelative(reqStr) and foundDomain is undefined and absReq of @arbiters
    return [absReq, 'M8', true] # in case of collisions with normal domains, if not relative, arbiters must have priority over any domains, hence this line


  #if foundDomain is 'npm' # explicit npm require or require from npm domain itself
  #  return npmResolve(absReq)

  # else we have to verify the file exists (if we know domain, easy, else, scan all, starting in requiree's domain)
  scannable = if foundDomain then [foundDomain] else [domain].concat(name for name of @domains when name isnt domain)

  if absReq[-1...] is '/'
    absReq += 'index'  # allow trailing slashes to indicate folder
    noTryFolder = true

  for dom in scannable
    # req ends in valid filename ?
    return [found, dom, false] if found = @finder(@domains[dom], absReq)

    # req ends in valid folder ?
    continue if noTryFolder # already done this test
    return [found, dom, false] if found = @finder(@domains[dom], absReq + '/index')

    packageJSONPath = path.join(absReq, 'package.json')
    if @finder(@domains[dom], packageJSONPath)
      json = JSON.parse(fs.readFileSync(path.join(@domains[dom], packageJSONPath)))
      mainPath = path.join(absReq, json.main)
      return [found, dom, false] if found = @finder(@domains[dom], mainPath)

  # could have gotten an absolute require of an npm module here do a final attempt to see if it is npm resolvable:
  #TODO:

  throw new Error("modul8::analysis could not resolve a require for #{reqStr} from #{domain} - looked in #{scannable}, trying extensions #{@exts[1...]}")

module.exports = {
  isLegalRequire
  Resolver
}
