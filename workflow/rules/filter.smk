rule split_multiallelics:
    """Normalize, left-align, and split mulit-allelics in the HC vcf.
    Splitting multi-allelics means we won't have each row in the vcf
    representing a unique genomic location.  But, this is allowed in
    the vcf spec, and most downstream tools are ok with it.  Plus,
    applying gatk hard filtering occurs via first separating out indels
    and snps.  Multi-type loci don't get split into either category,
    so by splitting the multi-allelics, you can apply the appropriate
    filter to all alt alleles.
    """
    input:
        vcf="results/HaplotypeCaller/genotyped/HC_variants.vcf.gz",
        index="results/HaplotypeCaller/genotyped/HC_variants.vcf.gz.tbi",
        ref="resources/Homo_sapiens_assembly38.fasta",
        fai="resources/Homo_sapiens_assembly38.fasta.fai",
    output:
        vcf=temp("results/HaplotypeCaller/genotyped/HC_variants_split_multiallelics.vcf.gz"),
        index=temp("results/HaplotypeCaller/genotyped/HC_variants_split_multiallelics.vcf.gz.tbi"),
    benchmark:
        "results/performance_benchmarks/split_multiallelics/benchmarks.tsv"
    threads: config["bcftools"]["threads"]
    conda:
        "../envs/bcftools_tabix.yaml"
    shell:
        "bcftools norm "
        "-f {input.ref} "
        "-m - "
        "--threads {threads} "
        "{input.vcf} "
        "-Oz -o {output.vcf} && "
        "tabix -p vcf {output.vcf}"


rule split_snps:
    """
    """
    input:
        vcf="results/HaplotypeCaller/genotyped/HC_variants_split_multiallelics.vcf.gz",
        index="results/HaplotypeCaller/genotyped/HC_variants_split_multiallelics.vcf.gz.tbi",
    output:
        vcf=temp("results/HaplotypeCaller/filtered/snps.all.vcf.gz"),
        index=temp("results/HaplotypeCaller/filtered/snps.all.vcf.gz.tbi"),
    params:
        t=tempDir,
        java_opts=utils.allow_blanks(config["selectVariants"]["java_opts"]),
    benchmark:
        "results/performance_benchmarks/split_snps/benchmarks.tsv"
    conda:
        "../envs/gatk.yaml"
    resources:
        mem_mb=lambda wildcards, attempt: attempt * config["selectVariants"]["memory"],
        xmx=lambda wildcards, attempt: attempt * config["selectVariants"]["xmx"],
    shell:
        'export _JAVA_OPTIONS="" && '
        'gatk --java-options "-Xmx{resources.xmx}m {params.java_opts}" SelectVariants '
        "--tmp-dir {params.t} "
        "-V {input.vcf} "
        "--select-type SNP "
        "-O {output.vcf}"


rule split_indels:
    """
    """
    input:
        vcf="results/HaplotypeCaller/genotyped/HC_variants_split_multiallelics.vcf.gz",
        index="results/HaplotypeCaller/genotyped/HC_variants_split_multiallelics.vcf.gz.tbi",
    output:
        vcf=temp("results/HaplotypeCaller/filtered/indels.all.vcf.gz"),
        index=temp("results/HaplotypeCaller/filtered/indels.all.vcf.gz.tbi"),
    params:
        t=tempDir,
        java_opts=utils.allow_blanks(config["selectVariants"]["java_opts"]),
    benchmark:
        "results/performance_benchmarks/split_indels/benchmarks.tsv"
    conda:
        "../envs/gatk.yaml"
    resources:
        mem_mb=lambda wildcards, attempt: attempt * config["selectVariants"]["memory"],
        xmx=lambda wildcards, attempt: attempt * config["selectVariants"]["xmx"],
    shell:
        'export _JAVA_OPTIONS="" && '
        'gatk --java-options "-Xmx{resources.xmx}m {params.java_opts}" SelectVariants '
        "--tmp-dir {params.t} "
        "-V {input.vcf} "
        "--select-type INDEL "
        "-O {output.vcf}"


rule hard_filter_snps:
    """
    """
    input:
        vcf="results/HaplotypeCaller/filtered/snps.all.vcf.gz",
        index="results/HaplotypeCaller/filtered/snps.all.vcf.gz.tbi",
    output:
        vcf=temp("results/HaplotypeCaller/filtered/snps.hardfiltered.vcf.gz"),
        index=temp("results/HaplotypeCaller/filtered/snps.hardfiltered.vcf.gz.tbi"),
    params:
        t=tempDir,
        java_opts=utils.allow_blanks(config["variantFiltration"]["java_opts"]),
    benchmark:
        "results/performance_benchmarks/hard_filter_snps/benchmarks.tsv"
    conda:
        "../envs/gatk.yaml"
    resources:
        mem_mb=lambda wildcards, attempt: attempt * config["variantFiltration"]["memory"],
        xmx=lambda wildcards, attempt: attempt * config["variantFiltration"]["xmx"],
    shell:
        'export _JAVA_OPTIONS="" && '
        'gatk --java-options "-Xmx{resources.xmx}m {params.java_opts}" VariantFiltration '
        "--tmp-dir {params.t} "
        "-V {input.vcf} "
        '-filter "QD < 2.0" --filter-name "QD2" '
        '-filter "QUAL < 30.0" --filter-name "QUAL30" '
        '-filter "SOR > 3.0" --filter-name "SOR3" '
        '-filter "FS > 60.0" --filter-name "FS60" '
        '-filter "MQ < 40.0" --filter-name "MQ40" '
        '-filter "MQRankSum < -12.5" --filter-name "MQRankSum-12.5" '
        '-filter "ReadPosRankSum < -8.0" --filter-name "ReadPosRankSum-8" '
        "-O {output.vcf}"


rule hard_filter_indels:
    """
    """
    input:
        vcf="results/HaplotypeCaller/filtered/indels.all.vcf.gz",
        index="results/HaplotypeCaller/filtered/indels.all.vcf.gz.tbi",
    output:
        vcf=temp("results/HaplotypeCaller/filtered/indels.hardfiltered.vcf.gz"),
        index=temp("results/HaplotypeCaller/filtered/indels.hardfiltered.vcf.gz.tbi"),
    params:
        t=tempDir,
        java_opts=utils.allow_blanks(config["variantFiltration"]["java_opts"]),
    benchmark:
        "results/performance_benchmarks/hard_filter_indels/benchmarks.tsv"
    conda:
        "../envs/gatk.yaml"
    resources:
        mem_mb=lambda wildcards, attempt: attempt * config["variantFiltration"]["memory"],
        xmx=lambda wildcards, attempt: attempt * config["variantFiltration"]["xmx"],
    shell:
        'export _JAVA_OPTIONS="" && '
        'gatk --java-options "-Xmx{resources.xmx}m {params.java_opts}" VariantFiltration '
        "--tmp-dir {params.t} "
        "-V {input.vcf} "
        '-filter "QD < 2.0" --filter-name "QD2" '
        '-filter "QUAL < 30.0" --filter-name "QUAL30" '
        '-filter "FS > 200.0" --filter-name "FS200" '
        '-filter "ReadPosRankSum < -20.0" --filter-name "ReadPosRankSum-20" '
        "-O {output.vcf}"


# rule recalibrate_calls:
#     """VQSR
#     """
#     input:
#     output:
#     conda: "../envs/gatk.yaml"
#     shell:

if full:

    rule subset_for_contam_check:
        input:
            vcf="results/HaplotypeCaller/filtered/snps.hardfiltered.vcf.gz",
            i="results/HaplotypeCaller/filtered/snps.hardfiltered.vcf.gz.tbi",
        output:
            vcf=temp("results/qc/contamination_check/subset.snps.hardfiltered.vcf.gz"),
            i=temp("results/qc/contamination_check/subset.snps.hardfiltered.vcf.gz.tbi"),
        params:
            region=",".join(config["verifyBamID"]["region"]),
        benchmark:
            "results/performance_benchmarks/subset_for_contam_check/subset.tsv"
        threads: config["bcftools"]["threads"]
        conda:
            "../envs/bcftools_tabix.yaml"
        shell:
            "bcftools view --threads {threads} -r {params.region} -Oz -o {output.vcf} {input.vcf} && "
            "tabix -p vcf {output.vcf}"

    rule contamination_check:
        input:
            vcf="results/qc/contamination_check/subset.snps.hardfiltered.vcf.gz",
            i1="results/qc/contamination_check/subset.snps.hardfiltered.vcf.gz.tbi",
            bam="results/bqsr/{sample}.bam",
            i2="results/bqsr/{sample}.bai",
        output:
            "results/qc/contamination_check/{sample}.selfSM",
            "results/qc/contamination_check/{sample}.selfRG",
            "results/qc/contamination_check/{sample}.log",
            "results/qc/contamination_check/{sample}.depthSM",
            "results/qc/contamination_check/{sample}.depthRG",
            "results/qc/contamination_check/{sample}.bestSM",
            "results/qc/contamination_check/{sample}.bestRG",
        params:
            d="results/qc/contamination_check/{sample}",
        benchmark:
            "results/performance_benchmarks/contamination_check/{sample}.tsv"
        conda:
            "../envs/verifybamid.yaml"
        resources:
            mem_mb=lambda wildcards, attempt: attempt * config["verifyBamID"]["memory"],
        shell:
            "verifyBamID "
            "--best "
            "--vcf {input.vcf} "
            "--bam {input.bam} "
            "--out {params.d}"

    rule summarize_contam_check:
        """This pulls the FREEMIX and depth estimate from the verifyBamID output"""
        input:
            expand("results/qc/contamination_check/{sample}.selfSM", sample=SAMPLES),
        output:
            "results/qc/contamination_check/summary.txt",
        params:
            "results/qc/contamination_check/",
        shell:
            'grep -v "^#" {params}*selfSM  > {output}'


rule merge_calls:
    """
    Opted for bcftools here, just because it's easy to multithread,
    sort, zip, etc. all in one data stream.
    """
    input:
        snps="results/HaplotypeCaller/filtered/snps.hardfiltered.vcf.gz",
        s_index="results/HaplotypeCaller/filtered/snps.hardfiltered.vcf.gz.tbi",
        indels="results/HaplotypeCaller/filtered/indels.hardfiltered.vcf.gz",
        i_index="results/HaplotypeCaller/filtered/indels.hardfiltered.vcf.gz.tbi",
    output:
        vcf="results/HaplotypeCaller/filtered/HC_variants.hardfiltered.vcf.gz",
        index="results/HaplotypeCaller/filtered/HC_variants.hardfiltered.vcf.gz.tbi",
    params:
        t=tempDir,
    benchmark:
        "results/performance_benchmarks/merge_calls/benchmarks.tsv"
    conda:
        "../envs/bcftools_tabix.yaml"
    resources:
        mem_mb=lambda wildcards, attempt: attempt * config["bcftools"]["memory"],
    shell:
        "bcftools concat -a -Ov {input.snps} {input.indels} | "
        "bcftools sort -T {params.t} -Oz -o {output.vcf} && "
        "tabix -p vcf {output.vcf}"


rule picard_metrics:
    """
    """
    input:
        calls="results/HaplotypeCaller/filtered/HC_variants.hardfiltered.vcf.gz",
        index="results/HaplotypeCaller/filtered/HC_variants.hardfiltered.vcf.gz.tbi",
        dbsnp="resources/Homo_sapiens_assembly38.dbsnp138.vcf",
        d="resources/Homo_sapiens_assembly38.dict",
    output:
        "results/HaplotypeCaller/filtered/HC.variant_calling_detail_metrics",
        "results/HaplotypeCaller/filtered/HC.variant_calling_summary_metrics",
    benchmark:
        "results/performance_benchmarks/picard_metrics/benchmarks.tsv"
    params:
        d="results/HaplotypeCaller/filtered/HC",
        t=tempDir,
        java_opts=utils.allow_blanks(config["picardCollectVariantCallingMetrics"]["java_opts"]),
    conda:
        "../envs/gatk.yaml"
    resources:
        mem_mb=(
            lambda wildcards, attempt: attempt
            * config["picardCollectVariantCallingMetrics"]["memory"]
        ),
        xmx=(
            lambda wildcards, attempt: attempt
            * config["picardCollectVariantCallingMetrics"]["xmx"]
        ),
    shell:
        'export _JAVA_OPTIONS="" && '
        'gatk --java-options "-Xmx{resources.xmx}m {params.java_opts}" CollectVariantCallingMetrics '
        "--TMP_DIR {params.t} "
        "-I {input.calls} "
        "--DBSNP {input.dbsnp} "
        "-SD {input.d} "
        "-O {params.d}"
