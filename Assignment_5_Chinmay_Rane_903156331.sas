/************************************************************************Start*******************************************************************************/

/* SET HOME Library PATH*/
LIBNAME QCFPrism "P:\Assignment4";

/* SET CRSP Library PATH*/
LIBNAME CRSPData "Q:\Data-ReadOnly\CRSP";

/* SET COMPUSTAT Library PATH*/
LIBNAME CompData "Q:\Data-ReadOnly\COMP";


/*GET FUNDA DATASET with Modifications*/
DATA QCFPrism.CompDataSet;
SET CompData.funda;
IF indfmt='INDL' and datafmt='STD' and popsrc='D' and fic='USA' and consol='C';

	CUSIP=substr(CUSIP,1,8);
 
	DLC=DLC*1000000;
	DLTT=DLTT*1000000;

	/*Lagging the Funda Data*/
	YEAR = FYEAR + 1;

	/*CALCULATING BANKUPTCY RATIOS */

	/***********************************************************Interest Coverage Ratio*********************************************************************/
	/********************************************************************************************************************************************************
	  A company that sustains earnings well above its interest requirements is in an excellent position to weather possible financial storms. 
	  A company that barely manages to cover its interest costs may easily fall into bankruptcy if its earnings suffer for even a single month.
	*********************************************************************************************************************************************************/

	INTRSTCVRGRATIO = EBIT /INTPN;

	/*****************************************************Debt to Asset Ratio - Financial Leverage *********************************************************/
	/********************************************************************************************************************************************************
	  The more debt a company holds relative to equity, the greater the risk the company could be forced into bankruptcy. The debt to total assets ratio is 
	  an indicator of financial leverage. It tells you the percentage of total assets that were financed by creditors, liabilities, debt.
	*********************************************************************************************************************************************************/

	FLEVERAGE = (DLC + DLTT)/AT;

	/***************************************************** Equity Leverage Ratio ****************************************************************************/
	/********************************************************************************************************************************************************
	  Equity Debt to ratio indicates how much debt a company is using to finance its assets relative to the amount of value represented in shareholders’ 
	  equity. The total liabilities as a part of Shareholder's equity is a potential measure for numerator of the bankruptcy of the given firm.
	*********************************************************************************************************************************************************/
	ELEVERAGE = LT/SEQ;

	/****************************************************** Liquidity Ratio *********************************************************************************/
	/********************************************************************************************************************************************************
	  The Working Capital to Total Assets ratio measures a company’s ability to cover its short term financial obligations. Net Working Capital to Total 
	  Assets ratio is defined as the net current assets (or net working capital) of a corporation expressed as a percentage of its total assets.
	*********************************************************************************************************************************************************/	
	
	LIQ = WCAP/AT;

	/****************************************************** Altman Z Score - B Component*********************************************************************/
	/********************************************************************************************************************************************************
	  The ratio of retained earnings to total assets helps measure the extent to which a company relies on debt, or leverage. The lower the ratio, the more a 
	  company is funding assets by borrowing instead of through retained earnings which, again, increases the risk of bankruptcy if the firm cannot meet its 
	  debt obligations.
	*********************************************************************************************************************************************************/
	ZSCORE = RE/AT;

	
	/****************************************************** Turnover Ratio **********************************************************************************/
	/********************************************************************************************************************************************************
	  An increase in sales will necessitate more operating assets at some point.Conversely, an inadequate sales volume may call for reduced investment.
	  It indicates how ow many times a company's inventory is sold and replaced over a period. 
	*********************************************************************************************************************************************************/
	TRNOVER = SALE/AT;

	/****************************************************** Current Ratio ***********************************************************************************/
	/********************************************************************************************************************************************************
	  The current ratio is a financial ratio that investors and analysts use to examine the liquidity of a company and its ability to pay short-term 
	  liabilities (debt and payables) with its short-term assets (cash, inventory, receivables).
	*********************************************************************************************************************************************************/
	CURRENTRATIO = ACT/LCT;


	/****************************************************** Return on Asset Ratio ***************************************************************************/
	/********************************************************************************************************************************************************
	  An indicator of how profitable a company is relative to its total assets. ROA gives an idea as to how efficient management is at using its assets to
	  generate earnings. Calculated by dividing a company's annual earnings by its total assets.
	*********************************************************************************************************************************************************/
	ROA = NI/AT;

	/*********************************************************  Quick Ratio  ********************************************************************************/
	/********************************************************************************************************************************************************
	  Purpose of the Acid Test ratio/ Quick Ratio is to measure a company's ability to take readily available assets and use them to pay currently outstanding 
	  bills and other liabilities.The result therefore indicates whether a company has any potential immediate cash-flow issues that could cause a short-term 
	  liquidity crisis.
	*********************************************************************************************************************************************************/
	QUICKRATIO = (ACT - INVT)/LCT;  


	IF 1961<=year<=2014;
		KEEP GVKEY YEAR DATADATE CUSIP INTRSTCVRGRATIO FLEVERAGE ELEVERAGE LIQ ZSCORE TRNOVER CURRENTRATIO ROA QUICKRATIO;	
RUN;

/*SORT FUNDA DataSet by CUSIP and Year*/
PROC SORT DATA = QCFPrism.CompDataSet;
	 BY CUSIP YEAR;
RUN;

/*GET CRSP DATASET with Modifications*/
DATA CRSPDataSet;
SET CRSPData.dsf;
	SHROUT = SHROUT * 1000;
	E = ABS(PRC) * SHROUT;
	YEAR = year(DATE) + 1;
	IF 1961<=YEAR<=2014;
		KEEP CUSIP PERMNO DATE PRC SHROUT RET E YEAR ;
RUN;


/*SORT CRSP by CUSIP and Year*/
PROC SORT DATA = CRSPDataSet;
	 BY CUSIP YEAR;
RUN;

/*CUMULATIVE Annual Return and Standard Deviation Calculation*/
/*Compress the Daily DATA to annual Data*/

/********************************************************* SIGMA E ***** ********************************************************************************/
/********************************************************************************************************************************************************
  SIGMAE is the volatality of the Asset Stock Price. It is an important indicator for the bankruptcy of the firm as a upward and downward pattern. 
  Volatility and Bankruptcy exhibit a positive correlation, meaning that large changes in stock price are often accompanied by large changes in patterns.
 *********************************************************************************************************************************************************/
PROC SQL;
	CREATE TABLE DSF AS
	SELECT CUSIP, AVG(E) AS E, EXP(SUM(LOG(1+RET)))-1 AS ANNRET,DATE, YEAR, STD(RET)*SQRT(250) AS SIGMAE, PERMNO
	FROM CRSPDataSet
	GROUP BY PERMNO, YEAR;
QUIT;

/*Remove Duplicates*/
PROC SORT DATA=DSF OUT = QCFPrism.DSFCLEAN NODUPKEY;
BY CUSIP YEAR;
RUN;


/*Import Bankruptcy Data*/
PROC IMPORT DATAFILE="Q:\Data-ReadOnly\SurvivalAnalysis\BR1964_2014.csv"
OUT= QCFPrism.SurvivalAnalysisData
DBMS=CSV
REPLACE;
GETNAMES=YES;
RUN;


/*Set the Year*/
DATA QCFPrism.SurvivalAnalysisData;
SET QCFPrism.SurvivalAnalysisData;
YEAR = YEAR(BANKRUPTCY_DT);
RUN;

/*SORT Clean DSF DataSet*/
PROC SORT DATA = QCFPrism.DSFCLEAN;
BY PERMNO;
RUN;

/*SORT Survival Analysis DataSet*/
PROC SORT DATA = QCFPrism.SurvivalAnalysisData;
BY PERMNO ;
RUN;

/*Merging Data from Clean DSF and Survival Analysis DataSet*/

PROC SQL;
CREATE TABLE QCFPrism.DSFSurvival AS

SELECT DSFCLEAN.YEAR, DSFCLEAN.PERMNO, DSFCLEAN.DATE, CUSIP, ANNRET,  E, SIGMAE,
	   SurvivalAnalysisData.PERMNO, SurvivalAnalysisData.YEAR, BANKRUPTCY_DT

FROM  QCFPrism.SurvivalAnalysisData AS SurvivalAnalysisData RIGHT JOIN QCFPrism.DSFCLEAN AS DSFCLEAN

ON SurvivalAnalysisData.PERMNO = DSFCLEAN.PERMNO AND SurvivalAnalysisData.YEAR = DSFCLEAN.YEAR

ORDER BY SurvivalAnalysisData.PERMNO,SurvivalAnalysisData.YEAR;

QUIT;

/*Sort the Merged Data Set by CUSIP and YEAR*/
PROC SORT DATA = QCFPrism.DSFSurvival;
BY CUSIP YEAR;
RUN;


/*MERGE DSF SURVIVAL and FUNDA*/

PROC SQL;
CREATE TABLE QCFPrism.CompuStatDSFSurvival AS

SELECT DSFSurvival.YEAR, DSFSurvival.PERMNO, DSFSurvival.DATE,DSFSurvival.CUSIP, ANNRET,  E, SIGMAE, BANKRUPTCY_DT,
	   CompDataSet.YEAR, GVKEY,  CompDataSet.YEAR, DATADATE, CompDataSet.CUSIP, INTRSTCVRGRATIO, FLEVERAGE, ELEVERAGE, LIQ, ZSCORE, TRNOVER, CURRENTRATIO, ROA, QUICKRATIO, LT

FROM  QCFPrism.DSFSurvival AS DSFSurvival LEFT JOIN QCFPrism.CompDataSet AS CompDataSet

ON DSFSurvival.CUSIP = CompDataSet.CUSIP AND DSFSurvival.YEAR = CompDataSet.YEAR

ORDER BY DSFSurvival.CUSIP,DSFSurvival.YEAR;

QUIT;

/*SORT descending by Year for encoutnering case scenarios addressed below*/
PROC SORT DATA = QCFPrism.CompuStatDSFSurvival;
BY PERMNO DESCENDING YEAR;


/* Case 1 : Bankruptcy Year is Less than YEAR in the data set it is available till.
   Case 2 : Bankruptcy Year is more than the Year in the DataSet is is available till.
   Case 3 : Bankruptcy year is equal to the Year in the DataSet is Available in

   Compare PermNo with the one previous to draw a distinction if a Bankruptcy year exists
   And Accordingly assign the flag variable.
*/

DATA QCFPrism.CompuStatDSFSurvival;
SET QCFPrism.CompuStatDSFSurvival;

IF GVKEY = . THEN DELETE;

IF YEAR(BANKRUPTCY_DT)^=. and YEAR > YEAR(BANKRUPTCY_DT) 
THEN
	delete;	

IF PERMNO ^= LAG(PERMNO) AND YEAR(BANKRUPTCY_DT)^=.
THEN 
	FLAG = 1;
else FLAG = 0;

RUN;

/*Computing Descriptive stats for the explanatory variables*/
ODS PDF FILE = "P:\Assignment5\Assignment5.pdf";

PROC MEANS DATA= QCFPrism.CompuStatDSFSurvival N MEAN P25 MEDIAN P75 STD MIN MAX ;
TITLE 'Descriptive Statistics FOR Variables';
VAR INTRSTCVRGRATIO FLEVERAGE ELEVERAGE LIQ ZSCORE TRNOVER CURRENTRATIO ROA QUICKRATIO SIGMAE;
OUTPUT N= MIN= MAX= MEAN= STDDEV= MEDIAN=;
RUN;


/*Running PROC LOGISTIC on the Data Set*/
TITLE 'PROC LOGISTIC for FLAG';
PROC LOGISTIC DATA = QCFPrism.CompuStatDSFSurvival DESCENDING OUTEST = RESULTS;
MODEL FLAG = INTRSTCVRGRATIO FLEVERAGE ELEVERAGE LIQ ZSCORE TRNOVER CURRENTRATIO ROA QUICKRATIO SIGMAE;
RUN;
QUIT;
 
/******************************************************************End In Sampling***************************************************************************/



/**************************************************************Out of Sampling*******************************************************************************/

/*Calculate Separately for 1991 and run through 1992 TO 2014*/
DATA QCFPrism.YEARLYDATA;
SET QCFPrism.CompuStatDSFSurvival;
IF YEAR < 1991;
RUN; 

/*RUN PROC Logistics*/
PROC LOGISTIC DATA = QCFPrism.YEARLYDATA OUTEST = QCFPrism.YEARLYDATA_RESULTS DESCENDING NOPRINT;
MODEL FLAG (EVENT = '1') = INTRSTCVRGRATIO FLEVERAGE ELEVERAGE LIQ ZSCORE TRNOVER CURRENTRATIO ROA QUICKRATIO SIGMAE;
RUN;
QUIT;

/*Set all the Estimates to the B Values*/

DATA QCFPrism.YEARLYDATA_RESULTS;
SET QCFPrism.YEARLYDATA_RESULTS;

B_INTRSTCVRGRATIO = INTRSTCVRGRATIO;
B_FLEVERAGE = FLEVERAGE;
B_ELEVERAGE = ELEVERAGE;
B_LIQ = LIQ;
B_ZSCORE = ZSCORE;
B_TRNOVER = TRNOVER;
B_CURRENTRATIO = CURRENTRATIO;
B_ROA = ROA;
B_QUICKRATIO = QUICKRATIO;
B_SIGMAE = SIGMAE;

NUM = 1;
YEAR = 1991;

KEEP INTERCEPT B_INTRSTCVRGRATIO B_FLEVERAGE B_ELEVERAGE B_LIQ B_ZSCORE B_TRNOVER B_CURRENTRATIO B_ROA B_QUICKRATIO B_SIGMAE NUM YEAR;
RUN;
QUIT;

/* Subset the DataSet*/
DATA QCFPrism.YEAR_FIRSTYEAREXPAND;
SET QCFPrism.CompuStatDSFSurvival;
WHERE YEAR = 1991;
RUN;

/* Merge the Expanded and Yearly Data Sets*/
DATA QCFPrism.FINALWINDOW;
MERGE QCFPrism.YEAR_FIRSTYEAREXPAND QCFPrism.YEARLYDATA_RESULTS;
by year;
RUN;

/*Calculate using the Expandign Window*/

%macro yearlyAppend(YYY);

/*Follow the Same Procedure followed for 1991*/
DATA QCFPrism.YEARLYDATA;
SET QCFPrism.CompuStatDSFSurvival;
IF YEAR < &YYY;
RUN; 

PROC LOGISTIC DATA = QCFPrism.YEARLYDATA OUTEST = QCFPrism.YEARLYDATA_RESULTS DESCENDING NOPRINT;
MODEL FLAG (EVENT = '1') = INTRSTCVRGRATIO FLEVERAGE ELEVERAGE LIQ ZSCORE TRNOVER CURRENTRATIO ROA QUICKRATIO SIGMAE;
RUN;
QUIT;

DATA QCFPrism.YEARLYDATA_RESULTS;
SET QCFPrism.YEARLYDATA_RESULTS;

B_INTRSTCVRGRATIO = INTRSTCVRGRATIO;
B_FLEVERAGE = FLEVERAGE;
B_ELEVERAGE = ELEVERAGE;
B_LIQ = LIQ;
B_ZSCORE = ZSCORE;
B_TRNOVER = TRNOVER;
B_CURRENTRATIO = CURRENTRATIO;
B_ROA = ROA;
B_QUICKRATIO = QUICKRATIO;
B_SIGMAE = SIGMAE;

NUM = 1;
YEAR = &YYY;

RUN;
QUIT;

DATA QCFPrism.YEAR_FIRSTYEAREXPAND;
SET QCFPrism.CompuStatDSFSurvival;
WHERE YEAR = &YYY;
RUN;

DATA QCFPrism.EXPANDINGWINDOW;
MERGE QCFPrism.YEAR_FIRSTYEAREXPAND QCFPrism.YEARLYDATA_RESULTS;
DROP _ESTTYPE_ _LNLIKE_ _NAME_ _STATUS_ _TYPE_ _LINK_;
BY YEAR;
RUN;

PROC APPEND BASE=QCFPrism.FINALWINDOW DATA=QCFPrism.EXPANDINGWINDOW;
RUN;

%mend;

/*Run the Loop from 1992 to 2014*/
%macro repeatYearly;
	%do i = 1992 %to 2014;
		%yearlyAppend(&i);
		%end;
%mend;

/*Call the MACRO*/
%repeatYearly;


/*Calculate the Probability*/
/* P = exp( Factor / (1+ Factor))*/

DATA QCFPrism.FINALDATASET;
SET QCFPrism.FINALWINDOW;
 P = (exp(intercept + B_INTRSTCVRGRATIO * INTRSTCVRGRATIO + B_FLEVERAGE * FLEVERAGE + B_ELEVERAGE * ELEVERAGE + B_LIQ * LIQ + B_ZSCORE * ZSCORE + B_TRNOVER * TRNOVER + B_CURRENTRATIO * CURRENTRATIO + 
 		B_ROA * ROA + B_QUICKRATIO * QUICKRATIO + B_SIGMAE * SIGMAE)) / (1 + (exp(intercept + B_INTRSTCVRGRATIO * INTRSTCVRGRATIO + B_FLEVERAGE * FLEVERAGE + B_ELEVERAGE * ELEVERAGE + B_LIQ * LIQ + B_ZSCORE * ZSCORE + B_TRNOVER * TRNOVER + B_CURRENTRATIO * CURRENTRATIO + 
 		B_ROA * ROA + B_QUICKRATIO * QUICKRATIO + B_SIGMAE * SIGMAE )));
 IF P = . THEN DELETE;
RUN;

/*SORT DATA BY P*/
PROC SORT DATA = QCFPrism.FINALDATASET;
BY P;
RUN;

/*RANK THE DATA FOR DECILE GROUPS OF 10*/
TITLE "RANKS FOR ALL THE VARIABLES";
PROC RANK DATA= QCFPrism.FINALDATASET GROUPS = 10 OUT = QCFPrism.Ranks;
VAR P;
RANKS RANK_P;
RUN;

/*SORT BY FLAG*/
PROC SORT DATA = QCFPrism.Ranks ;
BY FLAG;
RUN;

/*SORT BY P FOR Cumulative % in each ranks*/
PROC SORT DATA = QCFPrism.Ranks;
BY P;
RUN; 

/*Cumulative % in each ranks*/
TITLE "CUMULATIVE SUM FOR ALL VARIABLES";
PROC MEANS DATA=QCFPrism.Ranks SUM;
BY RANK_P;
VAR FLAG;
OUTPUT OUT = QCFPrism.RANK_DATASET SUM=;
RUN;

PROC SORT DATA=QCFPrism.RANK_DATASET;
BY DESCENDING FLAG ;
run;

/**************************Cumulative Frequency Distribution************************************/

Title "Cumulative Frequency";

PROC FREQ DATA=QCFPrism.RANK_DATASET ORDER=FREQ; WEIGHT FLAG;

 TABLES RANK_P;
RUN;

ODS PDF CLOSE;

/******************************************************************End Out of Sampling ***************************************************************************************/