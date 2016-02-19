/************************************************************************Start*******************************************************************************/

/* SET HOME Library PATH*/
LIBNAME QCFPrism "P:\Assignment52";

/* SET CRSP Library PATH*/
LIBNAME CONBank "P:\Assignment52\DataSets";

ODS PDF FILE = "P:\Assignment52\results52.pdf";


/*Import Loan Stats Data*/
PROC IMPORT DATAFILE="P:\Assignment52\DataSets\LoanStats3a.csv"
OUT= LoanStats3a
DBMS=CSV
REPLACE;
GETNAMES=YES;
GUESSINGROWS=1000;
RUN;

/*Import Loan Stats Data*/
PROC IMPORT DATAFILE="P:\Assignment52\DataSets\LoanStats3b.csv"
OUT= LoanStats3b
DBMS=CSV
REPLACE;
GETNAMES=YES;
RUN;

/*Import Variable Explaination Data*/
PROC IMPORT DATAFILE="P:\Assignment52\DataSets\LoanStats3c.csv"
OUT= LoanStats3c
DBMS=CSV
REPLACE;
GETNAMES=YES;
RUN;

/*Import Loan Stats Data*/
PROC IMPORT DATAFILE="P:\Assignment52\DataSets\LoanStats3d.csv"
OUT= LoanStats3d
DBMS=CSV
REPLACE;
GETNAMES=YES;
RUN;

/*Convert TO number*/
DATA LoanStats3a;
SET LoanStats3a;
	new_mths_since_last_record = INPUT(mths_since_last_record, BEST12.);
new_mths_since_last_major_derog = INPUT(mths_since_last_major_derog, BEST12.);
DROP mths_since_last_record mths_since_last_major_derog;
RENAME new_mths_since_last_record = mths_since_last_record
	   new_mths_since_last_major_derog = mths_since_last_major_derog;	
RUN;

/*Set the Flag Parameter*/
DATA CombinedLoanDataSet;
SET LOANSTATS3A LOANSTATS3B LOANSTATS3C LOANSTATS3D;
IF LENGTH(ISSUE_D) = 6
THEN
    FYEAR = ("20" || SUBSTR(ISSUE_D,1,2)) + 0;
ELSE
    FYEAR = ("200" || SUBSTR(ISSUE_D,1,1)) +0;

IF LOAN_STATUS IN ("Charged Off","Default") THEN FLAG = 1;
ELSE IF LOAN_STATUS = "Fully Paid" THEN FLAG = 0;
ELSE DELETE;
*Explanation of the Variables and the sign;
/***********************************************************Annual Income to Total Loan Amount Ratio*****************************************************/
/********************************************************************************************************************************************************
 							If The ratio of Annual Income to Total Loan Amount increases, the probability of default decreases.
						Hence associate Negative Sign with it. Also with a higher annual income, the probability to default decreases.
*********************************************************************************************************************************************************/

INC_AMTLOAN = Annual_Inc/Loan_amnt;

/****************************************************************Number of Credit Lines to Annual Income*************************************************/
/********************************************************************************************************************************************************
 						If The ratio of OPEN number of credit lines to the annual income increases, the probability of default increases.
						Hence associate Positive Sign with it. Also higher the annual income, Higher the probability of open credit lines.
*********************************************************************************************************************************************************/
OPENACC_AMTINC = Open_acc/Annual_Inc;

/*****************************************************************Late Fee to Loan Amount****************************************************************/
/********************************************************************************************************************************************************
 						If The ratio of Late fee received to the Loan Amount taken increases, the probability of default increases.
						Hence associate Positive Sign with it. Also higher the late fee receieved as a part of the loan amount,
						Higher the probability of defaulting
*********************************************************************************************************************************************************/

LATEFEE_AMTLOAN = total_rec_late_fee/loan_amnt;

/*****************************************************************Total Payment to Annual Income*********************************************************/
/********************************************************************************************************************************************************
 							If The ratio of total payment made to annual income taken increases, the probability of default increases.
						Hence associate Positive Sign with it. Also higher the annual income, Higher the probability of open credit lines.
*********************************************************************************************************************************************************/
X_RATIO = total_pymnt/annual_inc;


/*****************************************************************Months Since Last Delinquency*********************************************************/
/********************************************************************************************************************************************************
 							If the number of months since his last delinquent record is high, it increases his/her probability of default.
						Accordingly, we associate a positive sign.
						mths_since_last_delinq
*********************************************************************************************************************************************************/



/*****************************************************************DTI ***********************************************************************************/
/********************************************************************************************************************************************************
 							If The Debt to Income Ratio increases the probability of defaultign increases. This direct variance, lets us give positive 
							Sign to this Variable.
							dti
*********************************************************************************************************************************************************/

/*****************************************************************Public_Rec ***********************************************************************************/
/********************************************************************************************************************************************************
 							Public Records increases the probability of default. Hence we associate the Positive sign with them.
							pub_rec
*********************************************************************************************************************************************************/

KEEP mths_since_last_delinq FYEAR dti INC_AMTLOAN  OPENACC_AMTINC LATEFEE_AMTLOAN Pub_rec X_RATIO FLAG;
RUN;

/*SORT the DATA set */
PROC SORT DATA = CombinedLoanDataSet;
BY FYEAR;
RUN;

/*Run the Logistic PROC */
PROC LOGISTIC DATA = CombinedLoanDataSet DESCENDING OUTEST = LOGISTIC;
    MODEL Flag = mths_since_last_delinq dti INC_AMTLOAN  OPENACC_AMTINC Pub_rec LATEFEE_AMTLOAN X_RATIO ;
RUN;


/**************************************************************Out of Sampling*******************************************************************************/

/*Calculate Separately dataset upto 2013*/
DATA YEARLYDATA;
SET CombinedLoanDataSet;
IF FYEAR < 2014;
RUN; 

/*RUN PROC Logistics*/
PROC LOGISTIC DATA = YEARLYDATA OUTEST = YEARLYDATA_RESULTS DESCENDING;
MODEL FLAG (EVENT = '1') = mths_since_last_delinq dti INC_AMTLOAN  OPENACC_AMTINC Pub_rec LATEFEE_AMTLOAN X_RATIO;
RUN;
QUIT;

/*Set all the Estimates to the B Values*/

DATA YEARLYDATA_RESULTS;
SET YEARLYDATA_RESULTS;

B_mths_since_last_delinq = mths_since_last_delinq;
B_dti = dti;
B_INC_AMTLOAN = INC_AMTLOAN;
/*B_INST_INC = INST_INC;*/
B_OPENACC_AMTINC = OPENACC_AMTINC;
B_Pub_rec = Pub_rec;
B_LATEFEE_AMTLOAN = LATEFEE_AMTLOAN;
B_X_RATIO = X_RATIO;

FYEAR = 2014;

KEEP INTERCEPT B_mths_since_last_delinq B_dti B_INC_AMTLOAN B_OPENACC_AMTINC B_Pub_rec B_LATEFEE_AMTLOAN B_X_RATIO FYEAR;
RUN;
QUIT;

/* Subset the DataSet*/
DATA YEAR_FIRSTYEAREXPAND;
SET CombinedLoanDataSet;
WHERE FYEAR = 2014;
RUN;

/* Merge the Expanded and Yearly Data Sets*/
DATA FINALWINDOW;
MERGE YEAR_FIRSTYEAREXPAND YEARLYDATA_RESULTS;
by fyear;
RUN;

/*Calculate using the Expanding Window*/

%macro yearlyAppend(YYY);

/*Follow the Same Procedure followed for 2015*/
DATA YEARLYDATA;
SET CombinedLoanDataSet;
IF FYEAR ^= &YYY;
DELETE;
RUN; 

PROC LOGISTIC DATA = YEARLYDATA OUTEST = YEARLYDATA_RESULTS DESCENDING NOPRINT;
MODEL FLAG (EVENT = '1') = mths_since_last_delinq dti INC_AMTLOAN  OPENACC_AMTINC Pub_rec LATEFEE_AMTLOAN X_RATIO;
RUN;
QUIT;

DATA YEARLYDATA_RESULTS;
SET YEARLYDATA_RESULTS;

B_mths_since_last_delinq = mths_since_last_delinq;
B_dti = dti;
B_INC_AMTLOAN = INC_AMTLOAN;
/*B_INST_INC = INST_INC;*/
B_OPENACC_AMTINC = OPENACC_AMTINC;
B_Pub_rec = Pub_rec;
B_LATEFEE_AMTLOAN = LATEFEE_AMTLOAN;
B_X_RATIO = X_RATIO;

FYEAR = &YYY;

RUN;
QUIT;

DATA YEAR_FIRSTYEAREXPAND;
SET CombinedLoanDataSet;
WHERE FYEAR = &YYY;
RUN;

DATA EXPANDINGWINDOW;
MERGE YEAR_FIRSTYEAREXPAND YEARLYDATA_RESULTS;
DROP _ESTTYPE_ _LNLIKE_ _NAME_ _STATUS_ _TYPE_ _LINK_;
BY FYEAR;
RUN;

PROC APPEND BASE=FINALWINDOW DATA=EXPANDINGWINDOW;
RUN;

%mend;

/*Run the Loop from 2014 to 2015 Fiscal Year*/
/*Can be Done using a single Statement as well to Modualrize the Code*/

%yearlyAppend(2015);


DATA FINALDATASET;
SET FINALWINDOW;
 P = (exp(intercept + B_mths_since_last_delinq * mths_since_last_delinq + B_dti * dti + B_INC_AMTLOAN * INC_AMTLOAN  + B_OPENACC_AMTINC * OPENACC_AMTINC + B_Pub_rec * Pub_rec + B_LATEFEE_AMTLOAN * LATEFEE_AMTLOAN +B_X_RATIO*X_RATIO )) / (1 + (exp(intercept + B_mths_since_last_delinq * mths_since_last_delinq + B_dti * dti + B_INC_AMTLOAN * INC_AMTLOAN + B_OPENACC_AMTINC * OPENACC_AMTINC + B_Pub_rec * Pub_rec + B_LATEFEE_AMTLOAN * LATEFEE_AMTLOAN +B_X_RATIO *X_RATIO)));
 IF P = . THEN DELETE;
RUN;


/*SORT THE Final Data Set*/
PROC SORT DATA = FINALDATASET;
    BY P;
RUN;


/*RANK THE FINALDATASET BY P*/
PROC RANK DATA = FINALDATASET GROUPS = 10 OUT = RANKS;
    VAR P;
    RANKS RANK_P;
RUN;

/*SORT THE RANKS DATA BY RANK_P Variable*/
PROC SORT DATA = RANKS;
    BY RANK_P;
RUN;

/*Means for the RANKS DataSet*/
PROC MEANS DATA=RANKS SUM;
	BY RANK_P;
	VAR FLAG;
RUN;

/*CUMULATIVE FREQUENCY*/
PROC FREQ DATA= RANKS ORDER=FREQ; WEIGHT FLAG;
	TABLES RANK_P;
RUN;

ODS PDF CLOSE;

