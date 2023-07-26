library(ggplot2)
library(ComplexUpset)

args <- commandArgs(trailingOnly = TRUE)

input_file <- args[1]
output_dir <- args[2]
c_parameter <- args[3]

df <- read.csv(input_file, sep='\t', header=TRUE, row.names=1)

df[] = df[] == 1

set_size = function(w, h, factor=1.5) {
    s = 1 * factor
    options(
        repr.plot.width=w * s,
        repr.plot.height=h * s,
        repr.plot.res=100 / factor,
        jupyter.plot_mimetypes='image/png',
        jupyter.plot_scale=1
    )
}

set_size(4, 3)

# Output pdf
output_file = paste(output_dir, "/", "upsetplot_all-classes-combined", "_", c_parameter, ".pdf", sep='')
pdf(output_file) 
upset(df, colnames(df), name='dataset', width_ratio=0.1)
dev.off()

set_size(4, 3)

# Output jpeg
output_file = paste(output_dir, "/", "upsetplot_all-classes-combined", "_", c_parameter, ".jpg", sep='')
jpeg(output_file)
#upset(df, colnames(df), name='dataset', width_ratio=0.1, set_sizes=FALSE)
upset(df, colnames(df), name='dataset', width_ratio=0.4)
dev.off()
