//
//  PlayerCardDeckViewController.swift
//  Multiplayer Card-Game
//
//  Created by Tushar Gusain on 19/01/20.
//  Copyright © 2020 Hot Cocoa Software. All rights reserved.
//

import UIKit

class PlayerCardDeckViewController: UIViewController {

    //MARK:- IBOutlets
    
    @IBOutlet var cardViews: [CardView]!
    @IBOutlet var cardStackView: UIStackView!
    @IBOutlet var deckStackView: UIStackView!
    @IBOutlet var leftDeckView: CardView!
    @IBOutlet var rightDeckView: UIView!
    @IBOutlet var rightDeckTopCard: CardView!
    @IBOutlet var dragInstructionView: UIStackView!
    
    //MARK:- Property Variables
    
    var cards: [Card]?
    var swipeGestureEnabled: ((Bool)->Void)!
    
    private let animationDistance: CGFloat = 150
    private let gameManager = GameManager.shared
    private var selectedColor: UIColor! = UIColor.white
    private var isHost = false
    private var enableInteraction = false
    private let allColors = Constants.Colors.allColors()
    private var animator = UIViewPropertyAnimator()
    private var isDeck = false {
        didSet {
            updateDeck()
        }
    }
    
    //MARK:- Lifecycle Hooks
    
    override func viewDidLoad() {
        super.viewDidLoad()
        gameManager.cardsDelegate = self
        
                
        if let index = gameManager.players.firstIndex(of: GameService.shared.getPeerID()) {
            cards = gameManager.cardsForPlayer[index]
        }
        
        for cardView in cardViews {
            cardView.addShadow()
            cardView.transform = .init(rotationAngle: -CGFloat.pi/2)
            
            let gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
            cardView.addGestureRecognizer(gestureRecognizer)
        }
        
        deckStackView.transform = .init(rotationAngle: -CGFloat.pi/2)
        leftDeckView.addShadow()
        updateDeck()
        updateUI()
    }
    
    //MARK:- ViewController Methods
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    //MARK:- Custom Methods
    
    @objc func handlePan(recognizer: UIPanGestureRecognizer) {
        if let senderView = recognizer.view, let cardView = senderView as? CardView, let index = cardViews.firstIndex(of: cardView) {
            let selectedCardView = cardView
            switch recognizer.state {
            case .began:
                animator = UIViewPropertyAnimator.runningPropertyAnimator(withDuration: Constants.crazy8AnimationDuration, delay: 0.2, options: [], animations: {
                    selectedCardView.transform = .init(translationX: self.animationDistance, y: 0)
                    selectedCardView.alpha = 0
                }) { [weak self] _ in
                    guard let self = self else { return }
                    selectedCardView.transform = .identity
                    selectedCardView.transform = .init(rotationAngle: -CGFloat.pi / 2)
                    self.updateUI()
                }
                animator.pauseAnimation()
            case .changed:
                let fractionComplete = recognizer.translation(in: selectedCardView).x / animationDistance
                if fractionComplete < 0.001 {
                    animator.stopAnimation(true)
                    selectedCardView.transform = .identity
                    selectedCardView.transform = .init(rotationAngle: -CGFloat.pi / 2)
                    selectedCardView.alpha = 1
                    recognizer.state = .cancelled
                } else {
                    animator.fractionComplete = fractionComplete
                }
            case .ended:
                animator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
                let rank = Card.Rank.orderOf(rank: "\(cardView.rank)")
                let suit = Card.Suit(rawValue: cardView.suit)!
                let card = Card(suit: suit, rank: Card.Rank.allRanks[rank - 1])
                let cardIndex = cards!.firstIndex(of: card)!
                gameManager.throwCardInCenter(player: gameManager.playersConnected[0], card: gameManager.cardsForPlayer[0][cardIndex], playerColorIndex: allColors.firstIndex(of: selectedColor)!)
            default:
                ()
            }
        }
    }
    
    func setDeck(deck: Bool) {
        isDeck = deck
    }
    
    func setColor(color: UIColor) {
        selectedColor = color
    }
    
    func enablePlayer(enable: Bool) {
        enableInteraction = enable
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let cardViews = self.cardViews else { return }
            for cardView in cardViews {
                cardView.isUserInteractionEnabled = enable
            }
        }
    }
    
    //MARK:- Private Methods
    
    private func updateDeck() {
        deckStackView?.isHidden = !isDeck
        cardStackView?.isHidden = isDeck
        dragInstructionView?.isHidden = isDeck
    }
    
    private func updateUI() {
        DispatchQueue.main.async { [unowned self] in
            guard let cards = self.cards else { return }
            if self.isDeck {
                if let cards = self.cards, cards.count > 0 {
                    let card = cards.last!
                    self.rightDeckTopCard.rank = card.rank.order
                    self.rightDeckTopCard.suit = card.suit.description
                    self.rightDeckTopCard.isHidden = false
                    self.rightDeckTopCard.addBorder(color: self.selectedColor)
                    self.rightDeckTopCard.addShadow()
                }
            } else {
                for cardView in self.cardViews {
                    cardView.alpha = 0
                    cardView.isFaceUp = true
                    cardView.addShadow()
                    cardView.addBorder(color: self.selectedColor)
                    cardView.isUserInteractionEnabled = false
                }
                let m = 13
                let cardsToCut = Int((m - cards.count)/2)
                let start = cardsToCut
                
                for (index,card) in cards.enumerated() {
                        self.cardViews[start + index].rank = card.rank.order
                        self.cardViews[start + index].suit = card.suit.description
                        self.cardViews[start + index].isFaceUp = true
                        self.cardViews[start + index].alpha = 1
                        self.cardViews[start + index].isUserInteractionEnabled = self.enableInteraction
                }
            }
        }
    }
}

//MARK:- GameCard Manager Delegate Methods

extension PlayerCardDeckViewController: GameCardManagerDelegate {
    func cardsSwapped(updatedCards: [Card], deck: Bool) {
        cards = updatedCards
    }
}
