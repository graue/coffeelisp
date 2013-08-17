class LispError extends Error
  constructor: (@message) ->

parseText = (txt) ->
  tokens = txt.replace(/([\(\)])/g, ' $1 ').trim().split(/\s+/)
  [tree, consumed] = parseTokens tokens
  if consumed < tokens.length
    throw new LispError 'Unexpected extra input: ' + tokens[consumed]
  tree

parseTokens = (tokens, start = 0) ->
  # Returns parse tree and number of tokens consumed.
  curToken = tokens[start]
  if curToken.match /^-?\d/
    [parseFloat(curToken), 1]
  else if curToken == '('
    index = start + 1
    parsedList = while tokens[index] != ')'
      [parsedElement, consumed] = parseTokens tokens, index
      index += consumed
      throw new LispError 'Unterminated list' if index >= tokens.length
      parsedElement
    [parsedList, index + 1 - start]
  else
    [curToken, 1]

# Make a shallow copy.
clone = (obj) ->
  copy = {}
  for key, val of obj
    copy[key] = val
  copy

class Lambda
  constructor: (@env, @argNames, @body) ->

  apply: (self, args) ->
    checkArgs @argNames.length, args.length, 'user-defined function'
    innerEnv = clone @env
    for arg, i in args
      innerEnv[@argNames[i]] = arg
    evalParsed @body, innerEnv

checkArgs = (expected, actual, thing) ->
  if expected != actual
    throw new LispError "Expected #{expected} args to #{thing}, got #{actual}"

withCheckedArgs = (func, numArgs, name) ->
  (args...) ->
    checkArgs numArgs, args.length, name
    func args...

# Test for truthiness for purposes of Lisp.
truthy = (x) -> x? and x != false

builtins =
  '+':       withCheckedArgs(((a, b) -> a + b),  2, '+')
  '-':       withCheckedArgs(((a, b) -> a - b),  2, '-')
  '*':       withCheckedArgs(((a, b) -> a * b),  2, '*')
  '/':       withCheckedArgs(((a, b) -> a / b),  2, '/')
  '<':       withCheckedArgs(((a, b) -> a < b),  2, '<')
  '>':       withCheckedArgs(((a, b) -> a > b),  2, '>')
  '<=':      withCheckedArgs(((a, b) -> a <= b), 2, '<=')
  '>=':      withCheckedArgs(((a, b) -> a >= b), 2, '>=')
  'eq?':     withCheckedArgs(((a, b) -> a == b), 2, 'eq?')
  'not':     withCheckedArgs(((a) -> not truthy(a)), 1, 'not')
  'number?': withCheckedArgs(((a) -> typeof a == 'number'), 1, 'number?')

evalParsed = (expr, bindings = {}) ->
  head = expr[0] if expr[0]?
  if head instanceof Array
    head = evalParsed head, bindings

  if typeof expr == 'number'
    expr
  else if typeof expr == 'string'
    if expr == '#t'
      true
    else if expr == '#f'
      false
    else
      throw new LispError "Unbound var #{expr}" if not bindings[expr]?
      bindings[expr]
  else if head == 'define'
    checkArgs 2, expr.length - 1, 'define'
    [name, value] = expr[1..2]
    bindings[name] = evalParsed value, bindings
    null
  else if head == 'quote'
    checkArgs 1, expr.length - 1, 'quote'
    expr[1]
  else if head == 'if'
    checkArgs 3, expr.length - 1, 'if'
    [pred, whenTrue, whenFalse] = expr[1..3]
    choice = if truthy(evalParsed(pred, bindings)) then whenTrue else whenFalse
    evalParsed(choice, bindings)
  else if head == 'lambda'
    checkArgs 2, expr.length - 1, 'lambda definition'
    [argNames, body] = expr[1..2]
    if argNames not instanceof Array
      throw new LispError "Expected argument list, got #{argNames}"
    new Lambda clone(bindings), argNames, body
  else if bindings[head]?.apply? or builtins[head]?.apply?
    func = bindings[head] or builtins[head]
    func.apply(func, expr[1..].map((expr) -> evalParsed expr, bindings))
  else
    badThing = if bindings[head]? 'Non-function' else 'Unbound var'
    throw new LispError "#{badThing} #{head} in head position"

evalText = (txt, bindings) ->
  parsed = parseText txt
  evalParsed parsed, bindings

writeVal = (val) ->
  if val instanceof Array
    '(' + (writeVal subval for subval in val).join(' ') + ')'
  else if typeof val == 'number'
    val.toString()
  else if val instanceof Lambda
    '[user-defined function]'
  else if val instanceof Function
    '[builtin function]'
  else if val == null
    'nil'
  else if val == true
    '#t'
  else if val == false
    '#f'
  else
    val

module.exports =
  parse: parseText
  eval: evalText
  write: writeVal
