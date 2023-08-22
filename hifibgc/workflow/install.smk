
"""CONFIGURATION"""
configfile: os.path.join(workflow.basedir, "..", "config", "config.yaml")

OUTDIR = config['output']
LOGSDIR = os.path.join(OUTDIR, 'logs')


"""RULES"""
rule all:
    input:
        os.path.join(workflow.basedir, '..', '..', 'antismash'),
        os.path.join(workflow.basedir, '..', '..', 'bigscape')


rule antismash_db_setup:
    output:
        touch(os.path.join(LOGSDIR, "antismash_db_setup.done")), 
        DIR = directory(os.path.join(workflow.basedir, '..', '..', 'antismash')),
    conda:
        "envs/antismash_v7.yml"
    log:
        os.path.join(LOGSDIR, "antismash_db_setup.log")
    shell:
        """
        download-antismash-databases --database-dir {output.DIR} 2>> {log}
        antismash --version >> {log}
        antismash --database {output.DIR} --prepare-data &>> {log}
        #antismash --check-prereqs >> {log}
        """


# This rule TAKEN and ADAPTED from https://github.com/NBChub/bgcflow/blob/275d699ff9f3ecf8bf27d15e26fb87e261ff4815/workflow/rules/bigscape.smk
rule install_bigscape:
    output:
        touch(os.path.join(LOGSDIR, "install_bigscape.done")), 
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

