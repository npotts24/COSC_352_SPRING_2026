what this project does: 
scraped the 2025 baltimore city homicide list, parses its main HTML table into a data frame, and cleans its messy data

chosen statistic: 
Victim age distribution

Why is it interesting?:
it shows which ages are the most impacted in the dataset and works well as a histogram

cleaning decisions:
dropped rows with non numeric case numbers
kept ages between 0-120
saved plot as PNG

how to run: 
(in bash)
./run.sh

