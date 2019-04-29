/*
   Copyright 2019 Supercomputing Systems AG

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

extern crate sgx_types;

use sgx_types::*;

extern {
    // fn sign(
    //     eid: sgx_enclave_id_t,
    //     retval: *mut sgx_status_t,
    //     sealed_seed: * mut u8,
    //     sealed_seed_size: u32,
    //     msg: * mut u8,
    //     msg_size: u32,
    //     signature: * mut u8,
    //     signature_size: u32
    // ) -> sgx_status_t;

    pub fn decrypt_and_process_payload(
        eid: sgx_enclave_id_t,
        retval: *mut sgx_status_t,
        ciphertext: * mut u8,
        ciphertext_size: u32
    ) -> sgx_status_t;

    pub fn create_sealed_rsa3072_keypair(
        eid: sgx_enclave_id_t,
        retval: *mut sgx_status_t,
        filepath: *const u8,
        filepath_size: usize
    ) -> sgx_status_t;

    pub fn get_rsa_encryption_pubkey(
        eid: sgx_enclave_id_t,
        retval: *mut sgx_status_t,
        pubkey: * mut u8,
        pubkey_size: u32
    ) -> sgx_status_t;
}
