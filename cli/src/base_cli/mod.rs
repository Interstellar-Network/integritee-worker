/*
	Copyright 2021 Integritee AG and Supercomputing Systems AG

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

use crate::{
	base_cli::commands::{
		balance::BalanceCommand, faucet::FaucetCommand, listen::ListenCommand,
		shield_funds::ShieldFundsCommand, transfer::TransferCommand,
	},
	command_utils::*,
	Cli, CliResult,
};
use base58::ToBase58;
use chrono::{DateTime, Utc};
use clap::Subcommand;
use itc_rpc_client::direct_client::DirectApi;
use itp_node_api::api_client::PalletTeerexApi;
use sp_application_crypto::{ed25519, sr25519};
use sp_core::{crypto::Ss58Codec, Pair};
use std::{
	path::PathBuf,
	time::{Duration, UNIX_EPOCH},
};
use substrate_api_client::Metadata;
use substrate_client_keystore::{KeystoreExt, LocalKeystore};

mod commands;

#[derive(Subcommand)]
pub enum BaseCli {
	/// query parentchain balance for AccountId
	Balance(BalanceCommand),

	/// generates a new account for the integritee chain in your local keystore
	NewAccount,

	/// lists all accounts in your local keystore for the integritee chain
	ListAccounts,

	/// query node metadata and print it as json to stdout
	PrintMetadata,

	/// query sgx-runtime metadata and print it as json to stdout
	PrintSgxMetadata,

	/// send some bootstrapping funds to supplied account(s)
	Faucet(FaucetCommand),

	/// transfer funds from one parentchain account to another
	Transfer(TransferCommand),

	/// query enclave registry and list all workers
	ListWorkers,

	/// listen to parentchain events
	Listen(ListenCommand),

	/// Transfer funds from an parentchain account to an incognito account
	ShieldFunds(ShieldFundsCommand),
}

impl BaseCli {
	pub fn run(&self, cli: &Cli) -> CliResult {
		match self {
			BaseCli::Balance(cmd) => cmd.run(cli),
			BaseCli::NewAccount => new_account(),
			BaseCli::ListAccounts => list_accounts(),
			BaseCli::PrintMetadata => print_metadata(cli),
			BaseCli::PrintSgxMetadata => print_sgx_metadata(cli),
			BaseCli::Faucet(cmd) => cmd.run(cli),
			BaseCli::Transfer(cmd) => cmd.run(cli),
			BaseCli::ListWorkers => list_workers(cli),
			BaseCli::Listen(cmd) => cmd.run(cli),
			BaseCli::ShieldFunds(cmd) => cmd.run(cli),
		}
	}
}

fn new_account() -> CliResult {
	let store = LocalKeystore::open(PathBuf::from(&KEYSTORE_PATH), None).unwrap();
	let key: sr25519::AppPair = store.generate().unwrap();
	let key_base58 = key.public().to_ss58check();
	drop(store);
	println!("{}", key_base58);
	CliResult::PubKeysBase58 { pubkeys_sr25519: Some(vec![key_base58]), pubkeys_ed25519: None }
}

fn list_accounts() -> CliResult {
	let store = LocalKeystore::open(PathBuf::from(&KEYSTORE_PATH), None).unwrap();
	println!("sr25519 keys:");
	let mut keys_sr25519 = vec![];
	for pubkey in store.public_keys::<sr25519::AppPublic>().unwrap().into_iter() {
		let key_ss58 = pubkey.to_ss58check();
		println!("{}", key_ss58);
		keys_sr25519.push(key_ss58);
	}
	println!("ed25519 keys:");
	let mut keys_ed25519 = vec![];
	for pubkey in store.public_keys::<ed25519::AppPublic>().unwrap().into_iter() {
		let key_ss58 = pubkey.to_ss58check();
		println!("{}", key_ss58);
		keys_ed25519.push(key_ss58);
	}
	drop(store);

	CliResult::PubKeysBase58 {
		pubkeys_sr25519: Some(keys_sr25519),
		pubkeys_ed25519: Some(keys_ed25519),
	}
}

fn print_metadata(cli: &Cli) -> CliResult {
	let meta = get_chain_api(cli).get_metadata().unwrap();
	println!("Metadata:\n {}", Metadata::pretty_format(&meta).unwrap());
	CliResult::Metadata { metadata: meta }
}

fn print_sgx_metadata(cli: &Cli) -> CliResult {
	let worker_api_direct = get_worker_api_direct(cli);
	let metadata = worker_api_direct.get_state_metadata().unwrap();
	println!("Metadata:\n {}", Metadata::pretty_format(&metadata).unwrap());
	CliResult::Metadata { metadata }
}

fn list_workers(cli: &Cli) -> CliResult {
	let api = get_chain_api(cli);
	let wcount = api.enclave_count(None).unwrap();
	println!("number of workers registered: {}", wcount);
	let mut mr_enclaves = Vec::with_capacity(wcount as usize);
	for w in 1..=wcount {
		let enclave = api.enclave(w, None).unwrap();
		if enclave.is_none() {
			println!("error reading enclave data");
			continue
		};
		let enclave = enclave.unwrap();
		let timestamp =
			DateTime::<Utc>::from(UNIX_EPOCH + Duration::from_millis(enclave.timestamp));
		let mr_enclave = enclave.mr_enclave.to_base58();
		println!("Enclave {}", w);
		println!("   AccountId: {}", enclave.pubkey.to_ss58check());
		println!("   MRENCLAVE: {}", mr_enclave);
		println!("   RA timestamp: {}", timestamp);
		println!("   URL: {}", enclave.url);

		mr_enclaves.push(mr_enclave);
	}

	CliResult::MrEnclaveBase58 { mr_enclaves }
}
