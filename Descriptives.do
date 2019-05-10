clear all
set more off
set maxvar 10000
set seed 234534543 

*****************************************************
* Define filepaths
*****************************************************
global Code = "C:\Users\WB502620\OneDrive - WBG\South Sudan\Conflict_WP\Code"
global Raw = "C:\Users\WB502620\OneDrive - WBG\South Sudan\Conflict_WP\Code\Data"
global Output = "C:\Users\WB502620\OneDrive - WBG\South Sudan\Conflict_WP\Code/Output"

*****************************************************
* Sample and indicator
*****************************************************
use "${Code}/Conflict.dta", clear


*share of food and nonfood cons
gen share=cf/ct
svy: mean share , over(post)


twoway (kdensity share if post==0 [aw=pweight]) (kdensity share if post==1 [aw=pweight]), ///
	graphregion(style(none) color(white)) legend(label(1 "2009") label(2 "2016")) ///
	xtitle("share of food cons. of total cons.") ytitle("Kernel density")  	

BREAK


twoway (kdensity price_index if conflict==0 [aw=pweight]) (kdensity price_index if conflict==1 [aw=pweight]) if post==0, ///
	graphregion(style(none) color(white)) legend(label(1 "Non-exposed") label(2 "Conflict")) ///
	xtitle("Laspeyres price index") ytitle("Kernel density")  title("2009")
twoway (kdensity price_index if conflict==0 [aw=pweight]) (kdensity price_index if conflict==1 [aw=pweight]) if post==1, ///
	graphregion(style(none) color(white)) legend(label(1 "Non-exposed") label(2 "Conflict")) ///
	xtitle("Laspeyres price index") ytitle("Kernel density")  title("2016-17") 

label var events "Number of conflict events"
quantile events if events>0 , graphregion(style(none) color(white)) ytitle("Number of conflict events")
replace events=88 if events==184
quantile events if events>0 , graphregion(style(none) color(white)) ytitle("Number of conflict events")

quantile fatalit if inrange(fatalities,1,1000), yline(25 100 )  graphregion(style(none) color(white)) ytitle("Number of conflict fatalities")


*define controls
quietly tab toilet, gen(toi)
quietly tab watersource, gen(wat)
quietly tab lighting, gen(lig)
quietly tab cooking, gen(coo)
quietly tab dwelling, gen(dwe)
quietly tab head_education, gen(hed)
quietly tab livelihood, gen(liv)
local potential_controls = "ct cf cnf price_index urban hhsize sleeping_rooms head_age head_sex liv1 liv2 liv3 toi1 toi2 wat1 wat2 wat3 lig1 lig2 coo2 dwe1 dwe2 hed1 hed2 hed3 "
*corr `potential_controls'
svy: mean `potential_controls' if wave==0, 
svy: mean  `potential_controls' if inlist(wave,3), 
tabstat  `potential_controls' if wave==0, stat(min max) col(stat)
tabstat  `potential_controls' if inlist(wave,3), stat(min max) col(stat)
*balance at baseline
svy: mean `potential_controls' if wave==0, over(conflict)
foreach v of varlist `potential_controls' {
	lincom [`v']Conflict-[`v']Control
}
*selection of controls and interactions
local control_check = " urban hhsize sleeping_rooms head_age head_sex liv1 liv2 liv3 toi1 toi2 wat1 wat2 wat3 lig1 lig2 coo2 dwe1 dwe2 hed1 hed2 hed3 "
areg ct `control_check' if wave==0, absorb(county)
foreach v of local control_check {
	areg conflict `v' if wave==0 [pw=pweight], absorb(county)
	testparm `v'
}
*Distribution of consumption graphs
twoway (kdensity ct if post==0 [aw=pweight]) (kdensity ct if post==1 [aw=pweight]) if ct<8000 , graphregion(style(none) color(white)) legend(label(1 "2009") label(2 "2016")) ///
	xtitle("Total core consumption in July 2017 SSP") ytitle("Kernel density") 
cumul ct if post==0 [aw=pweight], gen(c0)
cumul ct if post==1 [aw=pweight], gen(c1)
sort ct
twoway (line c1 ct [aw=pweight]) (line c0 ct [aw=pweight]) if ct<8000, graphregion(style(none) color(white)) legend(label(1 "2009") label(2 "2016")) ///
	xtitle("Total core consumption in July 2017 SSP") ytitle("Cumulative density")
drop c1 c0
*Growth incidence curve
preserve
tempfile 2016
keep wave state ea hh ct pweight 
keep if wave==3
save `2016', replace
restore
preserve 
keep wave state ea hh ct pweight 
gicurve using `2016' [aw=pweight], var1(ct) var2(ct) ci(100) bands(50) legend(label(1 "[Boostrapped 95% CI]") label(2 "Percent decline in consumption")) graphregion(style(none) color(white))
restore
*events per Payam 
hist events if conflict==1, freq graphregion(style(none) color(white)) xtitle("Number of conflict events per Payam")
* descriptives
svy: mean ct , over(post)
di ([ct]Pre - [ct]Post)/[ct]Pre
fastgini ct if post==0 [pw=pweight]
fastgini ct if post==1 [pw=pweight]


