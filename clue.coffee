fs = require 'fs'

pad = (val, length, padChar = ' ') ->
  val += ''
  numPads = length - val.length
  if (numPads > 0) then new Array(numPads + 1).join(padChar) + val else val

class ClueSolver
  constructor: ->
    # For parseFile errors
    @currentFilename = null
    @currentLineNumber = 0

    # card database
    @cards = {}
    @cardlist = []

    # axis database
    @axes = {}
    @axeslist = []

    # player database
    @players = {}
    @playerlist = []

  verbose: (text) ->
    console.log("\n* #{text}")

  log: (text) ->
    console.log(text)

  fatalError: (reason) ->
    output = "\nFatal Error"
    if @currentFilename
      output += " (#{@currentFilename}:#{@currentLineNumber})"
    output += ": #{reason}"
    console.error(output)
    process.exit(-1)

  parseFile: (filename) ->
    @currentFilename = filename
    lines = fs.readFileSync(filename, 'utf8').replace(/\r/, '').split(/\n/)
    @currentLineNumber = 0
    for line in lines
      @currentLineNumber += 1
      continue if line.match(/^\s*#/)
      continue if line.match(/^\s*$/)
      words = line.split(/\s+/).filter (x) -> x.match(/\S/)
      action = words.shift()
      switch action
        when 'axis'
          axisName = words.shift()
          @addAxis(axisName, words)
        when 'players'
          @addPlayers(words)
        when 'hand'
          @hand(words)
        when 'suggest'
          playerName = words.shift()
          @suggest(playerName, words)
        when 'dump'
          @dump()
        when 'saw'
          playerName = words.shift()
          cardName = words.shift()
          @saw(playerName, cardName)
        else
          @fatalError "Unknown action: #{line}"
    @currentFilename = null

  dump: ->
    return
    console.log JSON.stringify(@players, null, 2)
    console.log JSON.stringify(@axes, null, 2)

  addAxis: (axisName, cardNames) ->
    @log("Adding axis '#{axisName}': #{cardNames}")
    if @playerlist.length < 1
      @fatalError "Please add players before defining an axis"
    for name in cardNames
      if @cards[name]?
        @fatalError("Card '#{name}' already exists!")
      card =
        name: name
        axis: axisName
        cantOwn: []
        owner: null
        index: @cardlist.length
        answer: null # can be true or false (null is unknown)
      for player in @playerlist
        card.cantOwn.push false
      if not @axes[axisName]?
        axis =
          name: axisName
          cards: []
          index: @axeslist.length
          answer: null
        @axes[axisName] = axis
        @axeslist.push axis
      @axes[axisName].cards.push card
      @cards[name] = card
      @cardlist.push card
      card.axisIndex = @axes[axisName].index

  addPlayers: (playerNames) ->
    @log("Adding players: #{playerNames}")
    if @playerlist.length > 0
      @fatalError "Please add all players in a single line"
    for name in playerNames
      player =
        name: name
        index: @playerlist.length
      @players[name] = player
      @playerlist.push player

  hand: (cardNames) ->
    cardInHand = {}
    for cardName in cardNames
      if not @cards[cardName]?
        @fatalError "unknown card #{cardName}"
      cardInHand[cardName] = true
      card = @cards[cardName]
      card.owner = @playerlist[0].name
      for player, index in @playerlist
        if index != 0
          card.cantOwn[index] = true
    for card in @cardlist
      if !cardInHand[card.name]
        card.cantOwn[0] = true

    @log "Your hand: #{cardNames}"

  saw: (playerName, cardName) ->
    @verbose("Saw (#{playerName}): #{cardName}")
    if not @players[playerName]?
      @fatalError "unknown player #{playerName}"
    if not @cards[cardName]?
      @fatalError "unknown card #{cardName}"

    card = @cards[cardName]
    if (card.owner != null) and (card.owner != playerName)
      @fatalError "Two people cant own #{card.name}: #{card.owner} and (now) #{playerName}"

    previousKnowledge = ""
    if card.owner == playerName
      previousKnowledge = "(already known)"
    card.owner = playerName
    for player, index in @playerlist
      if player.name != playerName
        card.cantOwn[index] = true
    @log "#{playerName} shows you a card: #{cardName} #{previousKnowledge}"
    @think()

  suggest: (playerName, cardNames) ->
    @verbose("Suggest (#{playerName}): #{cardNames}")

    # Organize mishmashed list of card/player names into one card per axis
    # and the list of players who showed a card. Error out appropriately if
    # we don't get exactly one card per axis, and either 1+ player names or '-'.
    axisCards = []
    nobodyMarkerPresent = false
    playersShowing = {}
    playersShowingCount = 0
    for axis in @axeslist
      axisCards.push null
    for cardName in cardNames
      if cardName == '-'
        nobodyMarkerPresent = true
      else if @cards[cardName]?
        card = @cards[cardName]
        if axisCards[card.axisIndex] != null
          @fatalError("suggesting two cards from the same axis! (#{@axeslist[card.axisIndex].name}: #{axisCards[card.axisIndex].name} and #{card.name})")
        axisCards[card.axisIndex] = card
      else
        if not @players[cardName]?
          @fatalError "unknown card or player #{cardName}"
        playersShowing[cardName] = true
        playersShowingCount += 1
    if nobodyMarkerPresent and (playersShowingCount > 0)
      @fatalError("Using 'nobody' marker (-) along with a player name")
    if (playersShowingCount == 0) and not nobodyMarkerPresent
      @fatalError("No player names and 'nobody' marker (-) is absent")
    for axisCard, index in axisCards
      if axisCard == null
        @fatalError "Suggestion missing axis: #{@axeslist[index].name}"

    # If there was one card shown for each axis, nothing in this suggestion
    # is a part of the answer. Mark it explicitly.
    if playersShowingCount == @axeslist.length
      for card in axisCards
        card.answer = false

    # Tag all players that didn't show a card during this suggestion as being
    # incapable of owning the suggested cards. Don't do this to the person
    # performing the suggestion, however, as it is a common strategy to
    # suggest cards in your hand.
    for player in @playerlist
      if (player.name != playerName) and not playersShowing[player.name]
        for card in axisCards
          card.cantOwn[player.index] = true

    @think()

    cardNameList = (card.name for card in axisCards)
    playersShowingList = Object.keys(playersShowing).sort()
    if playersShowingList.length == 0
      playersShowingList = "Nobody"
    @log("#{playerName} suggested [#{cardNameList}]. [#{playersShowingList}] showed a card.")
    for card in axisCards
      info = @cardInfo(card)
      @log("#{pad(card.name, 15)} - #{info}")

  think: ->
    # Find cards that nobody can possibly own, mark them as part of the answer.
    for card in @cardlist
      if card.owner == null
        someoneCanOwn = false
        for player, index in @playerlist
          if !card.cantOwn[index]
            someoneCanOwn = true
        if not someoneCanOwn
          if card.answer == null
            console.log "** Discovery! Part of the answer: #{card.name} **"
            card.answer = true
            @axeslist[card.axisIndex].answer = card.name
            for notAnswer in @axeslist[card.axisIndex].cards
              if notAnswer.answer != true
                notAnswer.answer = false

    # Look for any axis that has only one possible answer left
    for axis in @axeslist
      onlyAnswer = null
      for card in axis.cards
        if card.answer == true
          onlyAnswer = null
          break
        if card.answer == false
          continue
        if card.owner == null
          if onlyAnswer == null
            onlyAnswer = card
          else
            onlyAnswer = null
            break
      if onlyAnswer != null
        console.log "** Discovery! Part of the answer: #{onlyAnswer.name} **"
        onlyAnswer.answer = true
        @axeslist[card.axisIndex].answer = card.name
        for notAnswer in @axeslist[onlyAnswer.axisIndex].cards
          if notAnswer.answer != true
            notAnswer.answer = false

  cardInfo: (card) ->
    if card.answer == true
      info = "*ANSWER*"
    else if card.owner
      info = card.owner
    else
      possibleOwners = []
      if card.answer != false
        possibleOwners.push "answer"
      for player, index in @playerlist
        if not card.cantOwn[index]
          possibleOwners.push player.name
      info = "?           (" + possibleOwners.join("/") + ")"
    return info

  display: ->
    @log "-------------------------------------------------------------------"
    for axis in @axeslist
      @log "\n#{pad(axis.name, 15)}"
      @log "#{pad(pad('', axis.name.length, '-'), 15)}"
      for card in axis.cards
        @log "#{pad(card.name, 15)} - " + @cardInfo(card)
    @log ""

syntax = ->
  console.log "coffee clue.coffee FILENAME"
  process.exit(1)

main = ->
  filename = process.argv.slice(2).shift()
  if filename == undefined
    syntax()
  solver = new ClueSolver
  solver.parseFile(filename)
  solver.display()
main()
