lisp = require '../lisp'

# For more natural tests about plural subjects, define 'they'.
they = it

describe 'the parser', ->
  it 'parses numbers', ->
    expect(lisp.parse '243').toEqual 243
    expect(lisp.parse '-1667.5').toEqual -1667.5
  it 'parses symbols', ->
    expect(lisp.parse 'lambda').toEqual 'lambda'
  it 'parses lists', ->
    expect(lisp.parse '()').toEqual []
    expect(lisp.parse '(1337)').toEqual [1337]
    expect(lisp.parse '(+ 2 5)').toEqual ['+', 2, 5]
  it 'parses nested lists', ->
    expect(lisp.parse '((lambda (x) x) 4)').toEqual [['lambda', ['x'], 'x'], 4]
    expect(lisp.parse '(()(foobar 42))').toEqual [[], ['foobar', 42]]
  it 'knows that "-" is a function, not a number', ->
    expect(lisp.parse '(- 2 1)').toEqual ['-', 2, 1]

describe 'scalars', ->
  they 'evaluate to themselves if numeric', ->
    expect(lisp.eval '192').toEqual 192
  they 'refer to bindings', ->
    expect(lisp.eval 'foo', {'foo': 42}).toEqual 42
  they 'will throw if unbound', ->
    expect(() -> lisp.eval('bar', {'foo': 42})).toThrow()
  they 'can include booleans', ->
    expect(lisp.eval '#t').toEqual true
    expect(lisp.eval '#f').toEqual false

describe 'quoting', ->
  it 'quotes numbers', ->
    expect(lisp.eval '(quote 42)').toEqual 42
  it 'quotes strings', ->
    expect(lisp.eval '(quote foobar)').toEqual 'foobar'
    expect(lisp.eval '(quote lambda)').toEqual 'lambda'
  it 'quotes lists', ->
    expect(lisp.eval '(quote (a b c))').toEqual ['a', 'b', 'c']
    expect(lisp.eval '(quote (quote (a b)))').toEqual ['quote', ['a', 'b']]

describe 'if statement', ->
  it 'evaluates only the first thing if expression is true', ->
    expect(lisp.eval '(if #t 1 unbound-var)').toEqual 1
  it 'evaluates only the second thing if expression is false', ->
    expect(lisp.eval '(if #f unbound-var 2)').toEqual 2
  it 'treats 0 and empty list as true', ->
    expect(lisp.eval '(if 0 1 2)').toEqual 1
    expect(lisp.eval '(if (quote ()) 1 2)').toEqual 1
  it 'understands predicates', ->
    expect(lisp.eval '(if (eq? 0 0) 1 2)').toEqual 1
    expect(lisp.eval '(if (eq? 0 2) 1 2)').toEqual 2

describe 'builtin functions', ->
  they 'do math', ->
    expect(lisp.eval '(- (+ (* 4 8) (/ 3 6)) 1)').toEqual 31.5
  they 'negate booleans', ->
    expect(lisp.eval '(not #t)').toEqual false
    expect(lisp.eval '(not #f)').toEqual true

describe 'defined vars', ->
  they 'persist as long as bindings are reused', ->
    bindings = {}
    expect(lisp.eval '(define fingers 10)', bindings).toBeNull()
    expect(lisp.eval '(define fingersPerHand (/ fingers 2))',
      bindings).toBeNull()
    expect(lisp.eval 'fingersPerHand', bindings).toEqual 5

describe 'error checking', ->
  bindings = null
  ex = null

  beforeEach ->
    bindings = {}
    ex = null
    lisp.eval '(define foo 42)', bindings

  it 'catches using an unbound var', ->
    try
      lisp.eval '(+ foo bar)', bindings
    catch exception
      ex = exception
    expect(ex instanceof lisp.LispError).toBeTruthy()
    expect(ex.message).toEqual 'Unbound var bar'

  it 'catches unbound vars in head position', ->
    try
      lisp.eval '(bar foo)', bindings
    catch exception
      ex = exception
    expect(ex instanceof lisp.LispError).toBeTruthy()
    expect(ex.message).toEqual 'Unbound var bar in head position'

  it 'catches non-functions in head position', ->
    try
      lisp.eval '(foo bar)', bindings
    catch exception
      ex = exception
    expect(ex instanceof lisp.LispError).toBeTruthy()
    expect(ex.message).toEqual 'Non-function foo in head position'
