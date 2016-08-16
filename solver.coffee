fs = require 'fs'
path = require 'path'

MAX_PLAYERS = 20

verbose = (text) ->
  console.log("\n* #{text}")

log = (text) ->
  console.log(text)

fatalFilename = null
fatalLineNumber = 0
fatalError = (reason) ->
  output = "\nFatal Error"
  if @fatalFilename != null
    output += " (#{@fatalFilename}:#{@fatalLineNumber})"
  output += ": #{reason}"
  console.error(output)
  process.exit(-1)

class IndexedMap
  constructor: ->
    @clear()
  clear: ->
    @list = []
    @map = {}
  push: (name, obj) ->
    obj.name = name
    obj.index = @list.length
    @list.push obj
    @map[name] = obj

class Player
  constructor: (@fullName) ->

class Axis
  constructor: (@fullName, @prefix) ->

class Card
  constructor: (@axis, @fullName) ->
    @owner = null
    @cantOwn = new Array(MAX_PLAYERS).fill(false)

class ClueSolver
  constructor: ->
    @players = new IndexedMap
    @axes = new IndexedMap
    @cards = new IndexedMap
    @addPlayer('answer', 'Answer')

  addPlayer: (name, fullName) ->
    log "addPlayer(): #{Array.prototype.slice.call(arguments)}"
    player = new Player(fullName)
    @players.push(name, player)

  addAxis: (name, fullName, prefix) ->
    log "addAxis(): #{Array.prototype.slice.call(arguments)}"
    axis = new Axis(fullName, prefix)
    @axes.push(name, axis)

  addCard: (name, axisName, fullName) ->
    log "addCard(): #{Array.prototype.slice.call(arguments)}"
    card = new Card(axisName, fullName)
    @cards.push(name, card)

  hand: (cardNames) ->
    log "hand(): #{Array.prototype.slice.call(arguments)}"

  suggest: (playerName, cardAndPlayerNames) ->
    log "suggest(): #{Array.prototype.slice.call(arguments)}"

  saw: (playerName, cardName) ->
    log "saw(): #{Array.prototype.slice.call(arguments)}"

  dump: ->
  display: ->
    log @players
    # log @axes
    # log @cards

class ClueParser
  constructor: (@solver) ->
    @currentFilename = []
    @currentLineNumber = []

  parseFile: (filename) ->
    @currentFilename.push filename
    @currentLineNumber.push 0
    fatalFilename = filename
    lines = fs.readFileSync(filename, 'utf8').replace(/\r/, '').split(/\n/)
    for line in lines
      @currentLineNumber[@currentLineNumber.length-1] += 1
      fatalLineNumber = @currentLineNumber[@currentLineNumber.length-1]
      continue if line.match(/^\s*#/)
      continue if line.match(/^\s*$/)
      words = line.split(/\s+/).filter (x) -> x.match(/\S/)
      action = words.shift()
      switch action
        when 'include'
          includeFilename = line.match(/^include\s+(.*)/)[1]
          if includeFilename?
            currentDir = path.parse(filename).dir
            absFilename = path.resolve(currentDir, includeFilename)
            @parseFile(absFilename)
        when 'player'
          playerName = words.shift()
          fullName = words.join(' ')
          @solver.addPlayer(playerName, fullName)
        when 'axis'
          axisName = words.shift()
          fullName = words.shift()
          prefix = words.join(' ')
          @solver.addAxis(axisName, fullName, prefix)
        when 'card'
          cardName = words.shift()
          axisName = words.shift()
          fullName = words.join(' ')
          @solver.addCard(cardName, axisName, fullName)
        when 'hand'
          cardNames = words
          @solver.hand(cardNames)
        when 'suggest'
          playerName = words.shift()
          cardAndPlayerNames = words
          @solver.suggest(playerName, cardAndPlayerNames)
        when 'saw'
          playerName = words.shift()
          cardName = words.shift()
          @solver.saw(playerName, cardName)
        when 'dump'
          @solver.dump()
        else
          fatalError "Unknown action: #{line}"

    @currentFilename.pop()
    @currentLineNumber.pop()
    if @currentFilename.length > 0
      fatalFilename = @currentFilename[@currentFilename.length - 1]
      fatalLineNumber = @currentLineNumber[@currentLineNumber.length - 1]
    else
      fatalFilename = null
      fatalLineNumber = 0

syntax = ->
  console.log "coffee clue.coffee FILENAME"
  process.exit(1)

main = ->
  filename = process.argv.slice(2).shift()
  if filename == undefined
    syntax()
  solver = new ClueSolver
  parser = new ClueParser(solver)
  parser.parseFile(filename)
  solver.display()
main()
