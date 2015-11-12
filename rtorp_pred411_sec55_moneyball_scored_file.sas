%let PATH =/folders/myfolders/sasuser.v94/411_data/Moneyball;
%let NAME = MB;
%let LIB = &NAME..;

libname &NAME. "&PATH.";

%let INFILE = &LIB.MONEYBALL_TEST;

data moneyball_test_scores;
set &INFILE.;

* Perform the same transformations that were applied to training data;

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


* The stepwise regression model with all variables selected since aic, bic and squared error were best of the 3 models;

P_TARGET_WINS = 56.41909 
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
			
if P_TARGET_WINS < 50  then P_TARGET_WINS = 50;
if P_TARGET_WINS > 105 then P_TARGET_WINS = 105;

run;

* Verifies there are 259 results to match the number of obs in moneyball_test;

proc means data = moneyball_test_scores n;
TITLE "Number of obs in output file";
run;

* Keeps only desired columns;

data moneyball_results;
	set moneyball_test_scores;
	keep index PP_TARGET_WINS
run;
	

proc print data = moneyball_results;

TITLE "Moneyball Predictions";
un;

* Copies output to sas7dat file;

data MB.rtorp_pred411_s55__p_target_wins
	set moneyball_results;
run;
