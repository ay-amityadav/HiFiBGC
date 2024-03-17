# HiFiBGC

HiFiBGC is a tool to detect Biosynthetic Gene Clusters (BGCs) in PacBio HiFi metagenomic data.

# Installation

### Option 1: mamba
```
mamba create -n hifibgc -c conda-forge -c bioconda -c amityadav -y hifibgc

mamba activate hifibgc
```

mamba is preferred over below conda as it takes much lesser time and consumes lesser memory (RAM).<br>
mamba can be installed from [here](https://mamba.readthedocs.io/en/latest/installation/mamba-installation.html).

### Option 2: conda
```
conda create -n hifibgc -c conda-forge -c bioconda -c amityadav -y hifibgc

conda activate hifibgc
```

# Usage

### Install prerequisites
Below command need to be run only once. It installs a required database and a tool.
```
hifibgc install
```
### Run on test data
Test installation of HiFiBGC on a small dataset using below command. 
```
hifibgc test
```

On successful completion of above command, you should see something like `Snakemake finished successfully` on terminal and an output directory `hifibgc1.out`.

### Run on real data
Run HiFiBGC with default options with a required input (.fastq) file:
```
hifibgc run --input input.fastq  
```
Specify output directory and no of threads:
```
hifibgc run --input input.fastq --output outdir --threads 50
```
Specify bigscape_cutoff option:
```
hifibgc run --input input.fastq --bigscape_cutoff 0.3
```

### Output

The output directory from HiFiBGC contains following folders and files.

```
.
└── hifibgc1.out
    ├── 01_assembly --> Output from three assemblers
    ├── 02_mapping_reads_to_merged_assembly --> Read mapping to concatenated assembly and extraction of unmapped reads 
    ├── 03_antismash --> BGC prediction
    ├── 04_bgc_clustering --> BGC clustering
    ├── 05_final_output --> Primary output of HiFiBGC
    ├── benchmarks --> Resource usage and time consumption by different components of HiFiBGC
    ├── config.yaml --> Configuration file for HiFiBGC run
    ├── hifibgc.log --> Snakemake log file
    └── logs --> Logs associated with different tools used in HiFiBGC
```
Among above, the folder `05_final_output` contains primary output of HiFiBGC, specifically following folders and files.

```
├── 05_final_output
│   ├── BGC_all --> Folder containing all BGC .gbk files
│   ├── BGC_all_metadata.tsv --> File containing metadata associated with all BGCs
│   ├── BGC_representative --> Folder containing representative BGC .gbk files
│   ├── upsetplot --> Upsetplot comparison of results from three assemblers and unmapped reads
```
