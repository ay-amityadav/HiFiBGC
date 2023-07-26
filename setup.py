import os
from setuptools import setup, find_packages


def get_version():
    with open(
        os.path.join(
            os.path.dirname(os.path.realpath(__file__)),
            "hifibgc",
            "hifibgc.VERSION",
        )
    ) as f:
        return f.readline().strip()
    

def get_description():
    with open("README.md", "r") as fh:
        long_description = fh.read()
    return long_description


def get_data_files():
    data_files = [(".", ["README.md"])]
    return data_files


CLASSIFIERS = [
    "Environment :: Console",
    "Environment :: MacOS X",
    "Intended Audience :: Science/Research",
    "License :: OSI Approved :: MIT license",
    "Natural Language :: English",
    "Operating System :: POSIX :: Linux",
    "Operating System :: MacOS :: MacOS X",
    "Programming Language :: Python :: 3.9",
    "Programming Language :: Python :: 3.10",
    "Programming Language :: Python :: 3.11",
    "Topic :: Scientific/Engineering :: Bio-Informatics",
]

setup(
    name="hifibgc",
    packages=find_packages(),
    url="",
    python_requires=">=3.9",
    description="Detect Biosynthetic Gene Clusters (BGCs) in HiFi metagenomic data",
    long_description=get_description(),
    long_description_content_type="text/markdown",
    version=get_version(),
    author="Amit Yadav",
    author_email="ayamitjyoti12@gmail.com",
    data_files=get_data_files(),
    py_modules=["hifibgc"],
    install_requires=[
        "snakemake>=7.14.0",
        "pyyaml>=6.0",
        "Click>=8.1.3",
    ],
    entry_points={
        "console_scripts": [
            "hifibgc=hifibgc.__main__:main"
        ]
    },
    include_package_data=True,
)
