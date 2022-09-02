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
	trusted_base_cli::commands::{
		balance::BalanceCommand,
		interstellar::{
			ocw_garble_garble_and_strip_display_circuits_package_signed,
			ocw_garble_get_most_recent_circuits_package, tx_validation_check_input,
		},
		set_balance::SetBalanceCommand,
		transfer::TransferCommand,
		unshield_funds::UnshieldFundsCommand,
	},
	trusted_command_utils::get_keystore_path,
	trusted_commands::TrustedArgs,
	Cli,
};
use log::*;
use sp_application_crypto::{ed25519, sr25519};
use sp_core::{crypto::Ss58Codec, Pair};
use substrate_client_keystore::{KeystoreExt, LocalKeystore};

mod commands;

#[derive(Subcommand)]
pub enum TrustedBaseCli {
	/// generates a new incognito account for the given shard
	NewAccount,

	/// lists all incognito accounts in a given shard
	ListAccounts,

	/// send funds from one incognito account to another
	Transfer(TransferCommand),

	/// ROOT call to set some account balance to an arbitrary number
	SetBalance(SetBalanceCommand),

	/// query balance for incognito account in keystore
	Balance(BalanceCommand),

	/// Transfer funds from an incognito account to an parentchain account
	UnshieldFunds(UnshieldFundsCommand),

	/// [interstellar]
	GarbleAndStripDisplayCircuitsPackageSigned {
		/// AccountId in ss58check format
		account: String,
		/// Transaction message; that is what will be display on the "pinpad screen" in the mobile app
		tx_msg: String,
	},

	/// [interstellar]
	/// pallet_ocw_garble: Get Circuits - query circuits state for account in keystore
	GetCircuitsPackage {
		/// AccountId in ss58check format
		account: String,
	},

	/// [interstellar]
	/// pallet_tx_validation: Check input
	TxCheckInput {
		/// AccountId in ss58check format
		account: String,
		// WARNING: Vec<u8> means digits are expected else:
		// error: Invalid value "QmUFCR3bVhx6AnMkzo2UeMG8ev39kBqgcGXNDfFx5FyRmi" for '<IPFS_CID>...': invalid digit found in string
		// --> ipfs_cid MUST use String
		ipfs_cid: String,
		input_digits: Vec<u8>,
	},
}

impl TrustedBaseCli {
	pub fn run(&self, cli: &Cli, trusted_args: &TrustedArgs) {
		match self {
			TrustedBaseCli::NewAccount => new_account(trusted_args),
			TrustedBaseCli::ListAccounts => list_accounts(trusted_args),
			TrustedBaseCli::Transfer(cmd) => cmd.run(cli, trusted_args),
			TrustedBaseCli::SetBalance(cmd) => cmd.run(cli, trusted_args),
			TrustedBaseCli::Balance(cmd) => cmd.run(cli, trusted_args),
			TrustedBaseCli::UnshieldFunds(cmd) => cmd.run(cli, trusted_args),
			// [interstellar]
			TrustedBaseCli::GarbleAndStripDisplayCircuitsPackageSigned { account, tx_msg } =>
				ocw_garble_garble_and_strip_display_circuits_package_signed(
					cli,
					trusted_args,
					account,
					tx_msg,
				),
			TrustedBaseCli::GetCircuitsPackage { account } =>
				ocw_garble_get_most_recent_circuits_package(cli, trusted_args, account),
			TrustedBaseCli::TxCheckInput { account, ipfs_cid, input_digits } =>
				tx_validation_check_input(cli, trusted_args, account, ipfs_cid, input_digits),
		}
	}
}

fn new_account(trusted_args: &TrustedArgs) {
	let store = LocalKeystore::open(get_keystore_path(trusted_args), None).unwrap();
	let key: sr25519::AppPair = store.generate().unwrap();
	drop(store);
	info!("new account {}", key.public().to_ss58check());
	println!("{}", key.public().to_ss58check());
}

fn list_accounts(trusted_args: &TrustedArgs) {
	let store = LocalKeystore::open(get_keystore_path(trusted_args), None).unwrap();
	info!("sr25519 keys:");
	for pubkey in store.public_keys::<sr25519::AppPublic>().unwrap().into_iter() {
		println!("{}", pubkey.to_ss58check());
	}
	info!("ed25519 keys:");
	for pubkey in store.public_keys::<ed25519::AppPublic>().unwrap().into_iter() {
		println!("{}", pubkey.to_ss58check());
	}
	drop(store);
}
