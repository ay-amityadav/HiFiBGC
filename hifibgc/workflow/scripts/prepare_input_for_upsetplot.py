"""
Prepares input file for plotting upsetplot using complexupset package  
"""

import os
from pathlib import Path
import subprocess
import argparse
import glob
from collections import defaultdict

import pandas as pd

def add_bgc_info_to_upsetplot_dataframe(df_bgc_family_to_dataset: pd.DataFrame, bgc_name, family_number, datasets: list = ['hifiasm-meta', 'metaflye', 'hicanu', 'unmapped_reads']) -> pd.DataFrame:
    """
    Add/Insert BGC info(0/1) to df_bgc_family_to_dataset dataframe depending on the dataset a BGC belongs to.
    """         
    bgc_name_prefix = (bgc_name.split('.'))[0]
    
    if family_number in df_bgc_family_to_dataset.index:
        (df_bgc_family_to_dataset.loc[family_number])[bgc_name_prefix] = 1
    else:
        base_row_dictionary = defaultdict(int)
        for dataset in datasets:
            base_row_dictionary[dataset] = 0
            
        # change the value of appropriate column to 1, NOTE: we are interested in presence/absence only, not the count
        base_row_dictionary[bgc_name_prefix] = 1
    
        # append above row, first create a dataframe
        row = pd.DataFrame(base_row_dictionary, index=[family_number])
        df_bgc_family_to_dataset = pd.concat([df_bgc_family_to_dataset, row], ignore_index = False)
   
    return df_bgc_family_to_dataset

def main():
    parser = argparse.ArgumentParser()

    parser.add_argument("--bigscape_input_dir", type=str, required=True)
    parser.add_argument("--bigscape_clustering_file", type=str, required=True)
    parser.add_argument("--bgc_all_metadata_file", type=str, required=True)
    parser.add_argument("--output_directory", type=str, required=True)

    args = parser.parse_args()

    bigscape_input_dir = args.bigscape_input_dir
    bigscape_clustering_file = args.bigscape_clustering_file
    bgc_all_metadata_file = args.bgc_all_metadata_file
    output_directory = args.output_directory

    clustering = pd.read_csv(bigscape_clustering_file, sep='\t')
    clustering.columns = ["BGC Name", "Family Number"]

    # Figure out datasets and store bigscapes's output bgc 
    bigscape_bgc_names = set()
    datasets = set()
    for (key, row) in clustering.iterrows():
        bgc_name = row["BGC Name"]
        bigscape_bgc_names.add(bgc_name)
        bgc_name_prefix = (bgc_name.split('.'))[0]
        datasets.add(bgc_name_prefix)
    datasets = list(datasets) # datasets = ['hifiasm-meta', 'metaflye', 'hicanu', 'unmapped_reads]

    # Create a dataframe where a row corresponds to a BiG-SCAPE family and columns correspond to whether a BiG-SCAPE family contains atleast one BGC from the respective dataset category.   
    df_bgc_family_to_dataset = pd.DataFrame(columns = datasets)
    for (key, row) in clustering.iterrows():
        bgc_name = row["BGC Name"]
        family_number = row["Family Number"]
        
        df_bgc_family_to_dataset = add_bgc_info_to_upsetplot_dataframe(df_bgc_family_to_dataset, bgc_name, family_number, datasets)

    # Get BGCs ignored by BiG-SCAPE and add them to above `df_bgc_family_to_dataset` dataframe 
    bgcs_ignored_by_bigscape = []
    for bigscape_input_file_name in sorted(glob.glob(f"{bigscape_input_dir}/*.gbk")):
        bigscape_input_file_name_stem = Path(bigscape_input_file_name).stem
        if bigscape_input_file_name_stem not in bigscape_bgc_names:
            bgcs_ignored_by_bigscape.append(bigscape_input_file_name_stem)

    for bgc_name in bgcs_ignored_by_bigscape:
        df_bgc_family_to_dataset = add_bgc_info_to_upsetplot_dataframe(df_bgc_family_to_dataset, bgc_name, bgc_name, datasets)

    df_bgc_family_to_dataset['Family_Number'] = df_bgc_family_to_dataset.index

    df_bgc_all_metadata = pd.read_csv(bgc_all_metadata_file, sep='\t')
    df_bgc_all_metadata_representative = df_bgc_all_metadata[df_bgc_all_metadata['Representative_Member'] == True] # Select representative BGCs 
    df_bgc_all_metadata_representative = df_bgc_all_metadata_representative[['BGC_Id', 'Family_Number', 'Contig_Edge']]

    # For BGCs with Family_Number=NA, set Family_Number to BGC_Id; this is done for merging dataframes in below section
    for (index, row) in df_bgc_all_metadata_representative.iterrows():
        if not pd.isna(row['Family_Number']):
            break
        df_bgc_all_metadata_representative.loc[index, 'Family_Number'] = df_bgc_all_metadata_representative.loc[index, 'BGC_Id']

    assert (df_bgc_family_to_dataset.shape)[0] == (df_bgc_all_metadata_representative.shape)[0]
    df_bgc_family_to_dataset = pd.merge(df_bgc_family_to_dataset, df_bgc_all_metadata_representative, on='Family_Number', how='outer') 
    assert (df_bgc_family_to_dataset.shape)[0] == (df_bgc_all_metadata_representative.shape)[0]

    # Replace values for later plotting with complexupset package
    df_bgc_family_to_dataset.replace([0, 1], ['FALSE', 'TRUE'], inplace=True)
    df_bgc_family_to_dataset.replace([True, False], ['Partial', 'Complete'], inplace=True)

    # Rename column names
    df_bgc_family_to_dataset.rename(columns = {'Contig_Edge':'Partial/Complete'}, inplace = True)

    # Subset columns
    if 'unmapped_reads' in df_bgc_family_to_dataset.columns:
        df_bgc_family_to_dataset = df_bgc_family_to_dataset[["Family_Number", "hicanu", "metaflye", "hifiasm-meta", "unmapped_reads", "Partial/Complete"]]    
    else:
        df_bgc_family_to_dataset = df_bgc_family_to_dataset[["Family_Number", "hicanu", "metaflye", "hifiasm-meta", "Partial/Complete"]]

    # Create output directory
    if not os.path.exists(output_directory):
        subprocess.run(["mkdir", "-p", output_directory])

    # Extract metadata from input clustering file
    filename = os.path.basename(bigscape_clustering_file)
    filename_metadata = (filename.split('_'))[-1] 

    df_bgc_family_to_dataset.to_csv(f"{output_directory}/df_bgc_family_to_dataset_{filename_metadata}", index=True, sep='\t')

if __name__ == '__main__':
    main()