* Project: Price updating with production networks
* Author: Glenn Magerman
* First version: April, 2018.
* This version: February, 2020.
* Stata Version 17

/* Notes
- any remaining errors in product codes from the RAMON files can be adjusted in 
  A. product_mistakes.do.
*/

// change to directory of task
clear all
global folder	"~/Dropbox/work/research/papers/current/_local/PUPN/tasks" 
global task1 	"$folder/task1_concordances"
cd "$task1"

// initialize task (build from inputs)
foreach dir in tmp output {
	cap !rm -rf "`dir'"
}

// create task folders
foreach dir in input src output tmp {
	cap !mkdir -p "`dir'"
}	
	
// code	
	do "src/1. cn8_byyear.do"						// dataset with list of CN8 by year.
	do "src/2. cn8_over_time.do"					// cn8 concordance over time
	do "src/3. pc8_byyear.do"						// datasets with list of CN8 by year.
	do "src/4. pc8_over_time.do"					// pc8 concordance over time
	do "src/5. cn_to_pc.do"							// cn8 to pc8 concordance by year
	
// summary datasets and statistics
	do "src/6. summaries.do"						// codebooks & checks
	do "./src/7. descriptives.do"

// auxiliary do-files (are called within main do-files)
	*A. product_mistakes							// manual cleaning of typos and other 
	*A. unit_labels									// cleaning of verbal descriptions PC8 unit labels
		
// maintenance
cap !rm -rf "tmp"									// Unix
cap !rmdir /q /s "./tmp"							// Windows		

// back to main folder of tasks
cd "$folder"	

clear
