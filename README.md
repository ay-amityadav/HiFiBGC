# HiFiBGC

HiFiBGC is a tool for detecting Biosynthetic Gene Clusters (BGCs) in PacBio HiFi metagenomic data.

## Table of Contents
- [Installation](#installation)
- [Usage](#usage)
- [Output](#output)
- [Commands](#commands)
- [Third-party Tools](#third-party-tools)
- [Citation](#citation)

## Installation

Choose one of the following installation methods:

### Option 1: mamba (Recommended)
```bash
mamba create -n hifibgc -c conda-forge -c bioconda -c amityadav -y hifibgc
mamba activate hifibgc
```
mamba is preferred over below conda as it takes much lesser time and consumes lesser memory (RAM).<br>
mamba can be installed from [here](https://mamba.readthedocs.io/en/latest/installation/mamba-installation.html).

### Option 2: conda
```bash
conda create -n hifibgc -c conda-forge -c bioconda -c amityadav -y hifibgc
conda activate hifibgc
```

### Option 3: pip
Requires Python 3.11, pip, and mamba:
```bash
pip install hifibgc
```
Note: HiFiBGC can run without mamba, but then every command need to be run with `--conda-frontend conda` (e.g., `hifibgc test --conda-frontend conda`).

### Test Installation

#### Install Prerequisites
Run once to install the required database and tool:
```bash
hifibgc install
```

#### Run on a test dataset
Verify the installation using the test dataset:
```bash
hifibgc test
```
Successful completion will display "Snakemake finished successfully" and create an output directory `hifibgc1.out`.

**OS Compatibility:** Installation has been tested on Ubuntu 20.04 (Linux) and macOS-12. On macOS-12, installation was verified using conda and pip, but not mamba.

## Usage

### Install Prerequisites
Run once to install the required database and tool (note: if you have already run this earlier for testing installation, then skip this step):
```bash
hifibgc install
```

### Run on your own data

To run HiFiBGC on your own data, use the following command:
```bash
hifibgc run --input input.fastq
```

By default, HiFiBGC outputs to a directory named `hifibgc1.out`, you can specify a custom name using `--output` option as shown below. The count of threads can be specified via `--threads` option (the default is 80).
```bash
hifibgc run --input input.fastq --output outdir --threads 50
```

For all available options, see [Run command help](#run-command-help).


## Output

The output directory structure:

```
hifibgc1.out/
├── 01_assembly/                 # Output from three assemblers
├── 02_mapping_reads_to_merged_assembly/  # Read mapping to concatenated assembly and unmapped read extraction
├── 03_antismash/                # BGC prediction
├── 04_bgc_clustering/           # BGC clustering
├── 05_final_output/             # Primary HiFiBGC output
├── benchmarks/                  # Resource usage and timing information for different components of HiFiBGC
├── config.yaml                  # Configuration file for HiFiBGC run
├── hifibgc.log                  # Snakemake log file
└── logs/                        # Tool-specific log files
```

Among above, the folder `05_final_output` contains primary output of HiFiBGC with below directory structure.

```
05_final_output/                 # Primary HiFiBGC output
├── BGC_all/                     # All BGC .gbk files
├── BGC_all_metadata.tsv         # Metadata for all BGCs
├── BGC_representative/          # Representative BGC .gbk files
└── upsetplot/                   # Upsetplot comparison of results from three assemblers and unmapped reads
```

## Commands

### Main help
```bash
hifibgc --help
```

```
Usage: hifibgc [OPTIONS] COMMAND [ARGS]...

  Detect Biosynthetic Gene Clusters (BGCs) in HiFi metagenomic data. For
  more options, run: hifibgc command --help

Options:
  -v, --version  Show the version and exit.
  -h, --help     Show this message and exit.

Commands:
  run       Run HiFiBGC
  install   Install required database and tool
  test      Test HiFiBGC
  config    Copy the system default config file
  citation  Print the citation(s) for this tool
```


### Run command help
```bash
hifibgc run --help
```

```
Usage: hifibgc run [OPTIONS] [SNAKE_ARGS]...

  Run HiFiBGC

Options:
  --input TEXT                  Input file  [required]
  --output PATH                 Output directory  [default: hifibgc1.out]
  --bigscape_cutoff FLOAT       BiG-SCAPE cutoff parameter  [default: 0.3]
  --configfile TEXT             Custom config file [default:
                                (outputDir)/config.yaml]
  --threads INTEGER             Number of threads to use  [default: 80]
  --use-conda / --no-use-conda  Use conda for Snakemake rules  [default: use-
                                conda]
  --conda-prefix PATH           Custom conda env directory
  --snake-default TEXT          Customise Snakemake runtime args  [default:
                                --rerun-incomplete, --printshellcmds,
                                --nolock, --show-failed-logs]
  -h, --help                    Show this message and exit.
```


For detailed usage of other commands, use `hifibgc <command> --help`.

## Third-party Tools

HiFiBGC utilizes following tools:
- [hifiasm-meta](https://github.com/xfengnefx/hifiasm-meta)
- [metaFlye](https://github.com/mikolmogorov/Flye)
- [HiCanu](https://github.com/marbl/canu)
- [Minimap2](https://github.com/lh3/minimap2)
- [SAMtools](https://github.com/samtools/samtools)
- [antiSMASH](https://github.com/antismash/antismash)
- [BiG-SCAPE](https://github.com/medema-group/BiG-SCAPE)
- [complex-upsetplot](https://github.com/krassowski/complex-upset)
- [Snaketool](https://github.com/beardymcjohnface/Snaketool)
- [Snaketool-utils](https://github.com/beardymcjohnface/Snaketool-utils)

## Citation
Forthcoming.
