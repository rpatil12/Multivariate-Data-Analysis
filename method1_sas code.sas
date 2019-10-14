ods listing close;
ods rtf 
body="C:\Users\Desktop\Madhura_BIA 652\project\method1_output.rtf";
/*Problem 1*/

*METHOD 1;

/*IMPORTING ORIGINAL DATASET*/
PROC IMPORT OUT= WORK.original 
	            DATAFILE= "C:\Users\Desktop\Madhura_BIA 652\project\default of credit card clients.xls" 
            DBMS=EXCEL REPLACE;
     RANGE="Data$"; 
     GETNAMES=YES;
RUN;
/*IINTER QUANTILE RANGE USING MACROS METHOD TO REMOVE OUTLIERS*/

/* Creating a macro called as 'outliers' TO calculate IQR, Q1, Q3, upper and lower limits*/
%macro outliers(input=, var= , output=);

/* Calculate the first quartile, third quartile and the quartile range */
proc univariate data=&Input noprint;
var &Var;
output out=temp QRANGE=IQR Q1=First_Qtl Q3=Third_Qtl;
run;

/* Using symput routine to assign value produced in data step to the macro variable */
data _null_;
set temp;
call symput('QR', IQR);
call symput('Q1', First_Qtl);
call symput('Q3', Third_Qtl);
run;

%let ULimit=%sysevalf(&Q3 + 1.5 * &QR);
%let LLimit=%sysevalf(&Q1 - 1.5 * &QR);

/* Creating final dataset after removing outliers*/
data &output;
set &input;
%put See the lower and upper limit of acceptable range below: ;
%put Lower limit = &LLimit;
%put Upper limit = &ULimit;
if &Var >= &Llimit and &Var <= &ULimit;
run;
%mend;

*calls macro to remove outliers from each column one by one;
%outliers(Input=original, Var = LIMIT_BAL, Output= Outdata);
%outliers(Input=Outdata, Var = AGE, Output= Outdata1);
%outliers(Input=Outdata1, Var = BILL_AMT1, Output= Outdata2);
%outliers(Input=Outdata2, Var = BILL_AMT2, Output= Outdata3);
%outliers(Input=Outdata3, Var = BILL_AMT3, Output= Outdata4);
%outliers(Input=Outdata4, Var = BILL_AMT4, Output= Outdata5);
%outliers(Input=Outdata5, Var = BILL_AMT5, Output= Outdata6);
%outliers(Input=Outdata6, Var = BILL_AMT6, Output= Outdata7);
%outliers(Input=Outdata7, Var = PAY_AMT1, Output= Outdata8);
%outliers(Input=Outdata8, Var = PAY_AMT2, Output= Outdata9);
%outliers(Input=Outdata9, Var = PAY_AMT3, Output= Outdata10);
%outliers(Input=Outdata10, Var = PAY_AMT4, Output= Outdata11);
%outliers(Input=Outdata11, Var = PAY_AMT5, Output= Outdata12);
%outliers(Input=Outdata12, Var = PAY_AMT6, Output=credit_data);

*code to partition the original data without outliers into training and testing (60% train and 40% test);
data credit_testtrain;
set credit_data;
n=ranuni(8);
proc sort data=credit_data;
  by n;
  data training testing;
   set credit_testtrain nobs=nobs;
   if _n_<=.6*nobs then output training;
    else output testing;
   run;

* using standarize function on training dataset;
 proc standard data=training
 mean=0 std=1
 out=standard_output;
var LIMIT_BAL AGE BILL_AMT1 BILL_AMT2 BILL_AMT3 BILL_AMT4 BILL_AMT5 BILL_AMT6 PAY_AMT1 PAY_AMT2 PAY_AMT3 PAY_AMT4 PAY_AMT5 PAY_AMT6;
 run;

* using standarize function on testing dataset;
 proc standard data=testing
 mean=0 std=1
 out=stand_output1;
var LIMIT_BAL AGE BILL_AMT1 BILL_AMT2 BILL_AMT3 BILL_AMT4 BILL_AMT5 BILL_AMT6 PAY_AMT1 PAY_AMT2 PAY_AMT3 PAY_AMT4 PAY_AMT5 PAY_AMT6;
 run;


*APPROACH 1;
*TRAINING MODEL;

* selection technique MAXR to find the significant variables and also check for p values;
 title "APPROACH1: REGRESSION ANALYSIS WITH MAXR SELECTION TO FIND SIGNIFICANT VARIABLES"; 
  proc reg data= standard_output  outest=est_out ;
     model  default_payment_next_month= LIMIT_BAL SEX EDUCATION	MARRIAGE AGE PAY_0 PAY_2 PAY_3 PAY_4 PAY_5 PAY_6 BILL_AMT1 
BILL_AMT2 BILL_AMT3 BILL_AMT4 BILL_AMT5 BILL_AMT6 PAY_AMT1 PAY_AMT2 PAY_AMT3 PAY_AMT4 PAY_AMT5 PAY_AMT6 /    selection = MAXR  
dwProb   ;
  quit;

*run correlation function to understand the correlation between variables;
  title "APPROACH1: CORRELATION ANALYSIS "; 
  proc corr data=standard_output; 
var   PAY_0 PAY_2 PAY_3 PAY_4 PAY_5 PAY_6 BILL_AMT1 
BILL_AMT2 BILL_AMT3 BILL_AMT4 BILL_AMT5 BILL_AMT6 PAY_AMT1 PAY_AMT2 PAY_AMT3 PAY_AMT4 PAY_AMT5 PAY_AMT6;
run;
  

*finding Durbin watson and VIF using significant variables;
title "APPROACH1: REGRESSION ANALYSIS USING SIGNIFICANT VARIABLES WITH dwProb & VIF"; 
proc reg data=standard_output outest=est_out1 ; 
     model default_payment_next_month=  EDUCATION MARRIAGE  PAY_0 PAY_2 PAY_4 BILL_AMT1 BILL_AMT6  
  PAY_AMT1 PAY_AMT2 PAY_AMT5 /r VIF dwProb;      
quit; 

 * logistic regression using significant variables;
title "APPROACH1: LOGISTIC REGRESSION ANALYSIS USING SIGNIFICANT VARIABLES"; 
proc logistic data=standard_output plots=all outmodel=model1 ;
    model default_payment_next_month=  EDUCATION MARRIAGE  PAY_0 PAY_2 PAY_4 BILL_AMT1 BILL_AMT6  
  PAY_AMT1 PAY_AMT2  PAY_AMT5 / selection= stepwise STB ;
  score data=stand_output1 out=score1 outroc=vroc;
  roc;
quit;

* logistic regression to test the training and testing set std errors;
title "APPROACH1: TESTING MODEL LOGISTIC REGRESSION ANALYSIS FOR STANDARD ERROR"; 
proc logistic inmodel=model1;
score data=stand_output1 out=score1 fitstat;
quit;

*APPROACH 2;

*TRAINING MODEL;

* principal component anslysis on training dataset;
TITLE'APPROACH2: PRINCIPAL COMPONENT ANALYSIS ON TRAINING DATASET';
proc princomp data=standard_output out=pca_out;
    var LIMIT_BAL SEX EDUCATION MARRIAGE AGE PAY_0 PAY_2 PAY_3 PAY_4   
        PAY_5 PAY_6 BILL_AMT1 BILL_AMT2 BILL_AMT3 BILL_AMT4 BILL_AMT5 
        BILL_AMT6 PAY_AMT1 PAY_AMT2 PAY_AMT3 PAY_AMT4 PAY_AMT5 PAY_AMT6;
run;

*run correlation procedure to understand the correlation between variables;
 title "APPROACH2: CORRELATION ANALYSIS ON TRAINING SET ";
 proc corr data=pca_out; 
var prin1 prin2 prin3 prin4 prin5 prin6 prin7 prin8 prin9 prin10
prin11 prin12 prin13 prin14 prin15 prin16 prin17 prin18 prin19 prin20 prin21 prin22 prin23  ;
run;
  
*finding Durbin watson and VIF using significant variables;
  **PLOTS(MAXPOINTS=NONE);
title "APPROACH2: REGRESSION ANALYSIS WITH dwProb & VIF"; 
proc reg data=pca_out outest=est_out4 ; 
     model default_payment_next_month = prin1 prin2 prin3 prin4 prin5 prin6 prin7 prin8 prin9 prin10
prin11 prin12 prin13 prin14 prin15 prin16 prin17 prin18 prin19 prin20 prin21 prin22 prin23 /r VIF dwProb;
run; 

* logistic regression using all PCA variables;
title "APPROACH2: LOGISTIC REGRESSION ANALYSIS USING PCA VARIABLES ON TRAINING DATASET"; 
proc logistic data=pca_out plots=all outmodel=model2;
    model default_payment_next_month = prin1 prin2 prin3 prin4 prin5 prin6 prin7 prin8 prin9 prin10
prin11 prin12 prin13 prin14 prin15 prin16 prin17 prin18 prin19 prin20 prin21 prin22 prin23 / selection= stepwise STB ;
quit;


* TESTING MODEL;

* principal component anslysis on testing dataset;
title'APPROACH2: PRINCIPAL COMPONENT ANALYSIS FOR TESTING DATASET';
proc princomp data=stand_output1 out=pca_out1;
    var LIMIT_BAL SEX EDUCATION MARRIAGE AGE PAY_0 PAY_2 PAY_3 PAY_4   
        PAY_5 PAY_6 BILL_AMT1 BILL_AMT2 BILL_AMT3 BILL_AMT4 BILL_AMT5 
        BILL_AMT6 PAY_AMT1 PAY_AMT2   PAY_AMT3 PAY_AMT4 PAY_AMT5 PAY_AMT6;
run;

* logistic regression to test the training and testing set std errors;
title "APPROACH2: LOGISTIC REGRESSION ANALYSIS FOR STANDARD ERROR"; 
proc logistic inmodel=model2;
score data=pca_out1 out=score2 fitstat;
quit;




*APPROACH 3;

* log transformation on training dataset;
	data log ;
	set training;
    log_limit_bal = log(limit_bal);
	log_age=log(age);
    log_bill_amt1 = log(bill_amt1);
    log_bill_amt2 = log(bill_amt2); 
    log_bill_amt3 = log(bill_amt3);
    log_bill_amt4 = log(bill_amt4);
    log_bill_amt5 = log(bill_amt5) ;
    log_bill_amt6 = log(bill_amt6); 
    log_pay_amt1 = log(pay_amt1);
    log_pay_amt2 = log(pay_amt2);
    log_pay_amt3 = log(pay_amt3) ;
    log_pay_amt4 = log(pay_amt4);
    log_pay_amt5 = log(pay_amt5) ;
    log_pay_amt6 = log(pay_amt6);
run;


* selection technique MAXR to find the significant variables and also check for p values;
 title "APPROACH3: REGRESSION ANALYSIS WITH MAXR SELECTION TO FIND SIGNIFICANT VARIABLES ON TRAINING SET";
  proc reg data= log  outest=est_out2 ;
  model  default_payment_next_month=  log_limit_bal SEX EDUCATION	MARRIAGE log_age PAY_0 PAY_2 PAY_3 PAY_4 PAY_5 PAY_6 
 log_bill_amt1   log_bill_amt2   log_bill_amt3   log_bill_amt4   log_bill_amt5   log_bill_amt6 log_pay_amt1 log_pay_amt2
 log_pay_amt3 log_pay_amt4 log_pay_amt5 log_pay_amt6/    selection = MAXR  
  dwProb   ; 
 quit;

 *run correlation procedure to understand the correlation between variables;
 title "APPROACH3: CORRELATION ANALYSIS ";
proc corr data=log; 
var PAY_0 PAY_2 PAY_3 PAY_4 PAY_5 PAY_6 
log_bill_amt1   log_bill_amt2   log_bill_amt3   log_bill_amt4   log_bill_amt5   log_bill_amt6 log_pay_amt1 log_pay_amt2
log_pay_amt3 log_pay_amt4 log_pay_amt5 log_pay_amt6  ;
run;

*finding Durbin watson and VIF using significant variables;
title "APPROACH3: REGRESSION ANALYSIS WITH dwProb & VIF"; 
proc reg data=log outest=est_out3 ; 
     model default_payment_next_month=  pay_0 pay_2 pay_5 log_bill_amt1 log_pay_amt4 /r VIF dwProb;      
quit;

* logistic regression using significant variables;
title "APPROACH3: LOGISTIC REGRESSION ANALYSIS USING SIGNIFICANT VARIABLES ON TRAINING SET"; 
proc logistic data=log plots=all outmodel=model3;
model default_payment_next_month=  pay_0 pay_2 pay_5 log_bill_amt1 log_pay_amt4/ selection= stepwise STB ;
quit;


* TESTING MODEL;

* log transformation on testing dataset;
data log_test ;
	set testing;
    log_limit_bal = log(limit_bal);
	log_age=log(age);
    log_bill_amt1 = log(bill_amt1);
    log_bill_amt2 = log(bill_amt2); 
    log_bill_amt3 = log(bill_amt3);
    log_bill_amt4 = log(bill_amt4);
    log_bill_amt5 = log(bill_amt5) ;
    log_bill_amt6 = log(bill_amt6); 
    log_pay_amt1 = log(pay_amt1);
    log_pay_amt2 = log(pay_amt2);
    log_pay_amt3 = log(pay_amt3) ;
    log_pay_amt4 = log(pay_amt4);
    log_pay_amt5 = log(pay_amt5) ;
    log_pay_amt6 = log(pay_amt6);
run;


* logistic regression to test the training and testing set std errors;
title "APRROACH3: LOGISTIC REGRESSION ANALYSIS FOR STANDARD ERROR"; 
proc logistic inmodel=model3;
score data=log_test out=score3 fitstat;
quit;

ods rtf close;
ods listing;
