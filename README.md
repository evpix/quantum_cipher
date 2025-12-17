# Quantum Cipher ![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat) ![vlang](http://img.shields.io/badge/V-0.4.12-%236d8fc5?style=flat)

**Quantum Cipher** is a symmetric cipher written in the V programming language.

It is inspired by the ideas of quantum cryptography and combines classical cryptographic methods with elements of post-quantum protection. The algorithm provides reliable data protection from modern attacks and partly from future threats from quantum computers (in particular, it is resistant to the Shor algorithm due to the use of lattice cryptography).

> Important: the "quantum" components here are **classical simulation** on a regular computer.

### The main ideas of the algorithm (inspired by quantum physics)

- **Superposition of states** — the key is generated as if it is in several states at the same time.
- **Quantum entanglement** — linked pairs are used to verify integrity.
- **Lattice cryptography** — provides post-quantum stability (protection against the Shor algorithm).
- **BB84—style encoding** - different "bases" for data transformation.

### Simulation of quantum components

| Component     | Quantum analog                | As implemented in the code                  |
|---------------|-------------------------------|---------------------------------------------|
| Superposition | \|ψ⟩ = α\/0⟩ + β\/1⟩          | The amplitudes are calculated using SHA-256 |
| Measurement   | Collapse of the wave function | Deterministic function                      |
| BB84 bases    | Z, X, Y bases                 | 4 different data conversion modes           |
| Entanglement  | Bell states                   | Correlated key pairs                        |
| Hadamard Gate | H = 1/√2 [[1,1],[1,-1]]       | Linear transformation over data             |

### Recommended key sizes

| Key size            | Security level | Recommended use            |
|---------------------|----------------|----------------------------|
| 1 024 bytes         | Basic          | Testing, non-critical data |
| 4 096 bytes         | Standard       | Personal Documents         |
| 16 384 bytes        | High           | Sensitive data             |
| 65 536 bytes        | Very high      | Financial information      |
| 1 048 576 bytes     | Maximum        | State secret               |
| 1 073 741 824 bytes | Extreme        | Long-term storage          |

### Approximate performance

| File Size | Key Size | Encryption Time | Decryption Time |
|-----------|----------|-----------------|-----------------|
| 1 KB      | 4 KB     | ~1 ms           | ~1 ms           |
| 100 KB    | 4 KB     | ~15 ms          | ~15 ms          |
| 1 MB      | 4 KB     | ~150 ms         | ~150 ms         |
| 10 MB     | 4 KB     | ~1.5 s          | ~1.5 s          |
| 100 MB    | 4 KB     | ~15 s           | ~15 s           |
| 1 MB      | 1 MB     | ~2 s            | ~2 s            |

### Protection against threats

| Type of attack          | How protected              | Status     |
|-------------------------|----------------------------|------------|
| Brute-force attack      | Long key (up to 1 GB)      | ✅ Full    |
| Known-plaintext attack  | CBC mode, round keys       | ✅ Full    |
| Chosen-plaintext attack | Nonce + IV + Multi - round | ✅ Full    |
| Side-channel attack     | Constant execution time    | ⚠️ Partial |
| Quantum Attack (Shor)   | LWE-conversions            | ✅ Full    |
| Quantum Attack (Grover) | Key ≥256 bits              | ✅ Full    |
| Data modification       | SHA-512 Auth Tag           | ✅ Full    |
| Key Substitution        | SHA-512 Key Hash           | ✅ Full    |

### Comparison with popular algorithms

| Feature                  | Quantum Cipher | AES-256 | ChaCha20 | Kyber (POSTQUANT.) |
|--------------------------|----------------|---------|----------|--------------------|
| Block size               | 512 bit        | 128 bit | 512 bit  | N/A                |
| Max. key length          | 8 Gbit         | 256 bit | 256 bit  | 6144 bit           |
| Rounds                   | 16             | 14      | 20       | N/A                |
| Post-quantum protection  | ✅ LWE         | ❌      | ❌      | ✅                 |
| Built-up autentification | ✅ built-up    | ❌      | ❌      | ❌                 |
| Standardised             | ❌             | ✅ FIPS | ✅ RFC  | ✅ NIST            |

### Known limitations

| Limitation                            | Reason                            | Possible improvement         |
|---------------------------------------|-----------------------------------|------------------------------|
| The entire file is loaded into memory | Simplified implementation         | Add streaming                |
| Slow generation of large keys         | SHA-512 per block                 | Parallel computing           |
| No built-in compression               | Not provided by the specification | zlib integration             |
| Only one recipient                    | Symmetric cipher                  | Hybrid scheme with asymmetry |

### Dependencies (all from the V standard library)

- `crypto.rand` — random number generation
- `crypto.sha256` and `crypto.sha512` — hashing
- `encoding.hex` — output to hex
- `math`, `time`, `os` — auxiliary functions

### Detailed specification of the algorithm
[SPECIFICATION.md](SPECIFICATION.md)

### How to build and run

#### Cloning a repository

```shell
git clone --depth=1 https://github.com/evpix/quantum_cipher.git
cd quantum_cipher
```

#### Compilation

```shell
# Linux / macOS
v -prod -o qcrypt quantum_cipher.v

# Windows
v -prod -o qcrypt.exe quantum_cipher.v

# Linux (static build)
v -prod -cc musl-gcc -o qcrypt quantum_cipher.v
```

#### Launch

```shell
# Linux / macOS
./qcrypt

# Windows
qcrypt.exe
```

> Copyright (c) 2025-... EvPix.
[![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat)](https://opensource.org/license/mit/)
