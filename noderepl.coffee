fs = require 'fs'
lisp = require './lisp'

if process.argv[2]
  fs.readFile process.argv[2], {encoding: 'utf8'}, (err, data) ->
    console.log lisp.write lisp.eval data if not err
else
  rl = require('readline').createInterface {
    input: process.stdin
    output: process.stdout
  }
  rl.setPrompt '> '
  bindings = {}
  text = ''
  rl.on 'line', (newText) ->
    try
      text += newText
      result = lisp.eval text, bindings
      console.log lisp.write result
      text = ''
      rl.setPrompt '> '
    catch ex
      if ex instanceof lisp.UnterminatedListError
        # Assume the user just isn't finished typing, and give them a new line.
        rl.setPrompt '..'
      else
        console.log "Error: #{ex.message}"
        text = ''
        rl.setPrompt '> '
    rl.prompt()
  rl.on 'close', () ->
    console.log ''
    process.exit()
  rl.prompt()
