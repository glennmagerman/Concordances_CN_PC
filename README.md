# Correspondences of EU Product Classifications
Listings, correspondences and mappings of Prodcom (PC) and Combined Nomenclature (CN) product classifications at the 8-digit numerical level.

## Overview
This set of codes creates lists of numerical product codes by year (CN8 and PC8), their changes over time from t-1 to t, and mappings from CN to PC for the years 2001 up to 2014. 

See concordances_live.pdf in this repo for further information.

## Files for direct use
You can find all correspondences in /output. Final datasets are available in both .dta (Stata 17) and .tsv formats for further use.

## Running the correspondences
1. Pull or copy the repository to a preferred location.
2. Inside /src, open _main.do. Change the absolute path to your location.
3. Run /src/_main.do. This file calls all codes, creates subdirectories as needed, and creates all outputs in /output. 

Raw files are in /input. Codes are in /src. Output is generated in /output. /hand contains a short list of codes that are hard-coded (mappings of aggregated PC8 codes into their disaggregates with awkward mapping descriptions). /checks contains a cross-check with the mappings from Van Beveren et al. (2012), for the years that overlap.

## Remarks

If you have any comments or questions, please let us know: glenn.magerman@ulb.be
Thank you! 

