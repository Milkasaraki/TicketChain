;; Concert Ticket Contract - Updated Version

;; Error Constants
(define-constant contract-owner tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-ALREADY-EXISTS (err u101))
(define-constant ERR-DOES-NOT-EXIST (err u102))
(define-constant ERR-LISTING-CLOSED (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-ALREADY-SETTLED (err u105))
(define-constant ERR-LISTING-NOT-CLOSABLE (err u106))
(define-constant ERR-LISTING-NOT-CANCELABLE (err u107))
(define-constant ERR-INVALID-SEAT-COUNT (err u108))
(define-constant ERR-INVALID-CLOSE-HEIGHT (err u109))
(define-constant ERR-INVALID-SALE-TYPE (err u110))
(define-constant ERR-MISSING-PRICING (err u111))
(define-constant ERR-INVALID-SECTION (err u112))
(define-constant ERR-LISTING-EXPIRED (err u113))
(define-constant ERR-NO-AVAILABLE-SEATS (err u114))
(define-constant ERR-TOO-MANY-SECTIONS (err u115))
(define-constant ERR-INVALID-AVAILABILITY (err u116))
(define-constant ERR-NOT-PURCHASED (err u117))
(define-constant ERR-REFUND-FAILED (err u118))
(define-constant ERR-REFUND-PROCESSING (err u119))
(define-constant ERR-INVALID-DESCRIPTION (err u120))
(define-constant ERR-INVALID-PRICE-AMOUNT (err u121))

;; Data variables
(define-data-var next-concert-listing-id uint u0)

;; Sale types
(define-data-var sale-types (list 10 (string-ascii 20)) (list "fixed-price" "auction" "dynamic-pricing"))

;; Define complete listing structure
(define-map listings
  { concert-listing-id: uint }
  {
    seller: principal,
    concert-description: (string-ascii 256),
    seat-sections: (list 10 (string-ascii 64)),
    total-revenue: uint,
    is-listing-active: bool,
    available-sections: (list 5 uint),
    listing-close-height: uint,
    sale-type: (string-ascii 20),
    prices: (optional (list 10 uint))
  }
)

;; Define complete purchase structure
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
(define-private (calculate-refund (listing { seller: principal, concert-description: (string-ascii 256), seat-sections: (list 10 (string-ascii 64)), total-revenue: uint, is-listing-active: bool, available-sections: (list 5 uint), listing-close-height: uint, sale-type: (string-ascii 20), prices: (optional (list 10 uint)) }) (purchase { selected-section: uint, paid-amount: uint }) (available-section-ids (list 5 uint)))
  (let
    (
      (sale-type (get sale-type listing))
      (total-listing-revenue (get total-revenue listing))
      (buyer-payment (get paid-amount purchase))
    )
    (if (is-eq sale-type "fixed-price")
      buyer-payment
      (if (is-eq sale-type "auction")
        (/ (* buyer-payment total-listing-revenue) total-listing-revenue)
        (let
          (
            (price-list (unwrap! (get prices listing) u0))
            (section-price (unwrap! (element-at price-list (- (get selected-section purchase) u1)) u0))
          )
          (+ buyer-payment (* buyer-payment (/ section-price u100)))
        )
      )
    )
  )
)

(define-private (get-payment-for-section (section uint) (concert-listing-id uint))
  (let
    (
      (purchase (get-purchase concert-listing-id tx-sender))
    )
    (if (is-some purchase)
      (let
        ((purchase-data (unwrap! purchase u0)))
        (if (is-eq (get selected-section purchase-data) section)
          (get paid-amount purchase-data)
          u0
        )
      )
      u0
    )
  )
)

(define-private (validate-sections-helper (sections (list 5 uint)) (max-section uint))
  (let
    (
      (section-1 (element-at sections u0))
      (section-2 (element-at sections u1))
      (section-3 (element-at sections u2))
      (section-4 (element-at sections u3))
      (section-5 (element-at sections u4))
    )
    (and
      (match section-1
        value (and (> value u0) (<= value max-section))
        true)
      (match section-2
        value (and (> value u0) (<= value max-section))
        true)
      (match section-3
        value (and (> value u0) (<= value max-section))
        true)
      (match section-4
        value (and (> value u0) (<= value max-section))
        true)
      (match section-5
        value (and (> value u0) (<= value max-section))
        true)
    )
  )
)

(define-private (process-refunds (concert-listing-id uint))
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
      ERR-REFUND-PROCESSING
    )
  )
)

;; Public functions
(define-public (create-listing (concert-description (string-ascii 256)) (seat-sections (list 10 (string-ascii 64))) (listing-close-height uint) (sale-type (string-ascii 20)) (prices (optional (list 10 uint))))
  (let
    (
      (new-concert-listing-id (var-get next-concert-listing-id))
    )
    (asserts! (> (len concert-description) u0) ERR-INVALID-DESCRIPTION)
    (asserts! (> (len seat-sections) u1) ERR-INVALID-SEAT-COUNT)
    (asserts! (> listing-close-height block-height) ERR-INVALID-CLOSE-HEIGHT)
    (asserts! (is-some (index-of (var-get sale-types) sale-type)) ERR-INVALID-SALE-TYPE)
    (asserts! (or (is-eq sale-type "fixed-price") (is-eq sale-type "auction") (is-some prices)) ERR-MISSING-PRICING)
    
    (map-set listings
      { concert-listing-id: new-concert-listing-id }
      {
        seller: tx-sender,
        concert-description: concert-description,
        seat-sections: seat-sections,
        total-revenue: u0,
        is-listing-active: true,
        available-sections: (list),
        listing-close-height: listing-close-height,
        sale-type: sale-type,
        prices: prices
      }
    )
    (var-set next-concert-listing-id (+ new-concert-listing-id u1))
    (ok new-concert-listing-id)
  )
)

(define-public (purchase-ticket (concert-listing-id uint) (selected-section uint) (payment-amount uint))
  (let
    (
      (listing (unwrap! (get-listing concert-listing-id) ERR-DOES-NOT-EXIST))
      (existing-purchase (default-to { selected-section: u0, paid-amount: u0 } (get-purchase concert-listing-id tx-sender)))
    )
    (asserts! (> payment-amount u0) ERR-INVALID-PRICE-AMOUNT)
    (asserts! (get is-listing-active listing) ERR-LISTING-CLOSED)
    (asserts! (>= (len (get seat-sections listing)) selected-section) ERR-INVALID-SECTION)
    (asserts! (< block-height (get listing-close-height listing)) ERR-LISTING-EXPIRED)
    (try! (stx-transfer? payment-amount tx-sender (as-contract tx-sender)))
    
    (map-set purchases
      { concert-listing-id: concert-listing-id, buyer: tx-sender }
      {
        selected-section: selected-section,
        paid-amount: (+ payment-amount (get paid-amount existing-purchase))
      }
    )
    
    (map-set listings
      { concert-listing-id: concert-listing-id }
      (merge listing { total-revenue: (+ (get total-revenue listing) payment-amount) })
    )
    (ok true)
  )
)

(define-public (close-listing (concert-listing-id uint))
  (let
    (
      (listing (unwrap! (get-listing concert-listing-id) ERR-DOES-NOT-EXIST))
    )
    (asserts! (or (is-eq (get seller listing) tx-sender) (is-eq contract-owner tx-sender)) ERR-UNAUTHORIZED)
    (asserts! (get is-listing-active listing) ERR-LISTING-CLOSED)
    (asserts! (>= block-height (get listing-close-height listing)) ERR-LISTING-NOT-CLOSABLE)
    
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
    
    (process-refunds concert-listing-id)
  )
)

(define-public (update-section-availability (concert-listing-id uint) (available-section-ids (list 5 uint)))
  (let
    (
      (listing (unwrap! (get-listing concert-listing-id) ERR-DOES-NOT-EXIST))
    )
    (asserts! (is-eq contract-owner tx-sender) ERR-UNAUTHORIZED)
    (asserts! (not (get is-listing-active listing)) ERR-LISTING-CLOSED)
    (asserts! (is-eq (len (get available-sections listing)) u0) ERR-ALREADY-SETTLED)
    (asserts! (> (len available-section-ids) u0) ERR-NO-AVAILABLE-SEATS)
    (asserts! (<= (len available-section-ids) u5) ERR-TOO-MANY-SECTIONS)
    
    (asserts! (validate-sections-helper available-section-ids (len (get seat-sections listing))) ERR-INVALID-AVAILABILITY)
    
    (map-set listings
      { concert-listing-id: concert-listing-id }
      (merge listing { available-sections: available-section-ids })
    )
    (ok true)
  )
)

(define-public (claim-refund (concert-listing-id uint))
  (let
    (
      (listing (unwrap! (get-listing concert-listing-id) ERR-DOES-NOT-EXIST))
      (purchase (unwrap! (get-purchase concert-listing-id tx-sender) ERR-DOES-NOT-EXIST))
      (available-section-ids (get available-sections listing))
    )
    (asserts! (is-some (index-of available-section-ids (get selected-section purchase))) ERR-NOT-PURCHASED)
    (let
      (
        (refund-amount (calculate-refund listing purchase available-section-ids))
      )
      (try! (as-contract (stx-transfer? refund-amount tx-sender tx-sender)))
      (map-delete purchases { concert-listing-id: concert-listing-id, buyer: tx-sender })
      (ok refund-amount)
    )
  )
)

;; Contract initialization
(begin
  (var-set next-concert-listing-id u0)
)

;; Export the Component function (required for v0)
(define-public (Component)
  (ok true))