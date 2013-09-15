class LispError extends Error
  constructor: (@message) ->

class UnterminatedListError extends LispError

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
      if index >= tokens.length
        throw new UnterminatedListError 'Unterminated list'
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

checkList = (a, func) ->
  throw new LispError "Non-list argument to #{func}" unless a instanceof Array

checkNonEmptyList = (a, func) ->
  checkList a, func
  throw new LispError "Empty list passed to #{func}" if a.length == 0

car = (xs) ->
  checkNonEmptyList xs, 'car'
  xs[0]

cdr = (xs) ->
  checkNonEmptyList xs, 'cdr'
  xs.slice(1)

length = (xs) ->
  checkList xs, 'length'
  xs.length

writeOrLog = (str) ->
  if process?.stdout?
    process.stdout.write str
  else
    # console.log adds a newline at the end, so remove one if we can.
    if str[str.length-1] = '\n'
      str = str[0...str.length-1]
    console.log str
  null

display = (obj) ->
  writeOrLog writeVal obj

newline = () ->
  writeOrLog '\n'

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
  'car':     withCheckedArgs(car, 1, 'car')
  'cdr':     withCheckedArgs(cdr, 1, 'cdr')
  'length':  withCheckedArgs(length, 1, 'length')
  'display': withCheckedArgs(display, 1, 'display')
  'newline': withCheckedArgs(newline, 0, 'newline')

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
    badThing = if bindings[head]? then 'Non-function' else 'Unbound var'
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
  LispError: LispError
  UnterminatedListError: UnterminatedListError
