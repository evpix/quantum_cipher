module main

import os
import crypto.rand
import crypto.sha256
import crypto.sha512
import math
import time
import encoding.hex

// ============================================
// CONSTANTS
// ============================================

const min_key_length = 1024
const max_key_length = 1073741824
const magic_header = [u8(0x51), 0x43, 0x52, 0x59, 0x50, 0x54]
const version = u8(1)
const superposition_dims = 8
const lattice_dimension = 256
const rounds = 16

// ============================================
// DATA STRUCTURES
// ============================================

struct QuantumState {
mut:
	alpha_real f64
	alpha_imag f64
	beta_real  f64
	beta_imag  f64
}

struct QuantumKey {
mut:
	master_seed        []u8
	superposition_key  []u8
	entanglement_pairs [][]u8
	lattice_basis      [][]i64
	measurement_bases  []u8
	key_length         u64
	created_at         i64
	checksum           []u8
}

struct QCipher {
mut:
	key          QuantumKey
	sbox         []u8
	inverse_sbox []u8
	round_keys   [][]u8
}

// ============================================
// AUXILIARY FUNCTIONS
// ============================================

// Safe modulo division (protection against division by zero)
fn safe_mod(a int, b int) int {
	if b <= 0 {
		return 0
	}
	return a % b
}

fn safe_mod_u64(a u64, b u64) u64 {
	if b == 0 {
		return 0
	}
	return a % b
}

// ============================================
// QUANTUM OPERATIONS (DETERMINISTIC)
// ============================================

// Creating a deterministic quantum state
fn create_quantum_value(seed []u8, index int, round int) u8 {
	mut hash_input := seed.clone()
	hash_input << u8(index & 0xFF)
	hash_input << u8((index >> 8) & 0xFF)
	hash_input << u8(round & 0xFF)

	hash := sha256.sum(hash_input)

	// Simulation of quantum measurement (deterministic)
	alpha := f64(hash[0]) / 255.0
	beta := f64(hash[1]) / 255.0
	basis := hash[2] & 0x03

	norm := math.sqrt(alpha * alpha + beta * beta)
	if norm < 0.0001 {
		return hash[3]
	}

	prob := match basis {
		0 { (alpha / norm) * (alpha / norm) }
		1 { 0.5 + 0.25 * (alpha * beta) / (norm * norm) }
		2 { 0.5 - 0.25 * (alpha * beta) / (norm * norm) }
		else { alpha / norm }
	}

	return u8(prob * 255.0)
}

// Simulation of quantum entanglement
fn create_entangled_pair(seed []u8) ([]u8, []u8) {
	hash1 := sha512.sum512(seed)

	mut seed2 := seed.clone()
	seed2 << 0xFF
	hash2 := sha512.sum512(seed2)

	mut pair_a := []u8{len: 64}
	mut pair_b := []u8{len: 64}

	for i in 0 .. 64 {
		pair_a[i] = hash1[i]
		pair_b[i] = hash2[i] ^ hash1[i]
	}

	return pair_a, pair_b
}

// ============================================
// LATTICE CRYPTOGRAPHY (SIMPLIFIED)
// ============================================

fn generate_lattice_basis(seed []u8, dimension int) [][]i64 {
	if dimension <= 0 {
		return [][]i64{}
	}

	mut basis := [][]i64{len: dimension}
	mut current_seed := seed.clone()

	for i in 0 .. dimension {
		basis[i] = []i64{len: dimension}

		for j in 0 .. dimension {
			hash := sha256.sum(current_seed)
			value := u64(hash[0]) | (u64(hash[1]) << 8) |
				(u64(hash[2]) << 16) | (u64(hash[3]) << 24)

			// Values from 1 to 65536 (avoiding 0)
			basis[i][j] = i64((value % 65536) + 1)

			current_seed = hash[0..32].clone()
		}
	}

	return basis
}

// Simple LWE transformation (reversible)
fn lwe_transform(b u8, lattice [][]i64, noise_seed []u8, encrypt bool) u8 {
	if lattice.len == 0 {
		return b
	}

	hash := sha256.sum(noise_seed)

	dim := lattice.len
	row := safe_mod(int(hash[0]), dim)
	col := safe_mod(int(hash[1]), dim)

	if row < 0 || row >= lattice.len || col < 0 || col >= lattice[row].len {
		return b
	}

	// We use XOR with a lattice element (completely reversible)
	lattice_byte := u8(lattice[row][col] & 0xFF)

	return b ^ lattice_byte
}

// ============================================
// S-BLOCKS
// ============================================

fn generate_sbox(seed []u8) []u8 {
	mut sbox := []u8{len: 256}

	for i in 0 .. 256 {
		sbox[i] = u8(i)
	}

	mut current_seed := seed.clone()
	for i := 255; i > 0; i-- {
		hash := sha256.sum(current_seed)
		j := safe_mod(int(hash[0]), i + 1)

		tmp := sbox[i]
		sbox[i] = sbox[j]
		sbox[j] = tmp

		current_seed = hash[0..32].clone()
	}

	return sbox
}

fn generate_inverse_sbox(sbox []u8) []u8 {
	mut inv := []u8{len: 256}

	for i in 0 .. 256 {
		inv[sbox[i]] = u8(i)
	}

	return inv
}

// ============================================
// KEY GENERATION
// ============================================

fn generate_quantum_key(key_length u64) !QuantumKey {
	if key_length < min_key_length || key_length > max_key_length {
		return error('The key length must be between ${min_key_length} and ${max_key_length}')
	}

	println('Generating a quantum key with a length of ${key_length} bytes...')

	master_seed := rand.read(64) or { return error('Error generating random data') }

	println('   ├─ The master grain is generated')

	// Generating a superposition key
	mut superposition_key := []u8{cap: int(key_length)}
	mut current_seed := master_seed.clone()

	block_size := 64
	blocks_needed := int((key_length + u64(block_size) - 1) / u64(block_size))

	for block in 0 .. blocks_needed {
		if block % 10000 == 0 && block > 0 {
			progress := f64(block) / f64(blocks_needed) * 100.0
			print('\r   ├─ Generating a superposition: ${progress:.1f}%')
		}

		hash := sha512.sum512(current_seed)

		for i in 0 .. block_size {
			if superposition_key.len >= int(key_length) {
				break
			}
			superposition_key << hash[i % 64]
		}

		current_seed = hash[0..64].clone()
	}

	println('\r   ├─ The superposition key has been created        ')

	// Entanglement Pairs
	mut entanglement_pairs := [][]u8{}
	num_pairs := int(math.min(f64(key_length / 128), 1024.0))

	for _ in 0 .. num_pairs {
		pair_seed := sha256.sum(current_seed)
		pair_a, _ := create_entangled_pair(pair_seed[0..32])
		entanglement_pairs << pair_a
		current_seed = pair_seed[0..32].clone()
	}

	println('   ├─ ${num_pairs} entanglement pairs created')

	// Grid
	actual_lattice_dim := int(math.min(f64(lattice_dimension), f64(key_length / 8)))
	lattice_basis := generate_lattice_basis(master_seed, actual_lattice_dim)

	println('   ├─ The grid ${actual_lattice_dim}x${actual_lattice_dim} is constructed')

	// Measurement bases - at least 1 byte
	bases_len := int(math.max(1.0, f64(key_length / 8)))
	mut measurement_bases := []u8{len: bases_len}
	bases_seed := sha512.sum512(current_seed)

	for i in 0 .. measurement_bases.len {
		measurement_bases[i] = bases_seed[safe_mod(i, 64)]
	}

	println('   ├─ BB84 measurement bases are generated')

	// Checksum
	mut checksum_data := master_seed.clone()
	checksum_len := int(math.min(1024.0, f64(superposition_key.len)))
	checksum_data << superposition_key[0..checksum_len]
	checksum := sha512.sum512(checksum_data)

	println('   └─ The key has been successfully generated')

	return QuantumKey{
		master_seed:        master_seed
		superposition_key:  superposition_key
		entanglement_pairs: entanglement_pairs
		lattice_basis:      lattice_basis
		measurement_bases:  measurement_bases
		key_length:         key_length
		created_at:         time.now().unix()
		checksum:           checksum[0..64].clone()
	}
}

// ============================================
// INITIALIZING THE ENCODER
// ============================================

fn new_qcipher(key QuantumKey) QCipher {
	sbox := generate_sbox(key.master_seed)
	inverse_sbox := generate_inverse_sbox(sbox)

	mut round_keys := [][]u8{len: rounds}
	mut rk_seed := key.master_seed.clone()

	for r in 0 .. rounds {
		hash := sha512.sum512(rk_seed)
		round_keys[r] = hash[0..64].clone()
		rk_seed = hash[0..64].clone()
	}

	return QCipher{
		key:          key
		sbox:         sbox
		inverse_sbox: inverse_sbox
		round_keys:   round_keys
	}
}

// ============================================
// BLOCK ENCRYPTION
// ============================================

fn (c &QCipher) encrypt_block(block []u8, block_index u64, nonce []u8) []u8 {
	if block.len == 0 {
		return []u8{}
	}

	mut result := block.clone()

	// Secure calculation of the position in the key
	key_len := if c.key.superposition_key.len > 0 { c.key.superposition_key.len } else { 1 }
	bases_len := if c.key.measurement_bases.len > 0 { c.key.measurement_bases.len } else { 1 }

	key_pos := int(safe_mod_u64(block_index, u64(key_len)))

	for round in 0 .. rounds {
		// 1. XOR with keys
		for i in 0 .. result.len {
			kp := safe_mod(key_pos + i, key_len)
			result[i] ^= c.round_keys[round][safe_mod(i, 64)]
			result[i] ^= c.key.superposition_key[kp]
		}

		// 2. The S-block
		for i in 0 .. result.len {
			result[i] = c.sbox[result[i]]
		}

		// 3. Quantum transformation (deterministic)
		for i in 0 .. result.len {
			mut qseed := nonce.clone()
			qseed << c.key.measurement_bases[safe_mod(key_pos + i, bases_len)]
			quantum_val := create_quantum_value(qseed, int(block_index) * 64 + i, round)
			result[i] ^= quantum_val
		}

		// 4. LWE conversion (every 4 rounds)
		if round % 4 == 0 && c.key.lattice_basis.len > 0 {
			for i in 0 .. result.len {
				mut noise_seed := nonce.clone()
				noise_seed << u8(i)
				noise_seed << u8(round)
				noise_seed << u8(block_index & 0xFF)
				result[i] = lwe_transform(result[i], c.key.lattice_basis, noise_seed, true)
			}
		}

		// 5. Diffusion (byte permutation)
		if result.len > 1 {
			shift := safe_mod(int(c.round_keys[round][0]), result.len)
			if shift > 0 {
				mut shifted := []u8{len: result.len}
				for i in 0 .. result.len {
					shifted[safe_mod(i + shift, result.len)] = result[i]
				}
				result = shifted.clone()
			}
		}
	}

	return result
}

// ============================================
// DECRYPTING THE BLOCK
// ============================================

fn (c &QCipher) decrypt_block(block []u8, block_index u64, nonce []u8) []u8 {
	if block.len == 0 {
		return []u8{}
	}

	mut result := block.clone()

	key_len := if c.key.superposition_key.len > 0 { c.key.superposition_key.len } else { 1 }
	bases_len := if c.key.measurement_bases.len > 0 { c.key.measurement_bases.len } else { 1 }

	key_pos := int(safe_mod_u64(block_index, u64(key_len)))

	// Reverse the order of the rounds
	for round := rounds - 1; round >= 0; round-- {
		// 5. Reverse diffusion
		if result.len > 1 {
			shift := safe_mod(int(c.round_keys[round][0]), result.len)
			if shift > 0 {
				mut shifted := []u8{len: result.len}
				for i in 0 .. result.len {
					shifted[i] = result[safe_mod(i + shift, result.len)]
				}
				result = shifted.clone()
			}
		}

		// 4. Reverse LWE transformation (XOR is a self-reversible operation)
		if round % 4 == 0 && c.key.lattice_basis.len > 0 {
			for i := result.len - 1; i >= 0; i-- {
				mut noise_seed := nonce.clone()
				noise_seed << u8(i)
				noise_seed << u8(round)
				noise_seed << u8(block_index & 0xFF)
				result[i] = lwe_transform(result[i], c.key.lattice_basis, noise_seed, false)
			}
		}

		// 3. Reverse quantum transformation (XOR - self-reversible)
		for i in 0 .. result.len {
			mut qseed := nonce.clone()
			qseed << c.key.measurement_bases[safe_mod(key_pos + i, bases_len)]
			quantum_val := create_quantum_value(qseed, int(block_index) * 64 + i, round)
			result[i] ^= quantum_val
		}

		// 2. Reverse S-block
		for i in 0 .. result.len {
			result[i] = c.inverse_sbox[result[i]]
		}

		// 1. XOR with keys (reverse order)
		for i in 0 .. result.len {
			kp := safe_mod(key_pos + i, key_len)
			result[i] ^= c.key.superposition_key[kp]
			result[i] ^= c.round_keys[round][safe_mod(i, 64)]
		}
	}

	return result
}

// ============================================
// FILE ENCRYPTION
// ============================================

fn encrypt_file(input_path string, output_path string, key QuantumKey) ! {
	println('\nFile encryption: ${input_path}')

	plaintext := os.read_bytes(input_path) or {
		return error('Couldnt read the file: ${input_path}')
	}

	if plaintext.len == 0 {
		return error('The file is empty')
	}

	println('   ├─ File size: ${plaintext.len} bytes')

	cipher := new_qcipher(key)

	nonce := rand.read(32) or { return error('Nonce generation error') }
	salt := rand.read(32) or { return error('Salt generation error') }
	iv := rand.read(32) or { return error('IV generation error') }

	block_size := 64
	mut ciphertext := []u8{cap: plaintext.len + block_size}

	num_blocks := (plaintext.len + block_size - 1) / block_size

	for i in 0 .. num_blocks {
		if i % 1000 == 0 && i > 0 {
			progress := f64(i) / f64(num_blocks) * 100.0
			print('\r   ├─ Encryption: ${progress:.1f}%')
		}

		start := i * block_size
		end := if (i + 1) * block_size < plaintext.len { (i + 1) * block_size } else { plaintext.len }

		block := plaintext[start..end]

		// Padding the last block to its full size
		mut padded_block := block.clone()
		for padded_block.len < block_size {
			padded_block << u8(block_size - block.len) // PKCS7 padding
		}

		// CBC mode: XOR with previous block
		if i == 0 {
			for j in 0 .. padded_block.len {
				padded_block[j] ^= iv[safe_mod(j, iv.len)]
			}
		} else {
			prev_start := (i - 1) * block_size
			for j in 0 .. padded_block.len {
				if prev_start + j < ciphertext.len {
					padded_block[j] ^= ciphertext[prev_start + j]
				}
			}
		}

		encrypted_block := cipher.encrypt_block(padded_block, u64(i), nonce)
		ciphertext << encrypted_block
	}

	println('\r   ├─ Encryption is complete            ')

	// Authentication
	mut auth_data := ciphertext.clone()
	auth_data << key.checksum
	auth_tag := sha512.sum512(auth_data)

	key_hash := sha512.sum512(key.master_seed)

	// Generating the output file
	mut output := []u8{}
	output << magic_header
	output << version
	output << key_hash[0..32]
	output << nonce
	output << salt
	output << iv

	// Original size (8 bytes)
	original_size := u64(plaintext.len)
	for i in 0 .. 8 {
		output << u8((original_size >> (i * 8)) & 0xFF)
	}

	output << ciphertext
	output << auth_tag[0..64]

	os.write_file_array(output_path, output) or {
		return error('Failed to write a file: ${output_path}')
	}

	println('   ├─ Encrypted file size: ${output.len} bytes')
	println('   └─ Saved in: ${output_path}')
}

// ============================================
// DECRYPTING THE FILE
// ============================================

fn decrypt_file(input_path string, output_path string, key QuantumKey) ! {
	println('\nDecrypting the file: ${input_path}')

	encrypted := os.read_bytes(input_path) or {
		return error('Couldnt read the file: ${input_path}')
	}

	println('   ├─ File size: ${encrypted.len} bytes')

	// Minimum size: header(6) + version(1) + key_hash(32) + nonce(32) + salt(32) + iv(32) + size(8) + auth_tag(64)
	min_size := 6 + 1 + 32 + 32 + 32 + 32 + 8 + 64
	if encrypted.len < min_size {
		return error('The file is corrupted or not encrypted.')
	}

	// Checking the header
	if encrypted[0..6] != magic_header {
		return error('Incorrect file format')
	}

	if encrypted[6] != version {
		return error('Unsupported version: ${encrypted[6]}')
	}

	mut pos := 7

	stored_key_hash := encrypted[pos..pos + 32]
	pos += 32

	nonce := encrypted[pos..pos + 32]
	pos += 32

	_ = encrypted[pos..pos + 32] // salt (reserved)
	pos += 32

	iv := encrypted[pos..pos + 32]
	pos += 32

	// Original size
	mut original_size := u64(0)
	for i in 0 .. 8 {
		original_size |= u64(encrypted[pos + i]) << (i * 8)
	}
	pos += 8

	// Checking for the correct size
	if original_size > u64(encrypted.len) * 2 {
		return error('Incorrect data size in the header')
	}

	auth_tag := encrypted[encrypted.len - 64..]
	ciphertext := encrypted[pos..encrypted.len - 64]

	// Key verification
	key_hash := sha512.sum512(key.master_seed)
	if key_hash[0..32] != stored_key_hash {
		return error('Invalid encryption key!')
	}

	println('   ├─ The key has been verified')

	// Проверка целостности
	mut auth_data := ciphertext.clone()
	auth_data << key.checksum
	expected_auth := sha512.sum512(auth_data)

	if expected_auth[0..64] != auth_tag {
		return error('The file is corrupted or modified!')
	}

	println('   ├─ Integrity confirmed')

	cipher := new_qcipher(key)

	block_size := 64
	mut plaintext := []u8{cap: int(original_size) + block_size}

	num_blocks := (ciphertext.len + block_size - 1) / block_size

	// Saving the previous encrypted block for CBC
	mut prev_cipher_block := iv.clone()

	for i in 0 .. num_blocks {
		if i % 1000 == 0 && i > 0 {
			progress := f64(i) / f64(num_blocks) * 100.0
			print('\r   ├─ Decryption: ${progress:.1f}%')
		}

		start := i * block_size
		end := if (i + 1) * block_size < ciphertext.len { (i + 1) * block_size } else { ciphertext.len }

		block := ciphertext[start..end]

		// We supplement the block if it is incomplete
		mut padded_block := block.clone()
		for padded_block.len < block_size {
			padded_block << u8(0)
		}

		decrypted_block := cipher.decrypt_block(padded_block, u64(i), nonce)

		// CBC: XOR with the previous encrypted block
		mut final_block := decrypted_block.clone()
		for j in 0 .. final_block.len {
			final_block[j] ^= prev_cipher_block[safe_mod(j, prev_cipher_block.len)]
		}

		// Saving the current encrypted block
		prev_cipher_block = padded_block.clone()

		plaintext << final_block
	}

	println('\r   ├─ Decryption is complete          ')

	// Cut to the original size
	if u64(plaintext.len) > original_size {
		plaintext = plaintext[0..int(original_size)].clone()
	}

	os.write_file_array(output_path, plaintext) or {
		return error('Failed to write a file: ${output_path}')
	}

	println('   ├─ Restored size: ${plaintext.len} bytes')
	println('   └─ Saved in: ${output_path}')
}

// ============================================
// SAVING/LOADING THE KEY
// ============================================

fn save_key(key QuantumKey, path string) ! {
	println('\nSaving the key in: ${path}')

	mut data := []u8{}

	data << [u8(0x51), 0x4B, 0x45, 0x59] // "QKEY"
	data << version

	for i in 0 .. 8 {
		data << u8((key.key_length >> (i * 8)) & 0xFF)
	}

	for i in 0 .. 8 {
		data << u8((u64(key.created_at) >> (i * 8)) & 0xFF)
	}

	data << key.master_seed
	data << key.checksum

	bases_len := u32(key.measurement_bases.len)
	for i in 0 .. 4 {
		data << u8((bases_len >> (i * 8)) & 0xFF)
	}
	data << key.measurement_bases

	os.write_file_array(path, data) or {
		return error('Couldnt save the key')
	}

	println('   └─ The key is saved (${data.len} byte)')
}

fn load_key(path string) !QuantumKey {
	println('\nLoading a key from: ${path}')

	data := os.read_bytes(path) or {
		return error('Couldnt read the key file')
	}

	if data.len < 141 { // Minimum size
		return error('The key file is corrupted')
	}

	if data[0..4] != [u8(0x51), 0x4B, 0x45, 0x59] {
		return error('Incorrect key file format')
	}

	mut pos := 5

	mut key_length := u64(0)
	for i in 0 .. 8 {
		key_length |= u64(data[pos + i]) << (i * 8)
	}
	pos += 8

	mut created_at := u64(0)
	for i in 0 .. 8 {
		created_at |= u64(data[pos + i]) << (i * 8)
	}
	pos += 8

	master_seed := data[pos..pos + 64].clone()
	pos += 64

	checksum := data[pos..pos + 64].clone()
	pos += 64

	mut bases_len := u32(0)
	for i in 0 .. 4 {
		bases_len |= u32(data[pos + i]) << (i * 8)
	}
	pos += 4

	if pos + int(bases_len) > data.len {
		return error('The key file is corrupted')
	}

	measurement_bases := data[pos..pos + int(bases_len)].clone()

	println('   ├─ Key length: ${key_length} bytes')
	println('   ├─ Restoring components...')

	// Restoring the superposition key
	mut superposition_key := []u8{cap: int(key_length)}
	mut current_seed := master_seed.clone()

	block_size := 64
	blocks_needed := int((key_length + u64(block_size) - 1) / u64(block_size))

	for _ in 0 .. blocks_needed {
		hash := sha512.sum512(current_seed)
		for i in 0 .. block_size {
			if superposition_key.len >= int(key_length) {
				break
			}
			superposition_key << hash[safe_mod(i, 64)]
		}
		current_seed = hash[0..64].clone()
	}

	// Entanglement Pairs
	mut entanglement_pairs := [][]u8{}
	num_pairs := int(math.min(f64(key_length / 128), 1024.0))

	for _ in 0 .. num_pairs {
		pair_seed := sha256.sum(current_seed)
		pair_a, _ := create_entangled_pair(pair_seed[0..32])
		entanglement_pairs << pair_a
		current_seed = pair_seed[0..32].clone()
	}

	// Grid
	actual_lattice_dim := int(math.min(f64(lattice_dimension), f64(key_length / 8)))
	lattice_basis := generate_lattice_basis(master_seed, actual_lattice_dim)

	println('   └─ The key has been loaded')

	return QuantumKey{
		master_seed:        master_seed
		superposition_key:  superposition_key
		entanglement_pairs: entanglement_pairs
		lattice_basis:      lattice_basis
		measurement_bases:  measurement_bases
		key_length:         key_length
		created_at:         i64(created_at)
		checksum:           checksum
	}
}

// ============================================
// MAIN
// ============================================

fn main() {
	args := os.args

	println('╔════════════════════════════════════════════════════╗')
	println('║     QUANTUM CIPHER v1.0 - The Quantum Encoder      ║')
	println('║  Post-quantum cryptography based on LWE and BB84   ║')
	println('╚════════════════════════════════════════════════════╝')

	if args.len < 2 {
		print_usage()
		return
	}

	match args[1] {
		'genkey' {
			if args.len < 4 {
				println('Usage: qcrypt genkey <length> <file.qkey>')
				return
			}

			key := generate_quantum_key(args[2].u64()) or {
				println('Error: ${err}')
				return
			}

			save_key(key, args[3]) or {
				println('Error: ${err}')
				return
			}
		}
		'encrypt' {
			if args.len < 5 {
				println('Usage: qcrypt encrypt <input> <output> <key>')
				return
			}

			key := load_key(args[4]) or {
				println('Error: ${err}')
				return
			}

			encrypt_file(args[2], args[3], key) or {
				println('Error: ${err}')
				return
			}
		}
		'decrypt' {
			if args.len < 5 {
				println('Usage: qcrypt decrypt <input> <output> <key>')
				return
			}

			key := load_key(args[4]) or {
				println('Error: ${err}')
				return
			}

			decrypt_file(args[2], args[3], key) or {
				println('Error: ${err}')
				return
			}
		}
		'info' {
			if args.len < 3 {
				println('Usage: qcrypt info <file.qkey>')
				return
			}

			key := load_key(args[2]) or {
				println('Error: ${err}')
				return
			}

			println('\nInformation about the key:')
			println('   ├─ Length: ${key.key_length} bytes')
			println('   ├─ Entanglement Pairs: ${key.entanglement_pairs.len}')
			println('   ├─ The dimension of the lattice: ${key.lattice_basis.len}')
			println('   ├─ Measurement bases: ${key.measurement_bases.len}')
			println('   ├─ Created: ${time.unix(key.created_at)}')
			println('   └─ Checksum: ${hex.encode(key.checksum[0..16])}...')
		}
		else {
			print_usage()
		}
	}
}

fn print_usage() {
	println('\nUsing:')
	println('  qcrypt genkey <length> <file.qkey>      Generating a new key')
	println('  qcrypt encrypt <input> <output> <key>   File encryption')
	println('  qcrypt decrypt <input> <output> <key>   Decrypting the file')
	println('  qcrypt info <file.qkey>                 Information about the key')
	println('\nExamples:')
	println('  qcrypt genkey 4096 secret.qkey')
	println('  qcrypt encrypt photo.png photo.qcrypt secret.qkey')
	println('  qcrypt decrypt photo.qcrypt photo_dec.png secret.qkey')
}
