import glob
import os

# Concatenate Snakemake's own log file with the master log file
def copy_log_file():
    files = glob.glob(os.path.join(".snakemake", "log", "*.snakemake.log"))
    if not files:
        return None
    current_log = max(files, key=os.path.getmtime)
    shell("cat " + current_log + " >> " + config['log'])

onsuccess:
    copy_log_file()

onerror:
    copy_log_file()

print(f"workflow.basedir: {workflow.basedir}")

INPUT_FASTQ = config['input']
OUTDIR = config['output']
print(f"input_fastq: {INPUT_FASTQ}")
print(f"output: {config['output']}")
print(f"log: {config['log']}")

# Mark target rules
target_rules = []
def targetRule(fn):
    assert fn.__name__.startswith('__')
    target_rules.append(fn.__name__[2:])
    return fn

@targetRule
rule print_targets:
    run:
        print("\nTop level rules are: \n", file=sys.stderr)
        print("* " + "\n* ".join(target_rules) + "\n\n", file=sys.stderr)

rule seqkit_stats:
    input:
        INPUT_FASTQ
    output:
        os.path.join(OUTDIR, "seqkit_stats.txt"),
    conda:
        "envs/seqkit.yml"
    threads:
        80
    shell:
        """
        seqkit stats {input} -o {output}
        """

@targetRule
rule all:
    input:
        os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_output_parse_plots'),
        # Assembly
        # Antismash
        # BGC Clustering
        # Read mapping
        os.path.join(OUTDIR, '02_mapping_reads_to_merged_assembly', 'reads_mapped_to_merged_assembly_unmapped_seqlength_histogram.svg'),
        os.path.join(OUTDIR, '05_final_output'),


#######################
#   Assembly
########################

# Taken from phables
"""DIRECTORIES/FILES etc.
Declare some directories for pipeline intermediates and outputs.
"""
LOGSDIR = os.path.join(OUTDIR, 'logs')
BENCHMARKS_DIR = os.path.join(OUTDIR, 'benchmarks')


# TODO: add read selection option as done in `assembly.smk`: rule `hifiasm_meta_with_read_selection` 
rule hifiasm_meta: 
    input:
        INPUT_FASTQ
    output: 
        os.path.join(OUTDIR, '01_assembly', 'hifiasm-meta', 'hifiasm_meta.p_contigs.fa'),
        DIR = directory(os.path.join(OUTDIR, '01_assembly', 'hifiasm-meta')),
    conda:
        "envs/hifiasm_meta.yml"
    threads:
        80
    log:
        os.path.join(LOGSDIR, "hifiasm-meta_assembly.log")
    benchmark:
        os.path.join(BENCHMARKS_DIR, "rule_hifiasm_meta.tsv")
    shell:
        """
        mkdir -p {output.DIR}
        cd {output.DIR}
        hifiasm_meta -t {threads} -o hifiasm_meta {input} 2> ./../../../{log}
        # Below command is used when {input} is a relative path (relative to the current working directory)
        #hifiasm_meta -t {threads} -o hifiasm_meta ./../../../{input} 2> ./../../../{log}
        gfatools gfa2fa hifiasm_meta.p_ctg.gfa > hifiasm_meta.p_contigs.fa 2>> ./../../../{log}
        cd -
        """

rule metaflye:
    input: 
        INPUT_FASTQ        
    output:
        os.path.join(OUTDIR, '01_assembly', 'metaflye', 'assembly.fasta'),
        DIR = directory(os.path.join(OUTDIR, '01_assembly', 'metaflye')),
    conda:
        "envs/flye.yml"
    threads:
        80
    log:
        os.path.join(LOGSDIR, "metaflye_assembly.log")
    benchmark:
        os.path.join(BENCHMARKS_DIR, "rule_metaflye.tsv")
    shell:
        """
        flye --pacbio-hifi {input} --out-dir {output.DIR} --threads 80 --meta 2> {log}
        """

rule hicanu:
    input:
        INPUT_FASTQ
    output: 
        os.path.join(OUTDIR, '01_assembly', 'hicanu', 'hicanu.contigs.fasta'),
        DIR = directory(os.path.join(OUTDIR, '01_assembly', 'hicanu'))
    conda:
        "envs/canu.yml"
    threads:
        80
    log:
        os.path.join(LOGSDIR, "hicanu_assembly.log")
    benchmark:
        os.path.join(BENCHMARKS_DIR, "rule_hicanu.tsv")
    shell:
        """
        if canu -d {output.DIR} -p hicanu -pacbio-hifi {input} maxInputCoverage=1000 genomeSize=100m batMemory=200 maxThreads={threads} > {log} 2>&1; then
            echo "Enough data present for assembly and successfully completed."
        else
            echo "Enough data not present for assembly, hence running with tweaked parameters."
            canu -d {output.DIR} -p hicanu -pacbio-hifi {input} maxInputCoverage=1000 genomeSize=100m batMemory=200 minInputCoverage=0.3 stopOnLowCoverage=0.3 maxThreads={threads} > {log} 2>&1
        fi
        """
        # IMP: In above command, I have added parameter `minInputCoverage=0.3` to resolve the issue I was facing due to small size of test data. Relevant issue: https://github.com/marbl/canu/issues/1760. Also, in regard to this only, stopOnLowCoverage=0.3 parameter was added above. 
        # Above parameter settings are taken from "Source: Metagenome assembly of high-fidelity long reads with hifiasm-meta"
        
        # TODO: -p zymo (prefix below) --> probably a variable for it
        # Below parameter settings as recommended in "Source: HiFi metagenomic sequencing enables assembly of accurate and complete genomes from human gut microbiota, 2022"
        #"./canu/canu-2.2/bin/canu -d {output} -p bark -pacbio-hifi {input} " 
        #"genomeSize=3.7M maxInputCoverage=10000 corOutCoverage=10000 corMhapSensitivity=high corMinCoverage=0 >> {log} 2>&1 "
        
        # Below parameter settings are earlier one, as far as I remember 
        #"./assembler/canu-2.1.1/bin/canu -d {output} -p zymo -pacbio-hifi {input} " 
        #"genomeSize=100m maxInputCoverage=1000 batMemory=200 >> {log} 2>&1 "


#####################
#   Unmapped reads
#####################


rule merge_assembly:
    input: 
        hifiasm_meta_assembly = os.path.join(OUTDIR, '01_assembly', 'hifiasm-meta', 'hifiasm_meta.p_contigs.fa'),
        metaflye_assembly = os.path.join(OUTDIR, '01_assembly', 'metaflye', 'assembly.fasta'),
        hicanu_assembly = os.path.join(OUTDIR, '01_assembly', 'hicanu', 'hicanu.contigs.fasta')
    output: 
        os.path.join(OUTDIR, '01_assembly', 'merged_assembly', 'merged_assembly.fasta'),
        DIR = directory(os.path.join(OUTDIR, '01_assembly', 'merged_assembly')),
    shell:
        """
        mkdir -p {output.DIR}
        cat {input.hifiasm_meta_assembly} {input.metaflye_assembly} {input.hicanu_assembly} > {output.DIR}/merged_assembly.fasta
        """

rule map_reads_and_extract_unmapped_reads:
    input: 
        reads = INPUT_FASTQ,
        merged_assembly = os.path.join(OUTDIR, '01_assembly', 'merged_assembly', 'merged_assembly.fasta')
    output:
        os.path.join(OUTDIR, '02_mapping_reads_to_merged_assembly', 'reads_mapped_to_merged_assembly_unmapped.fasta'),
        DIR = directory(os.path.join(OUTDIR, '02_mapping_reads_to_merged_assembly')),
    conda:
        "envs/mapping.yml"
    threads:
        80
    benchmark:
        os.path.join(BENCHMARKS_DIR, "rule_map_reads_and_extract_unmapped_reads.tsv")
    shell:
        """
        # Make directory
        mkdir -p {output.DIR}

        # Map reads to merged assembly
        minimap2 -ax map-hifi -t {threads} {input.merged_assembly} {input.reads} > {output.DIR}/reads_mapped_to_merged_assembly.sam

        # Convert SAM to BAM, and sort the BAM
        samtools view -b --threads {threads} {output.DIR}/reads_mapped_to_merged_assembly.sam | samtools sort --threads {threads} > {output.DIR}/reads_mapped_to_merged_assembly.bam

        # Include (or filter in) only unmapped reads in BAM file 
        samtools view -f 4 -b {output.DIR}/reads_mapped_to_merged_assembly.bam > {output.DIR}/reads_mapped_to_merged_assembly_unmapped.bam

        # Get the unmapped reads in a fasta file
        samtools fasta --threads {threads} {output.DIR}/reads_mapped_to_merged_assembly_unmapped.bam > {output.DIR}/reads_mapped_to_merged_assembly_unmapped.fasta

        # Delete some above intermediate files
        rm {output.DIR}/reads_mapped_to_merged_assembly.sam {output.DIR}/reads_mapped_to_merged_assembly_unmapped.bam
        
        """

rule unmapped_reads_seqlength_histogram:
    input:
        os.path.join(OUTDIR, '02_mapping_reads_to_merged_assembly', 'reads_mapped_to_merged_assembly_unmapped.fasta') 
    output:
        os.path.join(OUTDIR, '02_mapping_reads_to_merged_assembly', 'reads_mapped_to_merged_assembly_unmapped_seqlength_histogram.svg')
    conda:
        "envs/seqkit.yml"
    shell:
        """
        # Histogram of sequence length of unmapped reads
        seqkit watch {input} -O {output}
        """


######################
#   BGC Prediction
######################

rule prepare_input_for_antismash:
    input:
        hifiasm_meta_assembly = os.path.join(OUTDIR, '01_assembly', 'hifiasm-meta', 'hifiasm_meta.p_contigs.fa'),
        metaflye_assembly = os.path.join(OUTDIR, '01_assembly', 'metaflye', 'assembly.fasta'),
        hicanu_assembly = os.path.join(OUTDIR, '01_assembly', 'hicanu', 'hicanu.contigs.fasta'),
        unmapped_reads = os.path.join(OUTDIR, '02_mapping_reads_to_merged_assembly', 'reads_mapped_to_merged_assembly_unmapped.fasta')
    output:
        hifiasm_meta_assembly = os.path.join(OUTDIR, '03_antismash', 'input', 'hifiasm_meta_contigs.fna'),
        metaflye_assembly = os.path.join(OUTDIR, '03_antismash', 'input', 'metaflye_contigs.fna'),
        hicanu_assembly = os.path.join(OUTDIR, '03_antismash', 'input', 'hicanu_contigs.fna'),
        unmapped_reads = os.path.join(OUTDIR, '03_antismash', 'input', 'unmapped_reads.fna')
    log:
        os.path.join(LOGSDIR, "prepare_input_for_antismash.log")
    shell:
        """
        ln -rs {input.hifiasm_meta_assembly} {output.hifiasm_meta_assembly}
        ln -rs {input.metaflye_assembly} {output.metaflye_assembly}
        ln -rs {input.hicanu_assembly} {output.hicanu_assembly}
        ln -rs {input.unmapped_reads} {output.unmapped_reads}
        echo "rule prepare_input_for_antismash finished successfully!"
        """

rule antismash:
    input: 
        antismash_database_dir = os.path.join(workflow.basedir, '..', '..', 'antismash'),
        hifiasm_meta_assembly = os.path.join(OUTDIR, '03_antismash', 'input', 'hifiasm_meta_contigs.fna'),
        metaflye_assembly = os.path.join(OUTDIR, '03_antismash', 'input', 'metaflye_contigs.fna'),
        hicanu_assembly = os.path.join(OUTDIR, '03_antismash', 'input', 'hicanu_contigs.fna'),
        unmapped_reads = os.path.join(OUTDIR, '03_antismash', 'input', 'unmapped_reads.fna'),
    output:
        hifiasm_meta_antismash = directory(os.path.join(OUTDIR, '03_antismash', 'output', 'hifiasm-meta')),
        metaflye_antismash = directory(os.path.join(OUTDIR, '03_antismash', 'output', 'metaflye')),
        hicanu_antismash = directory(os.path.join(OUTDIR, '03_antismash', 'output', 'hicanu')),
        unmapped_reads_antismash = directory(os.path.join(OUTDIR, '03_antismash', 'output', 'unmapped-reads')),
    conda:
        "envs/antismash_v7_bgcflow.yml"
    threads:
        80 
    log:
        os.path.join(LOGSDIR, "antismash.log")
    benchmark:
        os.path.join(BENCHMARKS_DIR, "rule_antismash.tsv")
    shell:
        """
        antismash --genefinding-tool prodigal-m --output-dir {output.hifiasm_meta_antismash} --database {input.antismash_database_dir} --allow-long-headers -c {threads} {input.hifiasm_meta_assembly} --logfile {log} 2>> {log}
        antismash --genefinding-tool prodigal-m --output-dir {output.metaflye_antismash} --database {input.antismash_database_dir} --allow-long-headers -c {threads} {input.metaflye_assembly} --logfile {log} 2>> {log}
        antismash --genefinding-tool prodigal-m --output-dir {output.hicanu_antismash} --database {input.antismash_database_dir} --allow-long-headers -c {threads} {input.hicanu_assembly} --logfile {log} 2>> {log}
        
        if [ ! -s {input.unmapped_reads} ]; then
            echo "File unmapped_reads.fna is empty"
            mkdir -p {output.unmapped_reads_antismash}
        else
            echo "File unmapped_reads.fna is not empty"
            antismash --genefinding-tool prodigal-m --output-dir {output.unmapped_reads_antismash} --database {input.antismash_database_dir} --allow-long-headers -c {threads} {input.unmapped_reads} --logfile {log} 2>> {log}
        fi
        """

# Below command was used for current antismash outputs on various datasets
#sudo ./run_antismash {input} {output} --allow-long-headers --cpus {threads} \
#--output-basename {wildcards.dataset}_{wildcards.assembler} --genefinding-tool prodigal-m
# NOTE: this command runs docker and apparently doesn't obey the --cores argument provided at the commandline, so this needs to be explicitly passed through the commandline here


#####################
#   BGC Clustering
#####################


rule bigscape_prepare_input:
    input:
        hifiasm_meta_antismash = os.path.join(OUTDIR, '03_antismash', 'output', 'hifiasm-meta'),
        metaflye_antismash = os.path.join(OUTDIR, '03_antismash', 'output', 'metaflye'),
        hicanu_antismash = os.path.join(OUTDIR, '03_antismash', 'output', 'hicanu'),
        unmapped_reads_antismash = os.path.join(OUTDIR, '03_antismash', 'output', 'unmapped-reads'),
        WORKFLOW_BASE_DIR = os.path.join(workflow.basedir)
    output:
        directory(os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_input'))
    shell:
        """
        python3 {input.WORKFLOW_BASE_DIR}/scripts/bigscape_create_symlinks.py \
            --input_dir {input.hifiasm_meta_antismash} \
            --output_dir {output} \
            --prefix 'hifiasm-meta'

        python3 {input.WORKFLOW_BASE_DIR}/scripts/bigscape_create_symlinks.py \
            --input_dir {input.metaflye_antismash} \
            --output_dir {output} \
            --prefix 'metaflye'

        python3 {input.WORKFLOW_BASE_DIR}/scripts/bigscape_create_symlinks.py \
            --input_dir {input.hicanu_antismash} \
            --output_dir {output} \
            --prefix 'hicanu'

        # Check if the directory is non-empty
        if [ "$(ls -A {input.unmapped_reads_antismash})" ]; then
            python3 {input.WORKFLOW_BASE_DIR}/scripts/bigscape_create_symlinks.py \
            --input_dir {input.unmapped_reads_antismash} \
            --output_dir {output} \
            --prefix 'unmapped_reads_antismash'
        fi
        """

rule run_bigscape:
    input:
        BIGSCAPE_BIN_DIR = os.path.join(workflow.basedir, '..', '..', 'bigscape'),
        BIGSCAPE_INPUT_DIR = os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_input'),
        #os.path.join(LOGSDIR, "install_bigscape.done"),
    output:
        directory(os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_output'))
    conda:
        "envs/bigscape.yml"
    threads:
        80
    log:
        os.path.join(LOGSDIR, "run_bigscape.log")
    benchmark:
        os.path.join(BENCHMARKS_DIR, "rule_run_bigscape.tsv")
    shell:
        """
        python {input.BIGSCAPE_BIN_DIR}/BiG-SCAPE-1.1.5/bigscape.py -i {input.BIGSCAPE_INPUT_DIR} --cutoffs 0.0001 0.1 0.2 0.3 1.0 \
        --mix --no_classify --include_singletons --hybrids-off --cores {threads} -o {output}
        # python {input.BIGSCAPE_BIN_DIR}/BiG-SCAPE-1.1.5/bigscape.py -i {input.BIGSCAPE_INPUT_DIR} --cutoffs 0.0001 0.1 0.2 0.3 1.0 \
        # --mix --no_classify -o {output}
        # python bigscape/BiG-SCAPE-1.1.5/bigscape.py -i {input.BIGSCAPE_INPUT_DIR} --cutoffs 0.0001 0.1 0.2 0.3 1.0 \
        # --mix --no_classify -o {output}
        """
        
rule parse_bigscape_output:
    input:
        BIGSCAPE_OUTPUT_DIR = os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_output'),
        WORKFLOW_BASE_DIR = os.path.join(workflow.basedir)
    output:
        bigscape_output_dir = directory(os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_output_parse')),
        c0_00 = os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_output_parse', 'df_bgc_family_to_dataset_c0.00.tsv'),
        c0_10 = os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_output_parse', 'df_bgc_family_to_dataset_c0.10.tsv'),
        c0_20 = os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_output_parse', 'df_bgc_family_to_dataset_c0.20.tsv'),
        c0_30 = os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_output_parse', 'df_bgc_family_to_dataset_c0.30.tsv')
    shell:
        """
        for i in {input.BIGSCAPE_OUTPUT_DIR}/network_files/*/mix/mix_clustering_c0.*0.tsv; do
            echo "Processing $i"

            python {input.WORKFLOW_BASE_DIR}/scripts/bigscape_parsing.py \
            --input_clustering_file $i \
            --output_directory {output.bigscape_output_dir}
        done    
        """


rule plot_upsetplot:
    input:
        c0_00 = os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_output_parse', 'df_bgc_family_to_dataset_c0.00.tsv'),
        c0_10 = os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_output_parse', 'df_bgc_family_to_dataset_c0.10.tsv'),
        c0_20 = os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_output_parse', 'df_bgc_family_to_dataset_c0.20.tsv'),
        c0_30 = os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_output_parse', 'df_bgc_family_to_dataset_c0.30.tsv'),
        WORKFLOW_BASE_DIR = os.path.join(workflow.basedir)
    output:
        directory(os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_output_parse_plots'))
    conda:
        "envs/r_complexupset.yml"
    shell:
        """
        mkdir -p {output}

        Rscript {input.WORKFLOW_BASE_DIR}/scripts/upsetplot.R {input.c0_00} {output} c0.00
        Rscript {input.WORKFLOW_BASE_DIR}/scripts/upsetplot.R {input.c0_10} {output} c0.10
        Rscript {input.WORKFLOW_BASE_DIR}/scripts/upsetplot.R {input.c0_20} {output} c0.20
        Rscript {input.WORKFLOW_BASE_DIR}/scripts/upsetplot.R {input.c0_30} {output} c0.30
        """

rule generate_final_outputs:  
    input:
        BIGSCAPE_INPUT_DIR = os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_input'),
        BIGSCAPE_OUTPUT_DIR = os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_output'),
        WORKFLOW_BASE_DIR = os.path.join(workflow.basedir)
    output:
        FINAL_OUTPUT_DIR = directory(os.path.join(OUTDIR, '05_final_output'))
    shell:
        """
        mkdir -p {output.FINAL_OUTPUT_DIR}/BGC_all
        mkdir -p {output.FINAL_OUTPUT_DIR}/BGC_representative

        for i in {input.BIGSCAPE_OUTPUT_DIR}/network_files/*/mix/mix_clustering_c0.30.tsv; do
            echo "Processing $i"

            echo "Now running python script!"
            python {input.WORKFLOW_BASE_DIR}/scripts/generate_final_outputs.py \
            --bigscape_input_dir {input.BIGSCAPE_INPUT_DIR}\
            --bigscape_clustering_file $i \
            --final_output_directory {output.FINAL_OUTPUT_DIR}
        done
        """








