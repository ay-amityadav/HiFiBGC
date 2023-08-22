
# Example run:
# python3 bigscape_parsing.py \
# --input_clustering_file bigscape_output_multiple_folders/network_files/2023-03-07_16-13-31_hybrids_glocal/Terpene/Terpene_clustering_c0.30.tsv

import glob
import os
import subprocess
import argparse

from collections import defaultdict
import pprint

import pandas as pd

parser = argparse.ArgumentParser()

parser.add_argument("--input_clustering_file", type=str, required=True)
parser.add_argument("--output_directory", type=str, required=True)

args = parser.parse_args()

input_clustering_file = args.input_clustering_file
output_directory = args.output_directory

clustering = pd.read_csv(input_clustering_file, sep='\t')
clustering.columns = ["BGC Name", "Family Number"]

# Figure out datasets
datasets = set()
for (key, row) in clustering.iterrows():
    bgc_name = row["BGC Name"]
    bgc_name_prefix = (bgc_name.split('.'))[0]
    datasets.add(bgc_name_prefix)
datasets = list(datasets) # datasets = ['hifiasm-meta', 'hicanu', 'metaflye']

df_bgc_family_to_dataset = pd.DataFrame(columns = datasets)

for (key, row) in clustering.iterrows():
    bgc_name = row["BGC Name"]
    family_number = row["Family Number"]
    
    bgc_name_prefix = (bgc_name.split('.'))[0]
    
    # if row index exists
    if family_number in df_bgc_family_to_dataset.index:
        (df_bgc_family_to_dataset.loc[family_number])[bgc_name_prefix] = 1
    else:
        # create a base pandas series
        base_row_dictionary = defaultdict(int)
        for dataset in datasets:
            base_row_dictionary[dataset] = 0
            
        # change the value of appropriate column to 1
        # NOTE: we loose information about count
        base_row_dictionary[bgc_name_prefix] = 1
    
        # append above row, first create a dataframe
        row = pd.DataFrame(base_row_dictionary, index=[family_number])

        df_bgc_family_to_dataset = pd.concat([df_bgc_family_to_dataset, row], ignore_index = False)

    # break    
#print(df_bgc_family_to_dataset)

# Create output directory
if not os.path.exists(output_directory):
    subprocess.run(["mkdir", "-p", output_directory])

# Extract metadata from input clustering file
filename  = os.path.basename(input_clustering_file)
filename_metadata = (filename.split('_'))[-1] 

df_bgc_family_to_dataset.to_csv(f"{output_directory}/df_bgc_family_to_dataset_{filename_metadata}", index=True, sep='\t')
