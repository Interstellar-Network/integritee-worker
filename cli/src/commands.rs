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

extern crate chrono;
use crate::{base_cli::BaseCli, command_utils::*, trusted_commands::TrustedArgs, Cli};
use clap::Subcommand;
use log::*;
use sp_keyring::AccountKeyring;
use substrate_api_client::{compose_extrinsic, UncheckedExtrinsicV4, XtStatus};

#[cfg(feature = "teeracle")]
use crate::oracle::OracleSubCommand;

#[derive(Subcommand)]
pub enum Commands {
	#[clap(flatten)]
	Base(BaseCli),

	// [interstellar] DEMO ONLY
	DemoOcwCircuitsSubmitConfigDisplayCircuitsPackage {
		// NO params
	},

	/// trusted calls to worker enclave
	#[clap(after_help = "stf subcommands depend on the stf crate this has been built against")]
	Trusted(TrustedArgs),

	/// Subcommands for the oracle.
	#[cfg(feature = "teeracle")]
	#[clap(subcommand)]
	Oracle(OracleSubCommand),
}

pub fn match_command(cli: &Cli) {
	#[allow(non_snake_case, unused_variables)]
	match &cli.command {
		Commands::Base(cmd) => cmd.run(cli),
		Commands::Trusted(cmd) => cmd.run(cli),
		#[cfg(feature = "teeracle")]
		Commands::Oracle(cmd) => cmd.run(cli),
		// [interstellar][DEMO ONLY]
		DemoOcwCircuitsSubmitConfigDisplayCircuitsPackage =>
			demo_pallet_ocw_circuits_submit_config_display_circuits_package_signed(cli),
	};
}

/// [interstellar][DEMO ONLY]
/// Convenience function to be able to call Extrinsic "ocwCircuits::submitConfigDisplayCircuitsPackageSigned"
/// from the demo script cli/demo_interstellar.sh
/// That avoids having to use a front-end for the M4 demo.
fn demo_pallet_ocw_circuits_submit_config_display_circuits_package_signed(cli: &Cli) {
	// NOTE: this assumes Alice is sudo; but that should be the case for the demos
	let api = get_chain_api(cli).set_signer(AccountKeyring::Alice.pair());

	// let xt = api.balance_transfer(GenericAddress::Id(to_account.clone()), *amount);
	// let tx_hash = api.send_extrinsic(xt.hex_encode(), XtStatus::InBlock).unwrap();
	let xt: UncheckedExtrinsicV4<_, _> = compose_extrinsic!(
		api,
		// MUST match the name in https://github.com/Interstellar-Network/integritee-node/blob/7585259bdb7230ea8ed4713c64f2c7b721c4e755/runtime/src/lib.rs
		"OcwCircuits",
		// MUST match the call in /substrate-offchain-worker-demo/pallets/ocw-circuits/src/lib.rs
		"submit_config_display_circuits_package_signed" // NO params
	);

	debug!("[+] Composed Extrinsic:\n {:?}\n", xt);

	// "send and watch extrinsic until InBlock"
	let tx_hash = api.send_extrinsic(xt.hex_encode(), XtStatus::InBlock).unwrap();
	debug!("[+] Transaction got included. Hash: {:?}", tx_hash);

	let tx_hash = tx_hash.expect("send_extrinsic failed");

	debug!("[+] TrustedOperation got finalized. Hash: {:?}\n", tx_hash);
}
