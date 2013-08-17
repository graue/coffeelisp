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
  rl.on 'line', (text) ->
    try
      result = lisp.eval text, bindings
      console.log lisp.write result
    catch ex
      console.log "Error: #{ex.message}"
    rl.prompt()
  rl.on 'close', () ->
    process.exit()
  rl.prompt()
