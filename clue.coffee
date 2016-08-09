fs = require 'fs'

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
    @log("Adding axis '#{axis}': #{cardNames}")
    if @playerlist.length < 3
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
        solution: null # can be true or false (null is unknown)
      for player in @playerlist
        card.cantOwn.push false
      if not @axes[axisName]?
        axis =
          name: axisName
          cards: []
          index: @axeslist.length
          solution: null
        @axes[axisName] = axis
        @axeslist.push axis
      @axes[axisName].cards.push card
      @cards[name] = card
      @cardlist.push card
      card.axisIndex = @axes[axisName].index

  addPlayers: (playerNames) ->
    @log("Adding players: #{playerNames}")
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

    card.owner = playerName
    for player, index in @playerlist
      if player.name != playerName
        card.cantOwn[index] = true
    @log "#{playerName} shows you a card: #{cardName}"
    @think(true)

  suggest: (playerName, cardNames) ->
    @verbose("Suggest (#{playerName}): #{cardNames}")
    axisCards = []
    nobodyShowedCard = false
    playersShowing = {}
    playersShowingCount = 0
    for axis in @axeslist
      axisCards.push null
    for cardName in cardNames
      if cardName == '-'
        nobodyShowedCard = true
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
    for axisCard, index in axisCards
      if axisCard == null
        @fatalError "Suggestion missing axis: #{@axeslist[index].name}"

    if playersShowingCount == @axeslist.length
      # All axes were shown, tag them all as not-the-solution
      for card in axisCards
        card.solution = false
    for player in @playerlist
      if not playersShowing[player.name]
        for card in axisCards
          card.cantOwn[player.index] = true

    @think()

    cardNameList = (card.name for card in axisCards)
    playersShowingList = Object.keys(playersShowing).sort()
    if playersShowingList.length == 0
      playersShowingList = "Nobody"
    @log("#{playerName} suggested [#{cardNameList}]. [#{playersShowingList}] showed a card.")
    for card in axisCards
      if card.solution == true
        info = "part of solution"
      else if card.owner
        info = "owned by #{card.owner}"
      else
        possibleOwners = []
        for player, index in @playerlist
          if not card.cantOwn[index]
            possibleOwners.push player.name
        info = "possible owners: #{possibleOwners}"

      @log("    #{card.name} - #{info}")

  think: (comingFromSaw=false) ->
    for card in @cardlist
      if card.owner == null
        someoneCanOwn = false
        for player, index in @playerlist
          if !card.cantOwn[index]
            someoneCanOwn = true
        if not someoneCanOwn
          if card.solution == null
            console.log "** Discovery! Part of the solution: #{card.name} **"
            card.solution = true
            @axeslist[card.axisIndex].solution = card.name

  display: ->

main = ->
  solver = new ClueSolver
  solver.parseFile("data.txt")
  solver.display()
main()
