;;     _____________  _______ _________  ___  ___  ____  ____
;;     / __/_  __/ _ |/ ___/ //_/ __/ _ \/ _ \/ _ |/ __ \/ __/
;;     _\ \  / / / __ / /__/ ,< / _// , _/ // / __ / /_/ /\ \  
;;    /___/ /_/ /_/ |_\___/_/|_/___/_/|_/____/_/ |_\____/___/  
;;                                                          
;;     ___  ___  ____  ___  ____  _______   __               
;;    / _ \/ _ \/ __ \/ _ \/ __ \/ __/ _ | / /               
;;   / ___/ , _/ /_/ / ___/ /_/ /\ \/ __ |/ /__              
;;  /_/  /_/|_|\____/_/   \____/___/_/ |_/____/              
;;                                                         

;; Title: SDP Transfer Fungible Tokens
;; Author: StackerDAO Dev Team
;; Type: Transfer

(impl-trait .proposal-trait.proposal-trait)

(define-constant MICRO (pow u10 u2))

(define-public (execute (sender principal))
	(begin
		(try! (contract-call? .sde-vault transfer-ft .sde-governance-token-with-delegation (* MICRO u100) 'STNHKEPYEPJ8ET55ZZ0M5A34J0R3N5FM2CMMMAZ6))

		(print {event: "execute", sender: sender})
		(ok true)
	)
)
