(define-trait nft-trait
  ((get-last-token-id () (response uint uint))
   (get-token-uri (uint) (response (optional (string-ascii 256)) uint))
   (get-owner (uint) (response (optional principal) uint))
   (transfer (uint principal principal) (response bool uint))))

(define-non-fungible-token elected-official uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-not-authorized (err u102))
(define-constant err-token-exists (err u103))
(define-constant err-token-not-found (err u104))
(define-constant err-invalid-term (err u105))
(define-constant err-term-expired (err u106))
(define-constant err-transfer-restricted (err u107))
(define-constant err-invalid-jurisdiction (err u108))

(define-data-var last-token-id uint u0)
(define-data-var contract-uri (string-ascii 256) "")

(define-map token-metadata uint {
  name: (string-ascii 64),
  position: (string-ascii 64),
  jurisdiction: (string-ascii 64),
  term-start: uint,
  term-end: uint,
  issued-at: uint,
  verified: bool,
  image-uri: (optional (string-ascii 256))
})

(define-map authorized-issuers principal bool)

(define-map jurisdiction-codes (string-ascii 64) bool)

(define-map position-types (string-ascii 64) bool)

(define-public (initialize-contract (uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-uri uri)
    (map-set authorized-issuers contract-owner true)
    (map-set jurisdiction-codes "FEDERAL" true)
    (map-set jurisdiction-codes "STATE" true)
    (map-set jurisdiction-codes "COUNTY" true)
    (map-set jurisdiction-codes "CITY" true)
    (map-set jurisdiction-codes "MUNICIPAL" true)
    (map-set position-types "PRESIDENT" true)
    (map-set position-types "SENATOR" true)
    (map-set position-types "REPRESENTATIVE" true)
    (map-set position-types "GOVERNOR" true)
    (map-set position-types "MAYOR" true)
    (map-set position-types "COMMISSIONER" true)
    (map-set position-types "JUDGE" true)
    (map-set position-types "SHERIFF" true)
    (ok true)))

(define-public (add-authorized-issuer (issuer principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set authorized-issuers issuer true))))

(define-public (remove-authorized-issuer (issuer principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-delete authorized-issuers issuer))))

(define-public (add-jurisdiction (code (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set jurisdiction-codes code true))))

(define-public (add-position-type (position (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set position-types position true))))

(define-public (mint-official-nft 
  (recipient principal)
  (name (string-ascii 64))
  (position (string-ascii 64))
  (jurisdiction (string-ascii 64))
  (term-start uint)
  (term-end uint)
  (image-uri (optional (string-ascii 256))))
  (let ((token-id (+ (var-get last-token-id) u1))
        (current-height stacks-block-height))
    (asserts! (default-to false (map-get? authorized-issuers tx-sender)) err-not-authorized)
    (asserts! (default-to false (map-get? jurisdiction-codes jurisdiction)) err-invalid-jurisdiction)
    (asserts! (default-to false (map-get? position-types position)) err-invalid-term)
    (asserts! (< term-start term-end) err-invalid-term)
    (asserts! (> term-end current-height) err-invalid-term)
    (asserts! (is-none (nft-get-owner? elected-official token-id)) err-token-exists)
    (try! (nft-mint? elected-official token-id recipient))
    (map-set token-metadata token-id {
      name: name,
      position: position,
      jurisdiction: jurisdiction,
      term-start: term-start,
      term-end: term-end,
      issued-at: current-height,
      verified: true,
      image-uri: image-uri
    })
    (var-set last-token-id token-id)
    (ok token-id)))

(define-public (verify-official (token-id uint))
  (let ((metadata (unwrap! (map-get? token-metadata token-id) err-token-not-found)))
    (asserts! (default-to false (map-get? authorized-issuers tx-sender)) err-not-authorized)
    (ok (map-set token-metadata token-id (merge metadata { verified: true })))))

(define-public (revoke-verification (token-id uint))
  (let ((metadata (unwrap! (map-get? token-metadata token-id) err-token-not-found)))
    (asserts! (default-to false (map-get? authorized-issuers tx-sender)) err-not-authorized)
    (ok (map-set token-metadata token-id (merge metadata { verified: false })))))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (let ((metadata (unwrap! (map-get? token-metadata token-id) err-token-not-found))
        (current-height stacks-block-height))
    (asserts! (is-eq tx-sender sender) err-not-token-owner)
    (asserts! (is-eq sender (unwrap! (nft-get-owner? elected-official token-id) err-not-token-owner)) err-not-token-owner)
    (asserts! (> current-height (get term-end metadata)) err-transfer-restricted)
    (nft-transfer? elected-official token-id sender recipient)))

(define-public (emergency-transfer (token-id uint) (new-owner principal))
  (let ((metadata (unwrap! (map-get? token-metadata token-id) err-token-not-found)))
    (asserts! (default-to false (map-get? authorized-issuers tx-sender)) err-not-authorized)
    (nft-transfer? elected-official token-id 
      (unwrap! (nft-get-owner? elected-official token-id) err-token-not-found) 
      new-owner)))

(define-public (update-term-dates (token-id uint) (new-term-start uint) (new-term-end uint))
  (let ((metadata (unwrap! (map-get? token-metadata token-id) err-token-not-found)))
    (asserts! (default-to false (map-get? authorized-issuers tx-sender)) err-not-authorized)
    (asserts! (< new-term-start new-term-end) err-invalid-term)
    (ok (map-set token-metadata token-id 
         (merge metadata { term-start: new-term-start, term-end: new-term-end })))))

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id)))

(define-read-only (get-token-uri (token-id uint))
  (ok (some (var-get contract-uri))))

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? elected-official token-id)))

(define-read-only (get-official-metadata (token-id uint))
  (map-get? token-metadata token-id))

(define-read-only (is-verified-official (token-id uint))
  (match (map-get? token-metadata token-id)
    metadata (get verified metadata)
    false))

(define-read-only (is-term-active (token-id uint))
  (match (map-get? token-metadata token-id)
    metadata (let ((current-height stacks-block-height))
               (and (>= current-height (get term-start metadata))
                    (<= current-height (get term-end metadata))))
    false))

(define-read-only (get-term-status (token-id uint))
  (match (map-get? token-metadata token-id)
    metadata (let ((current-height stacks-block-height)
                   (term-start (get term-start metadata))
                   (term-end (get term-end metadata)))
               (if (< current-height term-start)
                 "FUTURE"
                 (if (<= current-height term-end)
                   "ACTIVE"
                   "EXPIRED")))
    "NOT_FOUND"))

(define-read-only (is-authorized-issuer (issuer principal))
  (default-to false (map-get? authorized-issuers issuer)))

(define-read-only (is-valid-jurisdiction (code (string-ascii 64)))
  (default-to false (map-get? jurisdiction-codes code)))

(define-read-only (is-valid-position (position (string-ascii 64)))
  (default-to false (map-get? position-types position)))


(define-read-only (get-contract-info)
  {
    contract-owner: contract-owner,
    total-tokens: (var-get last-token-id),
    contract-uri: (var-get contract-uri)
  })
