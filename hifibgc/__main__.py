"""
Entrypoint for HiFiBGC

Check out the wiki for a detailed look at customising this file:
https://github.com/beardymcjohnface/Snaketool/wiki/Customising-your-Snaketool
"""

import os
import click

from .cli_utils import OrderedCommands, run_snakemake, copy_config, echo_click
#from cli_utils import OrderedCommands, run_snakemake, copy_config, echo_click

def snake_base(rel_path):
    """Get the filepath to a Snaketool system file (relative to __main__.py)"""
    return os.path.join(os.path.dirname(os.path.realpath(__file__)), rel_path)


def get_version():
    """Read and print the version from the version file"""
    with open(snake_base("hifibgc.VERSION"), "r") as f:
        version = f.readline()
    return version


def print_citation():
    """Read and print the Citation information from the citation file"""
    with open(snake_base("hifibgc.CITATION"), "r") as f:
        for line in f:
            echo_click(line)


def default_to_output(ctx, param, value):
    """Callback for click options; places value in output directory unless specified"""
    if param.default == value:
        return os.path.join(ctx.params["output"], value)
    return value


def common_options(func):
    """Common command line args
    Define common command line args here, and include them with the @common_options decorator below.
    """
    options = [
        click.option(
            "--output",
            help="Output directory",
            type=click.Path(dir_okay=True, writable=True, readable=True),
            default="hifibgc1.out",
            show_default=True,
        ),
        click.option(
            "--configfile",
            default="config.yaml",
            show_default=False,
            callback=default_to_output,
            help="Custom config file [default: (outputDir)/config.yaml]",
        ),
        click.option(
            "--threads", help="Number of threads to use", default=80, show_default=True
        ),
        click.option(
            "--use-conda/--no-use-conda",
            default=True,
            help="Use conda for Snakemake rules",
            show_default=True,
        ),
        click.option(
            "--conda-prefix",
            default=snake_base(os.path.join("workflow", "conda")),
            help="Custom conda env directory",
            type=click.Path(),
            show_default=False,
        ),
        click.option(
            "--snake-default",
            multiple=True,
            default=[
                "--rerun-incomplete",
                "--printshellcmds",
                "--nolock",
                "--show-failed-logs",
            ],
            help="Customise Snakemake runtime args",
            show_default=True,
        ),
        click.option(
            "--log",
            default="hifibgc.log",
            callback=default_to_output,
            hidden=True,
        ),
        click.argument("snake_args", nargs=-1),
    ]
    for option in reversed(options):
        func = option(func)
    return func


@click.group(
    cls=OrderedCommands, context_settings=dict(help_option_names=["-h", "--help"])
)
@click.version_option(get_version(), "-v", "--version", is_flag=True)
def cli():
    """Detect Biosynthetic Gene Clusters (BGCs) in HiFi metagenomic data.
    \b
    For more options, run:
    hifibgc command --help"""
    pass


help_msg_extra = """
\b
EXAMPLE:
Run hifibgc with defaults 
    hifibgc run --input input.fastq  # --input is required
Specify output directory and no of threads
    hifibgc run --input input.fastq --output outdir --threads 16 
Specify bigscape_cutoff option
    hifibgc run --input input.fastq --bigscape_cutoff 0.4 
"""

@click.command(
    epilog=help_msg_extra,
    context_settings=dict(
        help_option_names=["-h", "--help"], ignore_unknown_options=True
    ),
)
@click.option("--input", "_input", help="Input file", type=str, required=True)
@click.option(
            "--output",
            help="Output directory",
            type=click.Path(dir_okay=True, writable=True, readable=True),
            default="hifibgc1.out",
            show_default=True,
        )
@click.option(
    "--bigscape_cutoff", help="BiG-SCAPE cutoff parameter", default=0.3, type=float, show_default=True
)
@click.option(
    "--configfile",
    default="config.yaml",
    show_default=False,
    callback=default_to_output,
    help="Custom config file [default: (outputDir)/config.yaml]",
)
@click.option(
    "--threads", help="Number of threads to use", default=80, show_default=True
)
@click.option(
    "--use-conda/--no-use-conda",
    default=True,
    help="Use conda for Snakemake rules",
    show_default=True,
)
@click.option(
    "--conda-prefix",
    default=snake_base(os.path.join("workflow", "conda")),
    help="Custom conda env directory",
    type=click.Path(),
    show_default=False,
)
@click.option(
    "--snake-default",
    multiple=True,
    default=[
        "--rerun-incomplete",
        "--printshellcmds",
        "--nolock",
        "--show-failed-logs",
    ],
    help="Customise Snakemake runtime args",
    show_default=True,
)
@click.option(
    "--log",
    default="hifibgc.log",
    callback=default_to_output,
    hidden=True,
)
@click.argument("snake_args", nargs=-1)
def run(_input, output, log, bigscape_cutoff, **kwargs):
    """Run HiFiBGC"""
    # Get absolute path of input file
    _input = os.path.abspath(_input)
    #keep_all_files = True

    # Config to add or update in configfile
    merge_config = {
        "input": _input,
        "output": output,
        "log": log,
        "bigscape_cutoff": bigscape_cutoff,
        #"keep_all_files": keep_all_files,    
    }

    # run!
    run_snakemake(
        # Full path to Snakefile
        snakefile_path=snake_base(os.path.join("workflow", "hifibgc.smk")),
        system_config=snake_base(os.path.join("config", "config.yaml")),
        merge_config=merge_config,
        log=log,
        **kwargs
    )

# Install command
help_msg_extra = """
\b
EXAMPLE:
hifibgc install : Install required database and tool
"""
@click.command(
    epilog=help_msg_extra,
    context_settings=dict(
        help_option_names=["-h", "--help"], ignore_unknown_options=True
    ),
)
@click.option(
    "--use-conda/--no-use-conda",
    default=True,
    help="Use conda for Snakemake rules",
    show_default=True,
)
@click.option(
    "--conda-prefix",
    default=snake_base(os.path.join("workflow", "conda")),
    help="Custom conda env directory",
    type=click.Path(),
    show_default=False,
)
@click.option(
    "--snake-default",
    multiple=True,
    default=[
        "--rerun-incomplete",
        "--printshellcmds",
        "--nolock",
        "--show-failed-logs",
    ],
    help="Customise Snakemake runtime args",
    show_default=True,
)
@click.argument("snake_args", nargs=-1)
def install(**kwargs):
    """Install required database and tool"""

    # run!
    run_snakemake(
        # Full path to Snakefile
        snakefile_path=snake_base(os.path.join("workflow", "install.smk")),
        system_config=snake_base(os.path.join("config", "config.yaml")),
        **kwargs
    )

# Test command
help_msg_extra = """
\b
EXAMPLE:
hifibgc test : Run hifibgc with test data
"""
@click.command(
    epilog=help_msg_extra,
    context_settings=dict(
        help_option_names=["-h", "--help"], ignore_unknown_options=True
    ),
)
@common_options
def test(**kwargs):
    """Test HiFiBGC"""
    input = snake_base(os.path.join("test_data", "test_data_sampled.fastq"))
    
    # Config to add or update in configfile
    merge_config = {
        "input": input,
    }
    
    # run!
    run_snakemake(
        # Full path to Snakefile
        snakefile_path=snake_base(os.path.join("workflow", "hifibgc.smk")),
        system_config=snake_base(os.path.join("config", "config.yaml")),
        merge_config=merge_config,
        **kwargs
    )


# Config command
help_msg_extra = """
\b
EXAMPLE:
    hifibgc config                  : Copy system default config.yaml to default directory hifibgc1.out
    hifibgc config --output outdir  : Copy system default config.yaml to directory outdir
"""
@click.command(
    epilog=help_msg_extra,
    context_settings=dict(
         help_option_names=["-h", "--help"], ignore_unknown_options=True
     ),
)
@click.option(
            "--output",
            help="Output directory",
            type=click.Path(dir_okay=True, writable=True, readable=True),
            default="hifibgc1.out",
            show_default=True,
        )
@click.option(
            "--configfile",
            default="config.yaml",
            show_default=False,
            callback=default_to_output,
            help="Custom config file [default: (outputDir)/config.yaml]",
        )
def config(configfile, **kwargs):
    """Copy the system default config file"""
    copy_config(configfile, system_config=snake_base(os.path.join("config", "config.yaml")))

# Citation command
@click.command()
def citation(**kwargs):
    """Print the citation(s) for this tool"""
    print_citation()


cli.add_command(run)
cli.add_command(install)
cli.add_command(test)
cli.add_command(config)
cli.add_command(citation)


def main():
    cli()


if __name__ == "__main__":
    main()
