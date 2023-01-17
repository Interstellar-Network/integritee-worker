# Copyright (C) 2017-2018 Baidu, Inc. All Rights Reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#  * Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in
#    the documentation and/or other materials provided with the
#    distribution.
#  * Neither the name of Baidu, Inc., nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

######## Worker Feature Settings ########
# Set sidechain as default feature mode
WORKER_MODE ?= sidechain

Rust_Enclave_Name := libenclave.a
Rust_Enclave_Files := $(wildcard src/*.rs) $(wildcard ../stf/src/*.rs)
RUSTFLAGS :="-C target-feature=+avx2"

# IMPORTANT: DO NOT try and build the enclave in anything other than release!
# else: Compiling enclave-runtime/enclave.so
# /opt/intel/bin/ld: ./lib/libenclave.a(limbs.o): in function `LIMBS_less_than':
# /home/pratn/.cargo/git/checkouts/ring-sgx-f3f2b49526f918ea/844efe2/crypto/limbs/limbs.c:71: undefined reference to `__assert_fail'
# only needed for enclave-runtime build; in "NOT RELEASE"
# https://github.com/apache/incubator-teaclave-sgx-sdk/issues/373
# 	-> does NOT work?
# https://github.com/apache/incubator-teaclave-sgx-sdk/issues/44
# https://github.com/integritee-network/worker/issues/761
# and a bunch of other issues with the same "__assert_fail"
# TODO? ifeq ($(DEBUG_BUILD), 1)
ifeq ($(SGX_DEBUG), 1)
	OUTPUT_PATH := release
	CARGO_TARGET := --release
else
	OUTPUT_PATH := release
	CARGO_TARGET := --release
endif

ifeq ($(SGX_PRODUCTION), 1)
	ENCLAVE_FEATURES = --features=production,$(WORKER_MODE),$(ADDITIONAL_FEATURES)
else
	ENCLAVE_FEATURES = --features=test,$(WORKER_MODE),$(ADDITIONAL_FEATURES)
endif

.PHONY: all

all: $(Rust_Enclave_Name)

$(Rust_Enclave_Name): $(Rust_Enclave_Files)
	RUSTFLAGS=$(RUSTFLAGS) cargo build $(CARGO_TARGET) $(ENCLAVE_FEATURES)
	cp ./target/$(OUTPUT_PATH)/libenclave_runtime.a ../lib/libenclave.a

