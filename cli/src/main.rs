use clap::Parser;
use integritee_cli::{commands, Cli};

fn main() {
	env_logger::init();

	let cli = Cli::parse();

	commands::match_command(&cli);
}
