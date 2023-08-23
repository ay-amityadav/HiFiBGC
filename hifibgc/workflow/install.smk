
"""CONFIGURATION"""
configfile: os.path.join(workflow.basedir, "..", "config", "config.yaml")


"""RULES"""
rule all:
    input:
        os.path.join(workflow.basedir, '..', '..', 'antismash'),
        os.path.join(workflow.basedir, '..', '..', 'bigscape')


rule antismash_db_setup:
    output:
        DIR = directory(os.path.join(workflow.basedir, '..', '..', 'antismash')),
    conda:
        "envs/antismash_v7.yml"
    shell:
        """
        download-antismash-databases --database-dir {output.DIR} 
        antismash --version 
        antismash --database {output.DIR} --prepare-data 
        #antismash --check-prereqs 
        """

rule install_bigscape:
    output:
        DIR = directory(os.path.join(workflow.basedir, '..', '..', 'bigscape')),
    conda:
        "envs/bigscape.yml"
    shell:
        """
        mkdir {output.DIR} && cd {output.DIR}
        wget https://github.com/medema-group/BiG-SCAPE/archive/refs/tags/v1.1.5.zip
        unzip -o v1.1.5.zip
        rm v1.1.5.zip

        cd BiG-SCAPE-1.1.5
        wget ftp://ftp.ebi.ac.uk/pub/databases/Pfam/releases/Pfam32.0/Pfam-A.hmm.gz
        gunzip Pfam-A.hmm.gz
        hmmpress Pfam-A.hmm
        """

