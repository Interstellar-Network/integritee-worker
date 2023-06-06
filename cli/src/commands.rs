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
use crate::{
	base_cli::BaseCommand, command_utils::get_chain_api, trusted_cli::TrustedCli, Cli, CliResult,
	CliResultOk,
};
use clap::Subcommand;
use itp_node_api::api_client::ParentchainExtrinsicSigner;
use log::*;
use sp_keyring::AccountKeyring;
use substrate_api_client::{compose_extrinsic, SubmitAndWatch, XtStatus};

#[cfg(feature = "teeracle")]
use crate::oracle::OracleCommand;

use crate::attesteer::AttesteerCommand;

#[derive(Subcommand)]
pub enum Commands {
	#[clap(flatten)]
	Base(BaseCommand),

	// [interstellar] DEMO ONLY
	DemoOcwCircuitsSubmitConfigDisplayCircuitsPackage {
		// NO params
	},

	/// trusted calls to worker enclave
	#[clap(after_help = "stf subcommands depend on the stf crate this has been built against")]
	Trusted(TrustedCli),

	/// Subcommands for the oracle.
	#[cfg(feature = "teeracle")]
	#[clap(subcommand)]
	Oracle(OracleCommand),

	/// Subcommand for the attesteer.
	#[clap(subcommand)]
	Attesteer(AttesteerCommand),
}

pub fn match_command(cli: &Cli) -> CliResult {
	match &cli.command {
		Commands::Base(cmd) => cmd.run(cli),
		Commands::Trusted(trusted_cli) => trusted_cli.run(cli),
		#[cfg(feature = "teeracle")]
		Commands::Oracle(cmd) => {
			cmd.run(cli);
			Ok(CliResultOk::None)
		},
		Commands::Attesteer(cmd) => {
			cmd.run(cli);
			Ok(CliResultOk::None)
		},
		// [interstellar][DEMO ONLY]
		Commands::DemoOcwCircuitsSubmitConfigDisplayCircuitsPackage {} =>
			demo_pallet_ocw_circuits_submit_config_display_circuits_package_signed(cli),
	}
}

/// [interstellar][DEMO ONLY]
/// Convenience function to be able to call Extrinsic "ocwCircuits::submitConfigDisplayCircuitsPackageSigned"
/// from the demo script cli/demo_interstellar.sh
/// That avoids having to use a front-end for the M4 demo.
fn demo_pallet_ocw_circuits_submit_config_display_circuits_package_signed(cli: &Cli) -> CliResult {
	// NOTE: this assumes Alice is sudo; but that should be the case for the demos
	let mut chain_api = get_chain_api(cli);

	// TODO
	// let arg_signer = &trusted_args.xt_signer;
	// let signer = get_pair_from_str(arg_signer);
	// chain_api.set_signer(ParentchainExtrinsicSigner::new(sr25519_core::Pair::from(signer)));
	chain_api.set_signer(ParentchainExtrinsicSigner::new(AccountKeyring::Alice.pair()));

	// let xt = api.balance_transfer(GenericAddress::Id(to_account.clone()), *amount);
	// let tx_hash = api.send_extrinsic(xt.hex_encode(), XtStatus::InBlock).unwrap();
	let xt = compose_extrinsic!(
		&chain_api,
		// MUST match the name in https://github.com/Interstellar-Network/integritee-node/blob/7585259bdb7230ea8ed4713c64f2c7b721c4e755/runtime/src/lib.rs
		"OcwCircuits",
		// MUST match the call in /substrate-offchain-worker-demo/pallets/ocw-circuits/src/lib.rs
		"submit_config_display_circuits_package_signed" // NO params
	);

	debug!("[+] Composed Extrinsic:\n {:?}\n", xt);

	// "send and watch extrinsic until InBlock"
	let tx_hash = chain_api.submit_and_watch_extrinsic_until(xt, XtStatus::Finalized).unwrap();

	debug!("[+] TrustedOperation got finalized. Hash: {:?}\n", tx_hash);

	Ok(CliResultOk::None)
}
