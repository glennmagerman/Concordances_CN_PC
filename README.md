# Concordances_CN_PC
 Listings, correspondences and mappings of PC and CN product classifications.

## Overview
This set of programs creates lists of numerical product codes by year (CN8 and PC8), their changes over time from t-1 to t, and mappings from CN to PC. 

The method differs from similar methods such as Pierce and Schott (2012) in the following dimensions:

(i) we do not impose family trees of products to track the same products over the whole panel. We keep track of m:1, 1:m and m:m mappings individually. However, the final datasets still allow to collapse to synthetic product trees as in those methods.

(ii) we provide information on units of quantity reporting in CN, PC and CN to PC. This is crucial in obtaining correct unit values.

## Running the correspondences
To obtain the lists and correspondences, copy the folder, set the correct absolute folder path for your system and run notebooks > master.do. This creates all the necessary output. Raw datasets are in "raw", which might need to be unzipped first. Final datasets are available in "clean", in both .dta (Stata) and .csv formats for further use.

The file summary_datasets.xlsx contains summary statistics of the clean datasets for reference.

## Remarks
If you use any of these listings, correspondences or mappings, please cite Duprez and Magerman (2020).

If you have any comments, please let us know: glenn.magerman@ulb.ac.be

