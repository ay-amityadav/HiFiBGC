# HiFiBGC

Detect Biosynthetic Gene Clusters (BGCs) in HiFi metagenomic data.

# Installation

## Conda
```conda create -n hifibgc -c conda-forge -c bioconda -c amityadav -y hifibgc``` <br>
`conda activate hifibgc`

# Usage

## Install 
```hifibgc install``` <br>

Above command need to be run only once. It installs a required database and a tool. 
## Test
```hifibgc test``` <br>

Checks hifibgc on a small test data. On completion of above command, you should see something like `Snakemake finished successfully` on terminal and an output directory `hifibgc1.out`.

## Run
Run hifibgc with defaults: <br>
    `hifibgc run --input input.fastq`  # --input is required <br> <br>
Specify output directory and no of threads: <br>
    `hifibgc run --input input.fastq --output outdir --threads 16`  <br> <br>
Specify bigscape_cutoff option: <br>
    `hifibgc run --input input.fastq --bigscape_cutoff 0.4` <br>

### Output
```
05_final_output/ 
    BGC_all_metadata.tsv  -->  summary file containing metadata for all BGCs 
    BGC_representative/ -->  directory containing representative BGCs (.gbk files) 
    BGC_all/ -->  directory containing all BGCs (.gbk files) 
    upsetplot_0.3.[pdf|jpg] -->  upsetplot comparing three assemblers (hifiasm-meta, metaflye and hicanu), and unmapped reads
```
