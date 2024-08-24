title; footnote; libname _all_; filename _all_;
proc datasets library=work memtype=data kill; quit; run;
/****************************************************************************************
* PROJECT       	: ZICS
* SPONSOR/PI    	: Don Thea
* PROGRAM NAME  	: ZICS_SIDS_RP.sas
* LOCATION			: \\Dept\ZICS\09SAS_Programs\06Analysis\Secondary_Analyses\20240522_SIDS
* DESCRIPTION   	: program the descriptive table for SIDS
* SPEC NAME			: Specifications_SIDS_Paper_20240620
* SPEC LOC			: \\Dept\ZICS\09SAS_Programs\06Analysis\Secondary_Analyses\20240522_SIDS
* PROGRAMMER    	: Janaki Shah
* DATE WRITTEN  	: 2024.06.21
* GENERAL NOTES		: 
****************************************************************************************
* DATA IN			: 
* DATA OUT			: 
* REPORTS OUT		: 
***************************************************************************************/

/*%macro c; dm 'odsresults; clear'; dm 'log; clear'; %mend;*/
option symbolgen mprint mlogic EXTENDOBSCOUNTER=NO nofmterr;
%let rundate = %sysfunc(today(),yymmddn8.); *ex. 20200923;
%let tdate = %sysfunc(today(),mmddyy10.); *ex. 09/23/2020;
%let pgmname = %sysget(SAS_ExecFilePath) %sysfunc(getoption(sysin));
footnote3 j=l height=7pt  "&pgmname";
option mergenoby = error;
ods escapechar="^";

/**************************************/
/*		Libnames / Filenames    	  */
/**************************************/
libname zics "\\ad.bu.edu\bumcfiles\SPH\DCC\Dept\ZICS\08Data\01Raw_Data";
libname archive "\\ad.bu.edu\bumcfiles\SPH\DCC\Dept\ZICS\08Data\01Raw_Data\Archive"; 
libname an "\\ad.bu.edu\bumcfiles\SPH\DCC\Dept\ZICS\08Data\03Analytic_Data"; 
libname formats "\\ad.bu.edu\bumcfiles\SPH\DCC\Dept\ZICS\09SAS_Programs\01Dataset_Creation\Formats"; 


**Create a fileref that points to location of your macros;
filename dmmacs "\\ad.bu.edu\bumcfiles\SPH\DCC\Dept\BEDAC_Applications\SAS\01Instrument_Library\01Data_Management_Macros";
filename dvmacs "\\ad.bu.edu\bumcfiles\SPH\DCC\Dept\BEDAC_Applications\SAS\01Instrument_Library\02Derived_Variable_Macros";
filename anmacs "\\ad.bu.edu\bumcfiles\SPH\DCC\Dept\BEDAC_Applications\SAS\01Instrument_Library\03Analytic_Macros";

options mprint mautosource mrecall sasautos=(sasautos dmmacs dvmacs anmacs);

options fmtsearch = (formats.formats formats.outcomes);
/**************************************/
/*				FORMATS			   	  */
/**************************************/

/*create a format depending on gestational week*/
proc format;
	value gestweek 1="Preterm (28-<34 weeks)"
					 2="Late Preterm (34< 37 weeks)"
	   				 3="Term(37 completed weeks)";
	
run;
/**************************************/
/*				MACROS			   	  */
/**************************************/

/**************************************/
/*		   DATA MANIPULATION		  */
/**************************************/

/*read in zics dataset for live births*/
data zics_wstill;
	set an.ZICS_DSET_WSTILL_MULTI_AN; 
	where livbrth = 1;
run; 

/*proc contents data=an.ZICS_DSET_WSTILL_MULTI_AN; run; */

/*read in dataset for sleeping position*/
data sleepq;
	set ZICS.SLEEPQ;
	where position ne .;
run;

proc sort data=zics_wstill; by INFANTID; run; 
proc sort data=sleepq; by INFANTID; run; 


/*merge both datasets for preparing a final dataset to analyze*/
data merged;
	merge zics_wstill sleepq(in=s);
	by INFANTID; 
	if s ;
run; 


/*proc contents data=merged varnum;run; */

data tab1a;
	set merged;
	keep studyid  agecat  mar_stat tob_preg HIV_INF ed_mob age_yrs tobacco alc_pg;
run;

proc sort data=tab1a out=table1a nodupkey; by studyid agecat mar_stat tob_preg HIV_INF ed_mob age_yrs tobacco alc_pg;  run; 
/*proc print data=table1a varnum;run; */


/**************************************************************/
/*confirming that there is 1 row per STUDYID in the dataset TABLE1A */

/*proc freq data=table1a; */
/*	tables studyid; */
/*	ods output OneWayFreqs = table1a_check; */
/*run; */

/*proc freq data=table1a_check; */
/*	title "QC: # of times each ID  appears in the dataset - this should be 1 for everyone"; */
/*	tables frequency; */
/*run; title; */

/*proc print data=table1a_check; */
/*	title "This tells you which IDs appear >1x in the dataset";*/
/*	title2 "You can then print those IDs in the dataset TABLE1B to see if you can figure out what is going on";*/
/*	where frequency gt 1; */
/*run; title; */
/*******************************************************************/
 
/*adding breastfeeding variables from AN.ZICS_POSTNATAL_AN dataset*/
data ZICS_POSTNATAL (keep=  infantid redcap_event_name EXCLUSIVE_BF_DV ANY_BF_DV vac_bf_dv vac_bf_dv5) ;
	set AN.ZICS_POSTNATAL_AN ;
run;



proc freq data=ZICS_POSTNATAL   ; tables EXCLUSIVE_BF_DV ANY_BF_DV vac_bf_dv vac_bf_dv5; run;

/*using proc sort to	Keep only 1 row per INFANTID*/
proc sort data=ZICS_POSTNATAL out=ZICS_POSTNATAL_AN nodupkey; by infantid  EXCLUSIVE_BF_DV ANY_BF_DV  ;  run; 

/*adding birth anomalies variables from labor dataset*/
data LABOR  (keep=  INFANTID BRTHANOM BRTHANOMSP  ) ;
	set ZICS.LABOR;
run;

/*merging these two dataset to join with table2 dataset*/
data merged1a; 
	merge zics_postnatal_an (in=p) labor (in=L); 
	by infantid; 
	if p and L;
run;

data tab1b;
	set merged ;
	if prem_delivery=1 or prem_delivery=2 then Gestational_week=1;
	else if prem_delivery=3  then Gestational_week=2;
	else if prem_delivery=4  then Gestational_week=3;
	keep studyid infantid SEX BW BWCAT BWCAT3 PREM_DELIVERY PREM_DELIVERY37 PREM_DELIVERY34 
	     HIV_INF TWIN  Gestational_week;
	format Gestational_week gestweek.;
run;

proc sort data=tab1b; by  infantid; run;
proc sort data= merged1a; by  infantid; run;

/*merging to add the birthanomalies and breastfeeding variables to table1*/
data both
	(keep= studyid infantid SEX BW BWCAT BWCAT3 PREM_DELIVERY PREM_DELIVERY37 PREM_DELIVERY34 
	     HIV_INF TWIN  Gestational_week EXCLUSIVE_BF_DV ANY_BF_DV BRTHANOM BRTHANOMSP vac_bf_dv vac_bf_dv5);
	merge tab1b (in=t) merged1a;
	by infantid;
	if t;
run;


data tab1bs;
	set both;
/*	remove the ID that was not in the ZICS_WSTILL dataset*/
	if sex = . and bw = . and bwcat = . and  BWCAT3= .  and PREM_DELIVERY= . and PREM_DELIVERY37= . and
		PREM_DELIVERY34= . and  Gestational_week= . then delete; 
run;

/*checking for duplicates*/
proc sort data=tab1bs out=table1b nodupkey; 
	by studyid infantid SEX BW BWCAT BWCAT3 PREM_DELIVERY PREM_DELIVERY37 PREM_DELIVERY34 HIV_INF TWIN  Gestational_week 
        EXCLUSIVE_BF_DV ANY_BF_DV BRTHANOM BRTHANOMSP  ;  run; 



proc freq data=table1b; 
	title "QC"; 
	tables prem_delivery*gestational_week / list missing; 
run; title;
 
proc freq data=table1b; 
	title "QC"; 
	tables BRTHANOM  / list missing; 
run; title; 

/*JS 2024.06.28 for Infantid 2898.1 there is missing data and it is the same for all the variables (removed in the datastep above)*/
proc freq data=table1b; 
	tables SEX BW BWCAT BWCAT3 PREM_DELIVERY PREM_DELIVERY37 PREM_DELIVERY34 prem_delivery Gestational_week ;
	format PREM_DELIVERY;
run;

proc contents data=table1b varnum;run; 


/*******************************************************************/
	
/*proc freq data=table1b; */
/*	tables infantid; */
/*	ods output OneWayFreqs = table1b_check; */
/*run; */

/*proc freq data=table1b_check; */
/*	title "QC: # of times each ID  appears in the dataset - this should be 1 for everyone"; */
/*	tables frequency; */
/*run; title; */
/**/
/*proc print data=table1b_check; */
/*	title "This tells you which IDs appear >1x in the dataset";*/
/*	title2 "You can then print those IDs in the dataset TABLE1B to see if you can figure out what is going on";*/
/*	where frequency gt 1; */
/*run; title; */
/*******************************************************************/

data zics_postnatal_dv;
	set an.zics_postnatal_dv;
run;

data hivinf; 
	set merged; 
	keep infantid hiv_inf  REDCAP_EVENT_NAME ; 
run;

/*proc contents data= sleepq varnum; run;*/
/*proc contents data= an.zics_postnatal_dv varnum; run;*/
/*proc contents data=an.zics_postnatal_an; run; */


proc sql;
	create table tabs2 as
	  select   a.infantid , a.POSITION, a.WHERESLEEP, a.OUTFIT, a.REDCAP_EVENT_NAME,b.studyid, b.AGEDAYS_DV, c.hiv_inf
	  from sleepq as a
	  left join zics_postnatal_dv as b 
	  on a.infantid = b.infantid 
	  and  a.REDCAP_EVENT_NAME = b.REDCAP_EVENT_NAME
	  left join  hivinf as c	on
	  a.infantid = c.infantid   and  a.REDCAP_EVENT_NAME = c.REDCAP_EVENT_NAME;
quit;

/*proc print data=table2;run;*/

proc sort data=tabs2 out=table2 nodupkey; 
	by infantid POSITION WHERESLEEP OUTFIT REDCAP_EVENT_NAME studyid AGEDAYS_DV hiv_inf;
run;

proc freq data=table2; tables infantid/ list missing; run;

data table2e;
	set table2;
	if infantid = 2011.1 and redcap_event_name = 'w24_arm_1' then delete; 
	if infantid = 1868.1 and redcap_event_name = 'w24_arm_1' then delete;
	if infantid = 2145.1 and redcap_event_name = 'w24_arm_1' then delete;
run;

proc freq data=table2e; tables infantid/ list missing; run;



data vac (keep=  infantid redcap_event_name  vac_bf_dv vac_bf_dv5) ;
	set AN.ZICS_POSTNATAL_AN ;
run;

proc sort data=vac; by infantid redcap_event_name; run;
proc sort data=table2e; by infantid redcap_event_name; run;


data xx; 
	merge table2e (in=t) vac (in=v); 
	by infantid redcap_event_name ;
	if t; 
run; 
/*******************************************************************/
/*proc freq data=table2e; */
/*	tables infantid; */
/*	ods output OneWayFreqs = tabs2_check; */
/*run; */
/**/
/*proc freq data=tabs2_check; */
/*	title "QC: # of times each ID  appears in the dataset - this should be 1 for everyone"; */
/*	tables frequency; */
/*run; title; */

/*proc print data=tabs2_check; */
/*	title "This tells you which IDs appear >1x in the dataset";*/
/*	title2 "You can then print those IDs in the dataset TABLE1B to see if you can figure out what is going on";*/
/*	where frequency gt 1; */
/*run; title; */
/*******************************************************************/

/*proc contents data=table2e varnum;run; */

/*proc freq data=table2; tables POSITION WHERESLEEP OUTFIT;*/
/*run;*/
/**************************************/
/*		   PERMANENT DATASET		  */
/**************************************/


/**************************************/
/*		 STATISTICAL PROCEDURES		  */
/**************************************/

/*reorder variables to match specifications*/
proc sql; 
	create table table1aa as select age_yrs, agecat, mar_stat, ed_mob,  tobacco, alc_pg, HIV_INF , studyid  from table1a; 
quit;


/*LSF 2024.07.03 - you have to add TWIN to this statement*/
proc sql; 
	create table table1bb as select  SEX, BWCAT3,  Gestational_week, EXCLUSIVE_BF_DV, ANY_BF_DV, BRTHANOM,  TWIN, vac_bf_dv, vac_bf_dv5,  HIV_INF , studyid, infantid 
	from table1b; 
quit;

proc sql; 
	create table tablee2 as select AGEDAYS_DV, POSITION, WHERESLEEP, OUTFIT, studyid, hiv_inf, infantid , REDCAP_EVENT_NAME from table2e; 
quit;


%table1(data=table1aa,byvar= HIV_INF,outtype=rtf,
outfile=\\Dept\ZICS\09SAS_Programs\06Analysis\Secondary_Analyses\20240522_SIDS\SIDS_table1_&rundate..rtf,excluvar=studyid infantid marital2 marstat educ_mob tob_preg,dispp=0);

data SIDS_table1; 
	set table1; 
run; 
data table1; run; 

proc contents data=SIDS_table1 varnum; run; 


%table1(data=table1bb,byvar= HIV_INF,outtype=rtf,
outfile=\\Dept\ZICS\09SAS_Programs\06Analysis\Secondary_Analyses\20240522_SIDS\SIDS_table1b_&rundate..rtf,excluvar=studyid infantid PREM_DELIVERY PREM_DELIVERY37 PREM_DELIVERY34 bwcat BW  BRTHANOMSP vac_bf_dv ,dispp=0);

data SIDS_table1b; 
	set table1; 
run; 
data table1; run; 

proc contents data=SIDS_table1b varnum; run; 

%table1(data=tablee2,byvar= HIV_INF,outtype=rtf,
outfile=\\Dept\ZICS\09SAS_Programs\06Analysis\Secondary_Analyses\20240522_SIDS\SIDS_table2_&rundate..rtf,excluvar=studyid infantid REDCAP_EVENT_NAME ,dispp=0);

data SIDS_table2; 
	set table1; 
run; 
data table1; run; 

/*proc contents data=SIDS_table2 varnum; run; */
/**************************************/
/*		   OUTPUT MANIPULATION		  */
/**************************************/


/**************************************/
/*	   FORMATTED OUTPUT	(TFLs)		  */
/**************************************/
ods rtf file = "\\Dept\ZICS\09SAS_Programs\06Analysis\Secondary_Analyses\20240522_SIDS\SIDSresults_&rundate..rtf";


title "ZICS SIDS descriptive tables";
title2 "date run: &tdate";


title3 "Table 1a: Demographic Characteristics of caregivers ";
proc report data=SIDS_table1 nowd  headskip  style(header)={font_size=8pt} spanrows
			style(column)={font_size=8pt}  STYLE(column header)=[background=white vjust = center] ; 
	column order /*var*/ label level  N99; 
	define order/noprint group order=internal;
/*	define var/group 'Variable' order=internal left;*/
	define label/group 'Question' left group ;
	define level/'Response' left;
	define N99/'Overall' left;
run; title; footnote; 

title4 "Table 1b: Demographic characteristics of infants ";
proc report data=SIDS_table1b nowd  headskip  style(header)={font_size=8pt} spanrows
			style(column)={font_size=8pt}  STYLE(column header)=[background=white vjust = center] ; 
	column order /*var*/ label level  N99; 
	define order/noprint group order=internal;
/*	define var/group 'Variable' order=internal left;*/
	define label/group 'Question' left group ;
	define level/'Response' left;
	define N99/'Overall' left;
run; title;


title5 "Table 2: Risk factors for SIDs";
proc report data=SIDS_table2 nowd  headskip  style(header)={font_size=8pt} spanrows
			style(column)={font_size=8pt}  STYLE(column header)=[background=white vjust = center] ; 
	column order /*var*/ label level  N99; 
	define order/noprint group order=internal;
/*	define var/group 'Variable' order=internal left;*/
	define label/group 'Question' left group ;
	define level/'Response' left;
	define N99/'Overall' left;
run; title;

/*LSF 2024.07.03 - per the specifications, adding a simple PROC FREQ of this variable to the output*/
proc freq data=table1b; 
	tables brthanomsp; 
	label brthanomsp = "birth anomaly: specify"; 
run; title; 

ods rtf close; 
