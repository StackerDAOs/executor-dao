;;     _____________  _______ _________  ___  ___  ____  ____
;;     / __/_  __/ _ |/ ___/ //_/ __/ _ \/ _ \/ _ |/ __ \/ __/
;;     _\ \  / / / __ / /__/ ,< / _// , _/ // / __ / /_/ /\ \  
;;    /___/ /_/ /_/ |_\___/_/|_/___/_/|_/____/_/ |_\____/___/  
;;                                                          
;;     _____  _____________  ______________  _  __           
;;    / __/ |/_/_  __/ __/ |/ / __/  _/ __ \/ |/ /           
;;   / _/_>  <  / / / _//    /\ \_/ // /_/ /    /            
;;  /___/_/|_| /_/ /___/_/|_/___/___/\____/_/|_/             
;;                                                           

;; Title: SDE0011 Proposal Voting
;; Author: StackerDAO Dev Team
;; Depends-On:
;; Synopsis:
;; This extension is part of the core of StackerDAO. It allows NFT
;; holders to vote on and conclude proposals.
;; Description:
;; Once proposals are submitted, they are open for voting after a lead up time
;; passes. Any token holder may vote on an open proposal, where one token equals
;; one vote. Members can vote until the voting period is over. After this period
;; anyone may trigger a conclusion. The proposal will then be executed if the
;; votes in favour exceed the ones against.

(use-trait proposal-trait .proposal-trait.proposal-trait)
(use-trait sip009-nft-trait .sip009-nft-trait.sip009-nft-trait)

(impl-trait .extension-trait.extension-trait)

(define-constant ERR_UNAUTHORIZED (err u3400))
(define-constant ERR_NOT_NFT_OWNER (err u3401))
(define-constant ERR_PROPOSAL_ALREADY_EXECUTED (err u3402))
(define-constant ERR_PROPOSAL_ALREADY_EXISTS (err u3403))
(define-constant ERR_UNKNOWN_PROPOSAL (err u3404))
(define-constant ERR_PROPOSAL_ALREADY_STARTED (err u3405))
(define-constant ERR_PROPOSAL_ALREADY_CONCLUDED (err u3406))
(define-constant ERR_PROPOSAL_INACTIVE (err u3407))
(define-constant ERR_PROPOSAL_NOT_CONCLUDED (err u3408))
(define-constant ERR_NO_VOTES_TO_RETURN (err u3409))
(define-constant ERR_ALREADY_VOTED (err u3410))
(define-constant ERR_END_BLOCK_HEIGHT_NOT_REACHED (err u3411))
(define-constant ERR_DISABLED (err u3412))

(define-data-var nftContract principal .nft-membership)

(define-map Proposals
  principal
  {
    votesFor: uint,
    votesAgainst: uint,
    startBlockHeight: uint,
    endBlockHeight: uint,
    concluded: bool,
    passed: bool,
    proposer: principal
  }
)

(define-map MemberVotes {proposal: principal, voter: principal, tokenId: uint} uint)

;; --- Authorization check

(define-public (is-dao-or-extension)
  (ok (asserts! (or (is-eq tx-sender .executor-dao) (contract-call? .executor-dao is-extension contract-caller)) ERR_UNAUTHORIZED))
)

;; --- Internal DAO functions

(define-public (add-proposal (proposal <proposal-trait>) (data {startBlockHeight: uint, endBlockHeight: uint, proposer: principal}))
  (begin
    (try! (is-dao-or-extension))
    (asserts! (is-none (contract-call? .executor-dao executed-at proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
    (print {event: "propose", proposal: proposal, proposer: tx-sender})
    (ok (asserts! (map-insert Proposals (contract-of proposal) (merge {votesFor: u0, votesAgainst: u0, concluded: false, passed: false} data)) ERR_PROPOSAL_ALREADY_EXISTS))
  )
)

(define-public (cancel-proposal (proposal <proposal-trait>))
	(begin
		(try! (is-dao-or-extension))
		(asserts! (is-none (contract-call? .executor-dao executed-at proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
		(asserts! (< block-height (get startBlockHeight (unwrap-panic (get-proposal-data (contract-of proposal))))) ERR_PROPOSAL_ALREADY_STARTED)
		(print {event: "cancel", proposal: proposal, proposer: tx-sender})
		(ok (asserts! (map-delete Proposals (contract-of proposal)) ERR_UNKNOWN_PROPOSAL))
	)
)

;; Proposals

(define-read-only (get-proposal-data (proposal principal))
  (map-get? Proposals proposal)
)

;; Votes

(define-read-only (get-current-total-votes (proposal principal) (voter principal) (tokenId uint))
  (default-to u0 (map-get? MemberVotes {proposal: proposal, voter: voter, tokenId: tokenId}))
)

;; --- Read only functions

(define-read-only (get-nft-contract)
  (var-get nftContract)
)

(define-public (vote (tokenId uint) (for bool) (proposal principal))
  (let
    (
      (proposalData (unwrap! (map-get? Proposals proposal) ERR_UNKNOWN_PROPOSAL))
    )
    (asserts! (is-eq contract-caller (unwrap! (unwrap-panic (contract-call? .nft-membership get-owner tokenId)) ERR_NOT_NFT_OWNER)) ERR_UNAUTHORIZED)
    (asserts! (>= block-height (get startBlockHeight proposalData)) ERR_PROPOSAL_INACTIVE)
    (asserts! (< block-height (get endBlockHeight proposalData)) ERR_PROPOSAL_INACTIVE)
    (asserts! (is-none (map-get? MemberVotes {proposal: proposal, voter: tx-sender, tokenId: tokenId})) ERR_ALREADY_VOTED)
    (map-set MemberVotes {proposal: proposal, voter: tx-sender, tokenId: tokenId} u1)
    (map-set Proposals proposal
      (if for
        (merge proposalData {votesFor: (+ (get votesFor proposalData) u1)})
        (merge proposalData {votesAgainst: (+ (get votesAgainst proposalData) u1)})
      )
    )
    (print {event: "vote", proposal: proposal, voter: tx-sender, for: for, amount: u1, tokenId: tokenId})
    (ok true)
  )
)

(define-private (vote-many-iter (item {tokenId: uint, for: bool, proposal: principal}))
  (let
    (
      (tokenId (get tokenId item))
      (for (get for item))
      (proposal (get proposal item))
      (proposalData (unwrap! (map-get? Proposals proposal) ERR_UNKNOWN_PROPOSAL))
    )
    (asserts! (is-eq contract-caller (unwrap! (unwrap-panic (contract-call? .nft-membership get-owner tokenId)) ERR_NOT_NFT_OWNER)) ERR_UNAUTHORIZED)
    (asserts! (>= block-height (get startBlockHeight proposalData)) ERR_PROPOSAL_INACTIVE)
    (asserts! (< block-height (get endBlockHeight proposalData)) ERR_PROPOSAL_INACTIVE)
    (asserts! (is-none (map-get? MemberVotes {proposal: proposal, voter: tx-sender, tokenId: tokenId})) ERR_ALREADY_VOTED)
    (map-set MemberVotes {proposal: proposal, voter: tx-sender, tokenId: tokenId} u1)
    (map-set Proposals proposal
      (if for
        (merge proposalData {votesFor: (+ (get votesFor proposalData) u1)})
        (merge proposalData {votesAgainst: (+ (get votesAgainst proposalData) u1)})
      )
    )
    (print {event: "vote", proposal: proposal, voter: tx-sender, for: for, amount: u1, tokenId: tokenId})
    (ok true)
  )
)

(define-public (vote-many (votes (list 50 {tokenId: uint, for: bool, proposal: principal})))
  (ok (map vote-many-iter votes))
)

;; Conclusion

(define-public (conclude (proposal <proposal-trait>))
  (let
    (
      (proposalData (unwrap! (map-get? Proposals (contract-of proposal)) ERR_UNKNOWN_PROPOSAL))
      (passed (> (get votesFor proposalData) (get votesAgainst proposalData)))
    )
    (asserts! (not (get concluded proposalData)) ERR_PROPOSAL_ALREADY_CONCLUDED)
    (asserts! (>= block-height (get endBlockHeight proposalData)) ERR_END_BLOCK_HEIGHT_NOT_REACHED)
    (map-set Proposals (contract-of proposal) (merge proposalData {concluded: true, passed: passed}))
    (print {event: "conclude", proposal: proposal, passed: passed})
    (and passed (try! (contract-call? .executor-dao execute proposal tx-sender)))
    (ok passed)
  )
)

;; --- Extension callback

(define-public (callback (sender principal) (memo (buff 34)))
  (ok true)
)
