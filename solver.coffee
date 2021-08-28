fs = require 'fs'
path = require 'path'

colour = require './colour.min.js'
colour.setTheme {
  playerColor: 'cyan bold'
  answerColor: 'yellow bold'
  cardColor: 'bold'
  axis1Color: 'magenta bold'
  axis2Color: 'green bold'
  axis3Color: 'blue bold'
  indexColor: 'yellow'
}
axisColors = [
  colour.axis1Color
  colour.axis2Color
  colour.axis3Color
]

MAX_PLAYERS = 10 # eww, fix

setOutputMode = (mode) ->
  switch mode
    when 'none', 'colorless', 'bland'
      colour.mode = 'none'
    when 'browser'
      console.log "<body bgcolor='black'><pre style='color: white'>"
      colour.mode = 'browser'

journal = (text) ->
  console.log("#{text}")

log = (text) ->
  console.log(text)

pad = (val, length, padChar = ' ') ->
  val += ''
  numPads = length - val.length
  if (numPads > 0) then new Array(numPads + 1).join(padChar) + val else val

spaces = (count) ->
  s = ""
  for i in [0...count]
    s += " " #eww?
  return s

removeFromArray = (array, value) ->
  return array.filter (v) -> v != value

fatalFilename = null
fatalLineNumber = 0
fatalError = (reason) ->
  output = "\nFatal Error"
  if fatalFilename != null
    output += " (#{fatalFilename}:#{fatalLineNumber})"
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
  exists: (name) ->
    return @map.hasOwnProperty(name)

class Player
  constructor: (@fullName) ->
    @notes = []
  addNote: (note) ->
    @notes.push note

class Axis
  constructor: (@fullName, @prefix) ->
    @cards = []
  display: (solver) ->
    log "#{@color(@fullName)}"
    for card in @cards
      card.display(solver)

class Card
  constructor: (@axis, @fullName) ->
    @couldOwn = new Array(MAX_PLAYERS).fill(true)
    @owner = null
    @notes = []
  addNote: (note) ->
    @notes.push note
    journal "      #{@axis.color(@fullName)}: #{note}"
  display: (solver) ->
    ownerString = ""
    if @owner == null
      possibleOwners = []
      for player, index in solver.players.list
        if @couldOwn[index]
          possibleOwners.push player.fullName
      ownerString = possibleOwners.join('/')
    else
      if solver.players.map[@owner].index == 0
        ownerString = solver.players.map[@owner].fullName.answerColor
      else
        ownerString = solver.players.map[@owner].fullName.playerColor
    log "      #{@fullName.cardColor} #{spaces(20-@fullName.length)} #{ownerString}"

class Suggestion
  constructor: (@suggester, @cardNames, @playerNames, @index) ->
  describe: ->
    return "Suggestion[#{String(@index).indexColor}]"

class ClueSolver
  constructor: ->
    @players = new IndexedMap
    @axes = new IndexedMap
    @cards = new IndexedMap
    @suggestions = []
    @addPlayer('answer', 'Answer')

  addPlayer: (name, fullName) ->
    alreadyExists = @exists(name)
    if alreadyExists
      fatalError "#{name} already exists as a #{alreadyExists}"
    player = new Player(fullName)
    if @players.list.length > 0
      journal "#{fullName.playerColor} joins the game."
    @players.push(name, player)
    if @players.length > MAX_PLAYERS
      fatalError "Too many players! (#{MAX_PLAYERS} is the limit)"

  addAxis: (name, fullName, prefix) ->
    if @axes.exists(name)
      fatalError "#{name} already exists as an axis"
    axis = new Axis(fullName, prefix)
    @axes.push(name, axis)
    axis.color = axisColors[axis.index % axisColors.length]

  addCard: (name, axisName, fullName) ->
    alreadyExists = @exists(name)
    if alreadyExists
      fatalError "#{name} already exists as a #{alreadyExists}"
    if not @axes.exists(axisName)
      fatalError "#{axisName} is not an axis"
    card = new Card(@axes.map[axisName], fullName)
    @cards.push(name, card)
    @axes.map[axisName].cards.push card

  exists: (name) ->
    if @cards.exists(name)
      return 'card'
    if @players.exists(name)
      return 'player'
    return false

  hand: (ownerName, cardNames) ->
    owner = @players.map[ownerName]
    if not ownerName
      fatalError "unknown player #{playerName}"

    fullNames = []
    for cardName in cardNames
      card = @cards.map[cardName]
      fullNames.push card.axis.color(card.fullName)
    journal "#{owner.fullName.playerColor}'s hand: #{fullNames.join(', ')}"

    ownedByThisPlayer = {}
    for cardName in cardNames
      ownedByThisPlayer[cardName] = true

      # Set the card's owner, and mark all other players as can't own
      card = @cards.map[cardName]
      card.owner = owner.name
      card.addNote "Owned by #{owner.fullName.playerColor}, (in hand)"
      for player, index in @players.list
        couldOwn = (index == owner.index)
        if card.couldOwn[index] != couldOwn
          card.couldOwn[index] = couldOwn

    for card in @cards.list
      # We have the whole hand of this player. Mark all other cards as unownable for them.
      if not ownedByThisPlayer[card.name]
        card.couldOwn[owner.index] = false
        card.addNote "#{owner.fullName.playerColor} can't own, entire hand is known"

  suggest: (suggester, cardNames, playerNames) ->
    # Remember our suggestion for future replays
    suggestion = new Suggestion(suggester, cardNames, playerNames, @suggestions.length)
    @suggestions.push suggestion

    # Journal suggestion
    fullSuggesterName = @players.map[suggester].fullName
    suggestionPieces = []
    for cardName in cardNames
      card = @cards.map[cardName]
      axis = card.axis
      suggestionPieces.push "#{axis.prefix}#{axis.color(card.fullName)}"
    suggestionText = suggestionPieces.join(" ")
    fullPlayerNames = (@players.map[playerName].fullName.playerColor for playerName in playerNames)
    if fullPlayerNames.length == 0
      shows = "Nobody shows"
    else if fullPlayerNames.length == 1
      shows = "shows"
    else
      shows = "show"
    journal "\n[#{pad(suggestion.index, 3).indexColor}] #{fullSuggesterName.playerColor} suggests #{suggestionText}. #{fullPlayerNames.join(', ')} #{shows} a card."

    # Check that every axis has exactly one card in the suggestion
    axisSeen = new Array(@axes.list.length).fill(false)
    for cardName in cardNames
      card = @cards.map[cardName]
      if not card
        fatalError "unknown card #{cardName}"
      axisIndex = card.axis.index
      if axisSeen[axisIndex]
        fatalError "suggestion contains two cards from the #{card.axis.fullName} axis"
      axisSeen[axisIndex] = true
    for seen, axisIndex in axisSeen
      if not seen
        fatalError "suggestion missing axis #{@axes.list[axisIndex].fullName}"

    # If there was one card shown for each axis, nothing in this suggestion
    # is a part of the answer. Mark it explicitly.
    if playerNames.length == cardNames.length
      for cardName in cardNames
        card = @cards.map[cardName]
        if card.couldOwn[0]
          card.couldOwn[0] = false
          card.addNote "Not in answer, everyone showed a card during #{suggestion.describe()}"

    # Make a lookup table for all players that showed a card
    playerShowedACard = {}
    for playerName in playerNames
      playerShowedACard[playerName] = true

    # Tag all players that didn't show a card during this suggestion as being
    # incapable of owning the suggested cards. Don't do this to the person
    # performing the suggestion, however, as it is a common strategy to
    # suggest cards in your hand.
    for player in @players.list
      if ((playerNames.length == cardNames.length) or (player.name != suggester)) and not playerShowedACard[player.name] and (player.index != 0)
        for cardName in cardNames
          card = @cards.map[cardName]
          if card.couldOwn[player.index]
            card.couldOwn[player.index] = false
            card.addNote "#{player.fullName.playerColor} can't own, they didn't show a card during #{suggestion.describe()}"

    # See if we can find any cards with only one possible owner
    @findOwners(suggestion)

    # Display the known ownership state of the suggested cards
    log ""
    for cardName in cardNames
      card = @cards.map[cardName]
      card.display(this)

  saw: (ownerName, cardName) ->
    # log "saw(): #{Array.prototype.slice.call(arguments)}"

    owner = @players.map[ownerName]
    if not ownerName
      fatalError "unknown player #{playerName}"
    card = @cards.map[cardName]
    if not card
      fatalError "unknown card #{cardName}"

    alreadyKnown = ""
    if card.owner == owner.name
      alreadyKnown = " (already known)"
    else if card.owner != null
      fatalError "trying to set owner of #{card.name} to #{owner.name}, but #{card.owner} already owns it"

    journal "\n**    #{owner.fullName.playerColor} shows #{card.axis.color(card.fullName)}#{alreadyKnown}."

    if card.owner != owner.name
      # Set the card's owner, and mark all other players as can't own
      card.owner = owner.name
      card.addNote "Owned by #{owner.fullName.playerColor}, card shown"
      for player, index in @players.list
        card.couldOwn[index] = (index == owner.index)

    # See if we can find any cards with only one possible owner
    action =
      describe: -> "being shown #{card.axis.color(card.fullName)} by #{owner.name.playerColor}"
    @findOwners(action)

  findOwners: (action) ->
    potentialNewOwners = true
    while potentialNewOwners
      potentialNewOwners = false

      # Find cards with exactly one owner left
      for card in @cards.list
        if card.owner == null
          ownerCount = 0
          ownerIndex = -1
          for player, index in @players.list
            if card.couldOwn[index]
              ownerCount += 1
              ownerIndex = index
          if ownerCount == 0
            fatalError "Nobody can possibly own #{card.fullName}"
          if ownerCount == 1
            potentialNewOwners = true
            owner = @players.list[ownerIndex]
            card.owner = owner.name
            for player, index in @players.list
              card.couldOwn[index] = (index == owner.index)
            if ownerIndex == 0
              card.addNote "Part of the #{@players.list[0].fullName.answerColor}, discovered after #{action.describe()}"
              for axisCard in card.axis.cards
                continue if axisCard.index == card.index
                if axisCard.couldOwn[0]
                  axisCard.couldOwn[0] = false
                  axisCard.addNote "Not in answer, since #{card.axis.color(card.fullName)} is the answer, discovered after #{action.describe()}"
            else
              card.addNote "Owned by #{owner.fullName}, only possible owner, discovered after #{action.describe()}"

      # Find axes with only one possible Answer
      for axis in @axes.list
        answerCount = 0
        answerIndex = -1
        for card in axis.cards
          if card.owner == null
            if card.couldOwn[0] # Can this card be in the answer?
              answerCount += 1
              answerIndex = card.index
          else
            owner = @players.map[card.owner]
            if owner.index == 0
              # Already have an Answer for this axis, move on
              answerCount = 0
              break
        if answerCount == 1
          potentialNewOwners = true
          card = @cards.list[answerIndex]
          owner = @players.list[0] # Answer
          card.owner = owner.name
          for player, index in @players.list
            card.couldOwn[index] = (index == owner.index)
          card.addNote "Part of the #{@players.list[0].fullName.answerColor}, only possible choice in #{axis.color(axis.fullName)} left, discovered after #{action.describe()}"

      # Replay suggestions, attempting to match up owners with the cards they must have shown
      for suggestion in @suggestions
        unownedCards = []
        leftoverPlayers = suggestion.playerNames.slice(0)
        for cardName in suggestion.cardNames
          card = @cards.map[cardName]
          if card.owner == null
            unownedCards.push cardName
          else
            leftoverPlayers = removeFromArray(leftoverPlayers, card.owner)
        if (unownedCards.length == 1) and (leftoverPlayers.length == 1)
          potentialNewOwners = true
          ownerName = leftoverPlayers[0]
          owner = @players.map[ownerName]
          card = @cards.map[unownedCards[0]]
          card.owner = ownerName
          for player, index in @players.list
            card.couldOwn[index] = (index == owner.index)
          card.addNote "Owned by #{owner.fullName.playerColor}, owners of all other shown cards known, discovered by replaying #{suggestion.describe()}"

  dump: ->
  display: ->
    log ""
    for axis in @axes.list
      axis.display(this)

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
          if prefix.length > 0
            prefix += " "
          @solver.addAxis(axisName, fullName, prefix)
        when 'card'
          axisName = words.shift()
          cardName = words.shift()
          fullName = words.join(' ')
          @solver.addCard(cardName, axisName, fullName)
        when 'hand'
          playerName = words.shift()
          cardNames = words
          @solver.hand(playerName, cardNames)
        when 'suggest'
          playerName = words.shift()
          cardNames = []
          playerNames = []
          for name in words
            continue if name == '-' # TODO: use as assert 'nobody showed'
            type = @solver.exists(name)
            switch type
              when 'card'
                cardNames.push name
              when 'player'
                playerNames.push name
              else
                fatalError "Unknown card or player name: #{name}"
          @solver.suggest(playerName, cardNames, playerNames)
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
  console.log "coffee clue.coffee [-b|-n] FILENAME"
  process.exit(1)

main = ->
  args = process.argv.slice(2)
  for arg in args
    if arg == '-n'
      setOutputMode('none')
    else if arg == '-b'
      setOutputMode('browser')
    else
      filename = arg
  if filename == undefined
    syntax()

  solver = new ClueSolver
  parser = new ClueParser(solver)
  parser.parseFile(filename)
  solver.display()

main()
