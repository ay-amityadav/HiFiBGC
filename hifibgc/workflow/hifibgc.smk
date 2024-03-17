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


# Config variables
INPUT_FASTQ = config['input']
OUTDIR = config['output']

LOGSDIR = os.path.join(OUTDIR, 'logs')
BENCHMARKS_DIR = os.path.join(OUTDIR, 'benchmarks')


rule all:
    input:
        os.path.join(OUTDIR, '05_final_output', 'upsetplot', f"upsetplot_c{config['bigscape_cutoff']:.2f}.pdf")
    
#######################
#   Assembly
########################

rule hifiasm_meta: 
    input:
        INPUT_FASTQ
    output: 
        os.path.join(OUTDIR, '01_assembly', 'hifiasm-meta', 'hifiasm_meta.p_contigs.fa'),
        DIR = directory(os.path.join(OUTDIR, '01_assembly', 'hifiasm-meta')),
    conda:
        "envs/hifiasm_meta.yml"
    threads:
        workflow.cores
    log:
        os.path.join(LOGSDIR, "rule_hifiasm_meta.log")
    benchmark:
        os.path.join(BENCHMARKS_DIR, "rule_hifiasm_meta.tsv")
    shell:
        """
        mkdir -p {output.DIR}
        cd {output.DIR}
        hifiasm_meta -t {threads} -o hifiasm_meta {input} &> ./../../../{log}
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
        workflow.cores
    log:
        os.path.join(LOGSDIR, "rule_metaflye.log")
    benchmark:
        os.path.join(BENCHMARKS_DIR, "rule_metaflye.tsv")
    shell:
        """
        flye --pacbio-hifi {input} --out-dir {output.DIR} --threads {threads} --meta &> {log}
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
        workflow.cores
    log:
        os.path.join(LOGSDIR, "rule_hicanu.log")
    benchmark:
        os.path.join(BENCHMARKS_DIR, "rule_hicanu.tsv")
    shell:
        """
        if canu -d {output.DIR} -p hicanu -pacbio-hifi {input} maxInputCoverage=1000 genomeSize=100m batMemory=200 maxThreads={threads} &> {log}; then
            echo "Enough data present for assembly and successfully completed."
        else
            echo "Enough data not present for assembly (such as in test_data_sampled.fastq), hence running with tweaked parameters."
            canu -d {output.DIR} -p hicanu -pacbio-hifi {input} maxInputCoverage=1000 genomeSize=100m batMemory=200 minInputCoverage=0.3 stopOnLowCoverage=0.3 maxThreads={threads} &> {log}
        fi
        """
        # IMP: In above command, parameter `minInputCoverage=0.3` is added to resolve the issue occurring due to small size of test data. Relevant issue: https://github.com/marbl/canu/issues/1760. Also, in this regard only, stopOnLowCoverage=0.3 parameter was added above. 
        # Above parameter settings are taken from "Metagenome assembly of high-fidelity long reads with hifiasm-meta, 2022"


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
        workflow.cores
    log:
        os.path.join(LOGSDIR, "rule_map_reads_and_extract_unmapped_reads.log")
    benchmark:
        os.path.join(BENCHMARKS_DIR, "rule_map_reads_and_extract_unmapped_reads.tsv")
    shell:
        """
        # Make directory
        mkdir -p {output.DIR}

        # Map reads to merged assembly
        minimap2 -ax map-hifi -t {threads} {input.merged_assembly} {input.reads} > {output.DIR}/reads_mapped_to_merged_assembly.sam 2> {log}

        # Convert SAM to BAM, and sort the BAM
        samtools view -b --threads {threads} {output.DIR}/reads_mapped_to_merged_assembly.sam | samtools sort --threads {threads} > {output.DIR}/reads_mapped_to_merged_assembly.bam 2>> {log}

        # Include (or filter in) only unmapped reads in BAM file 
        samtools view -f 4 -b {output.DIR}/reads_mapped_to_merged_assembly.bam > {output.DIR}/reads_mapped_to_merged_assembly_unmapped.bam 2>> {log}

        # Get the unmapped reads in a fasta file
        samtools fasta --threads {threads} {output.DIR}/reads_mapped_to_merged_assembly_unmapped.bam > {output.DIR}/reads_mapped_to_merged_assembly_unmapped.fasta 2>> {log}

        # Delete some above intermediate files
        rm {output.DIR}/reads_mapped_to_merged_assembly.sam {output.DIR}/reads_mapped_to_merged_assembly_unmapped.bam
        
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
    shell:
        """
        ln -rs {input.hifiasm_meta_assembly} {output.hifiasm_meta_assembly}
        ln -rs {input.metaflye_assembly} {output.metaflye_assembly}
        ln -rs {input.hicanu_assembly} {output.hicanu_assembly}
        ln -rs {input.unmapped_reads} {output.unmapped_reads}
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
        "envs/antismash_v7.yml"
    threads:
        workflow.cores 
    log:
        os.path.join(LOGSDIR, "rule_antismash.log")
    benchmark:
        os.path.join(BENCHMARKS_DIR, "rule_antismash.tsv")
    shell:
        """
        antismash --genefinding-tool prodigal-m --output-dir {output.hifiasm_meta_antismash} --database {input.antismash_database_dir} --allow-long-headers -c {threads} {input.hifiasm_meta_assembly} --logfile {log} 2>> {log}
        antismash --genefinding-tool prodigal-m --output-dir {output.metaflye_antismash} --database {input.antismash_database_dir} --allow-long-headers -c {threads} {input.metaflye_assembly} --logfile {log} 2>> {log}
        antismash --genefinding-tool prodigal-m --output-dir {output.hicanu_antismash} --database {input.antismash_database_dir} --allow-long-headers -c {threads} {input.hicanu_assembly} --logfile {log} 2>> {log}
        
        if [ ! -s {input.unmapped_reads} ]; then
            echo "File unmapped_reads.fna is empty, hence Antismash can't be run on it"
            mkdir -p {output.unmapped_reads_antismash}
        else
            antismash --genefinding-tool prodigal-m --output-dir {output.unmapped_reads_antismash} --database {input.antismash_database_dir} --allow-long-headers -c {threads} {input.unmapped_reads} --logfile {log} 2>> {log}
        fi
        """


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
        python3 {input.WORKFLOW_BASE_DIR}/scripts/prepare_input_for_bigscape.py \
            --input_dir {input.hifiasm_meta_antismash} \
            --output_dir {output} \
            --prefix 'hifiasm-meta'

        python3 {input.WORKFLOW_BASE_DIR}/scripts/prepare_input_for_bigscape.py \
            --input_dir {input.metaflye_antismash} \
            --output_dir {output} \
            --prefix 'metaflye'

        python3 {input.WORKFLOW_BASE_DIR}/scripts/prepare_input_for_bigscape.py \
            --input_dir {input.hicanu_antismash} \
            --output_dir {output} \
            --prefix 'hicanu'

        # Check if the directory is non-empty
        if [ "$(ls -A {input.unmapped_reads_antismash})" ]; then
            python3 {input.WORKFLOW_BASE_DIR}/scripts/prepare_input_for_bigscape.py \
            --input_dir {input.unmapped_reads_antismash} \
            --output_dir {output} \
            --prefix 'unmapped_reads'
        fi
        """

rule run_bigscape:
    input:
        bigscape_bin_dir = os.path.join(workflow.basedir, '..', '..', 'bigscape'),
        bigscape_input_dir = os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_input'),
    output:
        directory(os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_output'))
    params:
        bigscape_cutoff = config['bigscape_cutoff']
    conda:
        "envs/bigscape.yml"
    threads:
        workflow.cores
    log:
        os.path.join(LOGSDIR, "rule_run_bigscape.log")
    benchmark:
        os.path.join(BENCHMARKS_DIR, "rule_run_bigscape.tsv")
    shell:
        """
        python {input.bigscape_bin_dir}/BiG-SCAPE-1.1.5/bigscape.py -i {input.bigscape_input_dir} --cutoffs {params.bigscape_cutoff} \
        --mix --no_classify --hybrids-off --clans-off --cores {threads} -o {output} &> {log}
        """

#####################
#   Final outputs
#####################

rule report_bgcs_with_metadata:  
    input:
        bigscape_input_dir = os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_input'),
        bigscape_output_dir = os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_output'),
        WORKFLOW_BASE_DIR = os.path.join(workflow.basedir)
    output:
        final_output_dir = directory(os.path.join(OUTDIR, '05_final_output')),
        bgc_all_metadata_file = os.path.join(OUTDIR, '05_final_output', 'BGC_all_metadata.tsv'),
    shell:
        """
        mkdir -p {output.final_output_dir}/BGC_all
        mkdir -p {output.final_output_dir}/BGC_representative

        for i in {input.bigscape_output_dir}/network_files/*/mix/mix_clustering_c*.tsv; do
            python {input.WORKFLOW_BASE_DIR}/scripts/generate_final_outputs.py \
                --bigscape_input_dir {input.bigscape_input_dir}\
                --bigscape_clustering_file $i \
                --final_output_directory {output.final_output_dir}
        done
        """

rule prepare_input_for_upsetplot:
    input:
        bigscape_input_dir = os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_input'),
        bigscape_output_dir = os.path.join(OUTDIR, '04_bgc_clustering', 'bigscape_output'),
        bgc_all_metadata_file = os.path.join(OUTDIR, '05_final_output', 'BGC_all_metadata.tsv'),
        WORKFLOW_BASE_DIR = os.path.join(workflow.basedir)
    output:
        upsetplot_dir = directory(os.path.join(OUTDIR, '05_final_output', 'upsetplot')),
        upsetplot_input_file = os.path.join(OUTDIR, '05_final_output', 'upsetplot', f"df_bgc_family_to_dataset_c{config['bigscape_cutoff']:.2f}.tsv"),
    shell:
        """
        for i in {input.bigscape_output_dir}/network_files/*/mix/mix_clustering_c*.tsv; do
            python {input.WORKFLOW_BASE_DIR}/scripts/prepare_input_for_upsetplot.py \
                --bigscape_input_dir {input.bigscape_input_dir} \
                --bigscape_clustering_file $i \
                --bgc_all_metadata_file {input.bgc_all_metadata_file} \
                --output_directory {output.upsetplot_dir}
        done    
        """

rule plot_upsetplot:
    input:
        upsetplot_input_file = os.path.join(OUTDIR, '05_final_output', 'upsetplot', f"df_bgc_family_to_dataset_c{config['bigscape_cutoff']:.2f}.tsv"),
        WORKFLOW_BASE_DIR = os.path.join(workflow.basedir),
    output:
        os.path.join(OUTDIR, '05_final_output', 'upsetplot', f"upsetplot_c{config['bigscape_cutoff']:.2f}.pdf") 
    params:
        bigscape_cutoff = config['bigscape_cutoff']
    conda:
        "envs/r_complexupset.yml"
    shell:
        """
        Rscript {input.WORKFLOW_BASE_DIR}/scripts/upsetplot.R {input.upsetplot_input_file} {output} 
        """
