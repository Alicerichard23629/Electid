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
(define-constant err-invalid-vote (err u109))
(define-constant err-proposal-not-found (err u110))
(define-constant err-already-voted (err u111))
(define-constant err-proposal-closed (err u112))
(define-constant err-invalid-proposal (err u113))

(define-data-var last-token-id uint u0)
(define-data-var contract-uri (string-ascii 256) "")
(define-data-var last-proposal-id uint u0)
(define-data-var last-vote-id uint u0)

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

(define-map proposals uint {
  title: (string-ascii 128),
  description: (string-ascii 512),
  proposal-type: (string-ascii 64),
  jurisdiction: (string-ascii 64),
  created-by: principal,
  created-at: uint,
  voting-deadline: uint,
  is-active: bool,
  total-votes: uint,
  yes-votes: uint,
  no-votes: uint,
  abstain-votes: uint
})

(define-map votes uint {
  proposal-id: uint,
  voter-token-id: uint,
  vote-choice: (string-ascii 16),
  voted-at: uint,
  rationale: (optional (string-ascii 256))
})

(define-map official-votes { token-id: uint, proposal-id: uint } uint)

(define-map proposal-types (string-ascii 64) bool)

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
    (map-set proposal-types "BILL" true)
    (map-set proposal-types "RESOLUTION" true)
    (map-set proposal-types "ORDINANCE" true)
    (map-set proposal-types "AMENDMENT" true)
    (map-set proposal-types "BUDGET" true)
    (map-set proposal-types "APPOINTMENT" true)
    (map-set proposal-types "POLICY" true)
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

(define-public (add-proposal-type (proposal-type (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set proposal-types proposal-type true))))

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

(define-public (create-proposal
  (title (string-ascii 128))
  (description (string-ascii 512))
  (proposal-type (string-ascii 64))
  (jurisdiction (string-ascii 64))
  (voting-deadline uint))
  (let ((proposal-id (+ (var-get last-proposal-id) u1))
        (current-height stacks-block-height))
    (asserts! (default-to false (map-get? authorized-issuers tx-sender)) err-not-authorized)
    (asserts! (default-to false (map-get? proposal-types proposal-type)) err-invalid-proposal)
    (asserts! (default-to false (map-get? jurisdiction-codes jurisdiction)) err-invalid-jurisdiction)
    (asserts! (> voting-deadline current-height) err-invalid-proposal)
    (map-set proposals proposal-id {
      title: title,
      description: description,
      proposal-type: proposal-type,
      jurisdiction: jurisdiction,
      created-by: tx-sender,
      created-at: current-height,
      voting-deadline: voting-deadline,
      is-active: true,
      total-votes: u0,
      yes-votes: u0,
      no-votes: u0,
      abstain-votes: u0
    })
    (var-set last-proposal-id proposal-id)
    (ok proposal-id)))

(define-public (cast-vote
  (proposal-id uint)
  (token-id uint)
  (vote-choice (string-ascii 16))
  (rationale (optional (string-ascii 256))))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
        (official-metadata (unwrap! (map-get? token-metadata token-id) err-token-not-found))
        (vote-id (+ (var-get last-vote-id) u1))
        (current-height stacks-block-height))
    (asserts! (is-eq tx-sender (unwrap! (nft-get-owner? elected-official token-id) err-not-token-owner)) err-not-token-owner)
    (asserts! (get verified official-metadata) err-not-authorized)
    (asserts! (get is-active proposal) err-proposal-closed)
    (asserts! (<= current-height (get voting-deadline proposal)) err-proposal-closed)
    (asserts! (is-none (map-get? official-votes { token-id: token-id, proposal-id: proposal-id })) err-already-voted)
    (asserts! (or (is-eq vote-choice "YES") (or (is-eq vote-choice "NO") (is-eq vote-choice "ABSTAIN"))) err-invalid-vote)
    (map-set votes vote-id {
      proposal-id: proposal-id,
      voter-token-id: token-id,
      vote-choice: vote-choice,
      voted-at: current-height,
      rationale: rationale
    })
    (map-set official-votes { token-id: token-id, proposal-id: proposal-id } vote-id)
    (map-set proposals proposal-id (merge proposal {
      total-votes: (+ (get total-votes proposal) u1),
      yes-votes: (if (is-eq vote-choice "YES") (+ (get yes-votes proposal) u1) (get yes-votes proposal)),
      no-votes: (if (is-eq vote-choice "NO") (+ (get no-votes proposal) u1) (get no-votes proposal)),
      abstain-votes: (if (is-eq vote-choice "ABSTAIN") (+ (get abstain-votes proposal) u1) (get abstain-votes proposal))
    }))
    (var-set last-vote-id vote-id)
    (ok vote-id)))

(define-public (close-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found)))
    (asserts! (default-to false (map-get? authorized-issuers tx-sender)) err-not-authorized)
    (asserts! (get is-active proposal) err-proposal-closed)
    (ok (map-set proposals proposal-id (merge proposal { is-active: false })))))

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

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id))

(define-read-only (get-vote (vote-id uint))
  (map-get? votes vote-id))

(define-read-only (get-official-vote (token-id uint) (proposal-id uint))
  (match (map-get? official-votes { token-id: token-id, proposal-id: proposal-id })
    vote-id (map-get? votes vote-id)
    none))

(define-read-only (has-voted (token-id uint) (proposal-id uint))
  (is-some (map-get? official-votes { token-id: token-id, proposal-id: proposal-id })))

(define-read-only (get-proposal-results (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal (some {
      total-votes: (get total-votes proposal),
      yes-votes: (get yes-votes proposal),
      no-votes: (get no-votes proposal),
      abstain-votes: (get abstain-votes proposal),
      yes-percentage: (if (> (get total-votes proposal) u0) 
                       (/ (* (get yes-votes proposal) u100) (get total-votes proposal)) 
                       u0),
      no-percentage: (if (> (get total-votes proposal) u0) 
                      (/ (* (get no-votes proposal) u100) (get total-votes proposal)) 
                      u0),
      abstain-percentage: (if (> (get total-votes proposal) u0) 
                           (/ (* (get abstain-votes proposal) u100) (get total-votes proposal)) 
                           u0)
    })
    none))

(define-read-only (get-voting-stats (token-id uint))
  (let ((metadata (unwrap! (map-get? token-metadata token-id) none)))
    (some {
      name: (get name metadata),
      position: (get position metadata),
      jurisdiction: (get jurisdiction metadata),
      total-votes-cast: (get-total-votes-by-official token-id),
      verified: (get verified metadata)
    })))

(define-read-only (get-total-votes-by-official (token-id uint))
  (fold count-votes (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20) u0))

(define-read-only (count-votes (proposal-id uint) (accumulator uint))
  (if (is-some (map-get? official-votes { token-id: proposal-id, proposal-id: proposal-id }))
    (+ accumulator u1)
    accumulator))

(define-read-only (is-proposal-active (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal (and (get is-active proposal) (<= stacks-block-height (get voting-deadline proposal)))
    false))

(define-read-only (get-last-proposal-id)
  (var-get last-proposal-id))

(define-read-only (get-last-vote-id)
  (var-get last-vote-id))

(define-read-only (is-valid-proposal-type (proposal-type (string-ascii 64)))
  (default-to false (map-get? proposal-types proposal-type)))


(define-read-only (get-contract-info)
  {
    contract-owner: contract-owner,
    total-tokens: (var-get last-token-id),
    contract-uri: (var-get contract-uri),
    total-proposals: (var-get last-proposal-id),
    total-votes: (var-get last-vote-id)
  })
