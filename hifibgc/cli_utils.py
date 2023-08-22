"""
This file taken from here: https://github.com/beardymcjohnface/Snaketool-utils/blob/main/snaketool_utils/cli_utils.py

To make hifibgc available on conda, all its dependencies have to be available on conda. See this: https://github.com/conda/conda-build/issues/548
`Snaketool-utils` is not available on conda, available only through pip. So to avoid creating a `Snaketool-utils` conda receipe, 
this file was copied directly from `Snaketool-utils`.
"""

import sys
import os
import subprocess
import yaml
import click
import collections.abc
from shutil import copyfile
from time import localtime, strftime


class OrderedCommands(click.Group):
    """This class will preserve the order of subcommands, which is useful when printing --help"""

    def list_commands(self, ctx: click.Context):
        return list(self.commands)


def echo_click(msg, log=None):
    """Print Error message to STDERR and copy to log file

    Args:
        msg (str): Error message to print
        log (srt): Filepath to log file for writing
    """
    click.echo(msg, nl=False, err=True)
    if log:
        with open(log, "a") as l:
            l.write(msg)


def msg(err_message, log=None):
    """Format error message for printing

    Args:
        err_message (str): Error message to print
        log (str): Filepath to log file for writing
    """
    tstamp = strftime("[%Y:%m:%d %H:%M:%S] ", localtime())
    echo_click(tstamp + err_message + "\n", log=log)


def msg_box(splash, errmsg=None, log=None):
    """Fancy formatting and multi-line error message for printing

    Args:
        splash (str): Short splash message to appear in box
        errmsg (str): Long error message to print
        log (str): Filepath to log file for writing
    """
    msg("-" * (len(splash) + 4), log=log)
    msg(f"| {splash} |", log=log)
    msg(("-" * (len(splash) + 4)), log=log)
    if errmsg:
        echo_click("\n" + errmsg + "\n", log=log)


def read_config(file):
    """Read a config file to a dictionary

    Args:
        file (str): Filepath to config YAML file for reading

    Returns (dict): Config read from YAML file
    """

    with open(file, "r") as stream:
        config = yaml.safe_load(stream)
    return config


def recursive_merge_config(config, overwrite_config):
    """Recursively merge a dictionary.

    This is required for updating/merging config dictionaries that are more than one level deep.

    Args:
        config (dict): Config dictionary to overwrite (e.g. defaults)
        overwrite_config (dict): Config dictionary of new/updated values to add
    """

    def _update(d, u):
        for key, value in u.items():
            if isinstance(value, collections.abc.Mapping):
                d[key] = _update(d.get(key, {}), value)
            else:
                d[key] = value
        return d

    _update(config, overwrite_config)


def update_config(in_config=None, merge=None, output_config=None, log=None):
    """Update the default config with the new config values

    Args:
        in_config (str): Filepath to YAML config file
        merge (dict): New values to merge into new config file
        output_config (str): Filepath to write new merged config YAML file
        log (str): Log file for writing STDERR
    """
    if output_config is None:
        output_config = in_config
    config = read_config(in_config)
    msg("Updating config file with new values", log=log)
    recursive_merge_config(config, merge)
    write_config(config, output_config, log=log)


def write_config(config, file, log=None):
    """Write the config dictionary to a YAML file

    Args:
        config (dict): Dictionary of config values
        file (str): Filepath of config file for writing
        log (str): Filepath of log file for writing STDERR
    """
    msg(f"Writing config file to {file}", log=log)
    with open(file, "w") as stream:
        yaml.dump(config, stream)


def copy_config(
    local_config,
    merge_config=None,
    system_config=None,
    log=None,
):
    """Copy a config file, optionally merging in new config values.

    Args:
        local_config (str): Filepath of new config YAML for writing
        merge_config (dict): Config values for merging
        system_config (str): Filepath of original config YAML file for reading
        log (str): Filepath of log file for writing STDERR
    """
    if not os.path.isfile(local_config):
        if len(os.path.dirname(local_config)) > 0:
            os.makedirs(os.path.dirname(local_config), exist_ok=True)
        msg(f"Copying system default config to {local_config}", log=log)

        if merge_config:
            update_config(
                in_config=system_config,
                merge=merge_config,
                output_config=local_config,
                log=log,
            )
        else:
            print(f"system_config: {system_config}")
            print(f"local_config: {local_config}")
            copyfile(system_config, local_config)
    else:
        msg(
            f"Config file {local_config} already exists. Using existing config file.",
            log=log,
        )


def run_snakemake(
    configfile=None,
    system_config=None,
    snakefile_path=None,
    merge_config=None,
    threads=1,
    use_conda=False,
    conda_prefix=None,
    snake_default=None,
    snake_args=[],
    profile=None,
    log=None,
    **kwargs,
):
    """Run a Snakefile!

    Args:
        configfile (str): Filepath of config file to pass with --configfile
        system_config (str): Filepath of system config to copy if configfile not present
        snakefile_path (str): Filepath of Snakefile
        merge_config (dict): Config values to merge with your config file
        threads (int): Number of local threads to request
        use_conda (bool): Snakemake's --use-conda
        conda_prefix (str): Filepath for Snakemake's --conda-prefix
        snake_default (list): Snakemake args to pass to Snakemake
        snake_args (list): Additional args to pass to Snakemake
        profile (str): Name of Snakemake profile
        log (str): Log file for writing STDERR
        **kwargs:

    Returns (int): Exit code
    """

    snake_command = ["snakemake", "-s", snakefile_path]

    # if using a configfile
    if configfile:
        # copy sys default config if not present
        copy_config(configfile, system_config=system_config, log=log)

        if merge_config:
            update_config(in_config=configfile, merge=merge_config, log=log)

        snake_command += ["--configfile", configfile]

        # display the runtime configuration
        snake_config = read_config(configfile)
        msg_box(
            "Runtime config",
            errmsg=yaml.dump(snake_config, Dumper=yaml.Dumper),
            log=log,
        )

    # add threads
    if "--profile" not in snake_args and profile is None:
        snake_command += ["--cores", threads]

    # add conda args if using conda
    if use_conda:
        snake_command += ["--use-conda"]
        if conda_prefix:
            snake_command += ["--conda-prefix", conda_prefix]

    # add snakemake default args
    if snake_default:
        snake_command += snake_default

    # add any additional snakemake commands
    if snake_args:
        snake_command += list(snake_args)

    # allow double-handling of profile
    if profile:
        snake_command += ["--profile", profile]

    # Run Snakemake!!!
    snake_command = " ".join(str(s) for s in snake_command)
    msg_box("Snakemake command", errmsg=snake_command, log=log)
    if not subprocess.run(snake_command, shell=True).returncode == 0:
        msg("ERROR: Snakemake failed", log=log)
        sys.exit(1)
    else:
        msg("Snakemake finished successfully", log=log)
    return 0