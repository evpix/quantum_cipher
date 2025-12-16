# Detailed Specification of Quantum Cipher

### General information

Quantum Cipher is a **symmetric block cipher** with elements of post-quantum cryptography.

| Parameter           | Value                            |
|---------------------|----------------------------------|
| Cipher type         | Symmetric block                  |
| Block size          | 64 bytes (512 bits)              |
| Number of rounds    | 16                               |
| Key length          | from 1 KB to 1 GB                |
| Operating mode      | CBC (Cipher Block Chaining)      |
| Data authentication | Tag based on SHA-512 (HMAC-like) |

### The structure of the "quantum" key

The key consists of several components generated from a single master seed.

| Component          | Size         | Description                                                             |
|--------------------|--------------|-------------------------------------------------------------------------|
| master_seed        | 64 bytes     | Main Cryptographically random seed (from CSPRNG)                        |
| superposition_key  | 1 KB — 1 GB  | The main key of the "superposition" is the main material for encryption |
| entanglement_pairs | up to 64 KB  | "Entangled" pairs for integrity checking                                |
| lattice_basis      | up to 512 KB | Lattice basis for post-quantum transformations (LWE)                    |
| measurement_bases  | key_length/8 | Array of measurement bases in the BB84 protocol style                   |
| checksum           | 64 bytes     | Checksum of the entire key (SHA-512)                                    |
| created_at         | 8 bytes      | Unix key creation time                                                  |

### Key file format (.qkey)

| Offset (bytes) | Size (bytes) | Field        | Description                     |
|----------------|--------------|--------------|---------------------------------|
| 0              | 4            | Magic        | QKEY (0x51 0x4B 0x45 0x59)      |
| 4              | 1            | Version      | Format version (0x01)           |
| 5              | 8            | Key Length   | Length of the superposition key |
| 13             | 8            | Created At   | Unix timestamp                  |
| 21             | 64           | Master Seed  | Master Seed                     |
| 85             | 64           | Checksum     | Checksum                        |
| 149            | 4            | Bases Length | Length of the array of bases    |
| 153            | N            | Bases        | Measurement bases BB84          |

### Encrypted file format (.qcrypt)

| Offset (bytes) | Size (bytes) | Field         | Description                            |
|----------------|--------------|---------------|----------------------------------------|
| 0              | 6            | Magic         | QCRYPT (0x51 0x43 0x52 0x59 0x50 0x54) |
| 6              | 1            | Version       | Format version (0x01)                  |
| 7              | 32           | Key Hash      | Partial SHA-512 hash of the key        |
| 39             | 32           | Nonce         | Nonce number                           |
| 71             | 32           | Salt          | Salt (reserved)                        |
| 103            | 32           | IV            | Initialization vector                  |
| 135            | 8            | Original Size | Original size (little-endian)          |
| 143            | N            | Ciphertext    | Encrypted data                         |
| 143+N          | 64           | Auth Tag      | SHA-512 authentication Tag             |

### Algorithm Architecture

#### 1. Generation of key materials (in parallel from master_seed)

- Superposition Key is the main encryption material
- S-Boxes — nonlinear substitution tables (dynamically generated)
- Lattice Basis — the basis for LWE transformations
- Entanglement Pairs — "entangled" pairs for verification
- BB84 Bases — random measurement bases

#### 2. Encryption (16 rounds)

For each block (64 bytes) are executed sequentially:

1. **XOR with a round key** is a bitwise addition with subkeys derived from superposition_key.
2. **S-Box Substitution** is a nonlinear substitution (similar to AES).
3. **Quantum Measurement** is a simulation of a "measurement" based on selected BB84 bases.
4. **LWE Transform** — transformation based on the lattice problem (Learning With Errors).
5. **Diffusion** — data diffusion through cyclic shifts.

After 16 rounds, standard chaining in CBC mode is applied.

#### 3. Finalizing

- An authentication tag (Auth Tag) based on SHA-512 is added.

### Cryptographic properties and protection

| Component            | Base                           | What protects                               |
|----------------------|--------------------------------|---------------------------------------------|
| LWE transformations  | NIST post-quantum cryptography | Resistance to Shor's quantum algorithm      |
| BB84-bases           | Quantum Distribution Protocol  | Helps detect interception/spoofing attempts |
| Dynamic S-Boxes      | AES-like design                | Provides non-linearity and confusion        |
| Lattice cryptography | Lattice-based                  | Post-Quantum security                       |
| Entangled pairs      | Simulation of Bell states      | Additional integrity verification           |

### Program error codes

| Code | Message                | Reason                                            |
|------|------------------------|---------------------------------------------------|
| E001 | "File is corrupted"    | Incorrect signature (magic header)                |
| E002 | "Invalid key"          | The hash of the key does not match the saved one  |
| E003 | "File is modified"     | Authentication tag was not verified               |
| E004 | "Unsupported version"  | File format version ≠ 1                           |
| E005 | "The file is empty"    | The input file has zero size                      |
| E006 | "Incorrect key length" | The key is less than 1024 bytes or more than 1 GB |
