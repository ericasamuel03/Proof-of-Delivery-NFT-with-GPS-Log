(define-non-fungible-token delivery-proof uint)

(define-data-var last-token-id uint u0)
(define-data-var contract-owner principal tx-sender)

(define-map delivery-metadata uint {
    tracking-number: (string-ascii 32),
    recipient-address: (string-ascii 256),
    location-hash: (string-ascii 64),
    delivery-signature: (string-ascii 128),
    delivery-timestamp: uint,
    delivery-company: principal,
    delivery-status: (string-ascii 16)
})

(define-map company-authorization principal bool)

(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-not-authorized-company (err u102))
(define-constant err-token-not-found (err u103))
(define-constant err-already-delivered (err u104))
(define-constant err-invalid-status (err u105))

(define-public (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-public (get-token-uri (token-id uint))
    (ok none)
)

(define-public (get-owner (token-id uint))
    (ok (nft-get-owner? delivery-proof token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (nft-transfer? delivery-proof token-id sender recipient)
    )
)

(define-public (authorize-company (company principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
        (ok (map-set company-authorization company true))
    )
)

(define-public (revoke-company (company principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
        (ok (map-set company-authorization company false))
    )
)

(define-public (mint-delivery-proof 
    (recipient principal)
    (tracking-number (string-ascii 32))
    (recipient-address (string-ascii 256))
    (location-hash (string-ascii 64)))
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
            (is-authorized (default-to false (map-get? company-authorization tx-sender)))
        )
        (asserts! is-authorized err-not-authorized-company)
        (try! (nft-mint? delivery-proof token-id recipient))
        (map-set delivery-metadata token-id {
            tracking-number: tracking-number,
            recipient-address: recipient-address,
            location-hash: location-hash,
            delivery-signature: "",
            delivery-timestamp: (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))),
            delivery-company: tx-sender,
            delivery-status: "pending"
        })
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

(define-public (confirm-delivery 
    (token-id uint)
    (delivery-signature (string-ascii 128))
    (final-location-hash (string-ascii 64)))
    (let
        (
            (metadata (unwrap! (map-get? delivery-metadata token-id) err-token-not-found))
            (is-authorized (default-to false (map-get? company-authorization tx-sender)))
        )
        (asserts! is-authorized err-not-authorized-company)
        (asserts! (is-eq (get delivery-company metadata) tx-sender) err-not-authorized-company)
        (asserts! (is-eq (get delivery-status metadata) "pending") err-already-delivered)
        (map-set delivery-metadata token-id (merge metadata {
            delivery-signature: delivery-signature,
            location-hash: final-location-hash,
            delivery-timestamp: (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))),
            delivery-status: "delivered"
        }))
        (ok true)
    )
)

(define-public (mark-failed-delivery (token-id uint))
    (let
        (
            (metadata (unwrap! (map-get? delivery-metadata token-id) err-token-not-found))
            (is-authorized (default-to false (map-get? company-authorization tx-sender)))
        )
        (asserts! is-authorized err-not-authorized-company)
        (asserts! (is-eq (get delivery-company metadata) tx-sender) err-not-authorized-company)
        (asserts! (is-eq (get delivery-status metadata) "pending") err-already-delivered)
        (map-set delivery-metadata token-id (merge metadata {
            delivery-timestamp: (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))),
            delivery-status: "failed"
        }))
        (ok true)
    )
)

(define-read-only (get-delivery-metadata (token-id uint))
    (map-get? delivery-metadata token-id)
)

(define-read-only (is-company-authorized (company principal))
    (default-to false (map-get? company-authorization company))
)

(define-read-only (verify-delivery 
    (token-id uint)
    (expected-tracking (string-ascii 32))
    (expected-address (string-ascii 256)))
    (match (map-get? delivery-metadata token-id)
        metadata (and 
            (is-eq (get tracking-number metadata) expected-tracking)
            (is-eq (get recipient-address metadata) expected-address)
            (is-eq (get delivery-status metadata) "delivered")
        )
        false
    )
)

(define-read-only (get-delivery-status (token-id uint))
    (match (map-get? delivery-metadata token-id)
        metadata (some (get delivery-status metadata))
        none
    )
)

(define-read-only (get-delivery-signature (token-id uint))
    (match (map-get? delivery-metadata token-id)
        metadata (some (get delivery-signature metadata))
        none
    )
)

(define-read-only (get-location-hash (token-id uint))
    (match (map-get? delivery-metadata token-id)
        metadata (some (get location-hash metadata))
        none
    )
)

(define-read-only (get-tracking-number (token-id uint))
    (match (map-get? delivery-metadata token-id)
        metadata (some (get tracking-number metadata))
        none
    )
)

(define-read-only (get-delivery-company (token-id uint))
    (match (map-get? delivery-metadata token-id)
        metadata (some (get delivery-company metadata))
        none
    )
)

(map-set company-authorization (var-get contract-owner) true)

(define-map company-performance principal {
    total-deliveries: uint,
    successful-deliveries: uint,
    failed-deliveries: uint,
    total-delivery-time: uint,
    last-updated: uint
})

(define-constant performance-decimals u10000)
(define-constant min-deliveries-for-rating u5)

(define-private (update-company-performance-on-delivery (company principal) (success bool) (delivery-time uint))
    (let
        (
            (current-stats (default-to 
                {total-deliveries: u0, successful-deliveries: u0, failed-deliveries: u0, total-delivery-time: u0, last-updated: u0}
                (map-get? company-performance company)))
            (new-total (+ (get total-deliveries current-stats) u1))
            (new-successful (if success (+ (get successful-deliveries current-stats) u1) (get successful-deliveries current-stats)))
            (new-failed (if success (get failed-deliveries current-stats) (+ (get failed-deliveries current-stats) u1)))
            (new-time-total (+ (get total-delivery-time current-stats) delivery-time))
            (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
        )
        (map-set company-performance company {
            total-deliveries: new-total,
            successful-deliveries: new-successful,
            failed-deliveries: new-failed,
            total-delivery-time: new-time-total,
            last-updated: current-time
        })
    )
)

(define-read-only (get-company-success-rate (company principal))
    (match (map-get? company-performance company)
        stats (if (> (get total-deliveries stats) u0)
            (some (/ (* (get successful-deliveries stats) performance-decimals) (get total-deliveries stats)))
            none)
        none
    )
)

(define-read-only (get-company-reputation-score (company principal))
    (match (map-get? company-performance company)
        stats (if (>= (get total-deliveries stats) min-deliveries-for-rating)
            (let
                (
                    (success-rate (/ (* (get successful-deliveries stats) performance-decimals) (get total-deliveries stats)))
                    (delivery-volume-bonus (if (>= (get total-deliveries stats) u50) u500 u0))
                    (base-score (+ success-rate delivery-volume-bonus))
                )
                (some (if (> base-score performance-decimals) performance-decimals base-score))
            )
            none)
        none
    )
)

(define-read-only (get-company-performance-stats (company principal))
    (map-get? company-performance company)
)

(define-read-only (get-average-delivery-time (company principal))
    (match (map-get? company-performance company)
        stats (if (> (get total-deliveries stats) u0)
            (some (/ (get total-delivery-time stats) (get total-deliveries stats)))
            none)
        none
    )
)

(define-map insurance-pools principal uint)
(define-map insurance-claims uint {claimant: principal, amount: uint, processed: bool})
(define-data-var insurance-claim-id uint u0)
(define-data-var insurance-rate uint u100000)
(define-data-var max-claim-amount uint u500000)

(define-public (deposit-insurance (amount uint))
    (let ((current-balance (default-to u0 (map-get? insurance-pools tx-sender))))
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set insurance-pools tx-sender (+ current-balance amount))
        (ok amount)
    )
)

(define-public (withdraw-insurance (amount uint))
    (let ((current-balance (default-to u0 (map-get? insurance-pools tx-sender))))
        (asserts! (>= current-balance amount) (err u110))
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (map-set insurance-pools tx-sender (- current-balance amount))
        (ok amount)
    )
)

(define-private (process-insurance-claim (token-id uint) (claim-type (string-ascii 16)))
    (let (
        (metadata (unwrap! (map-get? delivery-metadata token-id) (err u103)))
        (recipient (unwrap! (nft-get-owner? delivery-proof token-id) (err u103)))
        (company (get delivery-company metadata))
        (company-balance (default-to u0 (map-get? insurance-pools company)))
        (claim-amount (if (is-eq claim-type "failed") (var-get max-claim-amount) 
                     (/ (var-get max-claim-amount) u2)))
        (actual-payout (if (> claim-amount company-balance) company-balance claim-amount))
        (new-claim-id (+ (var-get insurance-claim-id) u1))
    )
        (if (> actual-payout u0)
            (begin
                (try! (as-contract (stx-transfer? actual-payout tx-sender recipient)))
                (map-set insurance-pools company (- company-balance actual-payout))
                (map-set insurance-claims new-claim-id {
                    claimant: recipient, amount: actual-payout, processed: true})
                (var-set insurance-claim-id new-claim-id)
                (ok actual-payout)
            )
            (ok u0)
        )
    )
)

(define-public (enhanced-confirm-delivery 
    (token-id uint) (delivery-signature (string-ascii 128)) (final-location-hash (string-ascii 64)))
    (let ((delivery-result (confirm-delivery token-id delivery-signature final-location-hash)))
        (match delivery-result
            success (ok true)
            error (err error)
        )
    )
)

(define-public (enhanced-mark-failed-delivery (token-id uint))
    (let ((failure-result (mark-failed-delivery token-id)))
        (match failure-result
            success (match (process-insurance-claim token-id "failed")
                payout-result (ok true)
                payout-error (ok true)
            )
            error (err error)
        )
    )
)

(define-read-only (get-insurance-balance (company principal))
    (default-to u0 (map-get? insurance-pools company))
)

(define-read-only (get-claim-details (claim-id uint))
    (map-get? insurance-claims claim-id)
)

(define-read-only (calculate-required-insurance (delivery-count uint))
    (ok (* delivery-count (var-get insurance-rate)))
)


(define-map delivery-verifiers uint (list 5 principal))
(define-map verifier-signatures uint (list 5 {verifier: principal, signature: (string-ascii 64), timestamp: uint}))
(define-map required-verifier-count uint uint)
(define-constant err-verifier-not-authorized (err u120))
(define-constant err-already-verified (err u121))
(define-constant err-insufficient-verifications (err u122))
(define-constant max-verifiers u5)

(define-public (set-delivery-verifiers (token-id uint) (verifiers (list 5 principal)) (required-count uint))
    (let ((token-owner (unwrap! (nft-get-owner? delivery-proof token-id) err-token-not-found)))
        (asserts! (is-eq tx-sender token-owner) err-not-token-owner)
        (asserts! (and (> required-count u0) (<= required-count (len verifiers))) err-invalid-status)
        (map-set delivery-verifiers token-id verifiers)
        (map-set required-verifier-count token-id required-count)
        (ok true)
    )
)

(define-public (sign-verification (token-id uint) (signature (string-ascii 64)))
    (let (
        (authorized-verifiers (default-to (list) (map-get? delivery-verifiers token-id)))
        (current-signatures (default-to (list) (map-get? verifier-signatures token-id)))
        (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
        (already-signed (is-some (index-of? (map get-verifier current-signatures) tx-sender)))
    )
        (asserts! (is-some (index-of? authorized-verifiers tx-sender)) err-verifier-not-authorized)
        (asserts! (not already-signed) err-already-verified)
        (map-set verifier-signatures token-id 
            (unwrap-panic (as-max-len? (append current-signatures {verifier: tx-sender, signature: signature, timestamp: current-time}) u5)))
        (ok true)
    )
)

(define-public (finalize-multi-sig-delivery (token-id uint) (final-location-hash (string-ascii 64)))
    (let (
        (metadata (unwrap! (map-get? delivery-metadata token-id) err-token-not-found))
        (signatures (default-to (list) (map-get? verifier-signatures token-id)))
        (required-count (default-to u1 (map-get? required-verifier-count token-id)))
        (is-authorized (default-to false (map-get? company-authorization tx-sender)))
    )
        (asserts! is-authorized err-not-authorized-company)
        (asserts! (is-eq (get delivery-company metadata) tx-sender) err-not-authorized-company)
        (asserts! (>= (len signatures) required-count) err-insufficient-verifications)
        (asserts! (is-eq (get delivery-status metadata) "pending") err-already-delivered)
        (map-set delivery-metadata token-id (merge metadata {
            delivery-signature: (concat-signatures signatures),
            location-hash: final-location-hash,
            delivery-timestamp: (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))),
            delivery-status: "verified"
        }))
        (ok true)
    )
)

(define-private (get-verifier (sig-entry {verifier: principal, signature: (string-ascii 64), timestamp: uint}))
    (get verifier sig-entry)
)

(define-private (concat-signatures (sigs (list 5 {verifier: principal, signature: (string-ascii 64), timestamp: uint})))
    (if (> (len sigs) u0) "multi-verified" "")
)

(define-read-only (get-delivery-verifiers (token-id uint))
    (map-get? delivery-verifiers token-id)
)

(define-read-only (get-verification-signatures (token-id uint))
    (map-get? verifier-signatures token-id)
)

(define-read-only (check-verification-status (token-id uint))
    (let (
        (signatures (default-to (list) (map-get? verifier-signatures token-id)))
        (required-count (default-to u1 (map-get? required-verifier-count token-id)))
    )
        (ok {verified-count: (len signatures), required-count: required-count, is-ready: (>= (len signatures) required-count)})
    )
)