
#!/bin/bash

fpath_geno=$1 # plink bfile name
fpath_sinf=$2 # sample information file, e.g., info.txt
fpath_popu_dat=$3 # plink bfile name of 1000 genomes project, e.g., all_hg38_extract_tpm12_indep
fpath_popu_inf=$4 # sample information of 1000 genomes project, e.g., all_hg38.psamp

fname=$(basename $fpath_geno)
data_name=TPMI

# (1) sex check (EMR vs Geno) -- 705
awk '$3=="fail" {print $2,$2}' ${fpath_sinf} > rmInd_sex.txt
plink2 --bfile ${fpath_geno} --remove rmInd_sex.txt --write-samples --out ${fname}_1

# (2) inconsistent EMR records (gender, birth dates) for highly-smiliar genomes (might be the same participants in different hospitals) --307
awk '$4=="fail" {print $2,$2}' ${fpath_sinfo} > rmInd_wrong.txt
plink2 --bfile ${fpath_geno} --keep ${fname}_1.id --remove rmInd_wrong.txt --write-samples --out ${fname}_2

# (3) GCR (0.95) check --19
# (4) homozygosity check (Mean rule) --8123
# plink --bfile ${fpath_geno} --keep ${fname}_2.id --het --missing --out ${fname}_2
plink2 --bfile ${fpath_geno} --keep ${fname}_2.id --het --missing --out ${fname}_2

R CMD BATCH --args --process=2 --imiss_thre=0.05 --het_thre=1 QC.R
plink2 --bfile ${fpath_geno} --keep ${fname}_2.id --remove rmInd_missing_het.txt --write-samples --out ${fname}_3_4

# (5) cryptic relatedness check --111489
awk '$5=="remove" {print $2,$2}' ${fpath_sinfo} > rmInd_rel.txt
plink2 --bfile ${fpath_geno} --keep ${fname}_3_4.id --remove rmInd_rel.txt --write-samples --out ${fname}_5
# R CMD BATCH --args --process=3 QC.R

# (6) divergent ancestry check (# using 1KGP)
plink2 --bfile ${fpath_geno} --set-all-var-ids @:# --rm-dup exclude-all --make-bed --out ${fname}_
plink --bfile ${fname}_ --bmerge ${fpath_popu_dat} --make-bed --out tmp
plink --bfile ${fpath_popu_dat} --exclude tmp-merge.missnp --make-bed --out popu_rm3alleles
plink --bfile ${fname}_ --bmerge popu_rm3alleles --exclude tmp-merge.missnp --maf 0.01 --make-bed --out ${fname}__
plink2 --bfile ${fname}__ \
       --read-freq ${fpath_popu_dat}.acount \
       --score ${fpath_popu_dat}.eigenvec.var 2 4 header-read variance-standardize no-mean-imputation \
       --score-col-nums 5-14 \
       --out ${fname}__projAll
R CMD BATCH --args --process=4 --fname_id_ind=${fname}_5.id --fname_id_rel=${fname}_3_4.id --fname_popu=${fpath_popu_dat} --ancestry_info=${fpath_popu_inf} --data_name=$data_name --confid=0.9999 QC.R

plink2 --bfile ${fpath_geno} --keep ${fname}_5.id --remove rmInd_divAncestry.txt --write-samples --out ${fname}_6ind
plink2 --bfile ${fpath_geno} --keep ${fname}_3_4.id --remove rmInd_divAncestry.txt --write-samples --out ${fname}_6rel

plink2 --bfile ${fpath_geno} --keep ${fname}_6ind.id --make-bed --out ${fname}_qcSampInd
plink2 --bfile ${fpath_geno} --keep ${fname}_6rel.id --make-bed --out ${fname}_qcSampRel
# causion!! when using plink2 to generate bfiles, ${fpath_geno}_qcSampInd had problems on some markers that would have zero MAFs (but ${fpath_geno}_qcSampRel was fine), thus, using plink1.9 to generate bfiles
# chr15 Affx-81719549 etc., over 85000 markers
















