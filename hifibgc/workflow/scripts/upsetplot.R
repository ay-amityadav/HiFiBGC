# Create Upsetplot 
library(ggplot2)
library(ComplexUpset)

args <- commandArgs(trailingOnly = TRUE)

input_file <- args[1]
output_file <- args[2]

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

df <- read.csv(input_file, sep='\t', header=TRUE)

# Rename column names
names(df)[names(df) == "Partial.Complete"] <- "Complete/Partial"

if (ncol(df) == 6) {
    columns <- c('hicanu', 'metaflye', 'hifiasm.meta')
} else {
    columns <- c('hicanu', 'metaflye', 'hifiasm.meta', 'unmapped_reads')
}

# Plot Upsetplot 
pdf(output_file) 
set_size(8, 3)
upset(
    df,
    columns,
    base_annotations=list(
        'Intersection size'=intersection_size(
            counts=TRUE,
            mapping=aes(fill=`Complete/Partial`),
            bar_number_threshold=1.00
        )
    ),
    set_sizes=(
        upset_set_size()
        + theme(axis.ticks.x=element_line())
    ),
    width_ratio=0.360,
 ) + patchwork::plot_layout(heights=c(1.2, 0.5))
dev.off()
