# Derived from https://github.com/robinlinden/libsodium-cmake/
#
# ISC License
#
# Copyright (c) 2019, Robin Linden
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

cmake_minimum_required(VERSION 3.13)

project("sodium" LANGUAGES C)

option(SODIUM_MINIMAL "Only compile the minimum set of functions required for the high-level API" OFF)
option(SODIUM_ENABLE_BLOCKING_RANDOM "Enable this switch only if /dev/urandom is totally broken on the target platform" OFF)

add_library(${PROJECT_NAME}
    extern/libsodium/src/libsodium/crypto_aead/aegis128l/aead_aegis128l.c
    extern/libsodium/src/libsodium/crypto_aead/aegis128l/aegis128l_aesni.c
    extern/libsodium/src/libsodium/crypto_aead/aegis128l/aegis128l_armcrypto.c
    extern/libsodium/src/libsodium/crypto_aead/aegis128l/aegis128l_soft.c
    extern/libsodium/src/libsodium/crypto_aead/aegis256/aead_aegis256.c
    extern/libsodium/src/libsodium/crypto_aead/aegis256/aegis256_aesni.c
    extern/libsodium/src/libsodium/crypto_aead/aegis256/aegis256_armcrypto.c
    extern/libsodium/src/libsodium/crypto_aead/aegis256/aegis256_soft.c
    extern/libsodium/src/libsodium/crypto_aead/aes256gcm/aesni/aead_aes256gcm_aesni.c
    extern/libsodium/src/libsodium/crypto_aead/aes256gcm/aead_aes256gcm.c
    extern/libsodium/src/libsodium/crypto_aead/chacha20poly1305/aead_chacha20poly1305.c
    extern/libsodium/src/libsodium/crypto_aead/xchacha20poly1305/aead_xchacha20poly1305.c
    extern/libsodium/src/libsodium/crypto_auth/crypto_auth.c
    extern/libsodium/src/libsodium/crypto_auth/hmacsha256/auth_hmacsha256.c
    extern/libsodium/src/libsodium/crypto_auth/hmacsha512/auth_hmacsha512.c
    extern/libsodium/src/libsodium/crypto_auth/hmacsha512256/auth_hmacsha512256.c
    extern/libsodium/src/libsodium/crypto_box/crypto_box.c
    extern/libsodium/src/libsodium/crypto_box/crypto_box_easy.c
    extern/libsodium/src/libsodium/crypto_box/crypto_box_seal.c
    extern/libsodium/src/libsodium/crypto_box/curve25519xsalsa20poly1305/box_curve25519xsalsa20poly1305.c
    extern/libsodium/src/libsodium/crypto_core/ed25519/ref10/ed25519_ref10.c
    extern/libsodium/src/libsodium/crypto_core/ed25519/ref10/fe_25_5/base.h
    extern/libsodium/src/libsodium/crypto_core/ed25519/ref10/fe_25_5/base2.h
    extern/libsodium/src/libsodium/crypto_core/ed25519/ref10/fe_25_5/constants.h
    extern/libsodium/src/libsodium/crypto_core/ed25519/ref10/fe_25_5/fe.h
    extern/libsodium/src/libsodium/crypto_core/ed25519/ref10/fe_51/base.h
    extern/libsodium/src/libsodium/crypto_core/ed25519/ref10/fe_51/base2.h
    extern/libsodium/src/libsodium/crypto_core/ed25519/ref10/fe_51/constants.h
    extern/libsodium/src/libsodium/crypto_core/ed25519/ref10/fe_51/fe.h
    extern/libsodium/src/libsodium/crypto_core/hchacha20/core_hchacha20.c
    extern/libsodium/src/libsodium/crypto_core/hsalsa20/core_hsalsa20.c
    extern/libsodium/src/libsodium/crypto_core/hsalsa20/ref2/core_hsalsa20_ref2.c
    extern/libsodium/src/libsodium/crypto_core/salsa/ref/core_salsa_ref.c
    extern/libsodium/src/libsodium/crypto_core/softaes/softaes.c
    extern/libsodium/src/libsodium/crypto_generichash/blake2b/generichash_blake2.c
    extern/libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2.h
    extern/libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-compress-avx2.c
    extern/libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-compress-avx2.h
    extern/libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-compress-ref.c
    extern/libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-compress-sse41.c
    extern/libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-compress-sse41.h
    extern/libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-compress-ssse3.c
    extern/libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-compress-ssse3.h
    extern/libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-load-avx2.h
    extern/libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-load-sse2.h
    extern/libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-load-sse41.h
    extern/libsodium/src/libsodium/crypto_generichash/blake2b/ref/blake2b-ref.c
    extern/libsodium/src/libsodium/crypto_generichash/blake2b/ref/generichash_blake2b.c
    extern/libsodium/src/libsodium/crypto_generichash/crypto_generichash.c
    extern/libsodium/src/libsodium/crypto_hash/crypto_hash.c
    extern/libsodium/src/libsodium/crypto_hash/sha256/cp/hash_sha256_cp.c
    extern/libsodium/src/libsodium/crypto_hash/sha256/hash_sha256.c
    extern/libsodium/src/libsodium/crypto_hash/sha512/cp/hash_sha512_cp.c
    extern/libsodium/src/libsodium/crypto_hash/sha512/hash_sha512.c
    extern/libsodium/src/libsodium/crypto_kdf/blake2b/kdf_blake2b.c
    extern/libsodium/src/libsodium/crypto_kdf/crypto_kdf.c
    extern/libsodium/src/libsodium/crypto_kdf/hkdf/kdf_hkdf_sha256.c
    extern/libsodium/src/libsodium/crypto_kdf/hkdf/kdf_hkdf_sha512.c
    extern/libsodium/src/libsodium/crypto_kx/crypto_kx.c
    extern/libsodium/src/libsodium/crypto_onetimeauth/crypto_onetimeauth.c
    extern/libsodium/src/libsodium/crypto_onetimeauth/poly1305/donna/poly1305_donna.c
    extern/libsodium/src/libsodium/crypto_onetimeauth/poly1305/donna/poly1305_donna.h
    extern/libsodium/src/libsodium/crypto_onetimeauth/poly1305/donna/poly1305_donna32.h
    extern/libsodium/src/libsodium/crypto_onetimeauth/poly1305/donna/poly1305_donna64.h
    extern/libsodium/src/libsodium/crypto_onetimeauth/poly1305/onetimeauth_poly1305.c
    extern/libsodium/src/libsodium/crypto_onetimeauth/poly1305/onetimeauth_poly1305.h
    extern/libsodium/src/libsodium/crypto_onetimeauth/poly1305/sse2/poly1305_sse2.c
    extern/libsodium/src/libsodium/crypto_onetimeauth/poly1305/sse2/poly1305_sse2.h
    extern/libsodium/src/libsodium/crypto_pwhash/argon2/argon2-core.c
    extern/libsodium/src/libsodium/crypto_pwhash/argon2/argon2-core.h
    extern/libsodium/src/libsodium/crypto_pwhash/argon2/argon2-encoding.c
    extern/libsodium/src/libsodium/crypto_pwhash/argon2/argon2-encoding.h
    extern/libsodium/src/libsodium/crypto_pwhash/argon2/argon2-fill-block-avx2.c
    extern/libsodium/src/libsodium/crypto_pwhash/argon2/argon2-fill-block-avx512f.c
    extern/libsodium/src/libsodium/crypto_pwhash/argon2/argon2-fill-block-ref.c
    extern/libsodium/src/libsodium/crypto_pwhash/argon2/argon2-fill-block-ssse3.c
    extern/libsodium/src/libsodium/crypto_pwhash/argon2/argon2.c
    extern/libsodium/src/libsodium/crypto_pwhash/argon2/argon2.h
    extern/libsodium/src/libsodium/crypto_pwhash/argon2/blake2b-long.c
    extern/libsodium/src/libsodium/crypto_pwhash/argon2/blake2b-long.h
    extern/libsodium/src/libsodium/crypto_pwhash/argon2/blamka-round-avx2.h
    extern/libsodium/src/libsodium/crypto_pwhash/argon2/blamka-round-avx512f.h
    extern/libsodium/src/libsodium/crypto_pwhash/argon2/blamka-round-ref.h
    extern/libsodium/src/libsodium/crypto_pwhash/argon2/blamka-round-ssse3.h
    extern/libsodium/src/libsodium/crypto_pwhash/argon2/pwhash_argon2i.c
    extern/libsodium/src/libsodium/crypto_pwhash/argon2/pwhash_argon2id.c
    extern/libsodium/src/libsodium/crypto_pwhash/crypto_pwhash.c
    extern/libsodium/src/libsodium/crypto_scalarmult/crypto_scalarmult.c
    extern/libsodium/src/libsodium/crypto_scalarmult/curve25519/ref10/x25519_ref10.c
    extern/libsodium/src/libsodium/crypto_scalarmult/curve25519/ref10/x25519_ref10.h
    extern/libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/consts_namespace.h
    extern/libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/curve25519_sandy2x.c
    extern/libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/curve25519_sandy2x.h
    extern/libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/fe.h
    extern/libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/fe51.h
    extern/libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/fe51_invert.c
    extern/libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/fe51_namespace.h
    extern/libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/fe_frombytes_sandy2x.c
    extern/libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/ladder.h
    extern/libsodium/src/libsodium/crypto_scalarmult/curve25519/sandy2x/ladder_namespace.h
    extern/libsodium/src/libsodium/crypto_scalarmult/curve25519/scalarmult_curve25519.c
    extern/libsodium/src/libsodium/crypto_scalarmult/curve25519/scalarmult_curve25519.h
    extern/libsodium/src/libsodium/crypto_secretbox/crypto_secretbox.c
    extern/libsodium/src/libsodium/crypto_secretbox/crypto_secretbox_easy.c
    extern/libsodium/src/libsodium/crypto_secretbox/xsalsa20poly1305/secretbox_xsalsa20poly1305.c
    extern/libsodium/src/libsodium/crypto_secretstream/xchacha20poly1305/secretstream_xchacha20poly1305.c
    extern/libsodium/src/libsodium/crypto_shorthash/crypto_shorthash.c
    extern/libsodium/src/libsodium/crypto_shorthash/siphash24/ref/shorthash_siphash24_ref.c
    extern/libsodium/src/libsodium/crypto_shorthash/siphash24/ref/shorthash_siphash_ref.h
    extern/libsodium/src/libsodium/crypto_shorthash/siphash24/shorthash_siphash24.c
    extern/libsodium/src/libsodium/crypto_sign/crypto_sign.c
    extern/libsodium/src/libsodium/crypto_sign/ed25519/ref10/keypair.c
    extern/libsodium/src/libsodium/crypto_sign/ed25519/ref10/open.c
    extern/libsodium/src/libsodium/crypto_sign/ed25519/ref10/sign.c
    extern/libsodium/src/libsodium/crypto_sign/ed25519/ref10/sign_ed25519_ref10.h
    extern/libsodium/src/libsodium/crypto_sign/ed25519/sign_ed25519.c
    extern/libsodium/src/libsodium/crypto_stream/chacha20/dolbeau/chacha20_dolbeau-avx2.c
    extern/libsodium/src/libsodium/crypto_stream/chacha20/dolbeau/chacha20_dolbeau-avx2.h
    extern/libsodium/src/libsodium/crypto_stream/chacha20/dolbeau/chacha20_dolbeau-ssse3.c
    extern/libsodium/src/libsodium/crypto_stream/chacha20/dolbeau/chacha20_dolbeau-ssse3.h
    extern/libsodium/src/libsodium/crypto_stream/chacha20/dolbeau/u0.h
    extern/libsodium/src/libsodium/crypto_stream/chacha20/dolbeau/u1.h
    extern/libsodium/src/libsodium/crypto_stream/chacha20/dolbeau/u4.h
    extern/libsodium/src/libsodium/crypto_stream/chacha20/dolbeau/u8.h
    extern/libsodium/src/libsodium/crypto_stream/chacha20/ref/chacha20_ref.c
    extern/libsodium/src/libsodium/crypto_stream/chacha20/ref/chacha20_ref.h
    extern/libsodium/src/libsodium/crypto_stream/chacha20/stream_chacha20.c
    extern/libsodium/src/libsodium/crypto_stream/chacha20/stream_chacha20.h
    extern/libsodium/src/libsodium/crypto_stream/crypto_stream.c
    extern/libsodium/src/libsodium/crypto_stream/salsa20/ref/salsa20_ref.c
    extern/libsodium/src/libsodium/crypto_stream/salsa20/ref/salsa20_ref.h
    extern/libsodium/src/libsodium/crypto_stream/salsa20/stream_salsa20.c
    extern/libsodium/src/libsodium/crypto_stream/salsa20/stream_salsa20.h
    extern/libsodium/src/libsodium/crypto_stream/salsa20/xmm6/salsa20_xmm6.c
    extern/libsodium/src/libsodium/crypto_stream/salsa20/xmm6/salsa20_xmm6.h
    extern/libsodium/src/libsodium/crypto_stream/salsa20/xmm6int/salsa20_xmm6int-avx2.c
    extern/libsodium/src/libsodium/crypto_stream/salsa20/xmm6int/salsa20_xmm6int-avx2.h
    extern/libsodium/src/libsodium/crypto_stream/salsa20/xmm6int/salsa20_xmm6int-sse2.c
    extern/libsodium/src/libsodium/crypto_stream/salsa20/xmm6int/salsa20_xmm6int-sse2.h
    extern/libsodium/src/libsodium/crypto_stream/salsa20/xmm6int/u0.h
    extern/libsodium/src/libsodium/crypto_stream/salsa20/xmm6int/u1.h
    extern/libsodium/src/libsodium/crypto_stream/salsa20/xmm6int/u4.h
    extern/libsodium/src/libsodium/crypto_stream/salsa20/xmm6int/u8.h
    extern/libsodium/src/libsodium/crypto_stream/xsalsa20/stream_xsalsa20.c
    extern/libsodium/src/libsodium/crypto_verify/verify.c
    extern/libsodium/src/libsodium/include/sodium.h
    extern/libsodium/src/libsodium/include/sodium/core.h
    extern/libsodium/src/libsodium/include/sodium/crypto_aead_aegis128l.h
    extern/libsodium/src/libsodium/include/sodium/crypto_aead_aegis256.h
    extern/libsodium/src/libsodium/include/sodium/crypto_aead_aes256gcm.h
    extern/libsodium/src/libsodium/include/sodium/crypto_aead_chacha20poly1305.h
    extern/libsodium/src/libsodium/include/sodium/crypto_aead_xchacha20poly1305.h
    extern/libsodium/src/libsodium/include/sodium/crypto_auth.h
    extern/libsodium/src/libsodium/include/sodium/crypto_auth_hmacsha256.h
    extern/libsodium/src/libsodium/include/sodium/crypto_auth_hmacsha512.h
    extern/libsodium/src/libsodium/include/sodium/crypto_auth_hmacsha512256.h
    extern/libsodium/src/libsodium/include/sodium/crypto_box.h
    extern/libsodium/src/libsodium/include/sodium/crypto_box_curve25519xchacha20poly1305.h
    extern/libsodium/src/libsodium/include/sodium/crypto_box_curve25519xsalsa20poly1305.h
    extern/libsodium/src/libsodium/include/sodium/crypto_core_ed25519.h
    extern/libsodium/src/libsodium/include/sodium/crypto_core_hchacha20.h
    extern/libsodium/src/libsodium/include/sodium/crypto_core_hsalsa20.h
    extern/libsodium/src/libsodium/include/sodium/crypto_core_ristretto255.h
    extern/libsodium/src/libsodium/include/sodium/crypto_core_salsa20.h
    extern/libsodium/src/libsodium/include/sodium/crypto_core_salsa2012.h
    extern/libsodium/src/libsodium/include/sodium/crypto_core_salsa208.h
    extern/libsodium/src/libsodium/include/sodium/crypto_generichash.h
    extern/libsodium/src/libsodium/include/sodium/crypto_generichash_blake2b.h
    extern/libsodium/src/libsodium/include/sodium/crypto_hash.h
    extern/libsodium/src/libsodium/include/sodium/crypto_hash_sha256.h
    extern/libsodium/src/libsodium/include/sodium/crypto_hash_sha512.h
    extern/libsodium/src/libsodium/include/sodium/crypto_kdf.h
    extern/libsodium/src/libsodium/include/sodium/crypto_kdf_blake2b.h
    extern/libsodium/src/libsodium/include/sodium/crypto_kx.h
    extern/libsodium/src/libsodium/include/sodium/crypto_onetimeauth.h
    extern/libsodium/src/libsodium/include/sodium/crypto_onetimeauth_poly1305.h
    extern/libsodium/src/libsodium/include/sodium/crypto_pwhash.h
    extern/libsodium/src/libsodium/include/sodium/crypto_pwhash_argon2i.h
    extern/libsodium/src/libsodium/include/sodium/crypto_pwhash_argon2id.h
    extern/libsodium/src/libsodium/include/sodium/crypto_pwhash_scryptsalsa208sha256.h
    extern/libsodium/src/libsodium/include/sodium/crypto_scalarmult.h
    extern/libsodium/src/libsodium/include/sodium/crypto_scalarmult_curve25519.h
    extern/libsodium/src/libsodium/include/sodium/crypto_scalarmult_ed25519.h
    extern/libsodium/src/libsodium/include/sodium/crypto_scalarmult_ristretto255.h
    extern/libsodium/src/libsodium/include/sodium/crypto_secretbox.h
    extern/libsodium/src/libsodium/include/sodium/crypto_secretbox_xchacha20poly1305.h
    extern/libsodium/src/libsodium/include/sodium/crypto_secretbox_xsalsa20poly1305.h
    extern/libsodium/src/libsodium/include/sodium/crypto_secretstream_xchacha20poly1305.h
    extern/libsodium/src/libsodium/include/sodium/crypto_shorthash.h
    extern/libsodium/src/libsodium/include/sodium/crypto_shorthash_siphash24.h
    extern/libsodium/src/libsodium/include/sodium/crypto_sign.h
    extern/libsodium/src/libsodium/include/sodium/crypto_sign_ed25519.h
    extern/libsodium/src/libsodium/include/sodium/crypto_sign_edwards25519sha512batch.h
    extern/libsodium/src/libsodium/include/sodium/crypto_stream.h
    extern/libsodium/src/libsodium/include/sodium/crypto_stream_chacha20.h
    extern/libsodium/src/libsodium/include/sodium/crypto_stream_salsa20.h
    extern/libsodium/src/libsodium/include/sodium/crypto_stream_salsa2012.h
    extern/libsodium/src/libsodium/include/sodium/crypto_stream_salsa208.h
    extern/libsodium/src/libsodium/include/sodium/crypto_stream_xchacha20.h
    extern/libsodium/src/libsodium/include/sodium/crypto_stream_xsalsa20.h
    extern/libsodium/src/libsodium/include/sodium/crypto_verify_16.h
    extern/libsodium/src/libsodium/include/sodium/crypto_verify_32.h
    extern/libsodium/src/libsodium/include/sodium/crypto_verify_64.h
    extern/libsodium/src/libsodium/include/sodium/export.h
    extern/libsodium/src/libsodium/include/sodium/private/chacha20_ietf_ext.h
    extern/libsodium/src/libsodium/include/sodium/private/common.h
    extern/libsodium/src/libsodium/include/sodium/private/ed25519_ref10.h
    extern/libsodium/src/libsodium/include/sodium/private/ed25519_ref10_fe_25_5.h
    extern/libsodium/src/libsodium/include/sodium/private/ed25519_ref10_fe_51.h
    extern/libsodium/src/libsodium/include/sodium/private/implementations.h
    extern/libsodium/src/libsodium/include/sodium/private/mutex.h
    extern/libsodium/src/libsodium/include/sodium/private/sse2_64_32.h
    extern/libsodium/src/libsodium/include/sodium/randombytes.h
    extern/libsodium/src/libsodium/include/sodium/randombytes_internal_random.h
    extern/libsodium/src/libsodium/include/sodium/randombytes_sysrandom.h
    extern/libsodium/src/libsodium/include/sodium/runtime.h
    extern/libsodium/src/libsodium/include/sodium/utils.h
    extern/libsodium/src/libsodium/include/sodium/version.h
    extern/libsodium/src/libsodium/randombytes/internal/randombytes_internal_random.c
    extern/libsodium/src/libsodium/randombytes/randombytes.c
    extern/libsodium/src/libsodium/randombytes/sysrandom/randombytes_sysrandom.c
    extern/libsodium/src/libsodium/sodium/codecs.c
    extern/libsodium/src/libsodium/sodium/core.c
    extern/libsodium/src/libsodium/sodium/runtime.c
    extern/libsodium/src/libsodium/sodium/utils.c
    extern/libsodium/src/libsodium/sodium/version.c
)

if(NOT SODIUM_MINIMAL)
    target_sources(${PROJECT_NAME}
        PRIVATE
            extern/libsodium/src/libsodium/crypto_box/curve25519xchacha20poly1305/box_curve25519xchacha20poly1305.c
            extern/libsodium/src/libsodium/crypto_box/curve25519xchacha20poly1305/box_seal_curve25519xchacha20poly1305.c
            extern/libsodium/src/libsodium/crypto_core/ed25519/core_ed25519.c
            extern/libsodium/src/libsodium/crypto_core/ed25519/core_ristretto255.c
            extern/libsodium/src/libsodium/crypto_pwhash/scryptsalsa208sha256/crypto_scrypt-common.c
            extern/libsodium/src/libsodium/crypto_pwhash/scryptsalsa208sha256/crypto_scrypt.h
            extern/libsodium/src/libsodium/crypto_pwhash/scryptsalsa208sha256/nosse/pwhash_scryptsalsa208sha256_nosse.c
            extern/libsodium/src/libsodium/crypto_pwhash/scryptsalsa208sha256/pbkdf2-sha256.c
            extern/libsodium/src/libsodium/crypto_pwhash/scryptsalsa208sha256/pbkdf2-sha256.h
            extern/libsodium/src/libsodium/crypto_pwhash/scryptsalsa208sha256/pwhash_scryptsalsa208sha256.c
            extern/libsodium/src/libsodium/crypto_pwhash/scryptsalsa208sha256/scrypt_platform.c
            extern/libsodium/src/libsodium/crypto_pwhash/scryptsalsa208sha256/sse/pwhash_scryptsalsa208sha256_sse.c
            extern/libsodium/src/libsodium/crypto_scalarmult/ed25519/ref10/scalarmult_ed25519_ref10.c
            extern/libsodium/src/libsodium/crypto_scalarmult/ristretto255/ref10/scalarmult_ristretto255_ref10.c
            extern/libsodium/src/libsodium/crypto_secretbox/xchacha20poly1305/secretbox_xchacha20poly1305.c
            extern/libsodium/src/libsodium/crypto_shorthash/siphash24/ref/shorthash_siphashx24_ref.c
            extern/libsodium/src/libsodium/crypto_shorthash/siphash24/shorthash_siphashx24.c
            extern/libsodium/src/libsodium/crypto_sign/ed25519/ref10/obsolete.c
            extern/libsodium/src/libsodium/crypto_stream/salsa2012/ref/stream_salsa2012_ref.c
            extern/libsodium/src/libsodium/crypto_stream/salsa2012/stream_salsa2012.c
            extern/libsodium/src/libsodium/crypto_stream/salsa208/ref/stream_salsa208_ref.c
            extern/libsodium/src/libsodium/crypto_stream/salsa208/stream_salsa208.c
            extern/libsodium/src/libsodium/crypto_stream/xchacha20/stream_xchacha20.c
    )
endif()

set_target_properties(${PROJECT_NAME}
    PROPERTIES
        C_STANDARD 99
)

target_include_directories(${PROJECT_NAME}
    PUBLIC
        extern/libsodium/src/libsodium/include
    PRIVATE
        extern/libsodium/src/libsodium/include/sodium
)

target_compile_definitions(${PROJECT_NAME}
    PUBLIC
        $<$<NOT:$<BOOL:${BUILD_SHARED_LIBS}>>:SODIUM_STATIC>
        $<$<BOOL:${SODIUM_MINIMAL}>:SODIUM_LIBRARY_MINIMAL>
    PRIVATE
        CONFIGURED
        $<$<BOOL:${BUILD_SHARED_LIBS}>:SODIUM_DLL_EXPORT>
        $<$<BOOL:${SODIUM_ENABLE_BLOCKING_RANDOM}>:USE_BLOCKING_RANDOM>
        $<$<BOOL:${SODIUM_MINIMAL}>:MINIMAL>
        $<$<C_COMPILER_ID:MSVC>:_CRT_SECURE_NO_WARNINGS>
)

# No generator expression for CMAKE_C_COMPILER_FRONTEND_VARIANT until CMake 3.30:
# https://gitlab.kitware.com/cmake/cmake/-/merge_requests/9538
if(CMAKE_C_COMPILER_ID STREQUAL "Clang" AND CMAKE_C_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC")
    target_compile_definitions(${PROJECT_NAME}
        PRIVATE
            _CRT_SECURE_NO_WARNINGS
    )

    # Special manual feature-handling for clang-cl.
    target_compile_options(${PROJECT_NAME}
        PUBLIC
            # blake2b-compress-avx2
            -mavx2
        PRIVATE
            # aead_aes256gcm_aesni
            -maes
            -mpclmul
            -mssse3
    )
endif()

# Variables that need to be exported to version.h.in
set(VERSION 1.0.20)
set(SODIUM_LIBRARY_VERSION_MAJOR 26)
set(SODIUM_LIBRARY_VERSION_MINOR 2)
if(SODIUM_MINIMAL)
    set(SODIUM_LIBRARY_MINIMAL_DEF "#define SODIUM_LIBRARY_MINIMAL 1")
endif()

configure_file(
    extern/libsodium/src/libsodium/include/sodium/version.h.in
    ${CMAKE_CURRENT_SOURCE_DIR}/extern/libsodium/src/libsodium/include/sodium/version.h
)
