"""
Generates:
    1. a summary file containing metadata associated with all BGCs
    2. a folder containing all BGCs
    3. a folder containing only representative BGCs (as determined by BiG-SCAPE clustering)
"""

import os
import glob
import subprocess
import argparse

from Bio import SeqIO
import pandas as pd

import warnings
warnings.simplefilter(action='ignore', category=FutureWarning)

def parse_antismash_output(antismash_output_directory):
    """
    Input:
        antismash_output_directory: A folder containing .gbk files that correspond to BGCs predicted by AntiSMASH

    Returns: A dataframe where each row represents a BGC, and the columns hold parsed metadata linked to the respective BGC 
    """
    df_bgcs = pd.DataFrame(columns = ["bgc_id", "contig_id", "length", "contig_edge", "bgc_product"])
    
    for gbk_file in glob.iglob(f"{antismash_output_directory}/*region*.gbk"):
        gbk_file_name = gbk_file.split("/")[-1]
        contig_id = '.'.join((gbk_file_name.split("."))[:-2])
        bgc_id = '.'.join((gbk_file_name.split("."))[:-1])
        records = SeqIO.parse(gbk_file, "gb")

        for record in records:
            for feature in record.features:
                qual = feature.qualifiers

                if feature.type == "region":
                    length = int(feature.location.end) - int(feature.location.start)
                    contig_edge = qual["contig_edge"][0]
                    #bgc_category = qual["category"][0]
                    bgc_product = qual["product"][0]

                    bgc = {"bgc_id": bgc_id, "contig_id": contig_id, "length": length, "contig_edge": contig_edge, "bgc_product": bgc_product}
                    df_bgcs = pd.concat([df_bgcs, pd.DataFrame([bgc])], ignore_index=True)

    return df_bgcs    


def assign_representative_bgc(df_bgc_merge_bigscape_clustering: pd.DataFrame) -> pd.DataFrame:        
    """
    Assigns a representative BGC among the BGCs in a BiG-SCAPE cluster
    """

    df_bgc_merge_bigscape_clustering_sorted = df_bgc_merge_bigscape_clustering.sort_values(by=['Family Number', 'length', 'contig_edge'], ascending=[True, False, True], na_position='first') # NA's are put at the top of dataframe

    previous_family_number = -1

    for index, row in df_bgc_merge_bigscape_clustering_sorted.iterrows():
        # If 'Family Number' is NA, assign that BGC as representative. 
        if pd.isna(row['Family Number']):
            df_bgc_merge_bigscape_clustering_sorted.loc[index, 'representative_member'] = True
            continue

        current_family_number = row['Family Number']
        if (current_family_number != previous_family_number):
            df_bgc_merge_bigscape_clustering_sorted.loc[index, 'representative_member'] = True
        else:
            df_bgc_merge_bigscape_clustering_sorted.loc[index, 'representative_member'] = False
        previous_family_number = current_family_number

    return df_bgc_merge_bigscape_clustering_sorted  


def main():
    # Argument parsing
    parser = argparse.ArgumentParser()

    parser.add_argument("--bigscape_input_dir", type=str, required=True)
    parser.add_argument("--bigscape_clustering_file", type=str, required=True)
    parser.add_argument("--final_output_directory", type=str, required=True)

    args = parser.parse_args()

    bigscape_input_dir = args.bigscape_input_dir
    bigscape_clustering_file = args.bigscape_clustering_file
    final_output_directory = args.final_output_directory


    # Parse BGC files
    df_bgc = parse_antismash_output(\
                        antismash_output_directory=f"{bigscape_input_dir}")

    # Read BiG-SCAPE output clustering file
    df_bigscape_clustering = pd.read_csv(f"{bigscape_clustering_file}", sep='\t')
    df_bigscape_clustering.columns = ['BGC Name', 'Family Number']

    # In the following statement, 'how='left' is used because BiG-SCAPE occasionally ignores certain BGCs for clustering. Consequently, the size of 'df_bigscape_clustering' may be smaller than that of 'df_bgc'.
    df_bgc_merge_bigscape_clustering = pd.merge(df_bgc, df_bigscape_clustering, how='left', left_on='bgc_id', right_on='BGC Name') 
    
    df_bgc_merge_bigscape_clustering_sorted = assign_representative_bgc(df_bgc_merge_bigscape_clustering)

    # Drop a duplicate column
    df_bgc_merge_bigscape_clustering_sorted = df_bgc_merge_bigscape_clustering_sorted.drop(['BGC Name'], axis=1)
    # Rename column names
    df_bgc_merge_bigscape_clustering_sorted.columns = ['BGC_Id', 'Contig_Id', 'BGC_Length', 'Contig_Edge', 'BGC_Product', 'Family_Number', 'Representative_Member']
    # Output BGC metadata file
    bgc_all_metadata_file = final_output_directory + "/" + "BGC_all_metadata.tsv"
    df_bgc_merge_bigscape_clustering_sorted.to_csv(bgc_all_metadata_file, sep='\t', index=False)


    # Copy representative BGCs to a folder
    representative_bgc_ids = (df_bgc_merge_bigscape_clustering_sorted[df_bgc_merge_bigscape_clustering_sorted['Representative_Member'] == True])['BGC_Id']
    for gbk_file in glob.iglob(f"{bigscape_input_dir}/*region*.gbk"):
        gbk_file_basename = os.path.basename(gbk_file)
        # remove assembler name prefix and `.gbk` suffix
        gbk_file_basename_stripped = '.'.join(gbk_file_basename.split('.')[1:-1])
        
        for item in representative_bgc_ids:
            if gbk_file_basename_stripped in item:
                gbk_file_bgc_representative_dir = f"{final_output_directory}/BGC_representative/{gbk_file_basename}" 
                subprocess.run(["cp", gbk_file, gbk_file_bgc_representative_dir])

    # Copy all BGCs to a folder
    for gbk_file in glob.iglob(f"{bigscape_input_dir}/*region*.gbk"):
        gbk_file_basename = os.path.basename(gbk_file)
        gbk_file_bgc_all_dir = f"{final_output_directory}/BGC_all/{gbk_file_basename}" 
        subprocess.run(["cp", gbk_file, gbk_file_bgc_all_dir])
    
if __name__ == '__main__':
    main()
