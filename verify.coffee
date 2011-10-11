# this acts as an arbiter for all test suites
# to run: expresso verify

suites = []
suites.push require('./test/branches')

for suite in suites
  for key,val of suite when key[0...5] is 'test '
    exports[key] = val
