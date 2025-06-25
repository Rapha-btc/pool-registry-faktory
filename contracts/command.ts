(contract-call? .pool-registry-faktory register-pool .leo-pool-faktory "sBTC-leo lp-token" "sBTC-leo" 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token 'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token u0 u100)

(contract-call? .pool-registry-faktory get-last-pool-id)

(contract-call? .pool-registry-faktory get-pool-by-id u1)

(contract-call? .pool-registry-faktory get-pool-by-contract .leo-pool-faktory)

(contract-call? .pool-registry-faktory get-pool .leo-pool-faktory)