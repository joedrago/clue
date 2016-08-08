fs = require 'fs'

class ClueSolver
  constructor: ->
    @currentFilename = null
    @currentLineNumber = 0

  verbose: (text) ->
    console.log(text)

  fatalError: (reason) ->
    output = "Fatal Error"
    if @currentFilename
      output += " (#{@currentFilename}:#{@currentLineNumber})"
    output += ": #{reason}"
    console.error(output)
    process.exit(-1)

  addAxis: (title, cards) ->
    @verbose("Adding axis '#{title}': #{cards}")

  addPlayers: (players) ->
    @verbose("Adding players: #{players}")

  suggest: (player, cards) ->
    @verbose("Suggest (#{player}): #{cards}")

  saw: (player, card) ->
    @verbose("Saw (#{player}): #{card}")

  parseFile: (filename) ->
    @currentFilename = filename
    lines = fs.readFileSync(filename, 'utf8').replace(/\r/, '').split(/\n/)
    @currentLineNumber = 0
    for line in lines
      @currentLineNumber += 1
      continue if line.match(/^\s*#/)
      continue if line.match(/^\s*$/)
      words = line.split(/\s+/)
      action = words.shift()
      switch action
        when 'axis'
          title = words.shift()
          @addAxis(title, words)
        when 'players'
          @addPlayers(words)
        when 'suggest'
          player = words.shift()
          @suggest(player, words)
        when 'saw'
          player = words.shift()
          card = words.shift()
          @saw(player, card)
        else
          @fatalError "Unknown action: #{line}"
    @currentFilename = null

main = ->
  solver = new ClueSolver
  solver.parseFile("data.txt")
main()
