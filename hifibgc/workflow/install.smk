

# """CONFIGURATION"""
# configfile: os.path.join(workflow.basedir, "..", "config", "config.yaml")
# configfile: os.path.join(workflow.basedir, "..", "config", "databases.yaml")

# include: "rules/00_database_preflight.smk"


# """TARGETS"""
# db_files = []

# db_files.append(os.path.join(DBPATH, config['phrogs_mmseqs_folder']))
# db_files.append(os.path.join(DBPATH, config['smg_hmm_file']))
# db_files.append(os.path.join(DBPATH, config['phrog_annot_file']))

#print(workflow.basedir)
#LOGSDIR = '.'

OUTDIR = config['output']
LOGSDIR = os.path.join(OUTDIR, 'logs')

"""RUN SNAKEMAKE"""
rule all:
    input:
        os.path.join(workflow.basedir, '..', '..', 'antismash'),
        os.path.join(workflow.basedir, '..', '..', 'bigscape')


"""RULES"""
#DBPATH = os.path.join(workflow.basedir, '..', '..', 'databases')

# TODO: Examine this rule again, TAKEN from BGCFlow
rule antismash_db_setup:
    output:
        touch(os.path.join(LOGSDIR, "antismash_db_setup.done")),
        DIR = directory(os.path.join(workflow.basedir, '..', '..', 'antismash')),
        #DIR = directory(os.path.join('antismash', 'databases'))
    conda:
        "envs/antismash_bgcflow.yml"
    log:
        os.path.join(LOGSDIR, "antismash_db_setup.log")
    shell:
        """
        download-antismash-databases --database-dir {output.DIR} 2>> {log}
        antismash --version >> {log}
        antismash --check-prereqs >> {log}
        """


# This rule TAKEN and ADAPTED from https://github.com/NBChub/bgcflow/blob/275d699ff9f3ecf8bf27d15e26fb87e261ff4815/workflow/rules/bigscape.smk
rule install_bigscape:
    output:
        touch(os.path.join(LOGSDIR, "install_bigscape.done")), 
        DIR = directory(os.path.join(workflow.basedir, '..', '..', 'bigscape')),
        #DIR = directory('bigscape')
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


# rule phrogs_mmseqs_download:
#     params:
#         url=os.path.join(config['phrogs_mmseqs']),
#         file=os.path.join(DBPATH, config['phrogs_mmseqs_file']),
#         db_path = DBPATH
#     output:
#         directory(os.path.join(DBPATH, config['phrogs_mmseqs_folder']))
#     conda:
#         os.path.join("envs", "curl.yaml")
#     shell:
#         """
#             curl -Lo {params.file} {params.url}
#             tar -xf {params.file} -C {params.db_path}
#             rm -rf {params.file}
#         """

# rule smg_hmm_download:
#     params:
#         url=os.path.join(config['smg_hmm'])
#     output:
#         os.path.join(DBPATH, config['smg_hmm_file'])
#     conda:
#         os.path.join("envs", "curl.yaml")
#     shell:
#         """
#             curl -Lo {output} {params.url}
#         """

# rule phrog_annot_download:
#     params:
#         url=os.path.join(config['phrog_annot'])
#     output:
#         os.path.join(DBPATH, config['phrog_annot_file'])
#     conda:
#         os.path.join("envs", "curl.yaml")
#     shell:
#         """
#             curl -Lo {output} {params.url}
#         """