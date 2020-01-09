//
//  GameManager.swift
//  Multiplayer Card-Game
//
//  Created by Tushar Gusain on 31/12/19.
//  Copyright © 2019 Hot Cocoa Software. All rights reserved.
//

import MultipeerConnectivity

//MARK:- GameManager Protocol
protocol GameManagerDelegate {
    func roundWinner(winner: MCPeerID)
    func gameWinner(winner: MCPeerID)
    func timeRemaining(timeString: String)
    func gaveCardToPlayer(card: Card, playerName: String)
    func playerTurnedCard(player: MCPeerID, card: Card)
    func nextPlayerTurn(playerName: String)
}

protocol GameCardManagerDelegate {
    func cardsSwapped(updatedCards: [Card])
}

class GameManager {
    //MARK:- Property Variables
    static var shared = GameManager()
    private var deck: Deck!
    private let numberOfCardsPerPlayer = 13
    private var currentPlayerIndex = 0 {
        didSet {
            delegate?.nextPlayerTurn(playerName: players[currentPlayerIndex].displayName)
            gameService.messageService.sendNextPlayerTurn(player: players[currentPlayerIndex].displayName)
        }
    }
    private var timer: Timer? = nil
    private var timeLeft = 5 * 60 {
        didSet {
            self.delegate?.timeRemaining(timeString: self.getTimeString())
            if timeLeft == 0 {
                delegate?.gameWinner(winner: getGameWinner())
                self.stopTimer()
                timeLeft = 5 * 60
            }
        }
    }
    private var isHost = true
    
    var delegate: GameManagerDelegate?
    var cardsDelegate: GameCardManagerDelegate?

    let minPlayersNeeded = 1
    var playerNames: [String]!
    var players: [MCPeerID]! {
        didSet {
            playerNames = players.map({ $0.displayName })
        }
    }
    var playerCount = 1
    var cardsForPlayer: [[Card]]!
    var cardsInCentre: [Card]! {
        didSet {
            if cardsInCentre.count == playerCount {
                delegate?.roundWinner(winner: players[getBoutWinnerIndex()])
            }
        }
    }
    var cardsWonPerPlayer: [[Card]]!
    
    //MARK:- Initializers
    private init() {  }
    
    //MARK:- Member Methods
    func setAsHost(host: Bool) {
        isHost = host
        if isHost {
            gameService.gameHostDelegate = self
        } else {
            gameService.gameClientDelegate = self
        }
    }
    
    func sendHostID(name: String) {
        gameService.messageService.sendHostName(player: name)
    }
    
    func newGame(playersArray: [MCPeerID]) {
        players = playersArray
        playerCount = players.count
        deck = Deck()
        cardsInCentre = [Card]()
        cardsForPlayer = [[Card]]()
        cardsWonPerPlayer = [[Card]]()
        timeLeft = 5 * 60
        for _ in 0..<players.count {
            cardsForPlayer.append([Card]())
            cardsWonPerPlayer.append([Card]())
        }
    }
    
    func distributeCards(uiHandler: @escaping (Result<(Card,MCPeerID),CardError>) -> Void) {
        for _ in 0..<numberOfCardsPerPlayer {
            for playerIndex in 0..<players.count {
                if let card = deck.draw() {
                    cardsForPlayer[playerIndex].append(card)
                    gameService.messageService.sendCardExchangePlayerMessage(played: .GiveCardToPlayer, card: card, player: players[playerIndex].displayName)
                    uiHandler(.success((card,players[playerIndex])))
                } else {
                    print("Error getting the card from the deck")
                    uiHandler(.failure(.CardDrawError))
                }
            }
        }
        startTimer()
        currentPlayerIndex = 0
    }
    
    func throwCardInCenter(player: MCPeerID, card: Card) {
        if isHost {
            throwCardInCenterClient(player: player, card: card)
            gameService.messageService.sendCardExchangePlayerMessage(played: .PlayerTurnedCardHostMessage, card: card, player: player.displayName)
            updateNextPlayer()
        } else {
            gameService.messageService.sendCardExchangePlayerMessage(played: .PlayerTurnedCardClientMessage, card: card, player: player.displayName)
        }
    }
    
    func giveCardToPlayerFromDeck(card: Card, player: MCPeerID) {
        cardsForPlayer[players.firstIndex(of: player)!].append(card)
        delegate?.gaveCardToPlayer(card: card, playerName: player.displayName)
    }
    
    func setTime(time: Int) {
        timeLeft = time
    }
    
    func swapCard(player: MCPeerID, index: Int) {
        if isHost {
            swapCardWithFirst(player: player, index: index)
            gameService.messageService.sendCardsSwappedHostMessage(player: player.displayName, index: index)
        } else {
            gameService.messageService.sendCardsSwappedClientMessage(player: player.displayName, index: index)
        }
    }
    
    func endGame() {
        stopTimer()
    }
    
    //MARK:- Private Methods
    private func throwCardInCenterClient(player: MCPeerID, card: Card) {
        cardsInCentre.append(card)
        delegate?.playerTurnedCard(player: player, card: card)
    }
    
    private func swapCardWithFirst(player: MCPeerID, index: Int) {
        let playerIndex = players.firstIndex(of: player)!
        print(gameService.getPeerID())
        print(cardsForPlayer[playerIndex][0], cardsForPlayer[playerIndex][index])
        let card = cardsForPlayer[playerIndex][0]
        cardsForPlayer[playerIndex][0] = cardsForPlayer[playerIndex][index]
        cardsForPlayer[playerIndex][index] = card
        print(cardsForPlayer[playerIndex][0], cardsForPlayer[playerIndex][index])
        print(player.displayName, gameService.getPeerID().displayName )
        if player.displayName == gameService.getPeerID().displayName {
            cardsDelegate?.cardsSwapped(updatedCards: cardsForPlayer[0])
        }
    }
    
    private func getBoutWinnerIndex() -> Int {
        var winnerIndex = 0
        for index in 1..<cardsInCentre.count {
            if cardsInCentre[index].rank.order > cardsInCentre[winnerIndex].rank.order {
                winnerIndex = index
            }
        }
        for card in cardsInCentre {
            cardsWonPerPlayer[winnerIndex].append(card)
        }
        cardsInCentre = [Card]()
        return winnerIndex
    }
    
    private func updateNextPlayer() {
        if currentPlayerIndex == playerCount - 1 {
            currentPlayerIndex = 0
        } else {
            currentPlayerIndex += 1
        }
        
        if cardsForPlayer[currentPlayerIndex].count == 0 {
            updateNextPlayer()
        }
    }
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(1.0), repeats: true) { [weak self] (timer) in
            guard let self = self else { return }
            self.timeLeft -= 1
            gameService.messageService.sendRemainingTime(timeString: self.getTimeString())
            print(self.timeLeft)
        }
    }
    
    private func stopTimer() {
        if timer != nil {
            timer?.invalidate()
        }
    }
    
    private func getTimeString() -> String {
        let seconds = timeLeft
        var min = 0
        var sec = 0
        min = Int(seconds/60)
        sec = seconds % 60
        var timeString = "\(min):\(sec)"
        if sec < 10 {
            timeString = "\(min):0\(sec)"
        }
        return timeString
    }
    
    private func getGameWinner() -> MCPeerID {
        var winnerIndex = 0
        for index in 1..<playerCount {
            if cardsWonPerPlayer[winnerIndex].count < cardsWonPerPlayer[index].count {
                winnerIndex = index
            }
        }
        return players[winnerIndex]
    }
}

//MARK:- GameService Game Client Delegate Methods
extension GameManager: GameServiceGameClientDelegate {
    func gameHost(hostName: String) {
        let hostID = players[playerNames.firstIndex(of: hostName)!]
        gameService.messageService.setHost(hostID: hostID)
    }
    
    func boutWinner(playerName: String) {
        //This'll we decided by the game manager of the client device
        print("Bout Winner is: ", playerName)
    }

    func winner(playerName: String) {
        //This'll we decided by the game manager of the client device
        print("Winner is: ", playerName)
    }
    
    func remainingTime(time: Int) {
        timeLeft = time
    }
    
    func nextPlayer(playerName: String) {
        let index = playerNames.firstIndex(of: playerName)!
        currentPlayerIndex = index
    }
    
    func gaveCardToPlayer(card: Card, playerName: String) {
        if !isHost {
            let playerID = players[playerNames.firstIndex(of: playerName)!]
            giveCardToPlayerFromDeck(card: card, player: playerID)
        }
    }
    
    func playerTurnedCard(playerName: String, card: Card) {
        let playerID = players[playerNames.firstIndex(of: playerName)!]
        throwCardInCenterClient(player: playerID, card: card)
    }
    
    func cardsSwapped(byPlayer: String, index: Int) {
        let playerIndex = playerNames.firstIndex(of: byPlayer)!
        let player = players[playerIndex]
        swapCardWithFirst(player: player, index: index)
    }
}

//MARK:- GameService Game Host Delegate Methods
extension GameManager: GameServiceGameHostDelegate {
    func clientPlayerTurnedCard(playerName: String, card: Card) {
        let playerID = players[playerNames.firstIndex(of: playerName)!]
        throwCardInCenter(player: playerID, card: card)
    }
    
    func clientCardsSwapped(byPlayer: String, index: Int) {
        let playerIndex = playerNames.firstIndex(of: byPlayer)!
        let player = players[playerIndex]
        swapCard(player: player, index: index)
    }
}
