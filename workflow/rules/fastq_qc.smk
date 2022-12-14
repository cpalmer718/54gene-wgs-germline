localrules:
    symlink_fastqs,


rule symlink_fastqs:
    """Create symbolic links with a different naming scheme.
    FastQC doesn't allow you to change the output file names, so
    this is a way to get the sample and readgroup info into the reports
    and use the filenaming convention followed in the rest of the pipeline.

    Note that we're assuming paired end data throughout.
    """
    input:
        r1=utils.get_read1_fastq,
        r2=utils.get_read2_fastq,
    output:
        r1="results/input/{rg}_r1.fastq.gz",
        r2="results/input/{rg}_r2.fastq.gz",
    benchmark:
        "results/performance_benchmarks/symlink_fastqs/{rg}.tsv"
    shell:
        "ln -s {input.r1} {output.r1} && "
        "ln -s {input.r2} {output.r2}"


rule fastqc:
    """Generate FastQC reports for all input fastqs."""
    input:
        r1="results/input/{rg}_r1.fastq.gz",
        r2="results/input/{rg}_r2.fastq.gz",
    output:
        html1="results/fastqc/{rg}_r1_fastqc.html",
        zip1="results/fastqc/{rg}_r1_fastqc.zip",
        html2="results/fastqc/{rg}_r2_fastqc.html",
        zip2="results/fastqc/{rg}_r2_fastqc.zip",
    benchmark:
        "results/performance_benchmarks/fastqc/{rg}.tsv"
    params:
        t=tempDir,
        o="results/fastqc/",
    threads: config["fastqc"]["threads"]
    conda:
        "../envs/fastqc_multiqc.yaml"
    resources:
        mem_mb=lambda wildcards, attempt: attempt * config["fastqc"]["memory"],
        batch=concurrent_limit,
    shell:
        "fastqc {input.r1} -d {params.t} --quiet -t {threads} --outdir={params.o} && "
        "fastqc {input.r2} -d {params.t} --quiet -t {threads} --outdir={params.o}"


rule quality_trimming:
    """Quality trimming of read ends.
    May want to tweak params; possibly put in config.  Could remove
    adapter sequences here if we want to move that downstream at
    some point.

    Adapter sequences are from Illumina's TruSeq adapters.
    """
    input:
        r1=utils.get_read1_fastq,
        r2=utils.get_read2_fastq,
    output:
        r1_paired=temp("results/paired_trimmed_reads/{rg}_r1.fastq.gz"),
        r2_paired=temp("results/paired_trimmed_reads/{rg}_r2.fastq.gz"),
        h="results/paired_trimmed_reads/{rg}_fastp.html",
        j="results/paired_trimmed_reads/{rg}_fastp.json",
    benchmark:
        "results/performance_benchmarks/quality_trimming/{rg}.tsv"
    threads: config["fastp"]["threads"]
    conda:
        "../envs/fastp.yaml"
    resources:
        mem_mb=lambda wildcards, attempt: attempt * config["fastp"]["memory"],
        batch=concurrent_limit,
        queue=config["compute_queue"],
    shell:
        "fastp -i {input.r1} -I {input.r2} "
        "-w {threads} "
        "-o {output.r1_paired} -O {output.r2_paired} "
        "-h {output.h} -j {output.j} "
        "--adapter_sequence=AGATCGGAAGAGCACACGTCTGAACTCCAGTCA "
        "--adapter_sequence_r2=AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT "
        "-l 36"


use rule fastqc as post_trimming_fastqc with:
    input:
        r1="results/paired_trimmed_reads/{rg}_r1.fastq.gz",
        r2="results/paired_trimmed_reads/{rg}_r2.fastq.gz",
    output:
        html1="results/post_trimming_fastqc/{rg}_r1_fastqc.html",
        zip1="results/post_trimming_fastqc/{rg}_r1_fastqc.zip",
        html2="results/post_trimming_fastqc/{rg}_r2_fastqc.html",
        zip2="results/post_trimming_fastqc/{rg}_r2_fastqc.zip",
    benchmark:
        "results/performance_benchmarks/post_trimming_fastqc/{rg}.tsv"
    params:
        t=tempDir,
        o="results/post_trimming_fastqc/",
