const fs = require("fs")
const path = require("path")

const colour = require("./colour.min.js")
colour.setTheme({
    playerColor: "cyan bold",
    answerColor: "yellow bold",
    cardColor: "bold",
    axis1Color: "magenta bold",
    axis2Color: "green bold",
    axis3Color: "blue bold",
    indexColor: "yellow"
})
const axisColors = [colour.axis1Color, colour.axis2Color, colour.axis3Color]

const MAX_PLAYERS = 10 // eww, fix

function setOutputMode(mode) {
    switch (mode) {
        case "none":
        case "colorless":
        case "bland":
            colour.mode = "none"
            break
        case "browser":
            console.log("<body bgcolor='black'><pre style='color: white'>")
            colour.mode = "browser"
            break
    }
}

function journal(text) {
    console.log(`${text}`)
}

function log(text) {
    console.log(text)
}

function pad(val, length, padChar = " ") {
    val += ""
    const numPads = length - val.length
    if (numPads > 0) {
        return new Array(numPads + 1).join(padChar) + val
    }
    return val
}

function spaces(count) {
    let s = ""
    for (let i = 0, end = count; i < end; i++) {
        s += " "
    } //eww?
    return s
}

const removeFromArray = (array, value) => array.filter((v) => v !== value)

let fatalFilename = null
let fatalLineNumber = 0
function fatalError(reason) {
    let output = "\nFatal Error"
    if (fatalFilename !== null) {
        output += ` (${fatalFilename}:${fatalLineNumber})`
    }
    output += `: ${reason}`
    console.error(output)
    process.exit(-1)
}

class IndexedMap {
    constructor() {
        this.clear()
    }
    clear() {
        this.list = []
        this.map = {}
    }
    push(name, obj) {
        obj.name = name
        obj.index = this.list.length
        this.list.push(obj)
        this.map[name] = obj
    }
    exists(name) {
        return this.map.hasOwnProperty(name)
    }
}

class Player {
    constructor(fullName) {
        this.fullName = fullName
        this.notes = []
    }
    addNote(note) {
        this.notes.push(note)
    }
}

class Axis {
    constructor(fullName, prefix) {
        this.fullName = fullName
        this.prefix = prefix
        this.cards = []
    }
    display(solver) {
        log(`${this.color(this.fullName)}`)
        for (var card of this.cards) {
            card.display(solver)
        }
    }
}

class Card {
    constructor(axis, fullName) {
        this.axis = axis
        this.fullName = fullName
        this.couldOwn = new Array(MAX_PLAYERS).fill(true)
        this.owner = null
        this.notes = []
    }
    addNote(note) {
        this.notes.push(note)
        journal(`      ${this.axis.color(this.fullName)}: ${note}`)
    }
    display(solver) {
        let index
        let ownerString = ""
        if (this.owner === null) {
            const possibleOwners = []
            for (index = 0; index < solver.players.list.length; index++) {
                var player = solver.players.list[index]
                if (this.couldOwn[index]) {
                    possibleOwners.push(player.fullName)
                }
            }
            ownerString = possibleOwners.join("/")
        } else {
            if (solver.players.map[this.owner].index === 0) {
                ownerString = solver.players.map[this.owner].fullName.answerColor
            } else {
                ownerString = solver.players.map[this.owner].fullName.playerColor
            }
        }
        log(`      ${this.fullName.cardColor} ${spaces(20 - this.fullName.length)} ${ownerString}`)
    }
}

class Suggestion {
    constructor(suggester, cardNames, playerNames, index) {
        this.suggester = suggester
        this.cardNames = cardNames
        this.playerNames = playerNames
        this.index = index
    }
    describe() {
        return `Suggestion[${String(this.index).indexColor}]`
    }
}

class ClueSolver {
    constructor() {
        this.players = new IndexedMap()
        this.axes = new IndexedMap()
        this.cards = new IndexedMap()
        this.suggestions = []
        this.addPlayer("answer", "Answer")
    }

    addPlayer(name, fullName) {
        const alreadyExists = this.exists(name)
        if (alreadyExists) {
            fatalError(`${name} already exists as a ${alreadyExists}`)
        }
        const player = new Player(fullName)
        if (this.players.list.length > 0) {
            journal(`${fullName.playerColor} joins the game.`)
        }
        this.players.push(name, player)
        if (this.players.length > MAX_PLAYERS) {
            fatalError(`Too many players! (${MAX_PLAYERS} is the limit)`)
        }
    }

    addAxis(name, fullName, prefix) {
        if (this.axes.exists(name)) {
            fatalError(`${name} already exists as an axis`)
        }
        const axis = new Axis(fullName, prefix)
        this.axes.push(name, axis)
        axis.color = axisColors[axis.index % axisColors.length]
    }

    addCard(name, axisName, fullName) {
        const alreadyExists = this.exists(name)
        if (alreadyExists) {
            fatalError(`${name} already exists as a ${alreadyExists}`)
        }
        if (!this.axes.exists(axisName)) {
            fatalError(`${axisName} is not an axis`)
        }
        const card = new Card(this.axes.map[axisName], fullName)
        this.cards.push(name, card)
        this.axes.map[axisName].cards.push(card)
    }

    exists(name) {
        if (this.cards.exists(name)) {
            return "card"
        }
        if (this.players.exists(name)) {
            return "player"
        }
        return false
    }

    hand(ownerName, cardNames) {
        let card, cardName, couldOwn, index
        const owner = this.players.map[ownerName]
        if (!ownerName) {
            fatalError(`unknown player ${playerName}`)
        }

        const fullNames = []
        for (cardName of cardNames) {
            card = this.cards.map[cardName]
            fullNames.push(card.axis.color(card.fullName))
        }
        journal(`${owner.fullName.playerColor}'s hand: ${fullNames.join(", ")}`)

        const ownedByThisPlayer = {}
        for (cardName of cardNames) {
            ownedByThisPlayer[cardName] = true

            // Set the card's owner, and mark all other players as can't own
            card = this.cards.map[cardName]
            card.owner = owner.name
            card.addNote(`Owned by ${owner.fullName.playerColor}, (in hand)`)
            for (index = 0; index < this.players.list.length; index++) {
                var player = this.players.list[index]
                couldOwn = index === owner.index
                if (card.couldOwn[index] !== couldOwn) {
                    card.couldOwn[index] = couldOwn
                }
            }
        }

        for (card of this.cards.list) {
            // We have the whole hand of this player. Mark all other cards as unownable for them.
            if (!ownedByThisPlayer[card.name]) {
                card.couldOwn[owner.index] = false
                card.addNote(`${owner.fullName.playerColor} can't own, entire hand is known`)
            }
        }
    }

    suggest(suggester, cardNames, playerNames) {
        // Remember our suggestion for future replays
        let axis, axisIndex, card, cardName, playerName, shows
        const suggestion = new Suggestion(suggester, cardNames, playerNames, this.suggestions.length)
        this.suggestions.push(suggestion)

        // Journal suggestion
        const fullSuggesterName = this.players.map[suggester].fullName
        const suggestionPieces = []
        for (cardName of cardNames) {
            card = this.cards.map[cardName]
            ;({ axis } = card)
            suggestionPieces.push(`${axis.prefix}${axis.color(card.fullName)}`)
        }
        const suggestionText = suggestionPieces.join(" ")
        const fullPlayerNames = []
        for (playerName of playerNames) {
            fullPlayerNames.push(this.players.map[playerName].fullName.playerColor)
        }
        if (fullPlayerNames.length === 0) {
            shows = "Nobody shows"
        } else if (fullPlayerNames.length === 1) {
            shows = "shows"
        } else {
            shows = "show"
        }
        journal(
            `\n[${pad(suggestion.index, 3).indexColor}] ${
                fullSuggesterName.playerColor
            } suggests ${suggestionText}. ${fullPlayerNames.join(", ")} ${shows} a card.`
        )

        // Check that every axis has exactly one card in the suggestion
        const axisSeen = new Array(this.axes.list.length).fill(false)
        for (cardName of cardNames) {
            card = this.cards.map[cardName]
            if (!card) {
                fatalError(`unknown card ${cardName}`)
            }
            axisIndex = card.axis.index
            if (axisSeen[axisIndex]) {
                fatalError(`suggestion contains two cards from the ${card.axis.fullName} axis`)
            }
            axisSeen[axisIndex] = true
        }
        for (axisIndex = 0; axisIndex < axisSeen.length; axisIndex++) {
            var seen = axisSeen[axisIndex]
            if (!seen) {
                fatalError(`suggestion missing axis ${this.axes.list[axisIndex].fullName}`)
            }
        }

        // If there was one card shown for each axis, nothing in this suggestion
        // is a part of the answer. Mark it explicitly.
        if (playerNames.length === cardNames.length) {
            for (cardName of cardNames) {
                card = this.cards.map[cardName]
                if (card.couldOwn[0]) {
                    card.couldOwn[0] = false
                    card.addNote(`Not in answer, everyone showed a card during ${suggestion.describe()}`)
                }
            }
        }

        // Make a lookup table for all players that showed a card
        const playerShowedACard = {}
        for (playerName of playerNames) {
            playerShowedACard[playerName] = true
        }

        // Tag all players that didn't show a card during this suggestion as being
        // incapable of owning the suggested cards. Don't do this to the person
        // performing the suggestion, however, as it is a common strategy to
        // suggest cards in your hand.
        for (var player of this.players.list) {
            if (
                (playerNames.length === cardNames.length || player.name !== suggester) &&
                !playerShowedACard[player.name] &&
                player.index !== 0
            ) {
                for (cardName of cardNames) {
                    card = this.cards.map[cardName]
                    if (card.couldOwn[player.index]) {
                        card.couldOwn[player.index] = false
                        card.addNote(
                            `${player.fullName.playerColor} can't own, they didn't show a card during ${suggestion.describe()}`
                        )
                    }
                }
            }
        }

        // See if we can find any cards with only one possible owner
        this.findOwners(suggestion)

        // Display the known ownership state of the suggested cards
        log("")
        for (cardName of cardNames) {
            card = this.cards.map[cardName]
            card.display(this)
        }
    }

    saw(ownerName, cardName) {
        // log "saw(): #{Array.prototype.slice.call(arguments)}"

        const owner = this.players.map[ownerName]
        if (!ownerName) {
            fatalError(`unknown player ${playerName}`)
        }
        const card = this.cards.map[cardName]
        if (!card) {
            fatalError(`unknown card ${cardName}`)
        }

        let alreadyKnown = ""
        if (card.owner === owner.name) {
            alreadyKnown = " (already known)"
        } else if (card.owner !== null) {
            fatalError(`trying to set owner of ${card.name} to ${owner.name}, but ${card.owner} already owns it`)
        }

        journal(`\n**    ${owner.fullName.playerColor} shows ${card.axis.color(card.fullName)}${alreadyKnown}.`)

        if (card.owner !== owner.name) {
            // Set the card's owner, and mark all other players as can't own
            card.owner = owner.name
            card.addNote(`Owned by ${owner.fullName.playerColor}, card shown`)
            for (let index = 0; index < this.players.list.length; index++) {
                var player = this.players.list[index]
                card.couldOwn[index] = index === owner.index
            }
        }

        // See if we can find any cards with only one possible owner
        const action = {
            describe() {
                return `being shown ${card.axis.color(card.fullName)} by ${owner.name.playerColor}`
            }
        }
        this.findOwners(action)
    }

    findOwners(action) {
        let potentialNewOwners = true
        while (potentialNewOwners) {
            var card, index, owner, player
            potentialNewOwners = false

            // Find cards with exactly one owner left
            for (card of this.cards.list) {
                if (card.owner === null) {
                    var ownerCount = 0
                    var ownerIndex = -1
                    for (index = 0; index < this.players.list.length; index++) {
                        player = this.players.list[index]
                        if (card.couldOwn[index]) {
                            ownerCount += 1
                            ownerIndex = index
                        }
                    }
                    if (ownerCount === 0) {
                        fatalError(`Nobody can possibly own ${card.fullName}`)
                    }
                    if (ownerCount === 1) {
                        potentialNewOwners = true
                        owner = this.players.list[ownerIndex]
                        card.owner = owner.name
                        for (index = 0; index < this.players.list.length; index++) {
                            player = this.players.list[index]
                            card.couldOwn[index] = index === owner.index
                        }
                        if (ownerIndex === 0) {
                            card.addNote(
                                `Part of the ${this.players.list[0].fullName.answerColor}, discovered after ${action.describe()}`
                            )
                            for (var axisCard of card.axis.cards) {
                                if (axisCard.index === card.index) {
                                    continue
                                }
                                if (axisCard.couldOwn[0]) {
                                    axisCard.couldOwn[0] = false
                                    axisCard.addNote(
                                        `Not in answer, since ${card.axis.color(
                                            card.fullName
                                        )} is the answer, discovered after ${action.describe()}`
                                    )
                                }
                            }
                        } else {
                            card.addNote(`Owned by ${owner.fullName}, only possible owner, discovered after ${action.describe()}`)
                        }
                    }
                }
            }

            // Find axes with only one possible Answer
            for (var axis of this.axes.list) {
                var answerCount = 0
                var answerIndex = -1
                for (card of axis.cards) {
                    if (card.owner === null) {
                        if (card.couldOwn[0]) {
                            // Can this card be in the answer?
                            answerCount += 1
                            answerIndex = card.index
                        }
                    } else {
                        owner = this.players.map[card.owner]
                        if (owner.index === 0) {
                            // Already have an Answer for this axis, move on
                            answerCount = 0
                            break
                        }
                    }
                }
                if (answerCount === 1) {
                    potentialNewOwners = true
                    card = this.cards.list[answerIndex]
                    owner = this.players.list[0] // Answer
                    card.owner = owner.name
                    for (index = 0; index < this.players.list.length; index++) {
                        player = this.players.list[index]
                        card.couldOwn[index] = index === owner.index
                    }
                    card.addNote(
                        `Part of the ${this.players.list[0].fullName.answerColor}, only possible choice in ${axis.color(
                            axis.fullName
                        )} left, discovered after ${action.describe()}`
                    )
                }
            }

            // Replay suggestions, attempting to match up owners with the cards they must have shown
            for (var suggestion of this.suggestions) {
                var unownedCards = []
                var leftoverPlayers = suggestion.playerNames.slice(0)
                for (var cardName of suggestion.cardNames) {
                    card = this.cards.map[cardName]
                    if (card.owner === null) {
                        unownedCards.push(cardName)
                    } else {
                        leftoverPlayers = removeFromArray(leftoverPlayers, card.owner)
                    }
                }
                if (unownedCards.length === 1 && leftoverPlayers.length === 1) {
                    potentialNewOwners = true
                    var ownerName = leftoverPlayers[0]
                    owner = this.players.map[ownerName]
                    card = this.cards.map[unownedCards[0]]
                    card.owner = ownerName
                    for (index = 0; index < this.players.list.length; index++) {
                        player = this.players.list[index]
                        card.couldOwn[index] = index === owner.index
                    }
                    card.addNote(
                        `Owned by ${
                            owner.fullName.playerColor
                        }, owners of all other shown cards known, discovered by replaying ${suggestion.describe()}`
                    )
                }
            }
        }
    }

    dump() {}
    display() {
        log("")
        for (var axis of this.axes.list) {
            axis.display(this)
        }
    }
}

class ClueParser {
    constructor(solver) {
        this.solver = solver
        this.currentFilename = []
        this.currentLineNumber = []
    }

    parseFile(filename) {
        this.currentFilename.push(filename)
        this.currentLineNumber.push(0)
        fatalFilename = filename
        const lines = fs.readFileSync(filename, "utf8").replace(/\r/, "").split(/\n/)
        for (var line of lines) {
            this.currentLineNumber[this.currentLineNumber.length - 1] += 1
            fatalLineNumber = this.currentLineNumber[this.currentLineNumber.length - 1]
            if (line.match(/^\s*#/)) {
                continue
            }
            if (line.match(/^\s*$/)) {
                continue
            }
            var words = line.split(/\s+/).filter((x) => x.match(/\S/))
            var action = words.shift()
            switch (action) {
                case "include":
                    var includeFilename = line.match(/^include\s+(.*)/)[1]
                    if (includeFilename != null) {
                        var currentDir = path.parse(filename).dir
                        var absFilename = path.resolve(currentDir, includeFilename)
                        this.parseFile(absFilename)
                    }
                    break
                case "player":
                    var playerName = words.shift()
                    var fullName = words.join(" ")
                    this.solver.addPlayer(playerName, fullName)
                    break
                case "axis":
                    var axisName = words.shift()
                    fullName = words.shift()
                    var prefix = words.join(" ")
                    if (prefix.length > 0) {
                        prefix += " "
                    }
                    this.solver.addAxis(axisName, fullName, prefix)
                    break
                case "card":
                    axisName = words.shift()
                    var cardName = words.shift()
                    fullName = words.join(" ")
                    this.solver.addCard(cardName, axisName, fullName)
                    break
                case "hand":
                    playerName = words.shift()
                    var cardNames = words
                    this.solver.hand(playerName, cardNames)
                    break
                case "suggest":
                    playerName = words.shift()
                    cardNames = []
                    var playerNames = []
                    for (var name of words) {
                        if (name === "-") {
                            continue
                        } // TODO: use as assert 'nobody showed'
                        var type = this.solver.exists(name)
                        switch (type) {
                            case "card":
                                cardNames.push(name)
                                break
                            case "player":
                                playerNames.push(name)
                                break
                            default:
                                fatalError(`Unknown card or player name: ${name}`)
                        }
                    }
                    this.solver.suggest(playerName, cardNames, playerNames)
                    break
                case "saw":
                    playerName = words.shift()
                    cardName = words.shift()
                    this.solver.saw(playerName, cardName)
                    break
                case "dump":
                    this.solver.dump()
                    break
                default:
                    fatalError(`Unknown action: ${line}`)
            }
        }

        this.currentFilename.pop()
        this.currentLineNumber.pop()
        if (this.currentFilename.length > 0) {
            fatalFilename = this.currentFilename[this.currentFilename.length - 1]
            fatalLineNumber = this.currentLineNumber[this.currentLineNumber.length - 1]
        } else {
            fatalFilename = null
            fatalLineNumber = 0
        }
    }
}

function syntax() {
    console.log("node solver.js [-b|-n] FILENAME")
    process.exit(1)
}

function main() {
    let filename
    const args = process.argv.slice(2)
    for (var arg of args) {
        if (arg === "-n") {
            setOutputMode("none")
        } else if (arg === "-b") {
            setOutputMode("browser")
        } else {
            filename = arg
        }
    }
    if (filename === undefined) {
        syntax()
    }

    const solver = new ClueSolver()
    const parser = new ClueParser(solver)
    parser.parseFile(filename)
    solver.display()
}

main()
