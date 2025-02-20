;; Concert Ticket Contract Improved Version

;; Error Constants
(define-constant contract-owner tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-ALREADY-EXISTS (err u101))
(define-constant ERR-DOES-NOT-EXIST (err u102))
(define-constant ERR-LISTING-CLOSED (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-INVALID-SEAT-COUNT (err u105))
(define-constant ERR-INVALID-CLOSE-HEIGHT (err u106))
(define-constant ERR-INVALID-SALE-TYPE (err u107))
(define-constant ERR-LISTING-EXPIRED (err u108))
(define-constant ERR-LISTING-NOT-CANCELABLE (err u109))
(define-constant ERR-REFUND-FAILED (err u110))
(define-constant ERR-INVALID-DESCRIPTION (err u111))
(define-constant ERR-INVALID-PRICE-AMOUNT (err u112))

;; Data variables
(define-data-var next-concert-listing-id uint u0)

;; Sale types
(define-data-var sale-types (list 10 (string-ascii 20)) (list "fixed-price" "auction"))

;; Define enhanced listing structure
(define-map listings
  { concert-listing-id: uint }
  {
    seller: principal,
    concert-description: (string-ascii 256),
    seat-sections: (list 10 (string-ascii 64)),
    ticket-price: uint,
    total-revenue: uint,
    is-listing-active: bool,
    listing-close-height: uint,
    sale-type: (string-ascii 20)
  }
)

;; Define enhanced purchase structure
(define-map purchases
  { concert-listing-id: uint, buyer: principal }
  { selected-section: uint, paid-amount: uint }
)

;; Read-only functions
(define-read-only (get-listing (concert-listing-id uint))
  (map-get? listings { concert-listing-id: concert-listing-id })
)

(define-read-only (get-purchase (concert-listing-id uint) (buyer principal))
  (map-get? purchases { concert-listing-id: concert-listing-id, buyer: buyer })
)

(define-read-only (get-current-block-height)
  block-height
)

;; Private functions
(define-private (process-refund (concert-listing-id uint))
  (let
    ((purchase (get-purchase concert-listing-id tx-sender)))
    (match purchase
      purchase-data (match (as-contract (stx-transfer? (get paid-amount purchase-data) tx-sender tx-sender))
        success (begin
          (map-delete purchases { concert-listing-id: concert-listing-id, buyer: tx-sender })
          (ok true)
        )
        error ERR-REFUND-FAILED
      )
      ERR-REFUND-FAILED
    )
  )
)

;; Public functions
(define-public (create-listing 
    (concert-description (string-ascii 256)) 
    (seat-sections (list 10 (string-ascii 64))) 
    (ticket-price uint)
    (listing-close-height uint)
    (sale-type (string-ascii 20)))
  (let
    (
      (new-concert-listing-id (var-get next-concert-listing-id))
    )
    (asserts! (> (len concert-description) u0) ERR-INVALID-DESCRIPTION)
    (asserts! (> (len seat-sections) u1) ERR-INVALID-SEAT-COUNT)
    (asserts! (> ticket-price u0) ERR-INVALID-PRICE-AMOUNT)
    (asserts! (> listing-close-height block-height) ERR-INVALID-CLOSE-HEIGHT)
    (asserts! (is-some (index-of (var-get sale-types) sale-type)) ERR-INVALID-SALE-TYPE)
    
    (map-set listings
      { concert-listing-id: new-concert-listing-id }
      {
        seller: tx-sender,
        concert-description: concert-description,
        seat-sections: seat-sections,
        ticket-price: ticket-price,
        total-revenue: u0,
        is-listing-active: true,
        listing-close-height: listing-close-height,
        sale-type: sale-type
      }
    )
    (var-set next-concert-listing-id (+ new-concert-listing-id u1))
    (ok new-concert-listing-id)
  )
)

(define-public (purchase-ticket (concert-listing-id uint) (selected-section uint))
  (let
    (
      (listing (unwrap! (get-listing concert-listing-id) ERR-DOES-NOT-EXIST))
    )
    (asserts! (get is-listing-active listing) ERR-LISTING-CLOSED)
    (asserts! (>= (len (get seat-sections listing)) selected-section) ERR-INVALID-SEAT-COUNT)
    (asserts! (< block-height (get listing-close-height listing)) ERR-LISTING-EXPIRED)
    (try! (stx-transfer? (get ticket-price listing) tx-sender (as-contract tx-sender)))
    
    (map-set purchases
      { concert-listing-id: concert-listing-id, buyer: tx-sender }
      {
        selected-section: selected-section,
        paid-amount: (get ticket-price listing)
      }
    )
    
    (map-set listings
      { concert-listing-id: concert-listing-id }
      (merge listing { total-revenue: (+ (get total-revenue listing) (get ticket-price listing)) })
    )
    (ok true)
  )
)

(define-public (close-listing (concert-listing-id uint))
  (let
    (
      (listing (unwrap! (get-listing concert-listing-id) ERR-DOES-NOT-EXIST))
    )
    (asserts! (is-eq (get seller listing) tx-sender) ERR-UNAUTHORIZED)
    (asserts! (get is-listing-active listing) ERR-LISTING-CLOSED)
    (asserts! (>= block-height (get listing-close-height listing)) ERR-LISTING-EXPIRED)
    
    (map-set listings
      { concert-listing-id: concert-listing-id }
      (merge listing { is-listing-active: false })
    )
    (ok true)
  )
)

(define-public (cancel-listing (concert-listing-id uint))
  (let
    (
      (listing (unwrap! (get-listing concert-listing-id) ERR-DOES-NOT-EXIST))
    )
    (asserts! (is-eq (get seller listing) tx-sender) ERR-UNAUTHORIZED)
    (asserts! (get is-listing-active listing) ERR-LISTING-CLOSED)
    (asserts! (< block-height (get listing-close-height listing)) ERR-LISTING-NOT-CANCELABLE)
    
    (map-set listings
      { concert-listing-id: concert-listing-id }
      (merge listing { is-listing-active: false })
    )
    
    (process-refund concert-listing-id)
  )
)

;; Contract initialization
(begin
  (var-set next-concert-listing-id u0)
)

;; Export the Component function (required for v0)
(define-public (Component)
  (ok true))