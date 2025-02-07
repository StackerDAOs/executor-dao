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

;; Title: SDE013 Multisig
;; Author: StackerDAO Dev Team
;; Depends-On:
;; Synopsis:
;; Description:

(use-trait proposal-trait .proposal-trait.proposal-trait)

(impl-trait .extension-trait.extension-trait)

(define-constant ERR_UNAUTHORIZED (err u3600))
(define-constant ERR_NOT_SIGNER (err u3601))
(define-constant ERR_INVALID (err u3602))
(define-constant ERR_ALREADY_EXECUTED (err u3603))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u3604))
(define-constant ERR_PROPOSAL_ALREADY_EXISTS (err u3605))
(define-constant ERR_PROPOSAL_ALREADY_EXECUTED (err u3606))

(define-data-var signers (list 10 principal) (list))
(define-data-var signalsRequired uint u2)
(define-data-var lastRemovedSigner (optional principal) none)
(define-data-var proposalList (list 100 principal) (list))

(define-map Proposals
  principal
  {
    proposer: principal,
    concluded: bool
  }
)

(define-map Signals {proposal: principal, teamMember: principal} bool)
(define-map SignalCount principal uint)

;; --- Authorization check

(define-public (is-dao-or-extension)
  (ok (asserts! (or (is-eq tx-sender .executor-dao) (contract-call? .executor-dao is-extension contract-caller)) ERR_UNAUTHORIZED))
)

;; --- Internal DAO functions

(define-public (add-signer (who principal))
  (begin
    (try! (is-dao-or-extension))
    (var-set signers (unwrap-panic (as-max-len? (append (var-get signers) who) u10)))
    (ok true)
  )
)

(define-public (remove-signer (who principal))
  (begin
    (try! (is-dao-or-extension))
    (asserts! (>= (- (get-signers-count) u1) (var-get signalsRequired)) ERR_INVALID)
    (asserts! (not (is-none (index-of (var-get signers) who))) ERR_INVALID)
    (var-set lastRemovedSigner (some who))
    (var-set signers (unwrap-panic (as-max-len? (filter remove-signer-filter (var-get signers)) u10)))
    (ok true)
  )
)

(define-public (set-signals-required (newRequirement uint))
  (begin
    (try! (is-dao-or-extension))
    (asserts! (and (<= (var-get signalsRequired) (get-signers-count)) (<= newRequirement (get-signers-count))) ERR_INVALID)
    (ok (var-set signalsRequired newRequirement))
  )
)

;; --- Read only functions

(define-read-only (is-signer (who principal))
  (is-some (index-of (var-get signers) tx-sender))
)

(define-read-only (has-signaled (proposal principal) (who principal))
  (default-to false (map-get? Signals {proposal: proposal, teamMember: who}))
)

(define-read-only (get-proposal-data (proposal principal))
  (map-get? Proposals proposal)
)

(define-read-only (get-signals-required)
  (var-get signalsRequired)
)

(define-read-only (get-signer (who principal))
  (match (index-of (var-get signers) who)
    success (some who)
    none
  )
)

(define-read-only (get-signers)
  (var-get signers)
)

(define-read-only (get-signers-count)
  (len (var-get signers))
)

(define-read-only (get-proposal-signals (proposal principal))
  (default-to u0 (map-get? SignalCount proposal))
)

(define-read-only (get-proposals (proposals (list 100 principal)))
  (map get-proposal-info proposals)
)

;; --- Public functions

(define-public (add-proposal (proposal <proposal-trait>))
  (let
    (
      (proposalPrincipal (contract-of proposal))
    )
    (asserts! (is-signer tx-sender) ERR_NOT_SIGNER)
    (asserts! (map-insert Proposals proposalPrincipal {proposer: tx-sender, concluded: false}) ERR_PROPOSAL_ALREADY_EXISTS)
    (asserts! (is-none (contract-call? .executor-dao executed-at proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
    (var-set proposalList (unwrap-panic (as-max-len? (append (var-get proposalList) proposalPrincipal) u100)))
    (print {event: "propose", proposal: proposal, proposer: tx-sender})
    (map-set Signals {proposal: proposalPrincipal, teamMember: tx-sender} true)
    (map-set SignalCount proposalPrincipal u1)
    (ok true)
  )
)

(define-public (sign (proposal <proposal-trait>))
  (let
    (
      (proposalPrincipal (contract-of proposal))
      (signals 
        (+ 
          (get-proposal-signals proposalPrincipal) 
          (if (has-signaled proposalPrincipal tx-sender) u0 u1)
        )
      )
      (proposalData (unwrap! (get-proposal-data proposalPrincipal) ERR_PROPOSAL_NOT_FOUND))
    )
    (asserts! (is-signer tx-sender) ERR_NOT_SIGNER)
    (asserts! (is-none (contract-call? .executor-dao executed-at proposal)) ERR_ALREADY_EXECUTED)
    (and (>= signals (var-get signalsRequired))
      (begin
        (try! (contract-call? .executor-dao execute proposal tx-sender))
        (map-set Proposals proposalPrincipal
          (merge proposalData {concluded: true})
        )
      )
    )
    (map-set Signals {proposal: proposalPrincipal, teamMember: tx-sender} true)
    (map-set SignalCount proposalPrincipal signals)
    (ok signals)
  )
)

;; Private functions

(define-private (remove-signer-filter (signer principal))
  (not (is-eq signer (unwrap-panic (var-get lastRemovedSigner))))
)

(define-private (get-proposal-info (proposalPrincipal principal))
  (begin
    (let
      (
        (proposalData (unwrap-panic (get-proposal-data proposalPrincipal)))
      )
      (some
        {
          proposer: (get proposer proposalData),
          concluded: (get concluded proposalData)
        }
      )
    )
  )
)

;; --- Extension callback

(define-public (callback (sender principal) (memo (buff 34)))
  (ok true)
)
