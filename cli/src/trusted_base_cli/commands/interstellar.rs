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
	get_layer_two_nonce,
	trusted_cli::TrustedCli,
	trusted_command_utils::{get_identifiers, get_pair_from_str},
	trusted_operation::perform_trusted_operation,
	Cli, CliError, CliResult, CliResultOk,
};
use codec::Decode;
use core::primitive::str;
use ita_stf::{Index, TrustedCall, TrustedGetter, TrustedOperation};
use itp_stf_primitives::types::KeyPair;
use log::*;
use sp_core::{crypto::Ss58Codec, Pair};
use std::boxed::Box;

/// pallet ocw-garble: garble_and_strip_display_circuits_package_signed
pub(crate) fn ocw_garble_garble_and_strip_display_circuits_package_signed(
	cli: &Cli,
	trusted_args: &TrustedCli,
	player_creator: &str,
	tx_msg: &str,
) -> CliResult {
	let creator = get_pair_from_str(trusted_args, player_creator);
	let direct: bool = trusted_args.direct;

	info!(
		"send trusted call garble_and_strip_display_circuits_package_signed from {} with tx_msg {:?}",
		creator.public().to_ss58check(),
		tx_msg
	);

	let (mrenclave, shard) = get_identifiers(trusted_args);
	let nonce = get_layer_two_nonce!(creator, cli, trusted_args);

	let top: TrustedOperation = TrustedCall::garble_and_strip_display_circuits_package_signed(
		creator.public().into(),
		tx_msg.as_bytes().to_vec(),
	)
	.sign(&KeyPair::Sr25519(Box::new(creator)), nonce, &mrenclave, &shard)
	.into_trusted_operation(direct);

	Ok(perform_trusted_operation(cli, trusted_args, &top).map(|_| CliResultOk::None)?)
}

/// pallet tx-validation: check_input
pub(crate) fn tx_validation_check_input(
	cli: &Cli,
	trusted_args: &TrustedCli,
	player_creator: &str,
	ipfs_cid: &str,
	input_digits: &Vec<u8>,
) -> CliResult {
	let creator = get_pair_from_str(trusted_args, player_creator);
	let direct: bool = trusted_args.direct;

	info!(
		"send trusted call tx_validation_check_input from {} with ipfs_cid: {:?}, inputs: {:?}",
		creator.public().to_ss58check(),
		ipfs_cid,
		input_digits
	);

	let (mrenclave, shard) = get_identifiers(trusted_args);
	let nonce = get_layer_two_nonce!(creator, cli, trusted_args);

	let top: TrustedOperation = TrustedCall::tx_validation_check_input(
		creator.public().into(),
		ipfs_cid.to_string(),
		input_digits.clone(),
	)
	.sign(&KeyPair::Sr25519(Box::new(creator)), nonce, &mrenclave, &shard)
	.into_trusted_operation(direct);

	Ok(perform_trusted_operation(cli, trusted_args, &top).map(|_| CliResultOk::None)?)
}

/// Query circuits state for a specific account.
pub(crate) fn ocw_garble_get_most_recent_circuits_package(
	cli: &Cli,
	trusted_args: &TrustedCli,
	arg_account: &str,
) -> CliResult {
	// TODO? apparently the "getters" does not return a value, so we MUST use
	// println to see a result in cli/demo_interstellar.sh

	let account = get_pair_from_str(trusted_args, arg_account);
	println!("account ss58 is {}", account.public().to_ss58check());
	// NOTE: this will end up calling "fn get_most_recent_circuits_for" in app-libs/stf/src/helpers.rs
	// and this returns ONE Circuit(the most recent)
	let top: TrustedOperation = TrustedGetter::most_recent_circuits(account.public().into())
		.sign(&KeyPair::Sr25519(Box::new(account)))
		.into();

	let getter_result = perform_trusted_operation(cli, trusted_args, &top);

	match getter_result {
		Ok(res) => {
			if let Ok(circuit) = pallet_ocw_garble::DisplayStrippedCircuitsPackage::decode(
				&mut res.unwrap_or_default().as_slice(),
			) {
				println!(
					"circuits : message_pgarbled_cid: {:?}, pinpad_pgarbled_cid: {:?}",
					std::str::from_utf8(&circuit.message_pgarbled_cid)
						.expect("message_pgarbled_cid utf8"),
					std::str::from_utf8(&circuit.pinpad_pgarbled_cid)
						.expect("pinpad_pgarbled_cid utf8"),
				);

				return Ok(CliResultOk::DisplayStrippedCircuitsPackage { circuit })
			} else {
				println!("could not decode circuits. maybe hasn't been set?");
			}
		},
		Err(_) => println!("could not fetch circuits [1]"),
	}

	Err(CliError::Default { msg: "could not fetch circuits".to_string() })
}
