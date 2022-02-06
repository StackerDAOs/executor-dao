;; Title: EDE006 DAO Members
;; Author: Ryan Waits
;; Depends-On: 
;; Synopsis:
;; This extension allows members to be added manually when creating the DAO.
;; Description:
;; An extension meant for creating safes or small groups of members to perform actions.

(impl-trait .extension-trait.extension-trait)
(use-trait proposal-trait .proposal-trait.proposal-trait)

(define-constant err-unauthorised (err u3000))
(define-constant err-not-a-member (err u3001))

(define-map members principal bool)

;; --- Authorisation check

(define-public (is-dao-or-extension)
  (ok (asserts! (or (is-eq tx-sender .executor-dao) (contract-call? .executor-dao is-extension contract-caller)) err-unauthorised))
)

;; --- Internal DAO functions

(define-public (set-member (who principal) (member bool))
  (begin
    (try! (is-dao-or-extension))
    (ok (map-set members who member))
  )
)

;; --- Public functions

(define-read-only (is-member (who principal))
  (default-to false (map-get? members who))
)

;; --- Extension callback

(define-public (callback (sender principal) (memo (buff 34)))
  (ok true)
)
