%let PATH =/folders/myfolders/sasuser.v94/411_data/Moneyball;
%let NAME = MB;
%let LIB = &NAME..;

libname &NAME. "&PATH.";

%let INFILE = &LIB.MONEYBALL;

*Explore response variable;

proc univariate data=&INFILE. plot;
	var TARGET_WINS;
run;


* Check correlations among variables with TARGET_WINS;

ods graphics on;
proc corr data=&INFILE. ; 
VAR TARGET_WINS;
WITH TEAM_BATTING_H TEAM_BATTING_2B TEAM_BATTING_3B TEAM_BATTING_HR 
TEAM_BATTING_BB TEAM_BATTING_SO TEAM_BASERUN_SB TEAM_BASERUN_CS 
TEAM_BATTING_HBP TEAM_PITCHING_H TEAM_PITCHING_HR TEAM_PITCHING_BB 
TEAM_PITCHING_SO TEAM_FIELDING_E TEAM_FIELDING_DP;
TITLE "Correlation TARGET_WINS Vs. Predictor Variables";
run;
ods graphics off;

* Univariate analysis predictors with Pearson CC > .10;

proc univariate data=&INFILE. plot;
	var TEAM_BATTING_2B TEAM_BATTING_3B TEAM_BATTING_HR TEAM_BATTING_BB
		TEAM_BASERUN_SB TEAM_PITCHING_H TEAM_PITCHING_HR TEAM_PITCHING_BB
		TEAM_FIELDING_E;
TITLE "Univariate Analysis Variables with Peaarson Correlation Coefficient > .10";
run;


*Explore missing values in data set;

data data_exploration;
	set &INFILE.;
	drop index;
run;

proc means data=data_exploration mean median min max p1 p10 p90 p99 max ndec=2 n nmiss;
TITLE "Exploration of Historical Team Data";
run;

* Impute missing data using mean and fix outliers;

data TEMP1;
set &INFILE.;

drop TEAM_BATTING_HBP;

SB_PCT = TEAM_BASERUN_SB /(TEAM_BASERUN_SB + TEAM_BASERUN_CS );

FLAG_SB_FIXED = missing(SB_PCT);
FLAG_BATSO_FIXED = missing(TEAM_BATTING_SO);
FLAG_BRSB_FIXED = missing(TEAM_BASERUN_SB);
FLAG_BRCS_FIXED = missing(TEAM_BASERUN_CS);
FLAG_FDP_FIXED = missing(TEAM_FIELDING_DP);
FLAG_PSO_FIXED = missing(TEAM_PITCHING_SO);

if missing(TEAM_BATTING_SO) then TEAM_BATTING_SO = 736; 
if missing(TEAM_BASERUN_SB) then TEAM_BASERUN_SB = 125;
if missing(TEAM_BASERUN_CS) then TEAM_BASERUN_CS = 53; 
if missing(TEAM_FIELDING_DP) then TEAM_FIELDING_DP = 146;
if missing(TEAM_PITCHING_SO) then TEAM_PITCHING_SO = 818;
if missing(SB_PCT) then SB_PCT = 0.63;

if TEAM_FIELDING_E > 542 then TEAM_FIELDING_E = 542;
if TEAM_PITCHING_BB > 694 then TEAM_PITCHING_BB = 694;
if TEAM_PITCHING_H > 2059 then TEAM_PITCHING_H = 2059;
if TEAM_PITCHING_SO > 1095 then TEAM_PITCHING_SO = 1095;


if SB_PCT < 0.63 then SB_PCT = 0.63;
if TEAM_PITCHING_BB < 417 then TEAM_PITCHING_BB = 417;
if TEAM_PITCHING_HR < 25 then TEAM_PITCHING_HR = 25;
if TEAM_PITCHING_SO < 490 then TEAM_PITCHING_SO = 490;
if TEAM_BATTING_SO < 421 then TEAM_BATTING_SO = 421;
if TEAM_BASERUN_SB < 44 then TEAM_BASERUN_SB = 44;
if TEAM_BASERUN_CS < 30 then TEAM_BASERUN_CS = 30;
if TEAM_BATTING_3B < 27 then TEAM_BATTING_3B = 27;
if TEAM_BATTING_HR < 20 then TEAM_BATTING_HR = 20;
if TEAM_BATTING_BB < 363 then TEAM_BATTING_BB = 363;

TEAM_BATTING_1B = TEAM_BATTING_H - TEAM_BATTING_2B - TEAM_BATTING_3B - TEAM_BATTING_HR;

run;

* Split moneyball data set into training and validation sets using a 70/30 split;

data MBTrain MBValidate;
set TEMP1;
if ranuni(1) < 0.70 then
	output MBTrain;
else
	output MBValidate;
run;

* Export MBTrain to create Decision Tree in Angoss;

proc export data=MBTrain file='/folders/myfolders/sasuser.v94/411_data/Moneyball/MBTrain.csv' replace;
run;

* Spot check training and validation data;

proc print data = MBTrain (obs = 10);
run;

proc print data = MBValidate (obs = 10);
run;

* Check training and validation data for remaing outliers and missing values;

proc means data=MBTrain mean median p1 p10 p90 p99 min max ndec=2 n nmiss;
TITLE "Exploration of MBTrain Data";
run;


proc means data=MBValidate mean median p1 p10 p90 p99 min max ndec=2 n nmiss;
TITLE "Exploration of MBValidata Data";
run;


/* Below are the 3 models selected for comparison. The first is a model I selected using variables with a Pearson */
/* correlation coefficient greater that .10. The second model was selected by feeding the MBTrain dataset into Angoss and */
/* selecting variables using a decision tree. The final model was selected by starting with all variables except */
/* TEAM_BATTING_H (Since this is a linear combination of 1B,2B,3B and HR) and applying stepwise variable selection with */
/* PROC REG. */

* My selection based on PCC .1 or greater;

proc reg data = MBTrain OUTEST = est1;
	pcc: model TARGET_WINS =
		TEAM_BATTING_1B
		TEAM_BATTING_2B
		TEAM_BATTING_3B
		TEAM_BATTING_HR
		TEAM_BATTING_BB
		TEAM_BASERUN_SB
		TEAM_PITCHING_H
		TEAM_PITCHING_HR
		TEAM_PITCHING_BB
		TEAM_FIELDING_E/ vif aic bic;
run;
quit;


* Model selected by Decision Tree in Angoss;

proc reg data = MBTrain OUTEST = est2;
	angoss: model TARGET_WINs = 
			TEAM_BATTING_1B
			TEAM_BATTING_2B
			TEAM_BASERUN_CS
			FLAG_SB_FIXED
			FLAG_BATSO_FIXED
			FLAG_FDP_FIXED/ vif aic bic;
run;
quit;
			
* All variables using stepwise selection;

proc reg data=MBTrain outest = est3;
	swise: model TARGET_WINS = 
			TEAM_BATTING_1B
			TEAM_BATTING_2B 
			TEAM_BATTING_3B
			TEAM_BATTING_HR 
			TEAM_BATTING_BB 
			TEAM_BATTING_SO 
			TEAM_BASERUN_SB
			TEAM_BASERUN_CS 
			TEAM_FIELDING_E 
			TEAM_FIELDING_DP 
			TEAM_PITCHING_BB 
			TEAM_PITCHING_H
			TEAM_PITCHING_HR 
			TEAM_PITCHING_SO 
			SB_PCT FLAG_SB_FIXED 
			FLAG_BATSO_FIXED 
			FLAG_BRSB_FIXED
			FLAG_BRCS_FIXED 
			FLAG_FDP_FIXED 
			FLAG_PSO_FIXED/ selection = stepwise vif aic bic;
run;
quit;



* Compare data sets add out files for other models;

data estout;
	set est3 est2 est1;
	keep _MODEL_ _RMSE_ _AIC_ _BIC_;
	run;
	proc sort data=estout; by _AIC_;
proc print data=estout; 
TITLE "Comparison of Models Based on Key Statistics";
run; 


*Score Code Below;

%let results = MBValidate;

data score_file;
set &results.;

* UNCOMMENT THE TRANSFORMATIONS WHEN CREATING FINAL SCORING DATA STEP, NO NEED TO DO THIS HERE, MBValidate ALREADY TRANSFORMED;

/* drop TEAM_BATTING_HBP; */
/*  */
/* SB_PCT = TEAM_BASERUN_SB /(TEAM_BASERUN_SB + TEAM_BASERUN_CS ); */
/*  */
/* FLAG_SB_FIXED = missing(SB_PCT); */
/* FLAG_BATSO_FIXED = missing(TEAM_BATTING_SO); */
/* FLAG_BRSB_FIXED = missing(TEAM_BASERUN_SB); */
/* FLAG_BRCS_FIXED = missing(TEAM_BASERUN_CS); */
/* FLAG_FDP_FIXED = missing(TEAM_FIELDING_DP); */
/* FLAG_PSO_FIXED = missing(TEAM_PITCHING_SO); */
/*  */
/* if missing(TEAM_BATTING_SO) then TEAM_BATTING_SO = 736;  */
/* if missing(TEAM_BASERUN_SB) then TEAM_BASERUN_SB = 125; */
/* if missing(TEAM_BASERUN_CS) then TEAM_BASERUN_CS = 53;  */
/* if missing(TEAM_FIELDING_DP) then TEAM_FIELDING_DP = 146; */
/* if missing(TEAM_PITCHING_SO) then TEAM_PITCHING_SO = 818; */
/* if missing(SB_PCT) then SB_PCT = 0.63; */
/*  */
/* if TEAM_FIELDING_E > 542 then TEAM_FIELDING_E = 542; */
/* if TEAM_PITCHING_BB > 694 then TEAM_PITCHING_BB = 694; */
/* if TEAM_PITCHING_H > 2059 then TEAM_PITCHING_H = 2059; */
/* if TEAM_PITCHING_SO > 1095 then TEAM_PITCHING_SO = 1095; */
/*  */
/*  */
/* if SB_PCT < 0.63 then SB_PCT = 0.63; */
/* if TEAM_PITCHING_BB < 417 then TEAM_PITCHING_BB = 417; */
/* if TEAM_PITCHING_HR < 25 then TEAM_PITCHING_HR = 25; */
/* if TEAM_PITCHING_SO < 490 then TEAM_PITCHING_SO = 490; */
/* if TEAM_BATTING_SO < 421 then TEAM_BATTING_SO = 421; */
/* if TEAM_BASERUN_SB < 44 then TEAM_BASERUN_SB = 44; */
/* if TEAM_BASERUN_CS < 30 then TEAM_BASERUN_CS = 30; */
/* if TEAM_BATTING_3B < 27 then TEAM_BATTING_3B = 27; */
/* if TEAM_BATTING_HR < 20 then TEAM_BATTING_HR = 20; */
/* if TEAM_BATTING_BB < 363 then TEAM_BATTING_BB = 363; */
/*  */
/* TEAM_BATTING_1B = TEAM_BATTING_H - TEAM_BATTING_2B - TEAM_BATTING_3B - TEAM_BATTING_HR; */

/*run;*/


*My equation based on PCC > .10 ;
PRED_1 = 4.53146 
		+ 0.0373*TEAM_BATTING_1B 
		+ 0.01415*TEAM_BATTING_2B 
		+ 0.13823*TEAM_BATTING_3B 
		+ 0.05439*TEAM_BATTING_HR 
		+ 0.058*TEAM_BATTING_BB 
		+ 0.04574*TEAM_BASERUN_SB 
		+ 0.00962*TEAM_PITCHING_H 
		+ 0.00659*TEAM_PITCHING_HR 
		+ -0.04083*TEAM_PITCHING_BB 
		+ -0.04412*TEAM_FIELDING_E;


* Variables selected by Angoss Decision Tree;


PRED_2 = 27.49448 
			+ 0.03067*TEAM_BATTING_1B 
			+ 0.08994*TEAM_BATTING_2B 
			+ -0.01648*TEAM_BASERUN_CS 
			+ -0.98614*FLAG_SB_FIXED 
			+ 6.12658*FLAG_BATSO_FIXED 
			+ -5.2505*FLAG_FDP_FIXED;


* Equation using all variables with stepwise selection;

PRED_3 = 56.41909 
			+ 0.05178*TEAM_BATTING_1B 
			+ 0.0333*TEAM_BATTING_2B 
			+ 0.16274*TEAM_BATTING_3B 
			+ 0.10789*TEAM_BATTING_HR 
			+ 0.03136*TEAM_BATTING_BB 
			+ -0.02736*TEAM_BATTING_SO 
			+ 0.07572*TEAM_BASERUN_SB 
			+ -0.04694*TEAM_BASERUN_CS 
			+ -0.11258*TEAM_FIELDING_E 
			+ -0.11187*TEAM_FIELDING_DP 
			+ -0.01241*TEAM_PITCHING_H 
			+ 0.01353*TEAM_PITCHING_SO 
			+ -24.63666*SB_PCT
			+ 7.63914*FLAG_BATSO_FIXED 
			+ 31.29647*FLAG_BRSB_FIXED 
			+ 2.4961*FLAG_BRCS_FIXED 
			+ 8.98023*FLAG_FDP_FIXED;


AVE_WINS_DIFF = (TARGET_WINS - 82);

if PRED_1 < 50  then PRED_1 = 50;
if PRED_1 > 105 then PRED_1 = 105;

if PRED_2 < 50  then PRED_2 = 50;
if PRED_2 > 105 then PRED_2 = 105;

if PRED_3 < 50  then PRED_3 = 50;
if PRED_3 > 105 then PRED_3 = 105;


PRED_1_DIFF = (TARGET_WINS - PRED_1);
PRED_2_DIFF = (TARGET_WINS - PRED_2);
PRED_3_DIFF = (TARGET_WINS - PRED_3);

ERROR_My_Selection = (TARGET_WINS - PRED_1)**2;
ERROR_Angoss = (TARGET_WINS - PRED_2)**2;
ERROR_Stepwise = (TARGET_WINS - PRED_3)**2;
ERROR_AVE_WINS = AVE_WINS_DIFF **2;

run;

proc print data = score_file;
var TARGET_WINS PRED_1 PRED_2 PRED_3 PRED_1_DIFF PRED_2_DIFF
 PRED_3_DIFF AVE_WINS_DIFF ERROR_My_Selection ERROR_Angoss ERROR_Stepwise ERROR_AVE_WINS;
run;

proc means data=score_file mean median;
var ERROR_My_Selection ERROR_Angoss ERROR_Stepwise ERROR_AVE_WINS;
TITLE "Squared Error Comparison of Models Using Validation Data";
run;



