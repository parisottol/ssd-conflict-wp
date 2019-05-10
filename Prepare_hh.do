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
*prepare calories and core food only measures
*****************************************************
*NBHS
use "${Raw}/NBHS_FOOD.dta", clear
merge m:1 item using "${Raw}/items_x.dta", assert(match master using) keep(match) keepusing(item_name mod_item itemid calories) nogen
format item_name %32s
keep if mod_item==0
drop if missing(value)
*replace missing prices
bysort itemid: egen price_median_overall=median(uv)
bysort state itemid: egen price_median_state=median(uv)
bysort state cluster itemid: egen price_median_ea=median(uv)
gen price=uv
replace price=price_median_ea if missing(price) & !missing(price_median_ea)
replace price=price_median_state if missing(price) & !missing(price_median_state)
replace price=price_median_overall if missing(price) & !missing(price_median_overall)
*still missing some prices so calculate them manually from value and quantity consumed
egen q=rowtotal( kgq07 kgq09 kgq11 kgq13)
replace q=. if q==0
gen p=value/q if missing(price)
bysort itemid cluster: egen price_median_calculated_ea=median(p) if missing(price)
bysort itemid state: egen price_median_calculated_state=median(p) if missing(price) 
bysort itemid: egen price_median_calculated_overall=median(p) if missing(price) 
replace price=price_median_calculated_ea if missing(price) & !missing(price_median_calculated_ea)
replace price=price_median_calculated_state if missing(price) & !missing(price_median_calculated_state)
replace price=price_median_calculated_overall if missing(price) & !missing(price_median_calculated_overall)
assert !missing(price)
drop price_median* p 
*replace missing quantities
gen miq= missing(kgq07) & missing(kgq09) & missing(kgq11) & missing(kgq13)
gen xq=value/price if miq
replace q=xq if miq
drop miq xq
*replace some item with missing calories
replace calories=3300 if item_name=="Kisra and asida"
replace calories=2000 if item_name=="Chicken"
replace calories=1500 if item_name=="Meat"
replace calories=2000 if item_name=="Fish"
replace calories=450 if item_name=="Traditional beer"
tab item_name if missing(calories)
gen cal_kg=calories*q
gen count=1
save "${Raw}/nbhs_core_food_items.dta", replace
*get aid food 
use "${Raw}/nbhs_core_food_items.dta", clear
gen food_aid=uv*kgq13 if !missing(kgq13) & !missing(uv)
replace food_aid=value if !missing(kgq13) & missing(uv)
*get own prod food
gen food_prod=uv*kgq11 if !missing(kgq11) & !missing(uv)
replace food_aid=value if !missing(kgq11) & missing(uv)
*get own stock food
gen food_stock=uv*kgq09 if !missing(kgq09) & !missing(uv)
replace food_stock=value if !missing(kgq09) & missing(uv)
*collapse by household
collapse (sum) value_fc=value quantity=q calories=cal_kg count food_aid food_prod food_stock, by(state urban cluster hhid)
gen wave=0
rename (cluster hhid) (ea hh)
*deflate upwards to July 2017 - first spatially as in NBHS 2009, then up to 2017
foreach v in value_fc food_aid food_prod food_stock {
	replace `v'=`v'/1.106 if urban==1
	replace `v'=`v'/0.983 if urban==2
	replace `v'=`v' * (1 /72.583)*3355.756
}
save "${Raw}/nbhs_core_food.dta", replace
*HFS
use "${Raw}/hfs_food_withprices.dta", clear
keep if mod_item==0 & cons==1
merge m:1 item using "${Raw}/items_x.dta", assert(match master using) keep(match) keepusing(item_name mod_item itemid calories) nogen
format item_name %32s
*replace some item with missing calories
replace calories=3300 if item_name=="Kisra and asida"
replace calories=2000 if item_name=="Chicken"
replace calories=1500 if item_name=="Meat"
replace calories=2000 if item_name=="Fish"
replace calories=450 if item_name=="Traditional beer"
tab item_name if missing(calories)
gen cal_kg=calories*cons_q_kg
gen count=1
save "${Raw}/hfs_core_food_items.dta", replace
*get aid food 
use "${Raw}/hfs_core_food_items.dta", clear
gen food_aid=cons_value_org if free_yn==1 & inlist(free_main,2,3,4)
gen food_prod=cons_value_org if free_yn==1 & inlist(free_main,1)
collapse (sum) value_fc=cons_value_org quantity=cons_q_kg calories=cal_kg count food_aid food_prod, by(wave state ea hh)
*deflate upwards, first spatially and then up to July 2017
merge 1:1  wave state ea hh using "${Raw}/hhq_analysis.dta", nogen assert(match master using) keep(match) keepusing(food_cons_defl)
foreach v in value_fc food_aid food_prod {
	replace `v'=`v'/ food_cons_defl / (3576.183/3355.756) if wave==4
	replace `v'=`v'/ food_cons_defl / (1779.765/3355.756) if wave==3
	replace `v'=`v'/ food_cons_defl / (517.19/3355.756) if wave==2
	replace `v'=`v'/ food_cons_defl / (239.906/3355.756) if wave==1 
}
drop food_cons_defl
save "${Raw}/hfs_core_food.dta", replace
*Append
use "${Raw}/nbhs_core_food.dta", clear
drop urban
append using "${Raw}/hfs_core_food.dta",
keep if state>10
save "${Raw}/conflict_core_food.dta", replace

*****************************************************
*prepare nonfood consumption
*****************************************************
*NBHS
use "${Raw}/nbhs_nonfood_items.dta", clear
rename (cluster hhid) (ea hh)
keep if mod_opt==0
gen value_nfc=q3 * 7 / item_recall
collapse (sum) value_nfc , by(state ea hh)
*deflate upwards to July 2017 - first spatially as in NBHS 2009, then up to 2017
merge 1:1 state ea hh using "${Raw}/nbhs_core_food.dta", nogen keepusing(urban)
replace value_nfc=value_nfc/1.106 if urban==1
replace value_nfc=value_nfc/0.983 if urban==2
replace value_nfc=value_nfc * 1 /72.583*3355.756
drop urban 
gen wave=0
save "${Raw}/nbhs_core_nonfood.dta", replace
*HFS
use "${Raw}/hfs_nonfood_analysis.dta", clear
keep if mod_item==0
gen nonfood_aid=cons_value if free_yn==1 & inlist(free_main,2,3,4)
collapse (sum) value_nfc=cons_value nonfood_aid, by(wave state ea hh)
*deflate upwards, first spatially and then up to July 2017
merge 1:1  wave state ea hh using "${Raw}/hhq_analysis.dta", nogen keepusing(nonfood_cons_defl food_cons_defl)
gen m=missing(value_nfc) | value_nfc==0
tab wave m
foreach v in value_nfc nonfood_aid {
	replace `v'=`v'/ nonfood_cons_defl / (3576.183/3355.756) if wave==4
	replace `v'=`v'/ nonfood_cons_defl / (1779.765/3355.756) if wave==3
	replace `v'=`v'/ nonfood_cons_defl / (517.19/3355.756) if wave==2
	replace `v'=`v'/ food_cons_defl / (239.906/3355.756) if wave==1 
}
drop *_cons_defl m
save "${Raw}/hfs_core_nonfood.dta", replace
*Append
use "${Raw}/nbhs_core_nonfood.dta", clear
append using "${Raw}/hfs_core_nonfood.dta",
keep if state>10
save "${Raw}/conflict_core_nonfood.dta", replace 

*****************************************************
*prepare data with optional module
*****************************************************
*Assign randomly
use "${Raw}/NBHS_HH.dta", clear
rename (cluster hhid hhweight) (ea hh weight)
keep state ea hh 
gen n=runiform()
bys state ea: egen rank=rank(n)
gen module=1 if inrange(rank,1,3)
replace module=2 if inrange(rank,4,6)
replace module=3 if inrange(rank,7,9)
replace module=4 if inrange(rank,10,12)
drop rank n 
save "${Raw}/NBHS_modules.dta", replace

*FOOOD
*NBHS
use "${Raw}/NBHS_FOOD.dta", clear
merge m:1 item using "${Raw}/items_x.dta", assert(match master using) keep(match) keepusing(item_name mod_item itemid calories) nogen
format item_name %32s
drop if missing(value)
keep state cluster hhid item hhweight value mod_item itemid item_name urban
collapse (sum) value, by(state urban cluster hhid mod_item)
gen wave=0
rename (cluster hhid) (ea hh)
*merge
merge m:1 state ea hh using "${Raw}/NBHS_modules.dta", keep(match) nogen
keep if mod_item==0 | mod_item==module
collapse (sum) value, by(wave state urban ea hh)
*deflate upwards to July 2017 - first spatially as in NBHS 2009, then up to 2017
foreach v in value {
	replace `v'=`v'/1.106 if urban==1
	replace `v'=`v'/0.983 if urban==2
	replace `v'=`v' * (1 /72.583)*3355.756
} 
save "${Raw}/nbhs_food_items_module.dta", replace
*HFS
use "${Raw}/hfs_food_withprices.dta", clear
keep if cons==1
collapse (sum) value=cons_value_org, by(wave state ea hh)
*deflate upwards, first spatially and then up to July 2017
merge 1:1  wave state ea hh using "${Raw}/hhq_analysis.dta", nogen assert(match master using) keep(match) keepusing(food_cons_defl)
foreach v in value {
	replace `v'=`v'/ food_cons_defl / (3576.183/3355.756) if wave==4
	replace `v'=`v'/ food_cons_defl / (1779.765/3355.756) if wave==3
	replace `v'=`v'/ food_cons_defl / (517.19/3355.756) if wave==2
	replace `v'=`v'/ food_cons_defl / (239.906/3355.756) if wave==1 
}
drop food_cons_defl
save "${Raw}/hfs_food_items_module.dta", replace
*Append
use "${Raw}/nbhs_food_items_module.dta", clear
append using "${Raw}/hfs_food_items_module.dta",
keep if state>10
rename value value_f_mod
save "${Raw}/conflict_food_modules.dta", replace

*NONFOOOD
*NBHS
use "${Raw}/nbhs_nonfood_items.dta", clear
rename (cluster hhid) (ea hh)
gen value_nfc=q3 * 7 / item_recall
collapse (sum) value_nfc, by(state ea hh mod_opt)
*merge
merge m:1 state ea hh using "${Raw}/NBHS_modules.dta", keep(match) nogen
keep if mod_opt==0 | mod_opt==module
collapse (sum) value_nfc, by(state ea hh)
*deflate upwards to July 2017 - first spatially as in NBHS 2009, then up to 2017
merge 1:1 state ea hh using "${Raw}/nbhs_core_food.dta", nogen keepusing(urban)
replace value_nfc=value_nfc/1.106 if urban==1
replace value_nfc=value_nfc/0.983 if urban==2
replace value_nfc=value_nfc * 1 /72.583*3355.756
drop urban 
gen wave=0
save "${Raw}/nbhs_nonfood_items_module.dta", replace
*HFS
use "${Raw}/hfs_nonfood_analysis.dta", clear
keep if cons==1
drop if state<10
collapse (sum) value_nfc=cons_value , by(wave state ea hh)
*deflate upwards, first spatially and then up to July 2017
merge 1:1  wave state ea hh using "${Raw}/hhq_analysis.dta", nogen keepusing(nonfood_cons_defl food_cons_defl)
gen m=missing(value_nfc) | value_nfc==0
tab wave m
foreach v in value_nfc  {
	replace `v'=`v'/ nonfood_cons_defl / (3576.183/3355.756) if wave==4
	replace `v'=`v'/ nonfood_cons_defl / (1779.765/3355.756) if wave==3
	replace `v'=`v'/ nonfood_cons_defl / (517.19/3355.756) if wave==2
	replace `v'=`v'/ food_cons_defl / (239.906/3355.756) if wave==1 
}
drop *_cons_defl m
save "${Raw}/hfs_nonfood_items_module.dta", replace
*Append
use "${Raw}/nbhs_nonfood_items_module.dta", clear
append using "${Raw}/hfs_nonfood_items_module.dta",
keep if state>10
rename value_nfc value_nf_mod
save "${Raw}/conflict_nonfood_modules.dta", replace 

*****************************************************
* prepare nbhs 
*****************************************************
*hhq
use "${Raw}/NBHS_HH.dta", clear
egen stratum=group(state urban)
gen pweight=hhweight*hhsize
rename (cluster hhid hhweight) (ea hh weight)
svyset ea [pw=pweight], strata(stratum)
replace urban=0 if urban==2
label define lurban 0 "Rural" 1 "Urban", modify
label val urban lurban
gen wave=0
keep wave urban stratum state ea hh pweight hhsize h1 h2 h3 h5 h7 h8 h9 /*h10*/ i1
numlabel h1 h5 h7 h8 h9 , add
recode i1 (1 2 = 1 "Agriculture") (3 = 2 "Wages") (4=3 "Own business") ( nonmissing = 4 "Remittances/Aid/Other") , gen(livelihood)
label var livelihood "Livelihood"
recode h9 (1 2 = 1 "Latrine") (3 4 = 2 "Flush") (5 6 7 -9 =3 "None")  , gen(toilet)
label var toilet "Toilet"
recode h5 (1 2 3 4 =1 "Borehole") (5=2 "Hand pump") (6 7 8 9 10 11 = 3 "Open water") (12 13 -9 = 4 "Other/purchased"), gen(watersource)
label var watersource "Water source"
recode h7 (1 2 3 9 10 =1 "Eletricity/solar/gas") (4 5 7 8 = 2 "Paraffin/wax") ( 6 11 -9=3  "Firewood/grass/none"), gen(lighting)
label var lighting "Lighting"
recode h8 (1=1 "Firewood") (nonmissing = 2 "Charcoal/other"), gen(cooking)
label var cooking "Cooking"
recode h1 (3 7 = 1 "Mud house") (2 4 9 = 2 "Wood/straw house") (nonmissing=3 "Concrete/other"), gen(dwelling)
label var dwelling "Dwelling"
quietly su h2, detail
replace h2=r(p50) if missing(h2) | h2<0
quietly su h3, detail
replace h3=r(p50) if missing(h3) | h3<0
rename (h2 h3) (total_rooms sleeping_rooms)
label var wave "Wave"
label var pweight "Population weight"
drop i1 h1 h9 h5 h7 h8
order wave stratum urban state ea hh pweight, first
save "${Raw}/NBHS_conflict1.dta", replace
*prepare NBHS 2009 hhm data
*hhm data
use "${Raw}/NBHS_IND.dta", clear
egen stratum=group(state urban)
rename hhweight weight
rename (cluster hhid) (ea hh)
svyset ea [pw=weight], strata(stratum)
rename (b3 b41) (gender age)
replace urban=0 if urban==2
gen wave=0
gen adult=inrange(age,18,120)
gen teenage=inrange(age,13,17)
gen child=inrange(age,0,12)
rename ( c2 c3) ( school_ever school_current)
gen child_noed=(school_current==2 | school_ever==2) if inrange(age,6,14)
gen dependent=inrange(age,0,14) | inrange(age,65,120)
gen working_age=inrange(age,15,64)
recode gender  (1=0 "Male") (2=1 "Female"), gen(sex)
gen working_age_men=sex==0 & working_age
replace head_education=head_education+1
quietly su head_age, detail
replace head_age=r(p50) if missing(head_age)
quietly su head_sex, detail
replace head_sex=r(p50) if missing(head_sex)
gen school=(school_current==1) if age>5
gen worked_7d=d1==1 if d1>0 & !missing(d1)
gen agr_own_7d=inlist(d6,1,2,3,4)  if !missing(d6)
gen agr_own_12m=inlist(d6,1,2,3,4) if !missing(d12)
*create individual level dataset
preserve 
keep state ea hh gender age school worked_7d agr_own_7d agr_own_12m
gen wave=0
save "${Raw}/nbhs_hhm_workschool.dta", replace
restore
*make hh level dataset
collapse (sum) adult teenage child working_age dependent working_age_men (max) head_education head_age head_sex , by(state ea hh)
label var adult "Adults" 
label var teenage "Teenager" 
label var child  "Children" 
label var working_age "Working age" 
label var dependent "Dependents" 
label var working_age_men "Working age, men" 
label var head_education "HH head education" 
label var head_age "HH head age" 
label var head_sex "HH head sex"  
save "${Raw}/nbhs_conflict2.dta", replace
*merge
use "${Raw}/nbhs_conflict1.dta", clear
merge 1:1 state ea hh using "${Raw}/nbhs_conflict2.dta", assert(match) nogen
save "${Raw}/nbhs_conflict3.dta", replace

*****************************************************
* prepare hfs 
*****************************************************
*HHQ
use "${Raw}/hhq_W3.dta", clear
gen wave=3
gen pweight=weight*hhsize
keep wave urban stratum state ea hh pweight hhsize D_1_housingtype D_2_rooms_n D_3_slrooms_n D_9_water_home D_10_drink_source D_15_light D_16_cook D_17_toilet D_46_lhood 
*numlabel, add
recode D_46 (1 2 3 = 1 "Agriculture") (4 = 2 "Wages") (5=3 "Own business") ( else = 4 "Remittances/Aid/Other") , gen(livelihood)
label var livelihood "Livelihood"
recode D_17_toilet (1 2 = 1 "Latrine") (3 4 = 2 "Flush") (5 6 7 =3 "None") (missing=3) , gen(toilet)
label var toilet "Toilet"
recode D_10_drink_source (1 2 3 =1 "Borehole") (4=2 "Hand pump") (5 6 7 8 9 = 3 "Open water") (10 11 = 4 "Other/purchased") (missing=4) , gen(watersource)
label var watersource "Water source"
recode D_15_light (1 2 3 9 10 11 12 =1 "Eletricity/solar/gas") (4 5 8 = 2 "Paraffin/wax") ( 6 7 13 =3  "Firewood/grass/none") (missing=3), gen(lighting)
label var lighting "Lighting"
recode D_16_cook (1=1 "Firewood") (nonmissing = 2 "Charcoal/other"), gen(cooking)
label var cooking "Cooking"
recode D_1_housingtype (4 7 = 1 "Mud house") (3 9 = 2 "Wood/straw house") (else=3 "Concrete/other"), gen(dwelling)
label var dwelling "Dwelling"
quietly su D_2_rooms_n, detail
replace D_2_rooms_n=r(p50) if missing(D_2_rooms_n)
quietly su D_3_slrooms_n, detail
replace D_3_slrooms_n=r(p50) if missing(D_3_slrooms_n)
rename (D_2_rooms_n D_3_slrooms_n) (total_rooms sleeping_rooms)
drop D_*
label var wave "Wave"
label var pweight "Population weight"
order wave stratum urban state ea hh pweight, first
save "${Raw}/hfs_conflict1.dta", replace
*HHM
use "${Raw}/hhm_W3.dta", clear
gen adult=inrange(B_2_age,18,120)
gen teenage=inrange(B_2_age,13,17)
gen child=inrange(B_2_age,0,12)
gen child_noed=(B_26_edu_current==0) if inrange(B_2_age,6,14)
recode edu_level_g (0=.) (5=4), gen(head_education)
replace head_education=. if B_3_ishead==0 
gen head_age=B_2_age if B_3_ishead==1
gen head_sex=B_15_gender if B_3_ishead==1
gen working_age_men=working_age & B_15_gender==1
gen school=(B_26_edu_current==1) if B_2_age>5
gen worked_7d=B_53_empl_active7d if !missing(B_53_empl_active7d)
gen agr_own_7d=inlist(B_57_empl_primary7d_kind,11,12,13,14)  if !missing(B_57_empl_primary7d_kind)
gen agr_own_12m=inlist(B_47_empl_primary12m,5) if !missing(B_47_empl_primary12m)
*create individual level dataset
preserve 
rename (B_15_gender B_2_age) (gender age)
keep state ea hh gender age school worked_7d agr_own_7d agr_own_12m
gen wave=3
save "${Raw}/hfs_hhm_workschool.dta", replace
restore
*make hh level dataset
collapse (sum) adult teenage child working_age dependent working_age_men (max) head_education head_age head_sex , by(state ea hh)
quietly su head_age, detail
replace head_age=r(p50) if missing(head_age)
quietly su head_education, detail
replace head_education=r(p50) if missing(head_education)
label var adult "Adults" 
label var teenage "Teenager" 
label var child  "Children" 
label var working_age "Working age" 
label var dependent "Dependents" 
label var working_age_men "Working age, men" 
label var head_education "HH head education" 
label var head_age "HH head age" 
label var head_sex "HH head sex"  
save "${Raw}/hfs_conflict2.dta", replace
*merge
use "${Raw}/hfs_conflict1.dta", clear
merge 1:1 state ea hh using "${Raw}/hfs_conflict2.dta", assert(match) nogen
save "${Raw}/hfs_conflict3.dta", replace

*****************************************************
* merge final dataset
*****************************************************
use "${Raw}/nbhs_conflict3.dta", clear
append using "${Raw}/hfs_conflict3.dta"
*merge with consumption
merge 1:1 wave state ea hh using "${Raw}/conflict_core_food.dta", nogen assert(match master using) keep(match master)
merge 1:1 wave state ea hh using "${Raw}/conflict_core_nonfood.dta", nogen assert(match master using) keep(match master)
merge 1:1 wave state ea hh using "${Raw}/conflict_nonfood_modules.dta", nogen assert(match master using) keep(match master)
merge 1:1 wave state ea hh using "${Raw}/conflict_food_modules.dta", nogen assert(match master using) keep(match master)
*merge with conflict data
merge 1:1 wave state ea hh using "${Raw}/conflict_indicators_sum.dta", nogen assert(match master using) keep(match master) 
order county payam boma, after(state)
*merge with the price index
decode county, gen(County)
decode payam, gen(Payam)
merge m:1 wave state County Payam using "${Raw}/payam_price_index_core_food.dta", nogen assert(match master using) keep(match master)
drop County Payam
*drop households in greater upper nile
drop if state<80
*drop households with no core food consumption
drop if value_fc==0 | missing(value_fc)
*drop households without conflict events data
drop if missing(events)
*create conflict exposure dummy
gen conflict=events>0
label define lconflict 0 "Control" 1 "Conflict"
label val conflict lconflict
gen post=wave==3
label define lpost 0 "Pre" 1 "Post"
label val post lpost
*redefine stratum
drop stratum
egen stratum=group(state urban)
svyset ea [pw=pweight], strata(stratum) 
decode urban , gen(x)
decode state, gen(y)
gen vl=y+ " - " +x
tab vl
labmask stratum, values(vl)
tab stratum
drop x y vl
*excluding IDPs
merge 1:1 state ea hh using "${Raw}/hhq_W3.dta", nogen assert(match master using) keep(match master) keepusing(A_8_migr_dec13)
gen idp=(A_8_migr_dec13==1)
label define lmigr 0 "Resident" 1 "IDP"
label values idp lmigr
*clean up variables
label define hhh_e 1 "No education" 2 "Primary" 3 "Secondary" 4 "Post-secondary"
label val head_education hhh_e
label define sex 1 "Male" 2 "Female"
label val head_sex sex
gen dep_ratio=dependent/working_age
replace head_sex=head_sex-1
*household size adjustement?
gen ae=1+(.7*(adult-1))+(.5*teenage)+(.3*child)
local a="ae"
*clean calories a bit
gen x=(calories/`a')
replace calories=. if x>100000
gen cal=calories/`a'
label var cal "calories per adult equivalent"
drop x
*check dependent variables
gen q=(quantity/`a')
label var q "quantity in kg per adult equivalent"
gen cf=(value_fc/`a')
label var cf "food consumption per adult equivalent"
gen cnf=(value_nfc/`a')
label var cnf "nonfood consumption per adult equivalent"
egen tot=rowtotal(value_fc value_nfc)
label var cf "food and nonfood consumption, total"
gen ct=(tot/`a')
label var ct "food and nonfood consumption per adult equivalent"
su q cal cf cnf ct
replace cnf=0 if missing(cnf)
/*remove absurb values
replace q=. if q>70
replace cal=. if cal>100000
replace cal=. if cal==0
replace cf=. if cf>15000
replace cnf=. if cnf>15000
replace ct=. if ct>30000
su q cal cf cnf ct
*/
drop if missing(ct)
*prepare dependent variables
gen lq=ln(1+q)
gen lcal=ln(1+cal)
gen lcf=ln(1+cf) 
gen lcnf=ln(1+cnf) 
gen lct=ln(1+ct)
su lq lcal lcf lcnf lct
*Excluding aid
gen f_aid=food_aid/ae
gen nf_aid=nonfood_aid/ae
gen ct_noaid=ct-f_aid
replace ct_noaid=. if ct_noaid<0
su ct_noaid
gen lct_noaid=ln(1+ct_noaid)
*Additional modules
gen f_mod=value_f_mod/ae
gen nf_mod=value_nf_mod/ae
egen ct_mod=rowtotal(f_mod nf_mod)
replace ct_mod=. if ct_mod<=0
gen lct_mod=ln(1+ct_mod)
*define poverty line (use NBHS poverty line)
gen pline=.8*(72.94/4.2)*(1/72.583)*3355.756
gen poor=ct<pline
svy: mean poor, over(wave)
gen gap = (pline - ct)/pline if (!missing(ct)) 
replace gap = 0 if (ct>pline & !missing(ct))
svy: mean gap, over(wave)
gen severity=gap^2
svy: mean severity, over(wave)
*save 
drop pline poor gap severity 
*Create treatment intensity indicators
/*
xtile c=fatalities if events>0, nq(3)
replace c=0 if events==0
*/
gen c=0 if events==0
replace c=1 if inrange(fatalities,0,50) & events>0
replace c=2 if inrange(fatalities,51,3000) & events>0
*replace c=3 if inrange(fatalities,101,3000) & events>0
svy: tab c
tabstat fata , stat(min max) by(c)
*prepare matching weights and other data
quietly tab toilet, gen(toi)
quietly tab watersource, gen(wat)
quietly tab lighting, gen(lig)
quietly tab cooking, gen(coo)
quietly tab dwelling, gen(dwe)
quietly tab head_education, gen(hed)
quietly tab livelihood, gen(liv)
quietly tab state, gen(sta)
*get pscore and weights to match
local matchvars = " hhsize sleeping_rooms head_age head_sex liv1 liv2 liv3 toi1 toi2 toi3 wat1 wat2 wat3 lig1 lig2 coo2 dwe1 dwe2 hed1 hed2 hed3" 
diff lct , t(conflict) p(post) cov(`matchvars') kernel rcs  support logit bw(.02)  report 
pstest `matchvars', t(conflict) graph both graphregion(style(none) color(white)) 
psgraph , t(conflict) p(_ps) supp(_support) graphregion(style(none) color(white))
drop toi1 toi2 toi3 wat1 wat2 wat3 wat4 lig1 lig2 lig3 coo1 coo2 dwe1 dwe2 dwe3 hed1 hed2 hed3 hed4 liv1 liv2 liv3 liv4 sta1 sta2 sta3 sta4 sta5 sta6 sta7
*censor the event that's way too high
*replace events=88 if events==184
save "${Code}/Conflict.dta", replace
