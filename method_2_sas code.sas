proc import file="C:\Users\Bhumi\Downloads\default of credit card clients.xls" dbms=xls out=taiwan.ccdata_orig replace;
getnames=yes;
run;

ODS TRACE ON;
ods graphics on;

*Renaming PAY_0 as PAY_1;
data ccdata;
set taiwan.ccdata_orig (rename=(PAY_0=PAY_1));
run;

*Creating UTILIZATION RATIOS for 5 months. UTILIZATION RATIO = BILL_AMT/LIMIT;
data ccdata2;
set ccdata;
array bill_am{*} bill_amt2-bill_amt6;
array util_rat{*} UTIL_RATIO1-UTIL_RATIO5; 
do i=1 to 5;
	util_rat(i) = bill_am(i)/limit_bal;
end;
drop i;
run;

*Creating PAYMENT RATIOS for 5 months. PAYMENT RATIO = PAY_AMT/BILL_AMT;
data ccdata3;
set ccdata2;
array pay_am{*} pay_amt1-pay_amt5;
array bill_am{*} bill_amt2-bill_amt6;
array pay_rat{*} PAY_RATIO1-PAY_RATIO5;
do i=1 to 5;
	if bill_am(i) ne 0 then do;
		pay_rat(i) = pay_am(i)/bill_am(i);
	end;
	else do;
		pay_rat(i) = 1;
	end;
end;
drop i;
run;

*Creating OUTSTANDING PAYMENT RATIOS for 5 months. OUTSTANDING PAYMENT RATIO = (BILL_AMT - PAY_AMT)/LIMIT;
data ccdata4;
set ccdata3;
array pay_am{*} pay_amt1-pay_amt5;
array bill_am{*} bill_amt2-bill_amt6;
array out_rat{*} OUT_RATIO1-OUT_RATIO5;
do i=1 to 5;
	out_rat(i) = (bill_am(i)- pay_am(i))/limit_bal;
end;
drop i;
run;

*Creating n-1 Dummy Variables for n categories of SEX, EDUCATION and MARRIAGE;
data ccdata5;
set ccdata4;
if sex = 2 then sex = 0;

GRAD_SCHOOL = 0;
UNIVERSITY = 0;
HIGH_SCHOOL = 0;
if education = 1 then GRAD_SCHOOL = 1;
if education = 2 then UNIVERSITY = 1;
if education = 3 then HIGH_SCHOOL = 1;

MARRIED = 0;
SINGLE = 0;
if marriage = 1 then MARRIED = 1;
if marriage = 2 then SINGLE = 1;

drop education marriage;
run;

*Removing unwanted variables BILL_AMT1 to BILL_AMT6 and PAY_AMT1 to PAY_AMT6;
data ccdata6;
set ccdata5;
drop i id bill_amt1 bill_amt2 bill_amt3 bill_amt4 bill_amt5 bill_amt6 pay_amt1 pay_amt2 pay_amt3 pay_amt4 pay_amt5 pay_amt6;
run;

*Normalizing AGE variable;
proc standard data=ccdata6 mean=0 std=1 out=ccdata7;
var age;
run;

data temp;
set ccdata7;
n=ranuni(8); *random number generator;
run;

proc sort data=temp;
by n;
run;

*Creating PCA on numeric variables only;
*Using Out_Ratio creating PCA_1;
proc princomp data=temp out=temp_pca1;
var  LIMIT_BAL PAY_1 PAY_2 PAY_3 PAY_4 PAY_5 PAY_6  OUT_RATIO1 OUT_RATIO2 OUT_RATIO3 OUT_RATIO4 OUT_RATIO5 AGE;
run;
*Using Ult_Ratio and Pay_Ratio  PCA_2
proc princomp data=temp out=temp_pca2;
var LIMIT_BAL PAY_1 PAY_2 PAY_3 PAY_4 PAY_5 PAY_6  UTIL_RATIO1 UTIL_RATIO2 UTIL_RATIO3 UTIL_RATIO4 UTIL_RATIO5 
	PAY_RATIO1 PAY_RATIO2 PAY_RATIO3 PAY_RATIO4 PAY_RATIO5 AGE;
run;

*Creating test and train data set in 70:30 ratio;
data train test;
set temp (drop=n) nobs=nobs;
if _n_<=.7*nobs then output train;
else output test;
run;

data train_pca1 test_pca1;
set temp_pca1 (keep = default_payment_next_month SEX GRAD_SCHOOL UNIVERSITY HIGH_SCHOOL MARRIED SINGLE Prin1-Prin10) nobs= nobs;
if _n_<=.7*nobs then output train_pca1;
else output test_pca1;
run;

data train_pca2 test_pca2;
set temp_pca2 (keep = default_payment_next_month SEX GRAD_SCHOOL UNIVERSITY HIGH_SCHOOL MARRIED SINGLE Prin1-Prin10) nobs=nobs;
if _n_<=.7*nobs then output train_pca2;
else output test_pca2;
run;



*LIMIT_BAL SEX PAY_1 PAY_2 PAY_3 PAY_4 PAY_5 PAY_6  OUT_RATIO1 OUT_RATIO2 OUT_RATIO3 OUT_RATIO4 OUT_RATIO5 GRAD_SCHOOL	UNIVERSITY	HIGH_SCHOOL	EDUCATION_OTHERS MARRIED SINGLE	MARITAL_STATUS_OTHERS AGE_NORM ;


/*UTIL_RATIO1
UTIL_RATIO2
UTIL_RATIO3
UTIL_RATIO4
UTIL_RATIO5
PAY_RATIO1
PAY_RATIO2
PAY_RATIO3
PAY_RATIO4
PAY_RATIO5
;*/

************************************************************************************************************************;
*With Utilization Ratio And Pay Ratio
*Stepwise 10 steps + Final model + Training/Test AUC ;
proc logistic data=train outmodel=model1;
model default_payment_next_month (event='1')= SEX GRAD_SCHOOL UNIVERSITY HIGH_SCHOOL MARRIED SINGLE LIMIT_BAL PAY_1 PAY_2 PAY_3 PAY_4 PAY_5 PAY_6 UTIL_RATIO1 UTIL_RATIO2 UTIL_RATIO3 UTIL_RATIO4 UTIL_RATIO5 PAY_RATIO1 PAY_RATIO2 PAY_RATIO3 PAY_RATIO4 PAY_RATIO5 AGE/stb selection=stepwise outroc=troc;
score data=test out=score1 outroc=vroc;
roc;
run;

*Fit statistics on test data: error rate, auc, rsq etc;
proc logistic inmodel=model1;
score data=test out=score1 fitstat;
run;

*For DW;
proc reg data= train outest=est1;
model default_payment_next_month = SEX GRAD_SCHOOL UNIVERSITY HIGH_SCHOOL MARRIED SINGLE LIMIT_BAL PAY_1 PAY_2 PAY_3 PAY_4 PAY_5 PAY_6  UTIL_RATIO1 UTIL_RATIO2 UTIL_RATIO3 UTIL_RATIO4 UTIL_RATIO5 PAY_RATIO1 PAY_RATIO2 PAY_RATIO3 PAY_RATIO4 PAY_RATIO5 AGE/dwProb;
*OUTPUT rstudent=C_rstudent h=leverage cookd=Cookd dffits=dffit STUDENT=C_student;  
run;

************************************************************************************************************************;
*With OutStanding Ratio;
proc logistic data=train outmodel=model2;
model default_payment_next_month (event='1')= SEX GRAD_SCHOOL UNIVERSITY HIGH_SCHOOL MARRIED SINGLE LIMIT_BAL PAY_1 PAY_2 PAY_3 PAY_4 PAY_5 PAY_6  OUT_RATIO1 OUT_RATIO2 OUT_RATIO3 OUT_RATIO4 OUT_RATIO5 AGE/stb selection=stepwise outroc=troc;
score data=test out=score2 outroc=vroc;
roc;
run;

proc logistic inmodel=model2;
   score data=test out=score2 fitstat;
run;

proc reg data= train outest=est2;
model default_payment_next_month = SEX GRAD_SCHOOL UNIVERSITY HIGH_SCHOOL MARRIED SINGLE LIMIT_BAL PAY_1 PAY_2 PAY_3 PAY_4 PAY_5 PAY_6  OUT_RATIO1 OUT_RATIO2 OUT_RATIO3 OUT_RATIO4 OUT_RATIO5 AGE/dwProb;
*OUTPUT rstudent=C_rstudent h=leverage cookd=Cookd dffits=dffit STUDENT=C_student;  
run;

************************************************************************************************************************;
*With PCA_1;
proc logistic data=train_pca1 outmodel=model_pca1;
model default_payment_next_month (event='1')= SEX GRAD_SCHOOL UNIVERSITY HIGH_SCHOOL MARRIED SINGLE Prin1 Prin2 Prin3 Prin4 Prin5 Prin6 Prin7 Prin8 Prin9 Prin10/stb outroc=troc;
score data=test_pca1 out=score_pca1 outroc=vroc;
roc;
run;

proc logistic inmodel=model_pca1;
   score data=test_pca1 out=score_pca1 fitstat;
run;

proc reg data= train_pca1 outest=est_pca1;
model default_payment_next_month = SEX GRAD_SCHOOL UNIVERSITY HIGH_SCHOOL MARRIED SINGLE Prin1 Prin2 Prin3 Prin4 Prin5 Prin6 Prin7 Prin8 Prin9 Prin10/dwProb;
*OUTPUT rstudent=C_rstudent h=leverage cookd=Cookd dffits=dffit STUDENT=C_student;  
run;


************************************************************************************************************************;
*With PCA_2;
proc logistic data=train_pca2 outmodel=model_pca2;
model default_payment_next_month (event='1')= SEX GRAD_SCHOOL UNIVERSITY HIGH_SCHOOL MARRIED SINGLE Prin1 Prin2 Prin3 Prin4 Prin5 Prin6 Prin7 Prin8 Prin9 Prin10/stb outroc=troc;
score data=test_pca2 out=score_pca2 outroc=vroc;
roc;
run;

proc logistic inmodel=model_pca2;
   score data=test_pca2 out=score_pca1 fitstat;
run;

proc reg data= train_pca2 outest=est_pca2;
model default_payment_next_month = SEX GRAD_SCHOOL UNIVERSITY HIGH_SCHOOL MARRIED SINGLE Prin1 Prin2 Prin3 Prin4 Prin5 Prin6 Prin7 Prin8 Prin9 Prin10/dwProb;
*OUTPUT rstudent=C_rstudent h=leverage cookd=Cookd dffits=dffit STUDENT=C_student;  
run;












