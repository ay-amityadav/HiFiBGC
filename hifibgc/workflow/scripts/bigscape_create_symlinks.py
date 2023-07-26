
# Example run:
# python3 bigscape_create_symlinks.py \
# --input_dir '/home/amityadav/soil_metagenome/pb-metagenomics-tools/HiFi-MAG-Pipeline/antismash-docker_soil-hifi_metaflye/soil-hifi-metaflye' \
# --output_dir /home/amityadav/soil_metagenome/pb-metagenomics-tools/HiFi-MAG-Pipeline/bigscape_multiple_folders \
# --prefix 'soil'

import glob
import os
import subprocess
import argparse

import pandas as pd

parser = argparse.ArgumentParser()

parser.add_argument("--input_dir", type=str, required=True)
parser.add_argument("--output_dir", type=str, required=True)
parser.add_argument("--prefix", type=str, required=True)

args = parser.parse_args()

input_dir = args.input_dir
output_dir = args.output_dir
prefix = args.prefix

input_dir_files = glob.glob(input_dir + '/*region*.gbk')

for file in input_dir_files:
    # get the base name
    file_basename = os.path.basename(file)
    # append prefix to above base name
    file_basename = prefix + '.' + file_basename
    
    # create output directory
    subprocess.run(["mkdir", "-p", output_dir])

    output_file = output_dir + "/" + file_basename

    # create symbolic link
    subprocess.run(["ln", "-rs", file, output_file])
