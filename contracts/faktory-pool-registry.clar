;; Pool Registry
;; A simple registry to track all FakFun and Charisma liquidity pools for easy discovery

;; Error constants
(define-constant ERR_NOT_AUTHORIZED (err u1001))
(define-constant ERR_POOL_ALREADY_EXISTS (err u1002))
(define-constant ERR_POOL_NOT_FOUND (err u1003))
(define-constant ERR_INVALID_POOL_DATA (err u1004))
(define-constant ERROR_RESERVES (err u1005))

;; Opcodes
(define-constant OP_SWAP_A_TO_B 0x00)
(define-constant OP_SWAP_B_TO_A 0x01)
(define-constant OP_ADD_LIQUIDITY 0x02)
(define-constant OP_REMOVE_LIQUIDITY 0x03)
(define-constant OP_LOOKUP_RESERVES 0x04)

;; Contract deployer (admin)
(define-constant DEPLOYER tx-sender)

;; Pool counter
(define-data-var last-pool-id uint u0)

;; Pool registry map: pool-id -> pool info with fixed metadata
(define-map pools uint {
    pool-contract: principal,
    pool-name: (string-ascii 64),
    pool-symbol: (string-ascii 32),
    x-token: principal,
    y-token: principal,
    creation-height: uint,
    lp-fee: uint,
    pool-uri: (string-utf8 256),
})

;; Pool lookup by contract address
(define-map pool-contracts principal uint)

;; Trait for pool contracts
(use-trait pool-trait 'SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS.dexterity-traits-v0.liquidity-pool-trait)

;; --- Read-only functions ---

(define-read-only (get-last-pool-id)
   (var-get last-pool-id)
)

(define-read-only (get-pool-by-id (pool-id uint))
    (map-get? pools pool-id)
)

(define-read-only (get-pool-by-contract (pool-contract principal))
    (match (map-get? pool-contracts pool-contract)
        pool-id (map-get? pools pool-id)
        none
    )
)

;; --- Public functions ---

(define-public (register-pool 
    (pool-contract <pool-trait>)
    (name (string-ascii 64))
    (symbol (string-ascii 32))
    (x-token principal)
    (y-token principal)
    (creation-height uint)
    (lp-fee uint)
    (pool-uri (optional (string-utf8 256)))
)
    (let (
        (new-pool-id (+ (var-get last-pool-id) u1))
        (uri (default-to u"https://faktory.fun/" pool-uri))
        (caller tx-sender)
        (reserves-data (unwrap! (contract-call? pool-contract quote u0 (some OP_LOOKUP_RESERVES)) ERROR_RESERVES))
    )
        ;; Only deployer can register pools
        (asserts! (is-eq caller DEPLOYER) ERR_NOT_AUTHORIZED)
        
        ;; Check pool doesn't already exist
        (asserts! (is-none (map-get? pool-contracts (contract-of pool-contract))) ERR_POOL_ALREADY_EXISTS)
        
        ;; Validate inputs
        (asserts! (> (len name) u0) ERR_INVALID_POOL_DATA)
        (asserts! (> (len symbol) u0) ERR_INVALID_POOL_DATA)
        
        ;; Register the pool with fixed metadata
        (map-set pools new-pool-id {
            pool-contract: (contract-of pool-contract),
            pool-name: name,
            pool-symbol: symbol,
            x-token: x-token,
            y-token: y-token,
            creation-height: creation-height,
            lp-fee: lp-fee,
            pool-uri: uri
        })
        
        ;; Add to contract lookup
        (map-set pool-contracts (contract-of pool-contract) new-pool-id)
        
        ;; Update counter
        (var-set last-pool-id new-pool-id)
        
        ;; Print event for indexers
        (print {
            action: "register-pool",
            caller: caller,
            pool-id: new-pool-id,
            pool-contract: (contract-of pool-contract),
            pool-name: name,
            pool-symbol: symbol,
            x-token: x-token,
            y-token: y-token,
            creation-height: creation-height,
            lp-fee: lp-fee,
            pool-uri: uri,
            x-amount: (get dx reserves-data),
            y-amount: (get dy reserves-data),    
            total-shares: (get dk reserves-data)          })
        
        (ok new-pool-id)
    )
)

(define-public (edit-pool
    (pool-id uint)
    (pool-contract <pool-trait>)
    (name (string-ascii 64))
    (symbol (string-ascii 32))
    (x-token principal)
    (y-token principal)
    (creation-height uint)
    (lp-fee uint)
    (pool-uri (optional (string-utf8 256)))
)
    (let (
        (caller tx-sender)
        (existing-pool (unwrap! (map-get? pools pool-id) ERR_POOL_NOT_FOUND))
        (uri (default-to u"https://faktory.fun/" pool-uri))
    )
        ;; Only deployer can edit pools
        (asserts! (is-eq caller DEPLOYER) ERR_NOT_AUTHORIZED)
        
        ;; Validate inputs
        (asserts! (> (len name) u0) ERR_INVALID_POOL_DATA)
        (asserts! (> (len symbol) u0) ERR_INVALID_POOL_DATA)
        
        ;; Update the pool with new metadata
        (map-set pools pool-id {
            pool-contract: (contract-of pool-contract),
            pool-name: name,
            pool-symbol: symbol,
            x-token: x-token,
            y-token: y-token,
            creation-height: creation-height,
            lp-fee: lp-fee,
            pool-uri: uri
        })
        
        ;; Print event for indexers
        (print {
            action: "edit-pool",
            caller: caller,
            pool-id: pool-id,
            pool-contract: (contract-of pool-contract),
            pool-name: name,
            pool-symbol: symbol,
            x-token: x-token,
            y-token: y-token,
            creation-height: creation-height,
            lp-fee: lp-fee,
            pool-uri: uri
        })
        
        (ok pool-id)
    )
)

(define-public (get-pool (pool-contract <pool-trait>))
    (let (
            (pool-id (map-get? pool-contracts (contract-of pool-contract)))
            (pool-info (match pool-id
                                id (map-get? pools id)
                                none))
          )
        (if (and (is-some pool-id) (is-some pool-info))
            (let (
                (id (unwrap-panic pool-id))
                (info (unwrap-panic pool-info))
                (reserves-data (unwrap! (contract-call? pool-contract quote u0 (some OP_LOOKUP_RESERVES)) ERROR_RESERVES))
            )
                (ok (some {
                    pool-id: id,
                    pool-contract: (contract-of pool-contract),
                    pool-name: (get pool-name info),
                    pool-symbol: (get pool-symbol info),
                    x-token: (get x-token info),
                    y-token: (get y-token info),
                    creation-height: (get creation-height info),
                    lp-fee: (get lp-fee info),
                    pool-uri: (get pool-uri info),
                    x-amount: (get dx reserves-data),
                    y-amount: (get dy reserves-data),    
                    total-shares: (get dk reserves-data)  
                }))
            )
            (ok none) ;; Pool not found or not registered
        )
    )
)

;; --- Single Execute Wrapper ---

(define-public (execute
    (pool-contract <pool-trait>)
    (amount uint)
    (opcode (optional (buff 16)))
)
    (let (
        (sender tx-sender)
        (operation (get-byte (default-to 0x00 opcode) u0))
        (pool-id (map-get? pool-contracts (contract-of pool-contract)))
        (pool-info (match pool-id
                        id (map-get? pools id)
                        none))
        ;; Execute operation via pool
        (result (try! (contract-call? pool-contract execute amount opcode)))
        ;; Get reserves after operation
        (reserves-after (unwrap! (contract-call? pool-contract quote u0 (some OP_LOOKUP_RESERVES)) ERROR_RESERVES))
    )
        ;; Emit appropriate event based on operation
        (match pool-info
            info (begin
                (if (is-eq operation OP_SWAP_A_TO_B)
                    ;; Buy event
                    (print {
                        type: "buy", ;; except for USDA?
                        sender: sender,
                        token-in: (get x-token info),
                        amount-in: amount,
                        token-out: (get y-token info),
                        amount-out: (get dy result),
                        pool-reserves: reserves-after,
                        pool-contract: (contract-of pool-contract),
                        min-y-out: u0
                    })
                    (if (is-eq operation OP_SWAP_B_TO_A)
                        ;; Sell event
                        (print {
                            type: "sell", ;; except for USDA?
                            sender: sender,
                            token-in: (get y-token info),
                            amount-in: amount,
                            token-out: (get x-token info),
                            amount-out: (get dy result),
                            pool-reserves: reserves-after,
                            pool-contract: (contract-of pool-contract),
                            min-y-out: u0
                        })
                        (if (is-eq operation OP_ADD_LIQUIDITY)
                            ;; Add liquidity event
                            (print {
                                type: "add-liquidity",
                                sender: sender,
                                token-a: (get x-token info),
                                token-a-amount: (get dx result),
                                token-b: (get y-token info),
                                token-b-amount: (get dy result),
                                lp-tokens: (get dk result),
                                pool-reserves: reserves-after,
                                pool-contract: (contract-of pool-contract)
                            })
                            (if (is-eq operation OP_REMOVE_LIQUIDITY)
                                ;; Remove liquidity event
                                (print {
                                    type: "remove-liquidity",
                                    sender: sender,
                                    token-a: (get x-token info),
                                    token-a-amount: (get dx result),
                                    token-b: (get y-token info),
                                    token-b-amount: (get dy result),
                                    lp-tokens: (get dk result),
                                    pool-reserves: reserves-after,
                                    pool-contract: (contract-of pool-contract)
                                })
                                false  ;; Unknown operation
                            )
                        )
                    )
                )
                true
            )
            false  ;; Pool not registered, just pass through
        )
        (ok result)
    )
)

;; Add this helper function (same as pool has)
(define-private (get-byte
    (opcode (buff 16))
    (position uint)
)
    (default-to 0x00 (element-at? opcode position))
)