;; margin-trading.clar
;; A decentralized margin trading platform on the Stacks blockchain
;; Enables users to trade with leveraged positions, manage collateral,
;; and execute trades with advanced risk management.

;; =============================
;; Constants / Error Codes
;; =============================

;; General errors
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-USER-ALREADY-REGISTERED (err u101))
(define-constant ERR-USER-NOT-FOUND (err u102))
(define-constant ERR-TRADER-NOT-VERIFIED (err u103))

;; Trading errors
(define-constant ERR-INSUFFICIENT-MARGIN (err u200))
(define-constant ERR-TRADE-ALREADY-EXISTS (err u201))
(define-constant ERR-TRADE-NOT-FOUND (err u202))
(define-constant ERR-LIQUIDATION-THRESHOLD (err u203))

;; Position errors
(define-constant ERR-POSITION-CLOSED (err u300))
(define-constant ERR-POSITION-ALREADY-OPEN (err u301))
(define-constant ERR-INVALID-LEVERAGE (err u302))

;; Role constants
(define-constant ROLE-TRADER u1)
(define-constant ROLE-MARKET-MAKER u2)
(define-constant ROLE-ADMIN u3)

;; =============================
;; Data Maps and Variables
;; =============================

;; Contract administrator
(define-data-var contract-admin principal tx-sender)

;; User registry
(define-map users principal 
  {
    role: uint,              ;; ROLE-TRADER or ROLE-MARKET-MAKER
    is-active: bool,         ;; Whether the user is active in the system
    verified: bool,          ;; Whether the trader has passed KYC
    name: (string-utf8 64),  ;; User's name
    registration-time: uint  ;; When the user registered (block height)
  }
)

;; Margin trading accounts
(define-map trading-accounts principal
  {
    total-balance: uint,         ;; Total account balance
    available-margin: uint,      ;; Margin available for trading
    open-positions-count: uint,  ;; Number of active positions
    last-activity: uint          ;; Block height of last activity
  }
)

;; Open trading positions
(define-map trading-positions
  { trader: principal, position-id: uint }
  {
    asset: (string-utf8 50),      ;; Trading pair (e.g., "BTC/USDC")
    position-type: (string-utf8 20), ;; "long" or "short"
    entry-price: uint,            ;; Price at position opening
    leverage: uint,               ;; Trading leverage
    margin-used: uint,            ;; Margin locked in this position
    liquidation-price: uint,      ;; Price at which position will be liquidated
    opened-at: uint               ;; Block height when position was opened
  }
)

;; Margin call and liquidation tracking
(define-map margin-calls
  { trader: principal }
  {
    is-margin-call: bool,         ;; Whether trader is in margin call
    call-time: uint,              ;; Block height of margin call
    required-margin-deposit: uint ;; Amount needed to prevent liquidation
  }
)

;; Global position tracking
(define-data-var total-open-positions uint u0)
(define-data-var total-margin-locked uint u0)

;; =============================
;; Private Functions
;; =============================

;; Check if caller is a registered trader
(define-private (is-trader (user principal))
  (match (map-get? users user)
    user-data (and 
      (is-eq (get role user-data) ROLE-TRADER)
      (get is-active user-data))
    false
  )
)

;; Check if caller is a market maker
(define-private (is-market-maker (user principal))
  (match (map-get? users user)
    user-data (and 
      (is-eq (get role user-data) ROLE-MARKET-MAKER)
      (get is-active user-data)
      (get verified user-data))
    false
  )
)

;; Check if user is contract admin
(define-private (is-admin (user principal))
  (is-eq user (var-get contract-admin))
)

;; Calculate liquidation risk
(define-private (calculate-liquidation-risk (trader principal) (position-id uint))
  (match (map-get? trading-positions { trader: trader, position-id: position-id })
    position 
      (let ((current-health (/ (* (get margin-used position) u100) 
                                 (get leverage position))))
        (if (< current-health u20)  ;; 20% margin health threshold
            true   ;; At high risk of liquidation
            false))
    false  ;; Position not found
  )
)

;; =============================
;; Public Functions
;; =============================

;; Change contract administrator
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (var-set contract-admin new-admin)
    (ok true)
  )
)

;; End of margin-trading.clar contract